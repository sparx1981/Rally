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
const CHAPTER_BLEND := Vector4(0.30, 0.37, 0.63, 0.72)

var track: Track
var landmark: RegionalLandmark
var tower_approach := Vector2.ZERO
var tower_position := Vector2.INF
var fixed_supports: Array[Vector3] = []
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

var _pivots: Array = []    # per placement: hinge node while its chunk is built, else null
var _springs: Array = []   # per placement: FlapSpring while built, else null
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
	if landmark:
		fixed_supports.append_array(landmark.obstacles)
	for o in fixed_supports:
		var cell := Vector2i(floori(o.x / 8.0), floori(o.y / 8.0))
		if not obstacles.has(cell):
			obstacles[cell] = []
		obstacles[cell].append([o.x, o.y, o.z, -1, false, "landmark"])
	_build_library()
	_measure_footprints()
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
		if k in ["house", "barn", "cabin"]:
			nv = 4 if k == "house" else 3
		if k in ["banner", "board", "flag"]:
			nv = 6
		for i in nv:
			vars.append(Pieces.make(k, pal, seed_base * 31 + hash(k) % 1000 + i * 101, i, stage_def["loc_id"]))
		lib[k] = vars
	lib["gate_fence"] = [Pieces.gate_fence(pal)]
	lib["_chev_l"] = [{"mesh": Pieces.chevron(-1.0), "r": 1.3, "solid": true, "h": 2.0, "size": 0.4}]
	lib["_chev_r"] = [{"mesh": Pieces.chevron(1.0), "r": 1.3, "solid": true, "h": 2.0, "size": 0.4}]


func _measure_footprints() -> void:
	for variants: Array in lib.values():
		for piece: Dictionary in variants:
			var bounds: AABB = piece["mesh"].get_aabb()
			var reach := Vector2(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.z), absf(bounds.end.z)))
			piece["shore_radius"] = maxf(piece["r"], reach.length())


func _weighted_kinds(weights := {}) -> Array:
	var out: Array = []
	var kinds: Dictionary = stage_def["kinds"]
	for k in kinds.keys():
		var copies := int(kinds[k]) if weights.is_empty() else roundi(float(kinds[k]) * float(weights.get(k, 1.0)) * 4.0)
		for i in copies:
			out.append(k)
	return out


func _chapter_blend(s: float) -> Vector2:
	var progress := track.chapter_progress(s)
	return Vector2(smoothstep(CHAPTER_BLEND.x, CHAPTER_BLEND.y, progress),
		smoothstep(CHAPTER_BLEND.z, CHAPTER_BLEND.w, progress))


