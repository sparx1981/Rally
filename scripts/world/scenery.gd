class_name Scenery
extends Node3D
## Places scenery in tight groups of 4-8 different pieces along the stage and draws it one of two ways:
##  * Pop-up ON:  each piece is a hinged node that lies flat and rises on the paper flap spring as the
##                player approaches (and folds down behind them).
##  * Pop-up OFF: pieces stand still and are batched into chunked MultiMeshes (far fewer draw calls).
## The toggle exists so the pop-up effect can be judged for distraction and performance.

const CHUNK := 160.0
const RISE_AHEAD := 70.0
const FALL_BEHIND := 34.0

var track: Track
var stage_def: Dictionary
var material: Material
var lib := {}                 # kind -> Array of variant dicts
var placements: Array = []    # {kind, var, pos(Vector2), yaw, out_yaw, s, delay}
var obstacles := {}           # Vector2i cell -> Array of [x, z, r]
var puddles: Array = []       # [Vector2 pos, radius]
var popups := true
var draw_distance := 110.0

var _pivots: Array[Node3D] = []
var _springs: Array[FlapSpring] = []
var _s_sorted := PackedFloat32Array()
var _active := {}
var _content: Node3D


func setup(t: Track, sdef: Dictionary, mat: Material, density: float, ddist: float, use_popups: bool) -> void:
	track = t
	stage_def = sdef
	material = mat
	draw_distance = ddist
	popups = use_popups
	_build_library()
	_place(density)
	rebuild_visuals(use_popups)


func _build_library() -> void:
	var pal: Dictionary = stage_def["pal"]
	var kinds: Dictionary = stage_def["kinds"]
	var seed_base: int = stage_def["seed"]
	var all_kinds := kinds.keys()
	if not "spectators" in all_kinds:
		all_kinds.append("spectators")
	for k in all_kinds:
		var vars: Array = []
		var nv := 2 if k in ["house", "barn", "cabin", "mesa", "spectators"] else 3
		if k == "house":
			nv = 4
		for i in nv:
			vars.append(Pieces.make(k, pal, seed_base * 31 + hash(k) % 1000 + i * 101))
		lib[k] = vars
	lib["_chev_l"] = [{"mesh": Pieces.chevron(-1.0), "r": 1.3, "solid": true, "h": 2.0, "size": 0.4}]
	lib["_chev_r"] = [{"mesh": Pieces.chevron(1.0), "r": 1.3, "solid": true, "h": 2.0, "size": 0.4}]


func _weighted_kinds() -> Array:
	var out: Array = []
	var kinds: Dictionary = stage_def["kinds"]
	for k in kinds.keys():
		for i in int(kinds[k]):
			out.append(k)
	return out


func _place(density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stage_def["seed"]) * 13 + 5
	var pool := _weighted_kinds()
	var w := track.width
	var big := ["house", "barn", "cabin", "mesa", "tent"]
	var spacing := 7.5 / clampf(density, 0.2, 1.0)
	var s := 4.0
	while s < track.length - 4.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue
			var i := track.index_at(s + rng.randf_range(-3.0, 3.0))
			var lat = side * (w * 0.5 + 3.0 + pow(rng.randf(), 1.6) * 34.0)
			var center = track.pts[i] + track.nrm[i] * lat
			var count := int(rng.randi_range(4, 8) * lerpf(0.6, 1.0, density))
			var used := {}
			for c in count:
				var kind: String = pool[rng.randi() % pool.size()]
				var tries := 0
				while used.has(kind) and tries < 4:
					kind = pool[rng.randi() % pool.size()]
					tries += 1
				used[kind] = true
				var spread := 6.5 if kind in big else 4.5
				var p = center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
				_try_add(kind, p, rng, s, kind in big)
		s += spacing * rng.randf_range(0.7, 1.3)
	# Chevron boards on the outside of tight bends, spectators at some corners.
	for cn in track.corners:
		if int(cn["sev"]) <= 3:
			var ia: int = cn["apex"]
			var dirv: float = cn["dir"]
			# nrm points screen-right relative to travel, so the outside of a left bend is +nrm.
			var out_lat := (w * 0.5 + 2.6) * (1.0 if dirv < 0.0 else -1.0)
			var ie := clampi(ia - 6, 0, track.pts.size() - 1)
			var pos := track.pts[ie] + track.nrm[ie] * out_lat
			var face := track.heading_at(ie) + PI   # face the incoming car
			_add("_chev_l" if dirv < 0.0 else "_chev_r", 0, pos, face, track.dist[ie], rng, true)
			if rng.randf() < 0.6:
				var sp := track.pts[ia] + track.nrm[ia] * (out_lat + signf(out_lat) * 4.0)
				_try_add("spectators", sp, rng, track.dist[ia], false)
	# Puddles on wet stages.
	var wd: Dictionary = Catalog.weather(stage_def["weather"])
	if wd["kind"] == "rain":
		var ps := 40.0
		while ps < track.length - 40.0:
			var i := track.index_at(ps)
			var lat := rng.randf_range(-w * 0.32, w * 0.32)
			var pos := track.pts[i] + track.nrm[i] * lat
			puddles.append([pos, rng.randf_range(1.1, 1.9)])
			ps += rng.randf_range(25.0, 70.0)
	placements.sort_custom(func(a, b): return float(a["s"]) + float(a["delay"]) < float(b["s"]) + float(b["delay"]))


