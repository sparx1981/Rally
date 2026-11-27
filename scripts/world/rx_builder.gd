class_name RxBuilder
extends RefCounted
## Builds a rallycross circuit's road data (see Rallycross for the authored circuit tables).

const STEP := 2.0
const BRIDGE_CLEARANCE := 7.6     # deck, 5.5 m of headroom and a margin
const ISLAND_GAP := 2.0           # island between the main road and the Joker lane
const EDGE_OFFSET := 0.9          # barrier line outside the road edge


# --- shape -----------------------------------------------------------------------------------------

## Closed polygon with a fillet at each corner. Returns points about STEP apart (first == last).
static func trace(verts: Array, scale: float) -> PackedVector2Array:
	var n := verts.size()
	var points: Array[Vector2] = []
	var radii: Array[float] = []
	for v: Array in verts:
		points.append(Vector2(float(v[0]), float(v[1])) * scale)
		radii.append(float(v[2]))
	var cuts: Array = []
	for i in n:
		var p0 := points[(i - 1 + n) % n]
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var u1 := p0 - p1
		var l1 := u1.length()
		u1 /= l1
		var u2 := p2 - p1
		var l2 := u2.length()
		u2 /= l2
		var ang := acos(clampf(u1.dot(u2), -1.0, 1.0))
		var theta := PI - ang
		var r := radii[i]
		if r <= 0.0 or theta < deg_to_rad(1.0):
			cuts.append(null)
			continue
		var t := r * tan(theta * 0.5)
		var limit := 0.5 * minf(l1, l2)
		if t > limit:
			t = limit
			r = t / tan(theta * 0.5)
		var bisector := (u1 + u2).normalized()
		cuts.append({"a": p1 + u1 * t, "b": p1 + u2 * t, "c": p1 + bisector * (r / sin(ang * 0.5)), "r": r,
			"sign": 1.0 if (u1.x * u2.y - u1.y * u2.x) < 0.0 else -1.0, "theta": theta})
	var out := PackedVector2Array()
	var start: Vector2 = cuts[0].b if cuts[0] != null else points[0]
	out.append(start)
	var cur := start
	var order: Array = range(1, n)
	order.append(0)
	for i: int in order:
		var cut = cuts[i]
		var entry: Vector2 = cut.a if cut != null else points[i]
		var steps := maxi(1, roundi(cur.distance_to(entry) / STEP))
		for j in range(1, steps + 1):
			out.append(cur.lerp(entry, float(j) / steps))
		if cut != null:
			var a0: float = (cut.a - cut.c).angle()
			var arc_steps: int = maxi(2, ceili(float(cut.theta) * float(cut.r) / STEP))
			for j in range(1, arc_steps + 1):
				var ang_j: float = a0 + cut.sign * cut.theta * j / arc_steps
				out.append(cut.c + Vector2(cos(ang_j), sin(ang_j)) * cut.r)
			cur = cut.b
		else:
			cur = points[i]
	var close_steps := maxi(1, roundi(cur.distance_to(start) / STEP))
	for j in range(1, close_steps + 1):
		out.append(cur.lerp(start, float(j) / close_steps))
	out[out.size() - 1] = out[0]
	return out


static func path_length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i].distance_to(line[i - 1])
	return total


## Uniform scale of the waypoints (corner radii stay fixed) that gives the target lap length.
static func autoscale(verts: Array, target: float) -> float:
	var lo := 0.3
	var hi := 3.0
	for _i in 30:
		var mid := (lo + hi) * 0.5
		if path_length(trace(verts, mid)) > target:
			hi = mid
		else:
			lo = mid
	return (lo + hi) * 0.5


# --- keyframes -------------------------------------------------------------------------------------

