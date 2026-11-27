class_name Track
extends RefCounted
## A point-to-point rally stage generated from a seed: smooth clothoid-like curvature changes,
## no self-crossing. Sampled every STEP units. Provides projection queries, pace notes and an
## ideal-speed profile used by the AI and for medal times.

const STEP := 2.0
const POST_FINISH := 120.0   # road beyond the flying finish, ending in the parc fermé
const CELL := 24.0

var pts := PackedVector2Array()
var tang := PackedVector2Array()
var nrm := PackedVector2Array()     # left-hand normal: lateral offset = (p - pts[i]).dot(nrm[i])
var dist := PackedFloat32Array()
var curv := PackedFloat32Array()     # signed curvature (dheading / ds)
var curv_abs := PackedFloat32Array() # smoothed |curvature| (window max)
var width := 9.0
var length := 0.0
var corners: Array = []              # {s0, s1, dir (-1 left / +1 right on screen), sev, hairpin}
var grid := {}
var start_s := 14.0
var finish_s := 0.0
var circuit := false
var rx := false                      # a rallycross circuit (see RxBuilder)
var widths := PackedFloat32Array()   # road width per sample (rallycross); `width` is then the maximum
var banks := PackedFloat32Array()    # cross-slope per sample, metres of height per metre of lateral offset
var joker := {}                      # alternative lane: s0, s1, side, lo/hi per sample, gap per sample
var rx_info := {}
var patches_unsorted := false        # rallycross patches overlap; the last match wins
var _barrier_cells := {}
var _sample_step := STEP

# Hazards (rally-game staples: crests, jumps, water splashes, hay-bale chicanes, loose surfaces).
var heights := PackedFloat32Array()  # hazard ramps per sample (crests and jump ramps are built paper ramps)
var elev := PackedFloat32Array()     # road altitude per sample (climbs, descents, rolling undulation)
var terrain: Terrain                 # the landscape heightfield around the road
var features: Array = []             # {type: jump|crest|splash|chicane, s0, s1, s (centre), side}
var patches: Array = []              # {s0, s1, lat0, lat1, kind, grip, drag}
var notes: Array = []                # pace notes: corners + features, sorted by s0
var barriers: Array = []             # {s0, s1, side (+1 = +nrm side), kind: armco | fence | parapet}
var gate_distances := PackedFloat32Array()
var bridges: Array = []              # {s, kind: stone | covered, half, a, b (river ends), water_y}
var tunnels: Array[Dictionary] = []
var stacked_crossing := {}
var chapters: Array = []



## Pre-generated layouts ship in res://data/tracks (same seed and settings = same road), so phones
## never pay for the self-avoiding search; anything else is generated and cached in user://.
static func cache_key(seed_v: int, target_len: float, twist: float) -> String:
	return "%d_%d_%d" % [seed_v, int(target_len), int(round(twist * 1000.0))]


## Build the same road data for racing, the route map and elevation preview.
func build_stage_route(stage_def: Dictionary, surface_kind: String) -> void:
	if stage_def.get("rx", false):
		RxBuilder.build(self, stage_def)
		return
	if stage_def.get("circuit", false):
		_build_sand_circuit(float(stage_def.width))
		return
	chapters = Catalog.CHAPTERS.get(stage_def.loc_id, [])
	generate(stage_def.seed, float(stage_def.length) + POST_FINISH, stage_def.twist, stage_def.width)
	if stage_def.get("stacked", false):
		_add_stacked_opening()
	build_elevation(stage_def.get("elev", {}), stage_def.seed)
	if not stacked_crossing.is_empty():
		_grade_stacked_opening()
	build_hazards(stage_def.seed, surface_kind, stage_def.twist)
	build_bridges(stage_def.seed, stage_def.get("bridges", []))
	if not stacked_crossing.is_empty():
		_register_stacked_bridge()
	var tunnel: Vector2 = Stage.SWITCHBACK_TUNNELS.get(stage_def.id, Vector2.ZERO)
	if tunnel != Vector2.ZERO:
		add_switchback_tunnel(tunnel.x, tunnel.y)
	if Stage.SWITCHBACK_BRIDGES.has(stage_def.id):
		add_switchback_bridge(Stage.SWITCHBACK_BRIDGES[stage_def.id])
	for bridge in bridges:
		var first := float(bridge.s) - float(bridge.half)
		notes.append({"s0": first, "s1": float(bridge.s) + float(bridge.half), "kind": "bridge",
			"dir": 0.0, "sev": 0, "hairpin": false})
	notes.sort_custom(func(a, b): return a.s0 < b.s0)


func _build_sand_circuit(road_width: float) -> void:
	circuit = true
	width = road_width
	var curve := Curve2D.new()
	curve.bake_interval = 0.25
	for i in 241:
		var angle := 0.58 + TAU * i / 240.0
		curve.add_point(Vector2(140.0 * sin(angle), 88.0 * sin(2.0 * angle)))
	var metres := curve.get_baked_length()
	var segments := roundi(metres / STEP)
	for i in range(segments + 1):
		pts.append(curve.sample_baked(metres * i / segments))
	pts[-1] = pts[0]
	_finalize()
	_rebuild_grid()
	_sample_step = length / segments
	start_s = 0.0
	finish_s = length
	var lower := 1
	var upper := segments - 1
	for i in range(1, segments):
		if i < segments / 2:
			if pts[i].length_squared() < pts[lower].length_squared():
				lower = i
		elif pts[i].length_squared() < pts[upper].length_squared():
			upper = i
	stacked_crossing = {"center": Vector2.ZERO, "lower": dist[lower], "upper": dist[upper], "half": 21.0}
	var splash := index_at(dist[lower] + 110.0)
	var water_s := dist[splash]
	for i in pts.size():
		var bridge_distance := absf(wrapf(dist[i] - float(dist[upper]), -length * 0.5, length * 0.5))
		elev[i] = 8.2 * (1.0 - smoothstep(29.0, 98.0, bridge_distance))
		elev[i] -= 0.78 * (1.0 - smoothstep(0.0, 16.0, absf(dist[i] - water_s)))
	features.append({"type": "splash", "i": splash, "s": water_s, "s0": water_s - 3.5,
		"s1": water_s + 3.5, "water_y": road_h(water_s) + Stage.ROAD_Y + 0.20})
	notes.append({"kind": "splash", "s0": water_s - 3.5, "s1": water_s + 3.5,
		"dir": 0.0, "sev": 0, "hairpin": false})
	_register_stacked_bridge()
	notes.append({"kind": "bridge", "s0": dist[upper] - 21.0, "s1": dist[upper] + 21.0,
		"dir": 0.0, "sev": 0, "hairpin": false})
	notes.sort_custom(func(a, b): return a.s0 < b.s0)