func _place(density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stage_def["seed"]) * 13 + 5
	var furniture_rng := RandomNumberGenerator.new()
	furniture_rng.seed = int(stage_def["seed"]) + 805
	_place_gates(furniture_rng)
	_place_signage(furniture_rng)
	var pool := _weighted_kinds()
	var chapter_pools: Array[Array] = []
	if not track.chapters.is_empty() and track.chapters[0].has("weights"):
		for chapter: Dictionary in track.chapters:
			chapter_pools.append(_weighted_kinds(chapter.weights))
	var w := track.width
	var big := ["house", "barn", "cabin", "mesa", "tent", "net_shed", "wood_store", "vine_row"]
	var spacing := 5.5 / clampf(density, 0.2, 1.0)
	var s := 4.0
	while s < track.length - 4.0:
		var blend := _chapter_blend(s) if not chapter_pools.is_empty() else Vector2.ZERO
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue
			if not chapter_pools.is_empty():
				var sample := rng.randf()
				var chapter := 2 if sample < blend.y else (1 if sample < blend.x else 0)
				pool = chapter_pools[chapter]
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
	# Broken runs of scrub frame a bank while leaving the bridge sightline open.
	for br in track.bridges:
		var a: Vector2 = br["a"]
		var end: Vector2 = br["b"]
		var flow := a.direction_to(end)
		var normal := Vector2(flow.y, -flow.x)
		var shrub := "heather" if lib.has("heather") else "bush"
		if not lib.has(shrub):
			continue
		var t := 3.0
		while t < a.distance_to(end) - 2.0:
			var pos := a + flow * t + normal * rng.randf_range(10.5, 13.5)
			_try_add(shrub, pos, rng, br["s"], false)
			t += rng.randf_range(3.5, 8.0) / clampf(density, 0.4, 1.0)
	_place_hazard_props(rng)
	if stage_def.has("forest"):
		_place_forest(rng, density)
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
## Forest locations: a thick wall of trees on both sides of the road, in bands that thin out with
## distance, broken by the odd clearing so the woods don't look stamped out.
func _place_forest(rng: RandomNumberGenerator, density: float) -> void:
	var f: Dictionary = stage_def["forest"]
	var trees: Array = []
	for k in f["trees"].keys():
		if not lib.has(k):
			continue
		for i in int(f["trees"][k]):
			trees.append(k)
	if trees.is_empty():
		return
	var clear := FastNoiseLite.new()
	clear.seed = int(stage_def["seed"]) + 31
	clear.frequency = 1.0 / 140.0
	var hw := track.width * 0.5
	var bands := [[3.2, 8.0, 0.75], [8.0, 15.0, 0.95], [15.0, 24.0, 0.95], [24.0, 36.0, 0.9], [36.0, 52.0, 0.5]]
	var step := 2.5 / clampf(density * float(f.get("thick", 1.0)), 0.35, 1.5)
	var s := 6.0
	while s < track.length - 10.0:
		var i := track.index_at(s)
		var cover := 1.0
		if not track.chapters.is_empty() and track.chapters[0].has("forest"):
			var blend := _chapter_blend(s)
			cover = lerpf(lerpf(track.chapters[0].forest, track.chapters[1].forest, blend.x),
				track.chapters[2].forest, blend.y)
		for side in [-1.0, 1.0]:
			for band in bands:
				if rng.randf() > float(band[2]) * cover:
					continue
				var lat: float = side * (hw + rng.randf_range(band[0], band[1]))
				var p := track.pts[i] + track.nrm[i] * lat + track.tang[i] * rng.randf_range(-1.8, 1.8)
				if clear.get_noise_2d(p.x, p.y) < -0.5:
					continue
				_try_add(trees[rng.randi() % trees.size()], p, rng, s, false)
		s += step * rng.randf_range(0.8, 1.2)


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


## True inside a rallycross Joker lane, its island or the verge beside it.
func _in_joker(p: Vector2, s: float) -> bool:
	if not track.rx or track.joker.is_empty():
		return false
	var jp: Array = track.project(p, track.index_at(s))
	if float(jp[1]) < float(track.joker.s0) - 30.0 or float(jp[1]) > float(track.joker.s1) + 30.0:
		return false
	var reach: float = track.road_half_width(float(jp[1])) + 4.0 + float(track.joker.w) + 8.0 + 12.0
	return signf(float(jp[2])) == float(track.joker.side) and absf(float(jp[2])) < reach


func _try_add(kind: String, p: Vector2, rng: RandomNumberGenerator, s: float, big: bool) -> void:
	if _in_joker(p, s):
		return
	if p.distance_to(track.point_at(track.length - Stage.PARC_BACK)) < 34.0:
		return   # keep the parc fermé lot clear
	if track.terrain.is_sea(p) or track.terrain.height(p) < track.terrain.sea_y + 1.0:
		return
	var vars: Array = lib[kind]
	var vi := rng.randi() % vars.size()
	var r: float = vars[vi]["r"]
	var need := track.width * 0.5 + 1.6 + r + (2.5 if big else 0.0)
	var hit0: Array = track.project(p, track.index_at(s))
	if not track.barrier_at(float(hit0[1]), signf(float(hit0[2]))).is_empty():
		need = maxf(need, track.width * 0.5 + 1.6 + r)
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
	if _in_joker(p, s):
		return
	if not track.terrain.supports_prop(p,lib[kind][vi]["shore_radius"]):
		return
	var r: float = lib[kind][vi]["r"]
	for o in fixed_supports:
		if p.distance_squared_to(Vector2(o.x,o.y)) < pow(o.z + float(lib[kind][vi]["shore_radius"]),2):
			return
	if tower_position.is_finite() and p.distance_squared_to(tower_position)<3600.0 and lib[kind][vi]["h"]>2.5:
		var nearest := Geometry2D.get_closest_point_to_segment(p,tower_approach,tower_position)
		if p.distance_to(nearest)<r+1.4:
			return
	if landmark and (landmark.overlaps(p, lib[kind][vi]["shore_radius"]) or (lib[kind][vi]["h"]>1.5 and landmark.blocks_view(p,r))):
		return
	if track.overlaps_water(p, lib[kind][vi]["shore_radius"]):
		return
	# Fold direction: away from the road.
	var hit: Array = track.project(p, track.index_at(s))
	if track.tunnel_at(float(hit[1]), r + 3.0) and absf(float(hit[2])) < track.width * 0.5 + 6.0 + r:
		return
	var tg: Vector2 = hit[3]
	var lat: float = hit[2]
	var away := Vector2(-tg.y, tg.x) * signf(lat if lat != 0.0 else 1.0)
	var out_yaw := atan2(away.x, away.y)
	if kind == "spectators":
		yaw = _sign_yaw(p, s - 4.0)
	placements.append({"kind": kind, "var": vi, "pos": p, "yaw": yaw, "out_yaw": out_yaw, "s": s,
		"delay": rng.randf_range(0.0, 14.0), "text": text})
	# Every piece registers for overlap tests; solid ones collide, small ones break.
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not obstacles.has(c):
		obstacles[c] = []
	obstacles[c].append([p.x, p.y, r if solid else -r, -1, kind in BREAKABLE, kind])


