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
	_find_corners()


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
				corners.append({"s0": dist[i], "s1": dist[mini(j, n - 1)], "dir": -sgn, "sev": sev,
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