## Slate Gorge Classic enters from the west, loops south of the bridge,
## crosses the same point northbound, then joins the seeded route.
func _add_stacked_opening() -> void:
	var curve := Curve2D.new()
	curve.bake_interval = 0.3
	curve.add_point(Vector2(32, -186), Vector2.ZERO, Vector2(44, 0))
	curve.add_point(Vector2(236, -186), Vector2(-40, 0), Vector2(27, 0))
	curve.add_point(Vector2(285, -235), Vector2(0, 27), Vector2(0, -18))
	curve.add_point(Vector2(285, -267), Vector2(0, 18), Vector2(0, -28))
	curve.add_point(Vector2(234, -318), Vector2(28, 0), Vector2(-35, 0))
	curve.add_point(Vector2(170, -254), Vector2(0, -35), Vector2(0, 40))
	curve.add_point(Vector2(170, -102), Vector2(0, -40), Vector2(0, 30))
	curve.add_point(Vector2(116, -48), Vector2(30, 0), Vector2(-23, 0))
	curve.add_point(Vector2(48, -48), Vector2(23, 0), Vector2(-26, 0))
	curve.add_point(Vector2.ZERO, Vector2(0, -26))
	var prefix := PackedVector2Array()
	var metres := curve.get_baked_length()
	var segments := roundi(metres / STEP)
	var middle := Vector2(170, -186)
	var lower_index := 0
	var upper_index := 0
	var lower_error := INF
	var upper_error := INF
	for index in range(segments + 1):
		var point := curve.sample_baked(metres * index / segments)
		prefix.append(point)
		var error := point.distance_squared_to(middle)
		if index < 120 and error < lower_error:
			lower_error = error
			lower_index = index
		elif index >= 120 and error < upper_error:
			upper_error = error
			upper_index = index
	# Keep the Classic distance by trading the original tail for the new opening.
	prefix.append_array(pts.slice(1, pts.size() - segments))
	pts = prefix
	_rebuild_grid()
	_finalize()
	stacked_crossing = {"center": middle, "lower": dist[lower_index], "upper": dist[upper_index],
		"half": 25.0, "authored_end": dist[segments]}


func _grade_stacked_opening() -> void:
	var lower: float = stacked_crossing.lower
	var upper: float = stacked_crossing.upper
	var end: float = stacked_crossing.authored_end
	var join_y := elev[index_at(end)]
	for index in range(index_at(end) + 1):
		var station := dist[index]
		var climb := smoothstep(lower + 24.0, upper - 35.0, station)
		elev[index] = lerpf(8.6 * climb, join_y, smoothstep(upper + 36.0, end, station))


func _register_stacked_bridge() -> void:
	var center: Vector2 = stacked_crossing.center
	var upper: float = stacked_crossing.upper
	var lower: float = stacked_crossing.lower
	var i := index_at(upper)
	bridges.append({"s": upper, "kind": "truss", "half": stacked_crossing.half, "i": i,
		"a": center - Vector2(18, 0), "b": center + Vector2(18, 0),
		"water_y": 0.0, "channel": 0.0, "dry": true, "stacked": true})
	bridges.sort_custom(func(a, b): return a.s < b.s)
	notes.append({"s0": lower - 7.0, "s1": lower + 7.0, "kind": "underpass", "dir": 0.0, "sev": 0, "hairpin": false})



func on_stacked_span(station: float, margin := 0.0) -> bool:
	return not stacked_crossing.is_empty() and absf(station - float(stacked_crossing.upper)) <= float(stacked_crossing.half) + margin


func crossing_near(p: Vector2) -> bool:
	return not stacked_crossing.is_empty() and p.distance_squared_to(stacked_crossing.center) < 40.0 * 40.0


func generate(seed_v: int, target_len: float, twist: float, w: float) -> void:
	width = w
	var key := cache_key(seed_v, target_len, twist)
	for path in ["res://data/tracks/%s.bin" % key, "user://tracks/%s.bin" % key]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				var data = bytes_to_var(f.get_buffer(f.get_length()))
				if data is PackedVector2Array and data.size() > 10:
					pts = data
					_rebuild_grid()
					_finalize()
					return
	_generate_fresh(seed_v, target_len, twist)
	DirAccess.make_dir_recursive_absolute("user://tracks")
	var wf := FileAccess.open("user://tracks/%s.bin" % key, FileAccess.WRITE)
	if wf:
		wf.store_buffer(var_to_bytes(pts))


func _generate_fresh(seed_v: int, target_len: float, twist: float) -> void:
	var best := PackedVector2Array()
	for attempt in 16:
		if _try(seed_v + attempt * 7919, target_len, twist):
			_finalize()
			return
		if pts.size() > best.size():
			best = pts.duplicate()
	pts = best
	_rebuild_grid()
	_finalize()