## Rally furniture: sponsor banners and billboards along the stage, warning boards before every
## hazard, distance boards each kilometre, flags at the start and finish.
func _place_gates(rng: RandomNumberGenerator) -> void:
	track.gate_distances.clear()
	if not stage_def["loc_id"] in ["meadow", "autumn", "moor", "pinewood"]:
		return
	var s := 240.0
	while s < track.finish_s - 120.0:
		var i := track.index_at(s)
		var straight := track.tang[i].dot(track.tang[track.index_at(s - 24.0)]) > 0.97
		var clear := straight and track.barrier_at(s, 1.0).is_empty() and track.barrier_at(s, -1.0).is_empty()
		clear = clear and track.bridge_at(s, 35.0).is_empty() and not track.overlaps_water(track.pts[i], 12.0)
		for feature in track.features:
			if s > feature["s0"] - 40 and s < feature["s1"] + 40:
				clear = false
				break
		if not clear:
			s += 32.0
			continue
		for side: float in [-1.0, 1.0]:
			var axis := (side * track.nrm[i] + track.tang[i] * 0.38).normalized()
			var start := track.pts[i] + track.nrm[i] * side * 2.45
			for rail in 3:
				var point := start + axis * (rail + 0.5)
				_add("gate_fence", 0, point, atan2(-axis.y, axis.x), s, rng, true)
		track.gate_distances.append(s)
		s += rng.randf_range(850.0, 1400.0)


func _place_signage(rng: RandomNumberGenerator) -> void:
	var w := track.width
	var s := 60.0
	var side := 1.0
	while s < track.length - 60.0:
		var i := track.index_at(s)
		if track.feature_at(s, "splash", 10.0).is_empty() and track.heights[i] <= 0.0:
			var pos := track.pts[i] + track.nrm[i] * side * (w * 0.5 + 3.4)
			if track.clearance(pos) > w * 0.5 + 2.0:
				var behind_barrier := not track.barrier_at(s, side).is_empty()
				var kind := "board" if behind_barrier else "banner"
				_add(kind, rng.randi() % 6, pos, _sign_yaw(pos, s - 8.0), s, rng, behind_barrier)
			if rng.randf() < 0.45:
				var bp := track.pts[i] + track.nrm[i] * -side * (w * 0.5 + 8.0)
				if track.clearance(bp) > w * 0.5 + 5.0:
					_add("board", rng.randi() % 6, bp, _sign_yaw(bp, s - 15.0), s, rng, true)
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


## Aim the printed (+Z) face at the approaching lane, including through bends.
func _sign_yaw(position_xz: Vector2, approach_s: float) -> float:
	var face := track.point_at(approach_s) - position_xz
	return atan2(face.x, face.y)


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
				if _scared.has(i) or placements[i]["kind"] != "spectators" or _pivots[i] == null:
					continue
				if _ppos[i].distance_to(p) < 11.0:
					_scared[i] = true
					var pv: Node3D = _pivots[i]
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
	if popups and idx < _pivots.size() and _pivots[idx] != null:
		start = (_pivots[idx] as Node3D).get_child(0).global_transform
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


