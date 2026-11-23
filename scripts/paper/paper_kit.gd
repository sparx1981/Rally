class_name PaperKit
extends RefCounted
## Builds paper geometry: cut cards with real thickness, a printed dark cut edge, a pale lip on the
## light-facing edges, kraft-tinted backs and darker side strips (papercraft skill, look.md 2-3).
## All pieces merge into one vertex-coloured mesh so a whole prop is a single draw call.

const KRAFT := Color(0.91, 0.827, 0.675)
const CREAM := Color(0.97, 0.94, 0.87)
const INK := Color(0.2, 0.13, 0.08)


class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var tone_rng := RandomNumberGenerator.new()

	func _init(seed_v: int = 1) -> void:
		tone_rng.seed = seed_v

	func tri3(a: Vector3, b: Vector3, d: Vector3, nn: Vector3, ca: Color, cb: Color, cd: Color) -> void:
		# Godot front faces are clockwise: make the winding agree with the wanted normal.
		if (b - a).cross(d - a).dot(nn) > 0.0:
			v.append(a); v.append(d); v.append(b)
			c.append(ca); c.append(cd); c.append(cb)
		else:
			v.append(a); v.append(b); v.append(d)
			c.append(ca); c.append(cb); c.append(cd)
		n.append(nn); n.append(nn); n.append(nn)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, nn: Vector3, col: Color) -> void:
		tri3(a, b, d, nn, col, col, col)
		tri3(a, d, e, nn, col, col, col)

	func quad4(a: Vector3, b: Vector3, d: Vector3, e: Vector3, nn: Vector3, ca: Color, cb: Color, cd: Color, ce: Color) -> void:
		tri3(a, b, d, nn, ca, cb, cd)
		tri3(a, d, e, nn, ca, cd, ce)

	## A cut card: outline `poly` in the card's XY plane (Y up), extruded along Z by `thick`.
	## opts: thick, edge, lip, back (Color), glow (bool: lit pane), tone (per-sheet variation), sides (bool)
	func card(poly: PackedVector2Array, xf: Transform3D, col: Color, opts: Dictionary = {}) -> void:
		var p := PaperKit.ccw(poly)
		var cnt := p.size()
		if cnt < 3:
			return
		var bb := PaperKit.bounds(p)
		var minside := minf(bb.size.x, bb.size.y)
		var t: float = opts.get("thick", 0.06)
		var ew: float = minf(float(opts.get("edge", 0.05)), minside * 0.09)
		var lw: float = minf(float(opts.get("lip", 0.06)), minside * 0.1)
		var var_amt: float = opts.get("tone", 0.05)
		var tone := 1.0 + tone_rng.randf_range(-var_amt, var_amt)
		var glow: bool = opts.get("glow", false)
		var alpha := 0.0 if glow else 1.0
		var print_c := PaperKit.lin(Color(col.r * tone, col.g * tone, col.b * tone), alpha)
		var edge_c := PaperKit.lin(col.lerp(Color(0.24, 0.15, 0.09), 0.62), 1.0)
		var pale_c := PaperKit.lin(col.lerp(Color(1.0, 0.97, 0.9), 0.5), alpha)
		var back_src: Color = opts.get("back", col.lerp(KRAFT, 0.45))
		var back_c := PaperKit.lin(back_src, 1.0)
		var side_c := PaperKit.lin((col * 0.52).lerp(CREAM, 0.08), 1.0)
		var nrm := PaperKit.vnormals(p)
		var in1 := PaperKit.inset_with(p, nrm, ew)
		var in2 := in1 if lw < 0.01 else PaperKit.inset_with(p, nrm, ew + lw)
		var bas := xf.basis
		var fz := (bas * Vector3(0, 0, 1)).normalized()
		var half := t * 0.5
		for face in 2:
			var z := half if face == 0 else -half
			var fn := fz if face == 0 else -fz
			var fc := print_c if face == 0 else back_c
			for i in cnt:
				var j := (i + 1) % cnt
				var o_i := xf * Vector3(p[i].x, p[i].y, z)
				var o_j := xf * Vector3(p[j].x, p[j].y, z)
				var a_i := xf * Vector3(in1[i].x, in1[i].y, z)
				var a_j := xf * Vector3(in1[j].x, in1[j].y, z)
				quad(o_i, o_j, a_j, a_i, fn, edge_c)
				if lw >= 0.01:
					var b_i := xf * Vector3(in2[i].x, in2[i].y, z)
					var b_j := xf * Vector3(in2[j].x, in2[j].y, z)
					var li := fc
					var lj := fc
					if face == 0:
						# Pale lip only on edges facing the key (up and to the left of the card).
						li = fc.lerp(pale_c, clampf(nrm[i].y * 0.9 - nrm[i].x * 0.35, 0.0, 1.0))
						lj = fc.lerp(pale_c, clampf(nrm[j].y * 0.9 - nrm[j].x * 0.35, 0.0, 1.0))
					quad4(a_i, a_j, b_j, b_i, fn, li, lj, fc, fc)
			var idx := Geometry2D.triangulate_polygon(in2)
			if idx.is_empty():
				var cen := Vector2.ZERO
				for q in in2:
					cen += q
				cen /= in2.size()
				var cw := xf * Vector3(cen.x, cen.y, z)
				for i in cnt:
					var j := (i + 1) % cnt
					tri3(cw, xf * Vector3(in2[i].x, in2[i].y, z), xf * Vector3(in2[j].x, in2[j].y, z), fn, fc, fc, fc)
			else:
				for k in range(0, idx.size(), 3):
					var q0 := in2[idx[k]]
					var q1 := in2[idx[k + 1]]
					var q2 := in2[idx[k + 2]]
					tri3(xf * Vector3(q0.x, q0.y, z), xf * Vector3(q1.x, q1.y, z), xf * Vector3(q2.x, q2.y, z), fn, fc, fc, fc)
		if opts.get("sides", true):
			for i in cnt:
				var j := (i + 1) % cnt
				var e := p[j] - p[i]
				var on := (bas * Vector3(e.y, -e.x, 0.0)).normalized()
				quad(xf * Vector3(p[i].x, p[i].y, half), xf * Vector3(p[j].x, p[j].y, half),
					xf * Vector3(p[j].x, p[j].y, -half), xf * Vector3(p[i].x, p[i].y, -half), on, side_c)

	## Two cards slotted at 90 degrees (trees, posts): never seen edge-on.
	func cross(poly: PackedVector2Array, xf: Transform3D, col: Color, opts: Dictionary = {}) -> void:
		card(poly, xf, col, opts)
		card(poly, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), col, opts)

	## A folded box (houses, bales, car bodies). Folds carry no cut edge.
	func box(center: Vector3, size: Vector3, xf: Transform3D, col: Color, top: Color = Color(-1, 0, 0), glow := false) -> void:
		var h := size * 0.5
		var cs := PaperKit.lin(col, 0.0 if glow else 1.0)
		var ct := cs if top.r < 0.0 else PaperKit.lin(top, 1.0)
		var bas := xf.basis
		var P := func(x: float, y: float, z: float) -> Vector3: return xf * (center + Vector3(x, y, z))
		var faces := [
			[Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)], ct],
			[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1)], cs],
			[Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)], cs],
			[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)], cs],
			[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)], cs],
			[Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)], cs],
		]
		for f in faces:
			var q: Array = f[1]
			var pts: Array = []
			for k in q:
				pts.append(P.call(k.x * h.x, k.y * h.y, k.z * h.z))
			quad(pts[0], pts[1], pts[2], pts[3], (bas * f[0]).normalized(), f[2])

	## A sloped roof plank or any thin slab between four corner points.
	func slab(a: Vector3, b: Vector3, d: Vector3, e: Vector3, thick: float, col: Color) -> void:
		var nn := (b - a).cross(e - a).normalized()
		var off := nn * thick * 0.5
		var cc := PaperKit.lin(col, 1.0)
		var cside := PaperKit.lin(col.lerp(Color(0.24, 0.15, 0.09), 0.55), 1.0)
		quad(a + off, b + off, d + off, e + off, nn, cc)
		quad(a - off, e - off, d - off, b - off, -nn, PaperKit.lin(col.lerp(KRAFT, 0.45), 1.0))
		var ring := [a, b, d, e]
		for i in 4:
			var p0: Vector3 = ring[i]
			var p1: Vector3 = ring[(i + 1) % 4]
			var mid := (p0 + p1) * 0.5 - (a + b + d + e) * 0.25
			quad(p0 + off, p1 + off, p1 - off, p0 - off, mid.normalized(), cside)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		var m := ArrayMesh.new()
		if v.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


