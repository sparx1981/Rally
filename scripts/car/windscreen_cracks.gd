class_name WindscreenCracks
extends MeshInstance3D
## Cracks drawn as geometry lying flush on the cockpit windscreen. Each hit on the front of the car adds a star
## crack (radial cracks with branches and a broken ring) at the place where the car was struck, inside a frosted
## patch. A shader bends the view behind each crack, so the glass refracts instead of being painted over.

var _origin := Vector3.ZERO     # corner of the glass (bottom left, driver's view)
var _ex := Vector3.RIGHT        # across the glass (metres)
var _ey := Vector3.UP           # up the slope of the glass (metres)
var _nrm := Vector3.BACK        # towards the driver
var _w := 1.0
var _h := 0.5
var _verts := PackedVector3Array()
var _uvs := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _ex_dir := Vector3.RIGHT
var _ey_dir := Vector3.UP


func setup(screen: Dictionary) -> void:
	_origin = screen["o"]
	_ex = screen["ex"]
	_ey = screen["ey"]
	_w = _ex.length()
	_h = _ey.length()
	_ex_dir = _ex / _w
	_ey_dir = _ey / _h
	_nrm = _ex_dir.cross(_ey_dir).normalized()
	if _nrm.dot(Vector3(screen["head"]) - (_origin + _ex * 0.5 + _ey * 0.5)) < 0.0:
		_nrm = -_nrm
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/windscreen_crack.gdshader")
	sm.render_priority = 8
	material_override = sm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## hits: Array of Vector3(u 0..1 across the glass, v 0..1 up it, power). Rebuilds the whole pattern.
func set_hits(hits: Array) -> void:
	_verts.clear()
	_uvs.clear()
	_cols.clear()
	_idx.clear()
	for k in hits.size():
		var h: Vector3 = hits[k]
		_star(Vector2(h.x * _w, h.y * _h), h.z, 1000 + k * 37)
	if _verts.is_empty():
		mesh = null
		visible = false
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am
	visible = true


func _pt(p: Vector2) -> Vector3:
	return _origin + _ex_dir * p.x + _ey_dir * p.y + _nrm * 0.0025


func _inside(p: Vector2) -> bool:
	return p.x > 0.03 and p.x < _w - 0.03 and p.y > 0.02 and p.y < _h - 0.02


## A strip from a to b (glass coordinates, metres) with half-widths wa and wb.
func _strip(a: Vector2, b: Vector2, wa: float, wb: float) -> void:
	var d := b - a
	if d.length() < 0.0005:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var world_perp := (_ex_dir * n.x + _ey_dir * n.y).normalized()
	var col := Color(world_perp.x * 0.5 + 0.5, world_perp.y * 0.5 + 0.5, world_perp.z * 0.5 + 0.5, 0.0)
	var base := _verts.size()
	_verts.append(_pt(a - n * wa))
	_verts.append(_pt(a + n * wa))
	_verts.append(_pt(b + n * wb))
	_verts.append(_pt(b - n * wb))
	_uvs.append(Vector2(-1, 0))
	_uvs.append(Vector2(1, 0))
	_uvs.append(Vector2(1, 1))
	_uvs.append(Vector2(-1, 1))
	for i in 4:
		_cols.append(col)
	_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _crack(start: Vector2, ang: float, length: float, w0: float, rng: RandomNumberGenerator, depth: int, store: Array) -> void:
	var seg := 5
	var p := start
	var a := ang
	var pts: Array = [p]
	for q in seg:
		a += rng.randf_range(-0.28, 0.28)
		var np := p + Vector2.from_angle(a) * (length / seg)
		if not _inside(np):
			break
		var wa := lerpf(w0, w0 * 0.3, float(q) / seg)
		var wb := lerpf(w0, w0 * 0.3, float(q + 1) / seg)
		_strip(p, np, wa, wb)
		p = np
		pts.append(p)
		if depth == 0 and q == 2 and rng.randf() < 0.55:
			_crack(p, a + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0), length * 0.4, w0 * 0.6, rng, 1, [])
	store.append(pts)


func _star(origin: Vector2, power: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	origin.x = clampf(origin.x, 0.1, _w - 0.1)
	origin.y = clampf(origin.y, 0.08, _h - 0.08)
	var reach := 0.8 + 0.06 * clampf(power, 4.0, 20.0)
	# Frosted patch where the glass took the blow.
	var fr := 0.05 + 0.006 * power
	var cb := _verts.size()
	_verts.append(_pt(origin))
	_uvs.append(Vector2(0, 0))
	_cols.append(Color(0, 0, 0, 1))
	var ring_n := 14
	for i in ring_n:
		var ang := TAU * float(i) / ring_n
		var rr := fr * rng.randf_range(0.75, 1.1)
		_verts.append(_pt(origin + Vector2.from_angle(ang) * rr))
		_uvs.append(Vector2(1, 0))
		_cols.append(Color(0, 0, 0, 1))
	for i in ring_n:
		_idx.append_array(PackedInt32Array([cb, cb + 1 + i, cb + 1 + (i + 1) % ring_n]))
	# Radial cracks with branches.
	var rays: Array = []
	var n := rng.randi_range(6, 9)
	for k in n:
		var ang := TAU * float(k) / n + rng.randf_range(-0.25, 0.25)
		_crack(origin + Vector2.from_angle(ang) * 0.006, ang, rng.randf_range(0.14, 0.26) * reach, rng.randf_range(0.0035, 0.0055), rng, 0, rays)
	# A broken ring joining neighbouring rays (the spider-web look).
	for ring_r in [0.045, 0.095, 0.15]:
		var rr: float = ring_r * reach
		var prev := Vector2.INF
		for ray: Array in rays:
			var hit := Vector2.INF
			for j in range(1, ray.size()):
				if (ray[j] as Vector2).distance_to(origin) >= rr:
					hit = ray[j]
					break
			if hit != Vector2.INF and prev != Vector2.INF and rng.randf() < 0.75 and hit.distance_to(prev) < rr * 1.6:
				_strip(prev, hit, 0.0022, 0.0022)
			if hit != Vector2.INF:
				prev = hit