var lights_on := false
var lamp_level := 1.0

# --- streaming: scenery is built in chunks of road around the camera and freed behind it ------
const STREAM_R := 320.0
var _chunk_members := {}    # chunk id -> Array of placement indices
var _chunk_center := {}     # chunk id -> Vector2
var _live := {}             # chunk id -> Node3D
var _chunk_fx := {}         # chunk id -> Array of [emitter or light, world position, piece index or -1]
var _stream_t := 0.0
var _last_center := Vector2.INF


func _index_chunks() -> void:
	_chunk_members.clear()
	_chunk_center.clear()
	_ppos.resize(placements.size())
	_jitter.resize(placements.size())
	_pgrid.clear()
	for i in placements.size():
		var pl: Dictionary = placements[i]
		var cid := int(float(pl["s"]) / CHUNK)
		if not _chunk_members.has(cid):
			_chunk_members[cid] = []
			_chunk_center[cid] = track.point_at((cid + 0.5) * CHUNK)
		_chunk_members[cid].append(i)
		var p: Vector2 = pl["pos"]
		_ppos[i] = p
		_jitter[i] = float(pl["delay"]) * 0.55
		var key := Vector2i(floori(p.x / PCELL), floori(p.y / PCELL))
		if not _pgrid.has(key):
			_pgrid[key] = PackedInt32Array()
		var arr: PackedInt32Array = _pgrid[key]
		arr.append(i)
		_pgrid[key] = arr


func rebuild_visuals(use_popups: bool) -> void:
	popups = use_popups
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	_live.clear()
	_chunk_fx.clear()
	_mm_map.clear()
	_active.clear()
	_up.clear()
	_pivots.clear()
	_springs.clear()
	_pivots.resize(placements.size())
	_springs.resize(placements.size())
	if _chunk_members.is_empty():
		_index_chunks()
	var c := _last_center if _last_center != Vector2.INF else track.point_at(track.start_s)
	_stream(c, true)


## Build chunks near the camera, free the ones far away.
func _stream(center: Vector2, all_now := false) -> void:
	_last_center = center
	var built := 0
	for cid in _chunk_members.keys():
		var d: float = (_chunk_center[cid] as Vector2).distance_to(center)
		if d < STREAM_R and not _live.has(cid):
			if built >= 2 and not all_now:
				continue   # spread the work over frames
			_build_chunk(cid)
			built += 1
		elif d > STREAM_R + 140.0 and _live.has(cid):
			_free_chunk(cid)