## Smooth value from [[f, v], ...] (first and last f are 0 and 1 and equal in value).
static func _smooth_key(keys: Array, f: float) -> float:
	f = clampf(f, 0.0, 1.0)
	for i in keys.size() - 1:
		var f0 := float(keys[i][0])
		var f1 := float(keys[i + 1][0])
		if f <= f1:
			return lerpf(float(keys[i][1]), float(keys[i + 1][1]), smoothstep(f0, f1, f))
	return float(keys[-1][1])


## Periodic Catmull-Rom through the keys (for altitude).
static func _periodic_key(keys: Array, f: float) -> float:
	var m := keys.size() - 1
	f = fposmod(f, 1.0)
	var i := 0
	while i < m - 1 and f >= float(keys[i + 1][0]):
		i += 1
	var f0 := float(keys[i][0])
	var f1 := float(keys[i + 1][0])
	var t := (f - f0) / maxf(f1 - f0, 0.000001)
	var p0 := float(keys[(i - 1 + m) % m][1])
	var p1 := float(keys[i][1])
	var p2 := float(keys[(i + 1) % m][1])
	var p3 := float(keys[(i + 2) % m][1])
	return 0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


static func _wrap_dist(a: float, b: float, length: float) -> float:
	return absf(wrapf(a - b, -length * 0.5, length * 0.5))


# --- build -----------------------------------------------------------------------------------------

static func build(track: Track, def: Dictionary) -> void:
	var rx: Dictionary = def.rx
	var scale := autoscale(rx.verts, float(rx.length))
	track.circuit = true
	track.rx = true
	track.pts = trace(rx.verts, scale)
	track._finalize()
	track._rebuild_grid()
	var n := track.pts.size()
	track._sample_step = track.length / float(n - 1)
	track.start_s = 0.0
	track.finish_s = track.length
	var length := track.length
	# Road width, altitude and bank around the lap.
	track.widths.resize(n)
	track.banks.resize(n)
	var turn_sign := _turn_signs(track)
	var max_width := 0.0
	for i in n:
		var f := track.dist[i] / length
		track.widths[i] = _smooth_key(rx.widths, f)
		max_width = maxf(max_width, track.widths[i])
		track.elev[i] = _periodic_key(rx.elev, f)
		var b := 0.0
		for band: Array in rx.get("bank", []):
			var edge := minf(0.06, (float(band[1]) - float(band[0])) * 0.45)   # bank rolls in and out gradually
			b += float(band[2]) * smoothstep(float(band[0]), float(band[0]) + edge, f) * (1.0 - smoothstep(float(band[1]) - edge, float(band[1]), f))
		# Positive banks into the turn: the inside edge is lower.
		track.banks[i] = -b * turn_sign[i]
	track.width = max_width
	_find_crossing(track)
	# Surfaces: tarmac everywhere, loose sectors on top, the Joker lane last.
	track.patches_unsorted = true
	_add_patch(track, 0.0, length, -99.0, 99.0, "tarmac")
	for sector: Array in rx.get("surf", []):
		_add_patch(track, float(sector[0]) * length, float(sector[1]) * length, -99.0, 99.0, str(sector[2]))
	var joker: Dictionary = rx.get("joker", {})
	if not joker.is_empty():
		_build_joker(track, joker)
	for jump: Dictionary in rx.get("jumps", []):
		_add_jump(track, jump)
	for splash: Dictionary in rx.get("splash", []):
		_add_splash(track, float(splash.f) * track.length)
	if rx.has("tunnel"):
		var span: Array = rx.tunnel
		var mid := (float(span[0]) + float(span[1])) * 0.5 * length
		track.add_switchback_tunnel(mid, (float(span[1]) - float(span[0])) * 0.5 * length)
		track.flatten_at(mid, 40.0, 30.0)
	if rx.has("bridge"):
		_add_covered_bridge(track, float(rx.bridge.f) * length)
	_build_barriers(track, rx)
	track.notes.sort_custom(func(a, b): return a.s0 < b.s0)
	track.rx_info = {"racers": int(rx.racers), "laps": int(rx.get("laps", 5)), "joker": track.joker.duplicate(),
		"delta": float(joker.get("delta", 0.0)), "pace": 0.0 if OS.get_cmdline_user_args().has("--nopace") else float(joker.get("pace", 0.0)), "kit": str(rx.kit)}