func _try_add(kind: String, p: Vector2, rng: RandomNumberGenerator, s: float, big: bool) -> void:
	var vars: Array = lib[kind]
	var vi := rng.randi() % vars.size()
	var r: float = vars[vi]["r"]
	var need := track.width * 0.5 + 1.6 + r + (2.5 if big else 0.0)
	if track.clearance(p) < need:
		return
	# Keep pieces from cutting into each other.
	if _overlaps(p, r * 0.8):
		return
	_add(kind, vi, p, rng.randf() * TAU, s, rng, bool(vars[vi]["solid"]))


func _overlaps(p: Vector2, r: float) -> bool:
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if obstacles.has(key):
				for o in obstacles[key]:
					if Vector2(o[0], o[1]).distance_to(p) < r + float(o[2]) * 0.8:
						return true
	return false


func _add(kind: String, vi: int, p: Vector2, yaw: float, s: float, rng: RandomNumberGenerator, solid: bool) -> void:
	var r: float = lib[kind][vi]["r"]
	# Fold direction: away from the road.
	var hit: Array = track.project(p, track.index_at(s))
	var tg: Vector2 = hit[3]
	var lat: float = hit[2]
	var away := Vector2(-tg.y, tg.x) * signf(lat if lat != 0.0 else 1.0)
	var out_yaw := atan2(away.x, away.y)
	placements.append({"kind": kind, "var": vi, "pos": p, "yaw": yaw, "out_yaw": out_yaw, "s": s,
		"delay": rng.randf_range(0.0, 14.0)})
	# Every piece registers for overlap tests; only solid ones collide with cars.
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not obstacles.has(c):
		obstacles[c] = []
	obstacles[c].append([p.x, p.y, r if solid else -r])


## Solid obstacles near p (for car collisions): Array of [x, z, r].
func solids_near(p: Vector2) -> Array:
	var out: Array = []
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if obstacles.has(key):
				for o in obstacles[key]:
					if float(o[2]) > 0.0:
						out.append(o)
	return out


func rebuild_visuals(use_popups: bool) -> void:
	popups = use_popups
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	_pivots.clear()
	_springs.clear()
	_active.clear()
	_s_sorted = PackedFloat32Array()
	if popups:
		_build_popups()
	else:
		_build_static()


func _piece_mesh(pl: Dictionary) -> Mesh:
	return lib[pl["kind"]][pl["var"]]["mesh"]


func _build_popups() -> void:
	for pl in placements:
		var pivot := Node3D.new()
		var p: Vector2 = pl["pos"]
		pivot.position = Vector3(p.x, 0.02, p.y)
		pivot.rotation.y = pl["out_yaw"]
		var mi := MeshInstance3D.new()
		mi.mesh = _piece_mesh(pl)
		mi.material_override = material
		mi.rotation.y = float(pl["yaw"]) - float(pl["out_yaw"])
		mi.visibility_range_end = draw_distance
		pivot.add_child(mi)
		pivot.rotation.x = PI * 0.5
		pivot.visible = false
		_content.add_child(pivot)
		var size: float = lib[pl["kind"]][pl["var"]]["size"]
		var sp := FlapSpring.new(size, randf_range(-1.0, 1.0))
		sp.reset(0.0)
		_pivots.append(pivot)
		_springs.append(sp)
		_s_sorted.append(float(pl["s"]) + float(pl["delay"]))


func _build_static() -> void:
	# Group by chunk of the stage and by mesh.
	var groups := {}
	for pl in placements:
		var key := "%d|%s|%d" % [int(float(pl["s"]) / CHUNK), pl["kind"], pl["var"]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(pl)
	for key in groups.keys():
		var arr: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _piece_mesh(arr[0])
		mm.instance_count = arr.size()
		var center := Vector3.ZERO
		for pl in arr:
			var p: Vector2 = pl["pos"]
			center += Vector3(p.x, 0, p.y)
		center /= arr.size()
		for i in arr.size():
			var p: Vector2 = arr[i]["pos"]
			var t := Transform3D(Basis(Vector3.UP, float(arr[i]["yaw"])), Vector3(p.x, 0.02, p.y) - center)
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.position = center
		mmi.visibility_range_end = draw_distance + CHUNK * 0.5
		_content.add_child(mmi)


## Drives the pop-ups from the player's stage distance `s`.
func update(s: float, dt: float) -> void:
	if not popups or _springs.is_empty():
		return
	var lo := _bsearch(s - FALL_BEHIND - 40.0)
	var hi := _bsearch(s + RISE_AHEAD + 20.0)
	var rose := false
	for i in range(lo, hi):
		var ps := _s_sorted[i]
		var want := 1.0 if (ps > s - FALL_BEHIND and ps < s + RISE_AHEAD) else 0.0
		var sp := _springs[i]
		if sp.target != want:
			if want == 1.0 and sp.p < 0.05:
				rose = true
			sp.set_target(want)
			_active[i] = true
	for i in _active.keys():
		var sp: FlapSpring = _springs[i]
		var p := sp.step(dt)
		_pivots[i].rotation.x = (1.0 - p) * PI * 0.5
		_pivots[i].visible = p > 0.01
		if sp.at_rest:
			_active.erase(i)
	if rose:
		Sfx.flap(-18.0)


## Stand everything up immediately (title screen / camera fly-by).
func raise_all() -> void:
	for i in _springs.size():
		_springs[i].reset(1.0)
		_springs[i].target = 1.0
		_pivots[i].rotation.x = 0.0
		_pivots[i].visible = true


func _bsearch(v: float) -> int:
	var lo := 0
	var hi := _s_sorted.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _s_sorted[mid] < v:
			lo = mid + 1
		else:
			hi = mid
	return lo