# --- colour --------------------------------------------------------------------------------------------

## Vertex colours are authored in sRGB and stored linear; alpha 0 marks a glowing (lit) pane.
static func lin(col: Color, alpha: float = 1.0) -> Color:
	var l := col.srgb_to_linear()
	l.a = alpha
	return l


# --- polygon helpers -----------------------------------------------------------------------------

static func area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a * 0.5


static func ccw(p: PackedVector2Array) -> PackedVector2Array:
	if area(p) < 0.0:
		var r := p.duplicate()
		r.reverse()
		return r
	return p


static func bounds(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for q in p:
		r = r.expand(q)
	return r


## Outward vertex normals (miter bisectors) for a CCW polygon.
static func vnormals(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := p.size()
	out.resize(cnt)
	for i in cnt:
		var a := p[(i - 1 + cnt) % cnt]
		var b := p[i]
		var d := p[(i + 1) % cnt]
		var e0 := (b - a).normalized()
		var e1 := (d - b).normalized()
		var n0 := Vector2(e0.y, -e0.x)
		var n1 := Vector2(e1.y, -e1.x)
		var m := n0 + n1
		if m.length_squared() < 1e-6:
			m = n1
		out[i] = m.normalized()
	return out


static func inset_with(p: PackedVector2Array, nrm: PackedVector2Array, w: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := p.size()
	out.resize(cnt)
	for i in cnt:
		var d := p[(i + 1) % cnt] - p[i]
		var n1 := Vector2(d.y, -d.x).normalized()
		var cosv := maxf(nrm[i].dot(n1), 0.45)
		out[i] = p[i] - nrm[i] * (w / cosv)
	return out


static func rect(w: float, h: float, cx := 0.0, y0 := 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - w * 0.5, y0), Vector2(cx + w * 0.5, y0), Vector2(cx + w * 0.5, y0 + h), Vector2(cx - w * 0.5, y0 + h)])


static func rrect(w: float, h: float, r: float, cx := 0.0, y0 := 0.0, seg := 3) -> PackedVector2Array:
	var out := PackedVector2Array()
	r = minf(r, minf(w, h) * 0.5)
	var cs := [Vector2(cx + w * 0.5 - r, y0 + r), Vector2(cx + w * 0.5 - r, y0 + h - r), Vector2(cx - w * 0.5 + r, y0 + h - r), Vector2(cx - w * 0.5 + r, y0 + r)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for s in seg + 1:
			var a: float = starts[k] + PI * 0.5 * float(s) / seg
			out.append(cs[k] + Vector2(cos(a), sin(a)) * r)
	return out


static func circle(r: float, cx := 0.0, cy := 0.0, seg := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / seg
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out


## Chunky scalloped blob (canopies, bushes, snow drifts).
static func blob(r: float, cx: float, cy: float, lobes: int, amp: float, seed_v: int, seg := 26, squash := 1.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var out := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / seg
		var rr := r * (1.0 - amp + amp * 2.0 * absf(sin(a * lobes * 0.5 + ph))) * (1.0 + rng.randf_range(-0.02, 0.02))
		out.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr * squash))
	return out


## A conifer tier: rounded apex, scalloped bottom edge.
static func tier(w: float, h: float, y0: float, scallops: int, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := PackedVector2Array()
	var apex := Vector2(0.0, y0 + h)
	var cap := w * 0.06
	out.append(apex + Vector2(-cap, -cap * 0.6))
	out.append(apex + Vector2(0.0, 0.0))
	out.append(apex + Vector2(cap, -cap * 0.6))
	out.append(Vector2(w * 0.5, y0 + h * 0.04))
	var sw := w / scallops
	for k in scallops:
		var x0 := w * 0.5 - k * sw
		for s in 4:
			var t := float(s + 1) / 5.0
			var x := x0 - sw * t
			var dip := sin(t * PI) * h * rng.randf_range(0.07, 0.11)
			out.append(Vector2(x, y0 - dip))
		out.append(Vector2(x0 - sw, y0 + h * 0.02))
	out.remove_at(out.size() - 1)
	out.append(Vector2(-w * 0.5, y0 + h * 0.04))
	return out


static func shift(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := p.duplicate()
	for i in out.size():
		out[i] += d
	return out


static func scaled(p: PackedVector2Array, s: float, about: Vector2) -> PackedVector2Array:
	var out := p.duplicate()
	for i in out.size():
		out[i] = about + (out[i] - about) * s
	return out


## Hand-cut wobble: points on the fold (y ~ 0) never move.
static func wobble(p: PackedVector2Array, amt: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := p.duplicate()
	var f1 := rng.randf_range(1.5, 3.0)
	var f2 := rng.randf_range(4.0, 7.0)
	for i in out.size():
		if absf(out[i].y) < 0.01:
			continue
		var t := float(i) / out.size() * TAU
		var k := sin(t * f1) * 0.6 + sin(t * f2 + 1.3) * 0.4
		var d := out[i].normalized() if out[i].length() > 0.001 else Vector2.UP
		out[i] += d * k * amt
	return out


static func xf_at(pos: Vector3, yaw := 0.0, pitch := 0.0, roll := 0.0) -> Transform3D:
	var b := Basis.from_euler(Vector3(pitch, yaw, roll))
	return Transform3D(b, pos)