## Signed turning direction (+1 left, -1 right) smoothed over +-40 m, for banking into corners.
static func _turn_signs(track: Track) -> PackedFloat32Array:
	var n := track.pts.size()
	var raw := PackedFloat32Array()
	raw.resize(n)
	var win := 20
	for i in n:
		var a := track.tang[posmod(i - win, n - 1)]
		var b := track.tang[posmod(i + win, n - 1)]
		raw[i] = a.x * b.y - a.y * b.x
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 1.0
	for i in n:
		if absf(raw[i]) > 0.08:
			last = signf(raw[i])
		out[i] = last
	return out


static func _add_patch(track: Track, s0: float, s1: float, lat0: float, lat1: float, kind: String) -> void:
	var surface: Dictionary = Rallycross.SURFACES[kind]
	track.patches.append({"s0": s0, "s1": s1, "lat0": lat0, "lat1": lat1, "kind": kind, "grip": float(surface.grip),
		"drag": float(surface.drag) * 0.3, "rx": true})   # graded and packed: half the free-gravel drag


## First place the line crosses itself: the second pass becomes the upper deck.
static func _find_crossing(track: Track) -> void:
	var n := track.pts.size()
	var skip := 60
	var found := false
	var lower := 0
	var upper := 0
	var center := Vector2.ZERO
	for i in range(0, n - 1):
		for j in range(i + skip, n - 1):
			if i == 0 and j > n - skip:
				continue
			if track.pts[i].distance_squared_to(track.pts[j]) > 9.0:
				continue
			var hit = Geometry2D.segment_intersects_segment(track.pts[i], track.pts[i + 1], track.pts[j], track.pts[j + 1])
			if hit != null:
				found = true
				lower = i
				upper = j
				center = hit
				break
		if found:
			break
	if not found:
		return
	var length := track.length
	var diff: float = track.elev[upper] - track.elev[lower]
	if diff < BRIDGE_CLEARANCE:
		var add := BRIDGE_CLEARANCE - diff
		for i in n:
			var up_d := _wrap_dist(track.dist[i], track.dist[upper], length)
			var low_d := _wrap_dist(track.dist[i], track.dist[lower], length)
			track.elev[i] += add * 0.6 * (1.0 - smoothstep(30.0, 100.0, up_d))
			track.elev[i] -= add * 0.4 * (1.0 - smoothstep(30.0, 100.0, low_d))
	# A shallow crossing angle overlaps for longer: size the bridge to cover both roads' full width at the crossing.
	var sin_a := absf(track.tang[lower].x * track.tang[upper].y - track.tang[lower].y * track.tang[upper].x)
	var overlap := track.road_half_width(track.dist[upper]) + track.road_half_width(track.dist[lower]) + 6.0
	var half := clampf(overlap / maxf(sin_a, 0.2), 21.0, 56.0)
	track.stacked_crossing = {"center": center, "lower": track.dist[lower], "upper": track.dist[upper], "half": half}
	track._register_stacked_bridge()


