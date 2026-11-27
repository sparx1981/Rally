class_name LightHalo
extends RefCounted
## Soft additive glow around lamps (headlights, tail lights, street lamps, floodlights, track lamps):
## a cheap stand-in for light scattering in the night air. Switch: Settings > "Light glow".
## Street-style lamps glow downward only: a short bright halo at the lamp head, a soft cone of light
## and a pool on the ground beneath, never a ball of light above the lamp.

static var _tex: GradientTexture2D
static var _cone_tex: GradientTexture2D


static func enabled() -> bool:
	return bool(Settings.g("light_halos"))


static func _radial() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.55, 0.55, 0.55, 1), Color(0.14, 0.14, 0.14, 1), Color(0, 0, 0, 1)])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 128
		_tex.height = 128
	return _tex


static func _material(tex: Texture2D, color: Color, strength: float, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = Color(color.r * strength, color.g * strength, color.b * strength, 1.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 140.0
	m.distance_fade_max_distance = 90.0
	return m


## A round glow that always faces the camera (vehicle lamps, floodlights).
static func make(color: Color, size: float, strength := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = _material(_radial(), color, strength, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Light thrown down from a lamp head: tiny halo at the head, a cone, a pool on the ground.
## The node origin is the lamp head; `drop` is the height of the head above the ground.
static func street(color: Color, drop: float, radius: float, strength := 1.0) -> Node3D:
	var root := Node3D.new()
	var head := make(color, 1.1, strength)
	root.add_child(head)
	if _cone_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(0.7, 0.7, 0.7, 1), Color(0.0, 0.0, 0.0, 1)])
		_cone_tex = GradientTexture2D.new()
		_cone_tex.gradient = g
		_cone_tex.fill_from = Vector2(0.5, 0.0)
		_cone_tex.fill_to = Vector2(0.5, 1.0)
		_cone_tex.width = 8
		_cone_tex.height = 64
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = radius * 0.9
	cm.height = drop
	cm.radial_segments = 14
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cone.mesh = cm
	cone.material_override = _material(_cone_tex, color, strength * 0.14, false)
	cone.position = Vector3(0, -drop * 0.5, 0)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (The cone is left out: a visible wedge reads as a solid when it is close to the camera.)
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.2, radius * 2.2)
	pool.mesh = pm
	pool.material_override = _material(_radial(), color, strength * 0.85, false)
	pool.position = Vector3(0, -drop + 0.12, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)
	return root
