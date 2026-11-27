class_name Puffs
extends RefCounted
## Volumetric paper puff emitters: faceted 3D balls that swell and shrink and fade (semi-transparent,
## no sprites), lit like the paper world. Used for dust, tyre smoke, exhaust smoke, water spray,
## splash bursts and chimney smoke.

static var _mesh: SphereMesh
static var _mats := {}


static func mesh() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.5
		_mesh.height = 0.85
		_mesh.radial_segments = 7
		_mesh.rings = 4
	return _mesh


static func material(leak: Color, tint: Color) -> ShaderMaterial:
	var key := leak.to_html()+tint.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/puff.gdshader")
		m.set_shader_parameter("leak", leak)
		m.set_shader_parameter("tint", tint)
		_mats[key] = m
	return _mats[key]


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c


## kind: dust | smoke | exhaust | spray | splash | chimney | snow
static func make(kind: String, color: Color, leak: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh()
	p.material_override = material(leak,color)
	p.local_coords = kind == "chimney"
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.angle_min = 0.0
	p.angle_max = 360.0

	match kind:
		"dust", "snow":
			p.amount = 48
			p.lifetime = 1.6
			p.direction = Vector3(0, 0.5, -1)
			p.spread = 35.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, 0.35 if kind == "dust" else -0.6, 0)
			p.damping_min = 1.5
			p.damping_max = 2.5
			p.scale_amount_min = 0.9
			p.scale_amount_max = 1.8
			p.scale_amount_curve = _curve([Vector2(0, 0.25), Vector2(0.25, 1.0), Vector2(1, 0.15)])
		"smoke", "exhaust":
			p.amount = 24 if kind == "smoke" else 14
			p.lifetime = 1.3
			p.direction = Vector3(0, 0.4, -1)
			p.spread = 20.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.0
			p.gravity = Vector3(0, 0.8, 0)
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.scale_amount_min = 0.5 if kind == "exhaust" else 0.9
			p.scale_amount_max = 0.9 if kind == "exhaust" else 1.6
			p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.3, 1.0), Vector2(1, 0.1)])
		"spray":
			p.amount = 40
			p.lifetime = 0.7
			p.direction = Vector3(0, 0.6, -1)
			p.spread = 30.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -6.0, 0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.7
			p.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(0.4, 1.0), Vector2(1, 0.1)])
		"splash":
			p.one_shot = true
			p.emitting = false
			p.explosiveness = 0.9
			p.amount = 46
			p.lifetime = 1.2
			p.direction = Vector3(0, 1, 0.2)
			p.spread = 70.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 8.5
			p.gravity = Vector3(0, -14.0, 0)
			p.scale_amount_min = 0.4
			p.scale_amount_max = 1.1
			p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.2)])
		"chimney":
			p.amount = 8
			p.lifetime = 4.5
			p.direction = Vector3(0.25, 1, 0)
			p.spread = 12.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0.25, 0.15, 0)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 0.9
			p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.5, 1.0), Vector2(1, 0.35)])
	# Semi-transparent: each puff fades in quickly, stays see-through, and thins out as it dies.
	var peak: float = float({"dust": 0.5, "snow": 0.7, "smoke": 0.55, "exhaust": 0.55, "spray": 0.55, "splash": 0.6, "chimney": 0.55}.get(kind, 0.55))
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, peak), Color(1, 1, 1, peak * 0.7), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	return p
