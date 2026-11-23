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
var obstacles := {}           # Vector2i cell -> Array of [x, z, r (<0 = not solid), placement index, breakable]
var broken := {}              # placement index -> true
const BREAKABLE := ["post", "tape", "bale", "crates", "tuft", "flowers", "bush", "snowbank", "heather", "tent", "cactus",
	"_chev_l", "_chev_r", "banner", "board", "warn", "km", "flag"]
var puddles: Array = []       # [Vector2 pos, radius]
var popups := true
var draw_distance := 110.0

var _pivots: Array[Node3D] = []
var _springs: Array[FlapSpring] = []
var _ppos := PackedVector2Array()
var _jitter := PackedFloat32Array()
var _pgrid := {}            # Vector2i (16-unit cells) -> PackedInt32Array of piece indices
var _up := {}               # pieces currently standing or rising
var _active := {}           # pieces whose spring is moving
const PCELL := 16.0
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
	for extra in ["spectators", "post", "tape", "bale", "rock", "logs", "banner", "board", "warn", "km", "flag"]:
		if not extra in all_kinds:
			all_kinds.append(extra)
	for k in all_kinds:
		var vars: Array = []
		var nv := 2 if k in ["house", "barn", "cabin", "mesa", "spectators"] else 3
		if k == "house":
			nv = 4
		if k in ["banner", "board", "flag"]:
			nv = 6
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
	var spacing := 5.5 / clampf(density, 0.2, 1.0)
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
	_place_hazard_props(rng)
	_place_signage(rng)
	# Puddles on wet stages.
	var wd: Dictionary = Catalog.weather(stage_def["weather"])
	if wd["kind"] == "rain":
		var ps := 40.0
		while ps < track.length - 40.0:
			var i := track.index_at(ps)
			var lat := rng.randf_range(-w * 0.32, w * 0.32)
			var pos := track.pts[i] + track.nrm[i] * lat
			if track.heights[i] <= 0.0 and track.patch_at(ps, lat).is_empty():
				puddles.append([pos, rng.randf_range(1.1, 1.9)])
			ps += rng.randf_range(25.0, 70.0)
	placements.sort_custom(func(a, b): return float(a["s"]) + float(a["delay"]) < float(b["s"]) + float(b["delay"]))
	# Link obstacle entries to their placement index (after sorting).
	var by_pos := {}
	for i in placements.size():
		var pp: Vector2 = placements[i]["pos"]
		by_pos[pp] = i
		placements[i]["_idx"] = i
	for key in obstacles.keys():
		for o in obstacles[key]:
			o[3] = by_pos.get(Vector2(o[0], o[1]), -1)


## Rally-game roadside: marker posts along the edges, rocks / logs / bales on the inside of tight
## bends (punishing cut corners), hay-bale chicanes, and taped-off crowds at jumps and splashes.
func _place_hazard_props(rng: RandomNumberGenerator) -> void:
	var w := track.width
	var ps := 20.0
	while ps < track.length - 20.0:
		var i := track.index_at(ps)
		if track.heights[i] <= 0.0 and track.feature_at(ps, "splash", 4.0).is_empty():
			for side in [-1.0, 1.0]:
				var pos = track.pts[i] + track.nrm[i] * side * (w * 0.5 + 0.9)
				if track.clearance(pos) >= w * 0.5 + 0.6:
					_add("post", 0, pos, rng.randf() * TAU, ps, rng, true)
		ps += 26.0
	for cn in track.corners:
		if int(cn["sev"]) > 3:
			continue
		var dirv: float = cn["dir"]
		var inside := -1.0 if dirv < 0.0 else 1.0     # inside of a left bend is -nrm
		var ia: int = cn["apex"]
		for off in [-4, 0, 4]:
			var j := clampi(ia + off, 0, track.pts.size() - 1)
			var kind: String = ["rock", "logs", "bale"][rng.randi() % 3]
			var r: float = lib[kind][0]["r"]
			var pos := track.pts[j] + track.nrm[j] * (inside * (w * 0.5 + 0.7 + r * 0.6))
			if track.clearance(pos) >= w * 0.5 + 0.3:
				_add(kind, 0, pos, track.heading_at(j) + rng.randf_range(-0.3, 0.3), track.dist[j], rng, true)
	for f in track.features:
		var sc: float = f["s"]
		match f["type"]:
			"chicane":
				var side: float = f["side"]
				for pair in [[sc, side], [sc + 16.0, -side]]:
					var j := track.index_at(pair[0])
					var lat := float(pair[1]) * (w * 0.5 + 0.4)
					while absf(lat) > 0.9:
						var pos := track.pts[j] + track.nrm[j] * lat
						_add("bale", 0, pos, track.heading_at(j) + PI * 0.5, track.dist[j], rng, true)
						lat -= signf(lat) * 1.5
			"jump", "splash":
				for side in [-1.0, 1.0]:
					var j := track.index_at(sc + 6.0)
					var tp = track.pts[j] + track.nrm[j] * side * (w * 0.5 + 3.0)
					_add("tape", 0, tp, track.heading_at(j) + PI * 0.5, track.dist[j], rng, false)
					var sp = track.pts[j] + track.nrm[j] * side * (w * 0.5 + 5.0)
					_add("spectators", rng.randi() % lib["spectators"].size(), sp, track.heading_at(j) + side * PI * 0.5, track.dist[j], rng, true)


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