## Joker lane: an alternative route beside the main road, separated by an island, that rejoins it.
static func _build_joker(track: Track, jk: Dictionary) -> void:
	var n := track.pts.size()
	var length := track.length
	var s0 := float(jk.f0) * length
	var s1 := float(jk.f1) * length
	var i0 := track.index_at(s0)
	var i1 := track.index_at(s1)
	var turn := 0.0
	for i in range(i0, i1):
		turn += track.tang[i].x * track.tang[i + 1].y - track.tang[i].y * track.tang[i + 1].x
	var inner := 1.0 if turn >= 0.0 else -1.0
	var side := inner if str(jk.side) == "inner" else -inner
	var lane_w := float(jk.w)
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	var gap := PackedFloat32Array()
	lo.resize(n)
	hi.resize(n)
	gap.resize(n)
	lo.fill(NAN)
	hi.fill(NAN)
	gap.fill(0.0)
	var max_hw := 0.0
	# Entry and exit blends are measured in metres (30 % of the lane, 36-80 m), so a long lane opens and closes
	# as gradually as a short one: it grows from a point at the road edge, the island appears after it, and
	# the whole thing folds back into the road at the other end.
	var blend := clampf((s1 - s0) * 0.3, 36.0, 80.0)
	for i in range(i0, i1 + 1):
		var u := clampf((track.dist[i] - s0) / (s1 - s0), 0.0, 1.0)
		var d0 := track.dist[i] - s0
		var d1 := s1 - track.dist[i]
		var hw: float = track.widths[i] * 0.5
		max_hw = maxf(max_hw, hw)
		var ramp := smoothstep(0.7 * blend, 1.9 * blend, d0) * smoothstep(0.7 * blend, 1.9 * blend, d1)
		gap[i] = ISLAND_GAP * ramp
		# The lateral offset also grows in over the blend, so the lane's centre line leaves the road at a gentle
		# angle (about 8 degrees) that a car at speed can follow.
		var grow := smoothstep(0.2 * blend, 1.8 * blend, d0) * smoothstep(0.2 * blend, 1.8 * blend, d1)
		var excursion := float(jk.out) * 0.5 * pow(sin(PI * u), 1.3) * grow
		var inner_edge := hw + gap[i] + excursion
		lo[i] = inner_edge
		var enter := maxf(smoothstep(0.0, 1.3 * blend, d0), 0.12)
		var leave := 0.25 + 0.75 * smoothstep(0.0, 1.3 * blend, d1)
		hi[i] = inner_edge + lane_w * enter * leave
	track.joker = {"s0": s0, "s1": s1, "side": side, "w": lane_w, "i0": i0, "i1": i1, "lo": lo, "hi": hi, "gap": gap,
		"surf": str(jk.surf), "max_hw": max_hw, "blend": blend}
	var lat0 := max_hw + 0.3 if side > 0.0 else -99.0
	var lat1 := 99.0 if side > 0.0 else -(max_hw + 0.3)
	_add_patch(track, s0, s1, lat0, lat1, str(jk.surf))
	# The lane is graded and packed, so it costs the Joker's time delta without being a mud bath:
	# half way between its loose surface and tarmac.
	track.patches[-1]["grip"] = lerpf(float(track.patches[-1]["grip"]), 1.15, 0.35)


## A shallow water crossing: the road dips a little and water runs over it (a splash for the pace notes).
static func _add_splash(track: Track, station: float) -> void:
	var ci := track.index_at(station)
	track.flatten_at(station, 12.0, 20.0)
	for i in range(track.index_at(station - 15.0), track.index_at(station + 15.0) + 1):
		track.elev[i] -= 0.95 * (1.0 - smoothstep(0.0, 15.0, absf(track.dist[i] - station)))
	track.features.append({"type": "splash", "i": ci, "s": station, "s0": station - 3.5, "s1": station + 3.5,
		"water_y": track.road_h(station) + Stage.ROAD_Y + 0.20})
	track.notes.append({"s0": station - 3.5, "s1": station + 3.5, "kind": "splash", "dir": 0.0, "sev": 0, "hairpin": false})


static func _add_jump(track: Track, jump: Dictionary) -> void:
	var sc := float(jump.f) * track.length
	# Higher and more ramp-like than the brief's first cut: a shorter, steeper take-off ramp and a taller lip,
	# so a car at speed leaves the ground for a real, if short, flight.
	var run := clampf(float(jump.len) * 0.65, 14.0, 20.0)
	var height := float(jump.h) * 1.9
	var drop := 8.0 if str(jump.kind) != "table" else 14.0
	var cap := 38.0 if str(jump.kind) == "gap" else 30.0
	track.features.append({"type": "jump", "s": sc, "s0": sc - run, "s1": sc + drop, "h": height, "cap": cap, "rx": true})
	track.notes.append({"s0": sc - run, "s1": sc + drop, "kind": "jump", "dir": 0.0, "sev": 0, "hairpin": false})
	for i in range(track.index_at(sc - run) - 1, track.index_at(sc + drop) + 2):
		if i >= 0 and i < track.pts.size():
			track.heights[i] = maxf(track.heights[i], track._bump(track.features[-1], track.dist[i]))