func _build_chunk(cid: int) -> void:
	var node := Node3D.new()
	_content.add_child(node)
	_live[cid] = node
	var members: Array = _chunk_members[cid]
	if popups:
		for i in members:
			var pl: Dictionary = placements[i]
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
			node.add_child(pivot)
			var sp := FlapSpring.new(float(lib[pl["kind"]][pl["var"]]["size"]), randf_range(-1.0, 1.0))
			sp.reset(0.0)
			_pivots[i] = pivot
			_springs[i] = sp
	else:
		var groups := {}
		for i in members:
			if broken.has(i):
				continue
			var pl: Dictionary = placements[i]
			var key := "%s|%d" % [pl["kind"], pl["var"]]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(i)
		for key in groups.keys():
			var arr: Array = groups[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _piece_mesh(placements[arr[0]])
			mm.instance_count = arr.size()
			var center := Vector3.ZERO
			for i in arr:
				var p: Vector2 = placements[i]["pos"]
				center += Vector3(p.x, _ground(p), p.y)
			center /= arr.size()
			for k in arr.size():
				var pl: Dictionary = placements[arr[k]]
				var p: Vector2 = pl["pos"]
				var t := Transform3D(Basis(Vector3.UP, float(pl["yaw"])), Vector3(p.x, _ground(p) + 0.02, p.y) - center)
				mm.set_instance_transform(k, t)
				_mm_map[int(arr[k])] = [mm, k]
				if lib[pl["kind"]][pl["var"]].has("labels"):
					var holder := Node3D.new()
					node.add_child(holder)
					holder.transform = Transform3D(t.basis, center + t.origin)
					_make_labels(holder, lib[pl["kind"]][pl["var"]], pl.get("text", ""))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = material
			mmi.position = center
			mmi.visibility_range_end = draw_distance + CHUNK * 0.5
			node.add_child(mmi)
	_chunk_fx[cid] = _make_fx(members, node)


func _free_chunk(cid: int) -> void:
	for i in _chunk_members[cid]:
		_pivots[i] = null
		_springs[i] = null
		_up.erase(i)
		_active.erase(i)
		_mm_map.erase(i)
	(_live[cid] as Node3D).queue_free()
	_live.erase(cid)
	_chunk_fx.erase(cid)


## Chimney smoke for houses and working lamps (at dusk and night) in a chunk.
func _make_fx(members: Array, node: Node3D) -> Array:
	var out: Array = []
	var leak: Color = Catalog.weather(stage_def["weather"])["leak"]
	for i in members:
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
			node.add_child(ol)
			out.append([ol, ol.position, -1])
			continue
		if not info.has("chimney"):
			continue
		var p: Vector2 = pl["pos"]
		var local: Vector3 = info["chimney"]
		var em := Puffs.make("chimney", Color("#d8d6d2"), leak)
		em.emitting = false
		var world := Transform3D(Basis(Vector3.UP, float(pl["yaw"])), Vector3(p.x, _ground(p), p.y)) * local
		if popups and _pivots[i] != null:
			(_pivots[i] as Node3D).get_child(0).add_child(em)
			em.position = local
			out.append([em, world, i])
		else:
			node.add_child(em)
			em.position = world
			out.append([em, world, -1])
	return out


## Chimneys only smoke near the camera (and only once their house has unfolded).
func update_chimneys(center: Vector2, radius: float) -> void:
	for fx in _chunk_fx.values():
		for c in fx:
			if not is_instance_valid(c[0]):
				continue
			var wp: Vector3 = c[1]
			var dd := Vector2(wp.x, wp.z).distance_to(center)
			if c[0] is CPUParticles3D:
				var up: bool = c[2] < 0 or (_springs[c[2]] != null and (_springs[c[2]] as FlapSpring).p > 0.9)
				(c[0] as CPUParticles3D).emitting = dd < radius + 50.0 and up
			else:
				var lamp := c[0] as OmniLight3D
				lamp.visible = dd < radius + 30.0 and lamp_level > 0.01
				lamp.light_energy = 2.2 * lamp_level


## Ground height under a piece (pieces beside the road stand on the landscape).
func _ground(p: Vector2) -> float:
	return track.terrain.height(p) if track.terrain else 0.0


func _piece_mesh(pl: Dictionary) -> Mesh:
	return lib[pl["kind"]][pl["var"]]["mesh"]


## Pop-ups follow what the camera sees: every piece within `radius` of the view centre unfolds
## (staggered by a per-piece jitter so they rise in waves as they come into view) and folds
## back down once it is well out of view.
func update(center: Vector2, radius: float, dt: float) -> void:
	_stream_t -= dt
	if _stream_t <= 0.0:
		_stream_t = 0.25
		_stream(center)
	update_chimneys(center, radius)
	if not popups:
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
				if _up.has(i) or broken.has(i) or _springs[i] == null:
					continue
				if _ppos[i].distance_to(center) < radius - _jitter[i]:
					_up[i] = true
					(_springs[i] as FlapSpring).set_target(1.0)
					_active[i] = true
					rose += 1
	var down_r := radius + 14.0
	for i in _up.keys():
		if _springs[i] == null:
			_up.erase(i)
		elif _ppos[i].distance_to(center) > down_r:
			_up.erase(i)
			(_springs[i] as FlapSpring).set_target(0.0)
			_active[i] = true
	for i in _active.keys():
		if _springs[i] == null:
			_active.erase(i)
			continue
		var sp: FlapSpring = _springs[i]
		var p := sp.step(dt)
		var pv: Node3D = _pivots[i]
		pv.rotation.x = (1.0 - p) * PI * 0.5
		pv.visible = p > 0.01 and not broken.has(i)
		if sp.at_rest:
			_active.erase(i)
	if rose > 0:
		Sfx.flap(-20.0 + minf(rose, 6.0))