func _add(kind: String, vi: int, p: Vector2, yaw: float, s: float, rng: RandomNumberGenerator, solid: bool, text := "") -> void:
	var r: float = lib[kind][vi]["r"]
	# Fold direction: away from the road.
	var hit: Array = track.project(p, track.index_at(s))
	var tg: Vector2 = hit[3]
	var lat: float = hit[2]
	var away := Vector2(-tg.y, tg.x) * signf(lat if lat != 0.0 else 1.0)
	var out_yaw := atan2(away.x, away.y)
	placements.append({"kind": kind, "var": vi, "pos": p, "yaw": yaw, "out_yaw": out_yaw, "s": s,
		"delay": rng.randf_range(0.0, 14.0), "text": text})
	# Every piece registers for overlap tests; solid ones collide, small ones break.
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not obstacles.has(c):
		obstacles[c] = []
	obstacles[c].append([p.x, p.y, r if solid else -r, -1, kind in BREAKABLE])


## Rally furniture: sponsor banners and billboards along the stage, warning boards before every
## hazard, distance boards each kilometre, flags at the start and finish.
func _place_signage(rng: RandomNumberGenerator) -> void:
	var w := track.width
	var s := 60.0
	var side := 1.0
	while s < track.length - 60.0:
		var i := track.index_at(s)
		if track.feature_at(s, "splash", 10.0).is_empty() and track.heights[i] <= 0.0:
			var pos := track.pts[i] + track.nrm[i] * side * (w * 0.5 + 3.4)
			if track.clearance(pos) > w * 0.5 + 2.0:
				_add("banner", rng.randi() % 6, pos, track.heading_at(i) + PI + side * 0.35, s, rng, false)
			if rng.randf() < 0.45:
				var bp := track.pts[i] + track.nrm[i] * -side * (w * 0.5 + 8.0)
				if track.clearance(bp) > w * 0.5 + 5.0:
					_add("board", rng.randi() % 6, bp, track.heading_at(i) + PI - side * 0.3, s, rng, true)
		side = -side
		s += rng.randf_range(110.0, 170.0)
	var words := {"jump": "JUMP", "crest": "CREST", "splash": "WATER", "chicane": "CHICANE"}
	for f in track.features:
		var ws: float = float(f["s0"]) - 55.0
		var j := track.index_at(ws)
		var pos := track.pts[j] + track.nrm[j] * (w * 0.5 + 1.8)
		if track.clearance(pos) > w * 0.5 + 1.0:
			_add("warn", 0, pos, track.heading_at(j) + PI + 0.25, ws, rng, true, words.get(f["type"], "CAUTION"))
	var km := 1
	while km * 1000.0 < track.finish_s - 50.0:
		var j := track.index_at(track.start_s + km * 1000.0)
		var pos := track.pts[j] + track.nrm[j] * (w * 0.5 + 2.2)
		_add("km", 0, pos, track.heading_at(j) + PI + 0.25, track.dist[j], rng, true, "%d KM" % km)
		km += 1
	for at in [track.start_s + 6.0, track.finish_s + 8.0]:
		for k in 3:
			var j := track.index_at(at + k * 3.0)
			for sd in [-1.0, 1.0]:
				var pos = track.pts[j] + track.nrm[j] * sd * (w * 0.5 + 2.0 + k * 0.6)
				_add("flag", rng.randi() % 6, pos, track.heading_at(j) + PI * 0.5 * sd, track.dist[j], rng, false)
	var fj := track.index_at(track.finish_s - 60.0)
	_add("warn", 0, track.pts[fj] + track.nrm[fj] * (w * 0.5 + 1.8), track.heading_at(fj) + PI + 0.25, track.dist[fj], rng, true, "FINISH")


