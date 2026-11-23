class_name Track
extends RefCounted
## A point-to-point rally stage generated from a seed: smooth clothoid-like curvature changes,
## no self-crossing. Sampled every STEP units. Provides projection queries, pace notes and an
## ideal-speed profile used by the AI and for medal times.

const STEP := 2.0
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

# Hazards (rally-game staples: crests, jumps, water splashes, hay-bale chicanes, loose surfaces).
var heights := PackedFloat32Array()  # road height per sample (crests and jump ramps are built paper ramps)
var features: Array = []             # {type: jump|crest|splash|chicane, s0, s1, s (centre), side}
var patches: Array = []              # {s0, s1, lat0, lat1, kind, grip, drag}
var notes: Array = []                # pace notes: corners + features, sorted by s0


func generate(seed_v: int, target_len: float, twist: float, w: float) -> void:
	width = w
	for attempt in 40:
		if _try(seed_v + attempt * 7919, target_len, twist):
			_finalize()
			return
	_finalize()


func _try(seed_v: int, target_len: float, twist: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	pts = PackedVector2Array()
	grid = {}
	var pos := Vector2.ZERO
	var h := 0.0
	var base := 0.0
	var k := 0.0
	pts.append(pos)
	_grid_add(0, pos)
	var total := 0.0
	# Run-up straight for the start grid.
	var segs: Array = [[0.0, 46.0]]
	while total < target_len:
		if segs.is_empty():
			if rng.randf() < 0.32 - twist * 0.14:
				segs.append([0.0, rng.randf_range(24.0, 80.0) * (1.2 - twist * 0.4)])
			else:
				var hair := rng.randf() < twist * 0.16
				var radius := 14.0 if hair else lerpf(80.0, 17.0, pow(rng.randf(), 0.8) * (0.45 + twist * 0.55))
				var ang := deg_to_rad(rng.randf_range(155.0, 178.0) if hair else rng.randf_range(25.0, 80.0 + 70.0 * twist))
				var sgn := -1.0 if rng.randf() < 0.5 else 1.0
				var off := wrapf(h - base, -PI, PI)
				if absf(off) > 1.0:
					sgn = -signf(off)
				segs.append([sgn / radius, ang * radius])
				if rng.randf() < 0.3 + twist * 0.3:
					segs.append([0.0, rng.randf_range(8.0, 20.0)])
			base += rng.randf_range(-0.5, 0.5)
		var seg: Array = segs.pop_front()
		var kt: float = seg[0]
		var seg_len: float = seg[1]
		var steps := int(seg_len / STEP)
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
	return true


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
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
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
	finish_s = length - 30.0
	heights.resize(n)
	heights.fill(0.0)
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

func index_at(s: float) -> int:
	return clampi(int(s / STEP), 0, pts.size() - 1)


func point_at(s: float) -> Vector2:
	var f := clampf(s / STEP, 0.0, pts.size() - 1.001)
	var i := int(f)
	return pts[i].lerp(pts[i + 1], f - i)


## Returns [index, s, lateral, tangent]. `hint` speeds up the local search.
func project(p: Vector2, hint: int) -> Array:
	var n := pts.size()
	var best := -1
	var bd := INF
	var lo := clampi(hint - 24, 0, n - 1)
	var hi := clampi(hint + 24, 0, n - 1)
	for i in range(lo, hi + 1):
		var d := p.distance_squared_to(pts[i])
		if d < bd:
			bd = d
			best = i
	if best < 0 or bd > 900.0:
		best = nearest_global(p)
	var i0 := best
	var i1 := mini(best + 1, n - 1)
	if best > 0 and (p - pts[best]).dot(tang[best]) < 0.0:
		i0 = best - 1
		i1 = best
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
			"jump": cap = 26.0
		for i in range(index_at(float(f["s0"]) - 6.0), index_at(float(f["s1"]) + 4.0) + 1):
			v[i] = minf(v[i], cap)
	for p in patches:
		for i in range(index_at(p["s0"]), index_at(p["s1"]) + 1):
			v[i] *= sqrt(float(p["grip"]))
	for i in range(n - 2, -1, -1):
		v[i] = minf(v[i], sqrt(v[i + 1] * v[i + 1] + 2.0 * a_brake * STEP))
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
	var want := ["jump", "splash", "chicane", "crest", "jump", "crest", "splash"]
	if twist > 0.55:
		want = ["jump", "chicane", "splash", "crest", "crest", "chicane"]
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
					features.append({"type": "jump", "s": sc, "s0": sc - 12.0, "s1": sc + 3.0, "h": rng.randf_range(1.5, 1.9)})
				"crest":
					features.append({"type": "crest", "s": sc, "s0": sc - 14.0, "s1": sc + 14.0, "h": rng.randf_range(0.9, 1.2)})
				"splash":
					features.append({"type": "splash", "s": sc, "s0": sc - 3.5, "s1": sc + 3.5})
				"chicane":
					features.append({"type": "chicane", "s": sc, "s0": sc - 2.0, "s1": sc + 18.0, "side": -1.0 if rng.randf() < 0.5 else 1.0})
			break
	features.sort_custom(func(a, b): return a["s"] < b["s"])
	for f in features:
		if f["type"] == "jump" or f["type"] == "crest":
			for i in range(index_at(f["s0"]) - 1, index_at(f["s1"]) + 2):
				if i < 0 or i >= n:
					continue
				heights[i] = maxf(heights[i], _bump(f, dist[i]))
	# Loose-surface patches on the road (gravel / mud / ice / deep snow).
	var pk := {"dry": ["gravel", 0.78, 0.1], "rain": ["mud", 0.62, 0.45], "snow": ["ice", 0.55, 0.0]}
	for k in 6:
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
	var f := clampf(s / STEP, 0.0, pts.size() - 1.001)
	var i := int(f)
	return lerpf(heights[i], heights[i + 1], f - i)


func patch_at(s: float, lat: float) -> Dictionary:
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