## Self-avoiding road built segment by segment (straights and clothoid-eased bends). When the
## road runs into itself it rewinds to an earlier segment and tries another bend, so stages of
## 15 km and more lay out without crossing.
func _try(seed_v: int, target_len: float, twist: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	pts = PackedVector2Array()
	grid = {}
	var st := {"pos": Vector2.ZERO, "h": 0.0, "base": 0.0, "k": 0.0, "total": 0.0}
	pts.append(Vector2.ZERO)
	_grid_add(0, Vector2.ZERO)
	var checkpoints: Array = []
	var first := true
	var budget := 12000
	while st["total"] < target_len:
		budget -= 1
		if budget <= 0:
			return false
		checkpoints.append({"n": pts.size(), "st": st.duplicate(), "fails": 0})
		var segs: Array = []
		if first:
			segs = [[0.0, 46.0]]
			first = false
		else:
			segs = _pick_segment(rng, twist, st)
		var ok := true
		for seg in segs:
			if not _run_segment(seg, st, target_len):
				ok = false
				break
			if st["total"] >= target_len:
				break
		if ok:
			continue
		# Rewind: retry from this checkpoint, or back further after repeated failures.
		var cp: Dictionary = checkpoints.pop_back()
		cp["fails"] = int(cp["fails"]) + 1
		while int(cp["fails"]) > 8 and not checkpoints.is_empty():
			cp = checkpoints.pop_back()
			cp["fails"] = int(cp["fails"]) + 1
		if int(cp["fails"]) > 8:
			return false
		_truncate(int(cp["n"]))
		st = (cp["st"] as Dictionary).duplicate()
		# Steer the retry back toward the general direction of travel.
		st["base"] = float(st["base"]) + rng.randf_range(-0.6, 0.6)
		checkpoints.append(cp)
		checkpoints.pop_back()
	return true


func _pick_segment(rng: RandomNumberGenerator, twist: float, st: Dictionary) -> Array:
	var out: Array = []
	var h: float = st["h"]
	var base: float = st["base"]
	if rng.randf() < 0.32 - twist * 0.14:
		out.append([0.0, rng.randf_range(24.0, 80.0) * (1.2 - twist * 0.4)])
	else:
		var hair := rng.randf() < twist * 0.16
		var radius := 14.0 if hair else lerpf(80.0, 17.0, pow(rng.randf(), 0.8) * (0.45 + twist * 0.55))
		var ang := deg_to_rad(rng.randf_range(155.0, 178.0) if hair else rng.randf_range(25.0, 80.0 + 70.0 * twist))
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var off := wrapf(h - base, -PI, PI)
		if absf(off) > 0.9:
			sgn = -signf(off)
		out.append([sgn / radius, ang * radius])
		if rng.randf() < 0.3 + twist * 0.3:
			out.append([0.0, rng.randf_range(8.0, 20.0)])
	st["base"] = base + rng.randf_range(-0.35, 0.35)
	return out


func _run_segment(seg: Array, st: Dictionary, target_len: float) -> bool:
	var kt: float = seg[0]
	var steps := int(float(seg[1]) / STEP)
	var pos: Vector2 = st["pos"]
	var h: float = st["h"]
	var k: float = st["k"]
	var total: float = st["total"]
	for i in steps:
		k = lerpf(k, kt, 0.22)
		h += k * STEP
		pos += Vector2(sin(h), cos(h)) * STEP
		var idx := pts.size()
		if _collides(pos, idx):
			return false
		pts.append(pos)
		_grid_add(idx, pos)
		total += STEP
		if total >= target_len:
			break
	st["pos"] = pos
	st["h"] = h
	st["k"] = k
	st["total"] = total
	return true


func _truncate(n: int) -> void:
	for i in range(n, pts.size()):
		var key := Vector2i(floori(pts[i].x / CELL), floori(pts[i].y / CELL))
		if grid.has(key):
			var arr: PackedInt32Array = grid[key]
			var keep := PackedInt32Array()
			for j in arr:
				if j < n:
					keep.append(j)
			grid[key] = keep
	pts.resize(n)


func _rebuild_grid() -> void:
	grid = {}
	for i in pts.size():
		_grid_add(i, pts[i])


func _collides(p: Vector2, idx: int) -> bool:
	var lim := width * 3.2
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if not grid.has(key):
				continue
			for j in grid[key]:
				if idx - j > 30 and p.distance_to(pts[j]) < lim:
					return true
	return false


func _grid_add(i: int, p: Vector2) -> void:
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if not grid.has(key):
		grid[key] = PackedInt32Array()
	var arr: PackedInt32Array = grid[key]
	arr.append(i)
	grid[key] = arr


func _finalize() -> void:
	var n := pts.size()
	tang.resize(n)
	nrm.resize(n)
	dist.resize(n)
	curv.resize(n)
	curv_abs.resize(n)
	var acc := 0.0
	var closed := n > 4 and pts[n - 1].distance_to(pts[0]) < 0.5   # a circuit: the last sample is the first
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		if closed and i == 0:
			a = pts[n - 2]
		elif closed and i == n - 1:
			b = pts[1]
		var t := (b - a).normalized()
		tang[i] = t
		nrm[i] = Vector2(-t.y, t.x)
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		dist[i] = acc
	length = acc
	for i in n:
		var i0 := maxi(i - 2, 0)
		var i1 := mini(i + 2, n - 1)
		if i1 == i0:
			curv[i] = 0.0
			continue
		var h0 := atan2(tang[i0].x, tang[i0].y)
		var h1 := atan2(tang[i1].x, tang[i1].y)
		curv[i] = wrapf(h1 - h0, -PI, PI) / (dist[i1] - dist[i0])
	for i in n:
		var m := 0.0
		for j in range(maxi(i - 3, 0), mini(i + 4, n)):
			m = maxf(m, absf(curv[j]))
		curv_abs[i] = m
	finish_s = length - POST_FINISH
	heights.resize(n)
	heights.fill(0.0)
	elev.resize(n)
	elev.fill(0.0)
	_find_corners()
	notes = corners.duplicate()


func _find_corners() -> void:
	corners = []
	var n := pts.size()
	var i := 0
	while i < n:
		if absf(curv[i]) > 1.0 / 110.0:
			var sgn := signf(curv[i])
			var j := i
			var turn := 0.0
			var kmax := 0.0
			while j < n and signf(curv[j]) == sgn and absf(curv[j]) > 1.0 / 160.0:
				turn += curv[j] * STEP
				kmax = maxf(kmax, absf(curv[j]))
				j += 1
			if absf(turn) > deg_to_rad(18.0):
				var r := 1.0 / maxf(kmax, 0.0001)
				var sev := 6
				for lim in [[17.0, 1], [25.0, 2], [34.0, 3], [46.0, 4], [65.0, 5]]:
					if r < lim[0]:
						sev = lim[1]
						break
				# Positive curvature turns the heading toward +X, which is screen-left behind the car.
				corners.append({"kind": "corner", "s0": dist[i], "s1": dist[mini(j, n - 1)], "dir": -sgn, "sev": sev,
					"hairpin": absf(turn) > deg_to_rad(140.0), "apex": (i + j) / 2})
			i = j + 1
		else:
			i += 1


# --- queries -------------------------------------------------------------------------------------

func chapter_progress(s: float) -> float:
	return clampf(s / finish_s, 0.0, 1.0)


func index_at(s: float) -> int:
	return clampi(int(route_station(s) / _sample_step), 0, pts.size() - 1)


func route_station(s: float) -> float:
	return fposmod(s, length) if circuit and (s < 0.0 or s > length) else s


func point_at(s: float) -> Vector2:
	var f := clampf(route_station(s) / _sample_step, 0.0, pts.size() - 1.001)
	var i := int(f)
	return pts[i].lerp(pts[i + 1], f - i)


## Returns [index, s, lateral, tangent]. `hint` speeds up the local search.
func project(p: Vector2, hint: int, altitude := INF) -> Array:
	var n := pts.size()
	var best := -1
	var bd := INF
	var lo := clampi(hint - 24, 0, n - 1)
	var hi := clampi(hint + 24, 0, n - 1)
	if circuit:
		lo = hint - 24
		hi = hint + 24
	for candidate in range(lo, hi + 1):
		var i := posmod(candidate, n - 1) if circuit else candidate
		var d := p.distance_squared_to(pts[i])
		if d < bd:
			bd = d
			best = i
	if best < 0 or bd > 900.0:
		best = nearest_global(p)
	if is_finite(altitude) and crossing_near(p):
		# Resolve a nearby return leg by both road height and horizontal
		# distance. Keep the local hint's small tie-break near the approaches.
		var score := p.distance_squared_to(pts[best])
		score += pow((altitude - road_h_i(best)) * 2.0, 2.0)
		for station: float in [stacked_crossing.lower, stacked_crossing.upper]:
			var middle := index_at(station)
			for index in range(middle - 22, middle + 23):
				var d := p.distance_squared_to(pts[index]) + pow((altitude - road_h_i(index)) * 2.0, 2.0)
				if d + 0.25 < score:
					best = index
					score = d
	var i0 := best
	var i1 := mini(best + 1, n - 1)
	if best > 0 and (p - pts[best]).dot(tang[best]) < 0.0:
		i0 = best - 1
		i1 = best
	elif circuit and best == 0 and (p - pts[best]).dot(tang[best]) < 0.0:
		i0 = n - 2
		i1 = n - 1
	var seg := pts[i1] - pts[i0]
	var t := 0.0
	if seg.length_squared() > 1e-6:
		t = clampf((p - pts[i0]).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var foot := pts[i0] + seg * t
	var tg := tang[i0].lerp(tang[i1], t).normalized()
	var lat := (p - foot).dot(Vector2(-tg.y, tg.x))
	var s := dist[i0] + (dist[i1] - dist[i0]) * t
	return [best, s, lat, tg]


func nearest_global(p: Vector2) -> int:
	var best := 0
	var bd := INF
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var key := Vector2i(c.x + dx, c.y + dy)
				if grid.has(key):
					for j in grid[key]:
						var d := p.distance_squared_to(pts[j])
						if d < bd:
							bd = d
							best = j
		if bd < INF:
			return best
	for j in pts.size():
		var d := p.distance_squared_to(pts[j])
		if d < bd:
			bd = d
			best = j
	return best


## Distance from p to the nearest road centreline sample (for placing scenery clear of the road).
func clearance(p: Vector2) -> float:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var bd := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if grid.has(key):
				for j in grid[key]:
					bd = minf(bd, p.distance_squared_to(pts[j]))
	return sqrt(bd)


## True when a prop of radius r at p would stand on, or too close to, ANY drivable surface: any stretch of road
## nearby (switchbacks and loops put other legs close by) and any Joker lane, to either side.
func near_road(p: Vector2, r: float, margin := 1.5) -> bool:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dy)
			if not grid.has(key):
				continue
			for j in grid[key]:
				var dv: Vector2 = p - pts[j]
				var lat := dv.dot(nrm[j])
				var along := dv.dot(tang[j])
				var ext := road_half_width(dist[j])
				var band := joker_band(dist[j])
				if not is_nan(band.x):
					if lat >= 0.0 and band.y > 0.0:
						ext = maxf(ext, band.y)
					elif lat < 0.0 and band.x < 0.0:
						ext = maxf(ext, -band.x)
				if Vector2(maxf(absf(lat) - ext, 0.0), maxf(absf(along) - 2.5, 0.0)).length() < r + margin:
					return true
	return false


func heading_at(i: int) -> float:
	return atan2(tang[i].x, tang[i].y)


func bounds() -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## Ideal speed per sample for a given lateral grip (u/s^2), braking and acceleration.
func speed_profile(a_lat: float, a_brake: float, a_acc: float, v_top: float) -> PackedFloat32Array:
	var n := pts.size()
	var v := PackedFloat32Array()
	v.resize(n)
	for i in n:
		v[i] = minf(v_top, sqrt(a_lat / maxf(curv_abs[i], 0.0005)))
	# Hazards: slow for chicanes, splashes and jump take-offs; loose surfaces cost grip.
	for f in features:
		var cap := 99.0
		match f["type"]:
			"chicane": cap = 13.0
			"splash": cap = 17.0
			"jump": cap = float(f.get("cap", 26.0))
		for i in range(index_at(float(f["s0"]) - 6.0), index_at(float(f["s1"]) + 4.0) + 1):
			v[i] = minf(v[i], cap)
	for p in patches:
		for i in range(index_at(p["s0"]), index_at(p["s1"]) + 1):
			v[i] *= sqrt(float(p["grip"]))
	for i in range(n - 2, -1, -1):
		v[i] = minf(v[i], sqrt(v[i + 1] * v[i + 1] + 2.0 * a_brake * STEP))
	if not circuit:
		v[0] = 0.0
	for i in range(1, n):
		v[i] = minf(v[i], sqrt(v[i - 1] * v[i - 1] + 2.0 * a_acc * STEP))
	return v


func ideal_time(a_lat: float, a_brake: float, a_acc: float, v_top: float) -> float:
	var v := speed_profile(a_lat, a_brake, a_acc, v_top)
	var t := 0.0
	var i0 := index_at(start_s)
	var i1 := index_at(finish_s)
	for i in range(i0, i1):
		t += STEP / maxf((v[i] + v[i + 1]) * 0.5, 1.0)
	return t


## Pace note for the next corner within `ahead` units of s, or {}.
func next_corner(s: float, ahead: float) -> Dictionary:
	for c in corners:
		if c["s1"] < s:
			continue
		if c["s0"] - s > ahead:
			return {}
		return c
	return {}


# --- altitude -------------------------------------------------------------------------------------

## Road altitude: an overall climb (Monte-Carlo-style cols), rolling undulation at two wavelengths
## (Welsh moors, Finnish crests) and a maximum grade, smoothed so the road stays drivable.
func build_elevation(params: Dictionary, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 11 + 1
	var n := pts.size()
	# Climb over the first few km, then the long stages go over a series of cols (up and down).
	var climb: float = minf(float(params.get("climb", 0.0)) * minf(length, 3000.0) / 1000.0, 170.0)
	var amp: float = params.get("amp", 5.0)
	var wave: float = params.get("wave", 180.0)
	var grade: float = params.get("grade", 0.09)
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var ph3 := rng.randf() * TAU
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var d := dist[i]
		var t := d / maxf(length, 1.0)
		var cols := maxf(1.0, round(length / 4000.0))
		var climb_t := 0.5 - 0.5 * cos(t * PI * (2.0 * cols - 1.0))   # rise to a summit, then over further cols
		raw[i] = climb * climb_t + amp * (sin(d / wave * TAU + ph1) * 0.65 + sin(d / (wave * 0.37) * TAU + ph2) * 0.35) \
			+ amp * 0.5 * sin(d / (wave * 2.7) * TAU + ph3)
	# Flat start and finish areas for the grid and the gantries.
	for i in n:
		var d := dist[i]
		var w0 := smoothstep(start_s + 30.0, start_s + 80.0, d) * (1.0 - smoothstep(finish_s - 60.0, finish_s, d))
		raw[i] = lerpf(raw[index_at(start_s + 30.0)] if d < start_s + 80.0 else raw[index_at(finish_s)], raw[i], w0)
	# Limit grade, then smooth (two passes of a 9-tap box).
	var lim := grade * STEP
	for _pass in 2:
		for i in range(1, n):
			raw[i] = clampf(raw[i], raw[i - 1] - lim, raw[i - 1] + lim)
		for i in range(n - 2, -1, -1):
			raw[i] = clampf(raw[i], raw[i + 1] - lim, raw[i + 1] + lim)
	for _pass in 2:
		var sm := raw.duplicate()
		for i in n:
			var acc := 0.0
			var cnt := 0
			for j in range(maxi(i - 4, 0), mini(i + 5, n)):
				acc += raw[j]
				cnt += 1
			sm[i] = acc / cnt
		raw = sm
	var base := raw[0]
	for i in n:
		elev[i] = raw[i] - base


## Road surface (altitude + hazard ramps) at distance s.
func road_h(s: float) -> float:
	var f := clampf(route_station(s) / _sample_step, 0.0, pts.size() - 1.001)
	var i := int(f)
	return lerpf(elev[i] + heights[i], elev[i + 1] + heights[i + 1], f - i)


## Height of whatever the car stands on: the road inside its edges, the landscape outside.
func surface_height(p: Vector2, s: float, lat: float) -> float:
	if rx:
		if on_road_at(s, lat, 0.1):
			return road_h(s) + clampf(lat, -road_extent(s), road_extent(s)) * banks[index_at(s)]
	elif absf(lat) <= road_half_width(s) + 0.1:
		return road_h(s)
	if terrain:
		return terrain.height(p)
	return road_h(s)


## Uphill grade along the given direction at a point (+ = climbing).
func grade_along(p: Vector2, s: float, lat: float, dir: Vector2) -> float:
	return (surface_height(p + dir, s + dir.dot(tang[index_at(s)]), lat) - surface_height(p - dir, s - dir.dot(tang[index_at(s)]), lat)) * 0.5


## Flatten the road altitude around s (water splashes sit in a level dip).
func flatten_at(s: float, half: float, blend: float) -> void:
	var c := elev[index_at(s)]
	for i in range(index_at(s - half - blend), index_at(s + half + blend) + 1):
		var d := absf(dist[i] - s)
		var w := 1.0 - smoothstep(half, half + blend, d)
		elev[i] = lerpf(elev[i], c, w)


# --- hazards ---------------------------------------------------------------------------------------

## Adds crests, jumps, water splashes, chicanes and loose-surface patches on straight sections.
func build_hazards(seed_v: int, kind: String, twist: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7 + 3
	var n := pts.size()
	# Candidates: jumps and crests need a straight run-off; splashes and chicanes tolerate mild bends.
	var strict := _candidates(-12, 24, 1.0 / 90.0)
	var loose := _candidates(-6, 14, 1.0 / 60.0)
	var used: Array = []
	var base_want := ["jump", "splash", "chicane", "crest", "jump", "crest", "splash"]
	if twist > 0.55:
		base_want = ["jump", "chicane", "splash", "crest", "crest", "chicane"]
	var want: Array = []
	for r in int(ceil(length / 2200.0)):
		want.append_array(base_want)
	for t in want:
		var pool: Array = strict if t in ["jump", "crest"] else loose
		if pool.is_empty():
			pool = loose
		for ci in pool:
			var sc: float = dist[ci]
			var free := true
			for u in used:
				if absf(u - sc) < 110.0:
					free = false
					break
			if not free:
				continue
			used.append(sc)
			match t:
				"jump":
					features.append({"type": "jump", "s": sc, "s0": sc - 12.0, "s1": sc + 3.0, "h": rng.randf_range(1.2, 1.5)})
				"crest":
					features.append({"type": "crest", "s": sc, "s0": sc - 14.0, "s1": sc + 14.0, "h": rng.randf_range(0.8, 1.05)})
				"splash":
					features.append({"type": "splash", "i": ci, "s": sc, "s0": sc - 3.5, "s1": sc + 3.5})
				"chicane":
					features.append({"type": "chicane", "s": sc, "s0": sc - 2.0, "s1": sc + 18.0, "side": -1.0 if rng.randf() < 0.5 else 1.0})
			break
	features.sort_custom(func(a, b): return a["s"] < b["s"])
	for f in features:
		if f["type"] == "splash" or f["type"] == "chicane":
			flatten_at(float(f["s"]), 12.0 if f["type"] == "splash" else 14.0, 20.0)
		# Carve the sampled road itself so the mesh, suspension and road grade agree.
		if f["type"] == "splash":
			var sc: float = f["s"]
			for i in range(index_at(sc - 15), index_at(sc + 15) + 1):
				elev[i] -= 0.95 * (1.0 - smoothstep(0.0, 15.0, absf(dist[i] - sc)))
			f["water_y"] = road_h(sc) + Stage.ROAD_Y + 0.20
	for f in features:
		if f["type"] == "jump" or f["type"] == "crest":
			for i in range(index_at(f["s0"]) - 1, index_at(f["s1"]) + 2):
				if i < 0 or i >= n:
					continue
				heights[i] = maxf(heights[i], _bump(f, dist[i]))
	# Loose-surface patches on the road (gravel / mud / ice / deep snow).
	var pk := {"dry": ["gravel", 0.78, 0.1], "rain": ["mud", 0.62, 0.45], "snow": ["ice", 0.53, 0.0]}
	for k in int(6 * maxf(1.0, length / 2200.0)):
		var sc := rng.randf_range(120.0, length - 120.0)
		var near := false
		for f in features:
			if absf(f["s"] - sc) < 40.0:
				near = true
		if near:
			continue
		var info: Array = pk.get(kind, pk["dry"])
		var pkind: String = info[0]
		if kind == "snow" and k % 2 == 1:
			info = ["deep snow", 0.72, 0.55]
			pkind = "deep snow"
		var half := rng.randf() < 0.5
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var l0 := -width * 0.5 if not half else (0.0 if side > 0 else -width * 0.5)
		var l1 := width * 0.5 if not half else (width * 0.5 if side > 0 else 0.0)
		patches.append({"s0": sc, "s1": sc + rng.randf_range(14.0, 30.0), "lat0": l0, "lat1": l1, "kind": pkind, "grip": info[1], "drag": info[2]})
	patches.sort_custom(func(a, b): return a["s0"] < b["s0"])
	# Pace notes for the hazards.
	for f in features:
		notes.append({"s0": f["s0"], "s1": f["s1"], "kind": f["type"], "dir": 0.0, "sev": 0, "hairpin": false})
	for p in patches:
		notes.append({"s0": p["s0"], "s1": p["s1"], "kind": p["kind"], "dir": 0.0, "sev": 0, "hairpin": false})
	notes.sort_custom(func(a, b): return a["s0"] < b["s0"])


func _candidates(from_k: int, to_k: int, kmax: float) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in range(int(90.0 / STEP), n - int(110.0 / STEP), 3):
		if not stacked_crossing.is_empty() and dist[i] < float(stacked_crossing.authored_end) + 38.0:
			continue
		var ok := true
		for j in range(i + from_k, i + to_k):
			if curv_abs[j] > kmax:
				ok = false
				break
		if ok:
			out.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 31 + out.size()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _bump(f: Dictionary, s: float) -> float:
	var h: float = f["h"]
	if f["type"] == "crest":
		var x := (s - float(f["s"])) / 14.0
		return h * 0.5 * (1.0 + cos(PI * clampf(x, -1.0, 1.0))) if absf(x) < 1.0 else 0.0
	# Jump: a long built ramp up to the lip, then a short steep drop.
	var s0: float = f["s0"]
	var sc: float = f["s"]
	if s < s0 or s > float(f["s1"]):
		return 0.0
	if s <= sc:
		var t := (s - s0) / (sc - s0)
		return h * t * t * (3.0 - 2.0 * t)
	return h * (1.0 - (s - sc) / (float(f["s1"]) - sc))


func height_at(s: float, lat: float) -> float:
	if absf(lat) > width * 0.5 + 0.1:
		return 0.0
	var f := clampf(route_station(s) / _sample_step, 0.0, pts.size() - 1.001)
	var i := int(f)
	return lerpf(heights[i], heights[i + 1], f - i)


func road_h_i(i: int) -> float:
	return elev[i] + heights[i]


func patch_at(s: float, lat: float) -> Dictionary:
	if patches_unsorted:
		s = route_station(s)
		var found := {}
		for p in patches:
			if s >= p["s0"] and s <= p["s1"] and lat >= p["lat0"] and lat <= p["lat1"]:
				found = p
		return found
	for p in patches:
		if s < p["s0"]:
			return {}
		if s <= p["s1"] and lat >= p["lat0"] and lat <= p["lat1"]:
			return p
	return {}


func feature_at(s: float, type: String, margin := 0.0) -> Dictionary:
	for f in features:
		if f["type"] == type and s >= float(f["s0"]) - margin and s <= float(f["s1"]) + margin:
			return f
	return {}


## Lane the AI should take through a chicane, or NAN.
func forced_lane(s: float) -> float:
	for gate in gate_distances:
		if s >= gate - 35.0 and s <= gate + 6.0:
			return 0.0
	for f in features:
		if f["type"] != "chicane":
			continue
		var sc: float = f["s"]
		var side: float = f["side"]
		if s > sc - 26.0 and s < sc + 6.0:
			return -side * width * 0.3
		if s >= sc + 6.0 and s < sc + 24.0:
			return side * width * 0.3
	return NAN


## Next pace note (corner or hazard) within `ahead` units of s, or {}.
func next_note(s: float, ahead: float) -> Dictionary:
	for c in notes:
		if c["s1"] < s:
			continue
		if c["s0"] - s > ahead:
			return {}
		return c
	return {}


# --- barriers -----------------------------------------------------------------------------------

## Armco on the outside of fast bends and where the land drops away; post-and-rail fencing along
## farm and moor stretches. kinds: which barrier kinds this location uses.
func build_barriers(seed_v: int, kinds: Array) -> void:
	barriers = []
	for tunnel in tunnels:
		for side: float in [-1, 1]:
			barriers.append({"s0": tunnel.s0, "s1": tunnel.s1, "side": side,
				"kind": "tunnel", "wall": width * 0.5 + 0.90})
	if kinds.is_empty():
		add_bridge_barriers()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 5 + 17
	var n := pts.size()
	var s := 70.0
	while s < finish_s - 120.0:
		var kind: String = kinds[bridges.size() % kinds.size()] if "girder" in kinds else kinds[rng.randi() % kinds.size()]
		var run := rng.randf_range(50.0, 150.0) if kind == "armco" else rng.randf_range(70.0, 200.0)
		# Armco on the outside of the bend (or the side the land falls away), fences either side.
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		if kind == "armco":
			var k := curv[index_at(s + run * 0.5)]
			if absf(k) > 1.0 / 200.0:
				side = 1.0 if k > 0.0 else -1.0   # outside of the bend
		var clear := true
		for tunnel in tunnels:
			if s + run > tunnel.s0 - 12.0 and s < tunnel.s1 + 12.0:
				clear = false
				break
		for f in features:
			if s + run > float(f["s0"]) - 25.0 and s < float(f["s1"]) + 25.0:
				clear = false
				break
		for br in bridges:
			if s + run > float(br["s"]) - float(br["half"]) - 20.0 and s < float(br["s"]) + float(br["half"]) + 20.0:
				clear = false
				break
		if clear:
			barriers.append({"s0": s, "s1": minf(s + run, finish_s - 60.0), "side": side, "kind": kind})
		s += run + rng.randf_range(40.0, 160.0)
	add_bridge_barriers()


# --- bridges -------------------------------------------------------------------------------------

## Bridges over rivers that cross the road at right angles: English stone humpback arches and
## covered wooden bridges. The deck has a parapet (or wall) each side that the cars bounce off.
## Authored crossing on an existing return leg. Keep its original grade and
## stop the cutting before it encounters another part of the route.
func add_switchback_bridge(station: float) -> void:
	var i := index_at(station)
	var ends := PackedVector2Array()
	for side: float in [-1, 1]:
		var reach := 18.0
		while reach < 80.0 and clearance(pts[i] + nrm[i] * side * (reach + 12.0)) > 19.0:
			reach += 4.0
		ends.append(pts[i] + nrm[i] * side * reach)
	bridges.append({"s": station, "kind": "truss", "half": 22.0, "a": ends[0],
		"b": ends[1], "water_y": elev[i] - 10.0, "channel": 13.0, "dry": true, "i": i})


func add_switchback_tunnel(station: float, half_span: float) -> void:
	tunnels.append({"s0": station - half_span, "s1": station + half_span})
	notes.append({"s0": station - half_span, "s1": station + half_span, "kind": "tunnel",
		"dir": 0.0, "sev": 0, "hairpin": false})
	notes.sort_custom(func(a, b): return a.s0 < b.s0)


func tunnel_at(station: float, margin := 0.0) -> bool:
	for tunnel in tunnels:
		if station >= tunnel.s0 - margin and station <= tunnel.s1 + margin:
			return true
	return false


func build_bridges(seed_v: int, kinds: Array) -> void:
	bridges = []
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 13 + 5
	var want := clampi(int(length / 3500.0) + 1, 1, 4)
	var candidates := _candidates(-12, 12, 1.0 / 72.0) if "girder" in kinds else _candidates(-14, 14, 1.0 / 160.0)
	for ci in candidates:
		if bridges.size() >= want:
			break
		var sc: float = dist[ci]
		if sc < 200.0 or sc > finish_s - 160.0:
			continue
		var ok := true
		for f in features:
			if absf(float(f["s"]) - sc) < 90.0:
				ok = false
				break
		for b in bridges:
			if absf(float(b["s"]) - sc) < 700.0:
				ok = false
				break
		if not ok:
			continue
		var kind: String = kinds[bridges.size() % kinds.size()] if "girder" in kinds else kinds[rng.randi() % kinds.size()]
		var long_span := kind in ["truss", "girder"]
		var half := 24.0 if long_span else (11.0 if kind == "stone" else 10.0)
		flatten_at(sc, half + 4.0, 16.0)
		var base := elev[ci]
		if kind == "stone":
			# The hump of a packhorse-style arch.
			for i in range(index_at(sc - half - 6.0), index_at(sc + half + 6.0) + 1):
				var u := absf(dist[i] - sc) / (half + 6.0)
				if u < 1.0:
					elev[i] += 0.85 * pow(cos(u * PI * 0.5), 2.0)
		var water_y := base - (12.0 if long_span else 3.6 if kind == "stone" else 3.9)
		# River runs straight across the road; it stops before it meets another stretch of road.
		var ends: Array = []
		for side: float in [-1.0, 1.0]:
			var t := 12.0
			while t < 260.0:
				var q: Vector2 = pts[ci] + nrm[ci] * side * (t + 4.0)
				if clearance(q) < (t + 4.0) * 0.6 - 2.0:
					break
				t += 4.0
			ends.append(pts[ci] + nrm[ci] * side * t)
		bridges.append({"s": sc, "kind": kind, "half": half, "a": ends[0], "b": ends[1], "water_y": water_y, "channel": 14.0 if long_span else 5.5, "dry": kind == "girder", "i": ci})
	bridges.sort_custom(func(a, b): return a["s"] < b["s"])


func road_half_width(s: float) -> float:
	if not widths.is_empty():
		return widths[index_at(s)] * 0.5
	var br := bridge_at(s, 12.0)
	if br.get("kind") == "stone":
		var approach := absf(s - float(br.s)) - float(br.half)
		return width * lerpf(0.34, 0.5, smoothstep(1.0, 12.0, approach))
	return width * 0.5


## Bridge at s (within its deck plus `margin`), or {}.
func bridge_at(s: float, margin := 0.0) -> Dictionary:
	for b in bridges:
		if absf(s - float(b["s"])) <= float(b["half"]) + margin:
			return b
	return {}


## All water sheets use local X across the banks and local Z downstream.
class Watercourse:
	var middle: Vector2
	var flow: Vector2
	var across: Vector2
	var length: float
	var width: float
	var bounds: Rect2

	func _init(a: Vector2, b: Vector2, half_width: float) -> void:
		middle = (a + b) * 0.5
		flow = a.direction_to(b)
		across = Vector2(flow.y, -flow.x)
		length = a.distance_to(b)
		width = half_width
		bounds = Rect2(a, Vector2.ZERO).expand(b).grow(width * 1.45 + 1.0)

	func overlaps(p: Vector2, radius: float) -> bool:
		if not bounds.grow(radius).has_point(p):
			return false
		var delta := p - middle
		return absf(delta.dot(flow)) <= length * 0.5 + radius and absf(delta.dot(across)) <= width * 1.45 + radius

var watercourses: Array[Watercourse] = []


func index_watercourses() -> void:
	watercourses.clear()
	for br in bridges:
		if not br.dry:
			watercourses.append(Watercourse.new(br.a, br.b, br.channel))
	for f in features:
		if f["type"] == "splash":
			var i: int = f["i"]
			var offset := nrm[i] * (width * 0.5 + 16.0)
			watercourses.append(Watercourse.new(pts[i] - offset, pts[i] + offset, 3.6))


static func channel_x(z: float, fraction: float, width: float, seed_v: int) -> float:
	var phase := float(seed_v % 41)
	var bend := sin(z * 0.093 + phase) * 0.18 + sin(z * 0.22 - phase) * 0.065
	var breadth := 1.0 + 0.09 * sin(z * 0.16 + phase)
	return width * (bend + fraction * breadth)


## Over the gravel lane the water sheet extends under the rising road at each shore.
static func ford_width(along: float, road_half_width: float) -> float:
	return lerpf(5.8, 3.6, smoothstep(road_half_width, road_half_width + 3.0, absf(along)))


## The stream mesh lies across the stage, with local +X pointing against travel.
func inside_ford(p: Vector2, s: float) -> bool:
	var ford := feature_at(s, "splash", 3.0)
	if ford.is_empty():
		return false
	var i: int = ford["i"]
	var offset := p - pts[i]
	var across := -offset.dot(tang[i])
	var along := -offset.dot(nrm[i])
	if absf(along) > width * 0.5 + 16.0 or surface_height(p, s, along) + (Stage.ROAD_Y if absf(along) <= width * 0.5 else 0.0) >= float(ford["water_y"]):
		return false
	var breadth := ford_width(along, width * 0.5)
	return across >= channel_x(along, -1.0, breadth, i) and across <= channel_x(along, 1.0, breadth, i)


func overlaps_water(p: Vector2, radius: float) -> bool:
	for stream in watercourses:
		if stream.overlaps(p, radius):
			return true
	return false


## Parapets: added after the ordinary barriers so a bridge always has its own.
func add_bridge_barriers() -> void:
	for b in bridges:
		for side: float in [-1.0, 1.0]:
			barriers.append({"s0": float(b["s"]) - float(b["half"]) - 1.5, "s1": float(b["s"]) + float(b["half"]) + 1.5, "side": side, "kind": "parapet", "wall": road_half_width(b.s) + (0.0 if b.kind == "stone" else Stage.BARRIER_LAT)})


## Coast: Armco wherever the land drops away into the sea beside the road.
func add_cliff_barriers() -> void:
	var hw := width * 0.5
	for side: float in [-1.0, 1.0]:
		var run_s := -1.0
		var last := -1.0
		var i := 0
		while i < pts.size():
			var s := dist[i]
			var q := pts[i] + nrm[i] * side * (hw + 9.0)
			var q2 := pts[i] + nrm[i] * side * (hw + 18.0)
			var drop := terrain.is_sea(q) or terrain.is_sea(q2) or terrain.height(q) < elev[i] - 4.0
			var ok := drop and s > 40.0 and s < finish_s - 20.0 and bridge_at(s, 15.0).is_empty()
			if ok:
				if run_s < 0.0:
					run_s = s - 10.0
				last = s + 10.0
			elif run_s >= 0.0 and s - last > 12.0:
				_add_cliff_run(run_s, last, side)
				run_s = -1.0
			i += 3
		if run_s >= 0.0:
			_add_cliff_run(run_s, last, side)


func _add_cliff_run(s0: float, s1: float, side: float) -> void:
	if s1 - s0 < 24.0:
		return
	# Drop any fence already on that stretch; the Armco takes over.
	var keep: Array = []
	for b in barriers:
		if float(b["side"]) == side and float(b["s1"]) > s0 and float(b["s0"]) < s1 and b["kind"] != "parapet":
			continue
		keep.append(b)
	barriers = keep
	barriers.append({"s0": s0, "s1": s1, "side": side, "kind": "armco"})


## Barrier at s on the given side of the road, or {}.
## Joker lane band (signed lateral lo, hi) at s, or Vector2(NAN, NAN).
func joker_band(s: float) -> Vector2:
	if joker.is_empty():
		return Vector2(NAN, NAN)
	var i := index_at(s)
	if i < joker.i0 or i > joker.i1:
		return Vector2(NAN, NAN)
	var lo: float = joker.lo[i]
	var hi: float = joker.hi[i]
	if is_nan(lo):
		return Vector2(NAN, NAN)
	return Vector2(lo, hi) * float(joker.side) if float(joker.side) > 0.0 else Vector2(-hi, -lo)


## True on the road proper or on the Joker lane (not on the island between them).
func on_road_at(s: float, lat: float, margin := 0.2) -> bool:
	if absf(lat) <= road_half_width(s) + margin:
		return true
	var band := joker_band(s)
	return not is_nan(band.x) and lat >= band.x - margin and lat <= band.y + margin


## Outermost drivable lateral offset at s (used to bound the banked surface).
func road_extent(s: float) -> float:
	var band := joker_band(s)
	var hw := road_half_width(s)
	if is_nan(band.x):
		return hw
	return maxf(hw, maxf(absf(band.x), absf(band.y)))


## Cross-slope at sample i (metres of height per metre sideways).
func bank_slope(i: int) -> float:
	return banks[i] if not banks.is_empty() else 0.0


## Lateral distance of a barrier's wall from the centre line at s.
func barrier_wall(bar: Dictionary, s: float) -> float:
	match str(bar.get("ref", "")):
		"road":
			return road_half_width(s) + float(bar.get("offset", 0.75))
		"lane_out":
			var band := joker_band(s)
			return (maxf(absf(band.x), absf(band.y)) if not is_nan(band.x) else road_half_width(s)) + float(bar.get("offset", 0.75))
		"lane_in":
			var b := joker_band(s)
			return (minf(absf(b.x), absf(b.y)) - float(bar.get("offset", 0.75)) if not is_nan(b.x) else road_half_width(s) + 0.75)
	return float(bar.get("wall", width * 0.5 + Stage.BARRIER_LAT))


func index_barriers() -> void:
	_barrier_cells = {}
	for b in barriers:
		for cell in range(int(float(b["s0"]) / 12.0), int(float(b["s1"]) / 12.0) + 1):
			if not _barrier_cells.has(cell):
				_barrier_cells[cell] = []
			_barrier_cells[cell].append(b)


## Every barrier on this side of the road at s (a Joker section has the island and the lane wall).
func barriers_at(s: float, side: float) -> Array:
	var out: Array = []
	s = route_station(s)
	var source: Array = _barrier_cells.get(int(s / 12.0), []) if rx else barriers
	for b in source:
		if s >= float(b["s0"]) and s <= float(b["s1"]) and float(b["side"]) == side:
			out.append(b)
	return out


func barrier_at(s: float, side: float) -> Dictionary:
	for b in barriers:
		if s >= float(b["s0"]) and s <= float(b["s1"]) and float(b["side"]) == side:
			return b
	return {}