## Labels printed on a piece's cards.
func _make_labels(parent: Node3D, info: Dictionary, text: String) -> void:
	if not info.has("labels"):
		return
	for lb in info["labels"]:
		var l := Label3D.new()
		var t: String = lb["text"]
		l.text = text if t == "{TEXT}" else t
		l.font = PaperTheme.font()
		l.font_size = lb["size"]
		l.pixel_size = 0.009
		l.modulate = lb["color"]
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.position = lb["pos"]
		l.rotation = Vector3(float(lb.get("pitch", 0.0)), float(lb["yaw"]), 0.0)
		l.visibility_range_end = draw_distance * 0.7
		parent.add_child(l)


var _scared := {}


## Spectators jump back off the road edge when a car comes close.
func scare(p: Vector2) -> void:
	if not popups:
		return
	var c := Vector2i(floori(p.x / PCELL), floori(p.y / PCELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if not _pgrid.has(key):
				continue
			for i in _pgrid[key]:
				if _scared.has(i) or placements[i]["kind"] != "spectators":
					continue
				if _ppos[i].distance_to(p) < 11.0:
					_scared[i] = true
					var pv := _pivots[i]
					var away := Vector3(sin(float(placements[i]["out_yaw"])), 0, cos(float(placements[i]["out_yaw"])))
					var tw := pv.create_tween()
					tw.tween_property(pv, "position", pv.position + away * 2.5 + Vector3.UP * 0.6, 0.22).set_trans(Tween.TRANS_SINE)
					tw.tween_property(pv, "position", pv.position + away * 3.2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Props near p that a car can hit: Array of [x, z, r, index, breakable] (broken ones excluded).
func props_near(p: Vector2) -> Array:
	var out: Array = []
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if obstacles.has(key):
				for o in obstacles[key]:
					if (float(o[2]) > 0.0 or o[4]) and not broken.has(o[3]):
						out.append(o)
	return out


# --- breaking small props -------------------------------------------------------------------------

var _tumblers: Array = []
var _mm_map := {}   # placement index -> [MultiMesh, instance]


## Knock a small prop over: hide it and send a copy tumbling away from the car.
func break_piece(idx: int, car_vel: Vector2) -> void:
	if idx < 0 or broken.has(idx):
		return
	broken[idx] = true
	var pl: Dictionary = placements[idx]
	var p: Vector2 = pl["pos"]
	var start := Transform3D(Basis(Vector3.UP, float(pl["yaw"])), Vector3(p.x, _ground(p) + 0.02, p.y))
	if popups and idx < _pivots.size():
		start = _pivots[idx].get_child(0).global_transform
		_pivots[idx].visible = false
		_up.erase(idx)
		_active.erase(idx)
	elif _mm_map.has(idx):
		var mm: MultiMesh = _mm_map[idx][0]
		mm.set_instance_transform(_mm_map[idx][1], Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
	var mi := MeshInstance3D.new()
	mi.mesh = _piece_mesh(pl)
	mi.material_override = material
	add_child(mi)
	mi.global_transform = start
	_make_labels(mi, lib[pl["kind"]][pl["var"]], pl.get("text", ""))
	var dir := car_vel.normalized() if car_vel.length() > 0.5 else Vector2.UP
	var spd := clampf(car_vel.length() * 0.6, 3.0, 16.0)
	var v := Vector3(dir.x * spd + randf_range(-2, 2), randf_range(4.0, 7.0), dir.y * spd + randf_range(-2, 2))
	var axis := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
	_tumblers.append({"node": mi, "vel": v, "axis": axis, "spin": randf_range(5.0, 11.0), "rest": false})
	if _tumblers.size() > 40:
		var old: Dictionary = _tumblers.pop_front()
		(old["node"] as Node3D).queue_free()


func _process(delta: float) -> void:
	for t in _tumblers:
		if t["rest"]:
			continue
		var n: Node3D = t["node"]
		var v: Vector3 = t["vel"]
		v.y -= 22.0 * delta
		n.global_position += v * delta
		n.rotate(t["axis"], float(t["spin"]) * delta)
		var g := _ground(Vector2(n.global_position.x, n.global_position.z))
		if n.global_position.y < g + 0.05 and v.y < 0.0:
			if absf(v.y) > 4.0:
				v.y = -v.y * 0.3
				v.x *= 0.5
				v.z *= 0.5
				t["spin"] = float(t["spin"]) * 0.4
			else:
				# Comes to rest lying on its side, like a dropped card.
				n.global_position.y = g + 0.05
				var yaw := n.global_rotation.y
				n.global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
				t["rest"] = true
		t["vel"] = v


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


var _chimneys: Array = []   # [emitter or light, world position, piece index or -1]
var lights_on := false


func _add_chimneys() -> void:
	_chimneys.clear()
	var leak: Color = Catalog.weather(stage_def["weather"])["leak"]
	for i in placements.size():
		var pl: Dictionary = placements[i]
		var info: Dictionary = lib[pl["kind"]][pl["var"]]
		if lights_on and pl["kind"] == "lamp":
			var lp: Vector2 = pl["pos"]
			var ol := OmniLight3D.new()
			ol.light_color = Color("#ffb070")
			ol.light_energy = 2.2
			ol.omni_range = 11.0
			ol.omni_attenuation = 1.2
			ol.position = Vector3(lp.x, _ground(lp) + 3.6, lp.y)
			ol.visible = false
			_content.add_child(ol)
			_chimneys.append([ol, ol.position, -1])
			continue
		if not info.has("chimney"):
			continue
		var p: Vector2 = pl["pos"]
		var local: Vector3 = info["chimney"]
		var em := Puffs.make("chimney", Color("#d8d6d2"), leak)
		em.emitting = false
		var world := Transform3D(Basis(Vector3.UP, float(pl["yaw"])), Vector3(p.x, _ground(p), p.y)) * local
		if popups:
			var mi: Node3D = _pivots[i].get_child(0)
			mi.add_child(em)
			em.position = local
		else:
			_content.add_child(em)
			em.position = world
		_chimneys.append([em, world, i if popups else -1])


## Chimneys only smoke near the camera (and only once their house has unfolded).
func update_chimneys(center: Vector2, radius: float) -> void:
	for c in _chimneys:
		var wp: Vector3 = c[1]
		var near := Vector2(wp.x, wp.z).distance_to(center) < radius + 50.0
		var up: bool = c[2] < 0 or _springs[c[2]].p > 0.9
		if not is_instance_valid(c[0]):
			continue
		if c[0] is CPUParticles3D:
			(c[0] as CPUParticles3D).emitting = near and up
		else:
			(c[0] as Node3D).visible = Vector2(wp.x, wp.z).distance_to(center) < radius + 30.0


func rebuild_visuals(use_popups: bool) -> void:
	popups = use_popups
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	_pivots.clear()
	_springs.clear()
	_mm_map.clear()
	_active.clear()
	_up.clear()
	_pgrid.clear()
	_ppos = PackedVector2Array()
	_jitter = PackedFloat32Array()
	if popups:
		_build_popups()
	else:
		_build_static()
	_add_chimneys()


## Ground height under a piece (pieces beside the road stand on the landscape).
func _ground(p: Vector2) -> float:
	return track.terrain.height(p) if track.terrain else 0.0


func _piece_mesh(pl: Dictionary) -> Mesh:
	return lib[pl["kind"]][pl["var"]]["mesh"]


func _build_popups() -> void:
	for pl in placements:
		var pivot := Node3D.new()
		var p: Vector2 = pl["pos"]
		pivot.position = Vector3(p.x, _ground(p) + 0.02, p.y)
		pivot.rotation.y = pl["out_yaw"]
		var mi := MeshInstance3D.new()
		mi.mesh = _piece_mesh(pl)
		mi.material_override = material
		mi.rotation.y = float(pl["yaw"]) - float(pl["out_yaw"])
		mi.visibility_range_end = draw_distance
		pivot.add_child(mi)
		_make_labels(mi, lib[pl["kind"]][pl["var"]], pl.get("text", ""))
		pivot.rotation.x = PI * 0.5
		pivot.visible = false
		_content.add_child(pivot)
		var size: float = lib[pl["kind"]][pl["var"]]["size"]
		var sp := FlapSpring.new(size, randf_range(-1.0, 1.0))
		sp.reset(0.0)
		var idx := _pivots.size()
		_pivots.append(pivot)
		_springs.append(sp)
		_ppos.append(p)
		_jitter.append(float(pl["delay"]) * 0.55)
		var key := Vector2i(floori(p.x / PCELL), floori(p.y / PCELL))
		if not _pgrid.has(key):
			_pgrid[key] = PackedInt32Array()
		var arr: PackedInt32Array = _pgrid[key]
		arr.append(idx)
		_pgrid[key] = arr


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
			center += Vector3(p.x, _ground(p), p.y)
		center /= arr.size()
		for i in arr.size():
			var p: Vector2 = arr[i]["pos"]
			var t := Transform3D(Basis(Vector3.UP, float(arr[i]["yaw"])), Vector3(p.x, _ground(p) + 0.02, p.y) - center)
			mm.set_instance_transform(i, t)
			_mm_map[int(arr[i]["_idx"])] = [mm, i]
			if lib[arr[i]["kind"]][arr[i]["var"]].has("labels"):
				var holder := Node3D.new()
				_content.add_child(holder)
				holder.transform = Transform3D(t.basis, center + t.origin)
				_make_labels(holder, lib[arr[i]["kind"]][arr[i]["var"]], arr[i].get("text", ""))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.position = center
		mmi.visibility_range_end = draw_distance + CHUNK * 0.5
		_content.add_child(mmi)


## Pop-ups follow what the camera sees: every piece within `radius` of the view centre unfolds
## (staggered by a per-piece jitter so they rise in waves as they come into view) and folds
## back down once it is well out of view.
func update(center: Vector2, radius: float, dt: float) -> void:
	update_chimneys(center, radius)
	if not popups or _springs.is_empty():
		return
	var rose := 0
	var reach := ceili((radius + 2.0) / PCELL)
	var c := Vector2i(floori(center.x / PCELL), floori(center.y / PCELL))
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var key := Vector2i(c.x + dx, c.y + dy)
			if not _pgrid.has(key):
				continue
			for i in _pgrid[key]:
				if _up.has(i) or broken.has(i):
					continue
				if _ppos[i].distance_to(center) < radius - _jitter[i]:
					_up[i] = true
					_springs[i].set_target(1.0)
					_active[i] = true
					rose += 1
	var down_r := radius + 14.0
	for i in _up.keys():
		if _ppos[i].distance_to(center) > down_r:
			_up.erase(i)
			_springs[i].set_target(0.0)
			_active[i] = true
	for i in _active.keys():
		var sp: FlapSpring = _springs[i]
		var p := sp.step(dt)
		_pivots[i].rotation.x = (1.0 - p) * PI * 0.5
		_pivots[i].visible = p > 0.01 and not broken.has(i)
		if sp.at_rest:
			_active.erase(i)
	if rose > 0:
		Sfx.flap(-20.0 + minf(rose, 6.0))


## Stand everything up immediately (title screen / camera fly-by).
func raise_all() -> void:
	for i in _springs.size():
		_springs[i].reset(1.0)
		_springs[i].target = 1.0
		_pivots[i].rotation.x = 0.0
		_pivots[i].visible = true