static func _add_covered_bridge(track: Track, station: float) -> void:
	var ci := track.index_at(station)
	var half := 10.0
	track.flatten_at(station, half + 4.0, 16.0)
	var ends: Array = []
	for side: float in [-1.0, 1.0]:
		var t := 12.0
		while t < 260.0:
			var q: Vector2 = track.pts[ci] + track.nrm[ci] * side * (t + 4.0)
			if track.clearance(q) < (t + 4.0) * 0.6 - 2.0:
				break
			t += 4.0
		ends.append(track.pts[ci] + track.nrm[ci] * side * t)
	track.bridges.append({"s": track.dist[ci], "kind": "covered", "half": half, "a": ends[0], "b": ends[1],
		"water_y": track.elev[ci] - 3.9, "channel": 5.5, "dry": false, "i": ci})
	track.notes.append({"s0": station - half - 14.0, "s1": station + half, "kind": "bridge", "dir": 0.0, "sev": 0, "hairpin": false})


## Edge walls (tyre walls, jersey barriers, Armco) following the road width, with the Joker island and
## the lane's outer wall replacing the ordinary wall on the lane side while the lane runs.
static func _build_barriers(track: Track, rx: Dictionary) -> void:
	var length := track.length
	track.barriers = []
	var jk := track.joker
	for side: float in [-1.0, 1.0]:
		for style: Array in rx.get("barrier", [[0, 1, "tyre"]]):
			var s0 := float(style[0]) * length
			var s1 := float(style[1]) * length
			var kind := str(style[2])
			if not jk.is_empty() and float(jk.side) == side:
				var j0: float = float(jk.s0)
				var j1: float = float(jk.s1)
				if s1 > j0 and s0 < j1:
					if s0 < j0:
						track.barriers.append(_bar(s0, j0, side, kind, "road"))
					if s1 > j1:
						track.barriers.append(_bar(j1, s1, side, kind, "road"))
					continue
			track.barriers.append(_bar(s0, s1, side, kind, "road"))
	if not jk.is_empty():
		var side: float = jk.side
		var a: float = jk.s0
		var b: float = jk.s1
		# Wall on the lane's outer edge for the whole lane.
		track.barriers.append(_bar(a, b, side, "tyre", "lane_out"))
		# Island: a foam and tyre divider along the road edge and along the lane's inner edge, from the
		# nose to the merge, leaving the entry and exit open.
		# The island's two walls (road side and lane side) only stand where the island is wide enough for them to
		# clear each other; before that the road simply widens into the lane.
		var isl0 := -1.0
		var isl1 := -1.0
		for i in range(int(jk.i0), int(jk.i1) + 1):
			var lo_i: float = jk.lo[i]
			if is_nan(lo_i):
				continue
			if lo_i - track.widths[i] * 0.5 >= 1.9:
				if isl0 < 0.0:
					isl0 = track.dist[i]
				isl1 = track.dist[i]
		if isl1 > isl0 and isl0 >= 0.0:
			track.barriers.append(_bar(isl0, isl1, side, "island", "road"))
			track.barriers.append(_bar(isl0, isl1, side, "island", "lane_in"))
	track.index_barriers()


static func _bar(s0: float, s1: float, side: float, kind: String, ref: String) -> Dictionary:
	return {"s0": s0, "s1": s1, "side": side, "kind": kind, "ref": ref, "offset": EDGE_OFFSET}
