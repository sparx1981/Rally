class_name HeroFx
extends Control
## Live touches on the painted hero art of the boot and stage loading screens, laid out in the art's own pixel space
## (1920 x 1080) and scaled to follow the "cover" fit of the picture: dust trailing from both wheels, drifting
## motes in the headlight beam, pulsing lamp flare, glowing brake discs and a reflection sliding across the
## windscreen. The clouds are handled by a shader on the picture itself (shaders/hero_sky.gdshader).

const ART := Vector2(1920, 1080)
const REAR_WHEEL := Vector2(738, 712)
const FRONT_WHEEL := Vector2(1085, 718)
const LAMPS := [Vector2(1342, 696), Vector2(1542, 688)]
const SCREEN := [Vector2(944, 494), Vector2(1170, 502), Vector2(1226, 612), Vector2(986, 608)]

var _glows: Array = []      # [sprite, base alpha, speed, phase]
var _lamps: Array = []
var _soft: Texture2D


func _ready() -> void:
	size = ART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2.ZERO
	_soft = _make_soft(64)
	var scale_n := 1.0 if Settings.fx_level() >= 1 else 0.5
	_dust(Vector2(700, 788), Vector2(-1.0, -0.28), 0.22, int(26 * scale_n), 3.4)
	_dust(Vector2(1118, 796), Vector2(-1.0, -0.2), 0.16, int(16 * scale_n), 2.6)
	_dust(Vector2(1640, 790), Vector2(1.0, -0.22), 0.14, int(14 * scale_n), 3.8)
	_beam_motes(int(46 * scale_n))
	for lp: Vector2 in LAMPS:
		var f := _sprite(lp, 150.0, Color(1.0, 0.9, 0.7), true)
		_lamps.append([f, randf() * TAU])
	for w: Vector2 in [REAR_WHEEL, FRONT_WHEEL]:
		var g := _sprite(w + Vector2(0, 4), 120.0 if w == FRONT_WHEEL else 108.0, Color(1.0, 0.42, 0.1), true)
		_glows.append([g, 0.42, 0.9 + randf() * 0.5, randf() * TAU])
	_windscreen()


func _make_soft(px: int) -> Texture2D:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = px
	gt.height = px
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)])
	gt.gradient = gr
	return gt


func _sprite(at: Vector2, diameter: float, col: Color, additive: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _soft
	s.position = at
	s.scale = Vector2.ONE * diameter / 64.0
	s.modulate = Color(col.r, col.g, col.b, 0.0)
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	add_child(s)
	return s


## Soft dust puffs that rise, spread and fade as they drift away from a wheel.
func _dust(at: Vector2, dir: Vector2, alpha: float, amount: int, life: float) -> void:
	if amount <= 0:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _soft
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = dir
	p.spread = 22.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.damping_min = 8.0
	p.damping_max = 22.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 2.8))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.88, 0.7, 0.0), Color(1.0, 0.88, 0.7, alpha), Color(0.98, 0.82, 0.64, alpha * 0.55), Color(0.98, 0.82, 0.64, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.6, 1.0])
	p.color_ramp = ramp
	add_child(p)


## Specks of dust hanging in the headlight beam: a cone opening to the right of the lamps.
func _beam_motes(amount: int) -> void:
	if amount <= 0:
		return
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 300:
		var d := rng.randf_range(30.0, 360.0)
		var spread := d * 0.34
		pts.append(Vector2(1568.0 + d, 690.0 + rng.randf_range(-spread, spread) - d * 0.05))
	var p := CPUParticles2D.new()
	p.texture = _soft
	p.amount = amount
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.direction = Vector2(1, -0.3)
	p.spread = 80.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 0.0), Color(1.0, 0.95, 0.8, 0.9), Color(1.0, 0.95, 0.8, 0.9), Color(1.0, 0.95, 0.8, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	p.color_ramp = ramp
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	add_child(p)


func _windscreen() -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(SCREEN)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v: Vector2 in SCREEN:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	var uvs := PackedVector2Array()
	for v: Vector2 in SCREEN:
		uvs.append((v - lo) / (hi - lo))
	poly.uv = uvs
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	poly.texture = ImageTexture.create_from_image(img)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/hero_glint.gdshader")
	poly.material = sm
	add_child(poly)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for g: Array in _glows:
		var s: Sprite2D = g[0]
		var pulse := 0.5 + 0.5 * sin(t * float(g[2]) + float(g[3]))
		var flicker := 0.9 + 0.1 * sin(t * 13.0 + float(g[3]) * 3.0)
		s.modulate.a = float(g[1]) * (0.55 + 0.45 * pulse) * flicker
	for l: Array in _lamps:
		var s: Sprite2D = l[0]
		s.modulate.a = 0.20 + 0.10 * sin(t * 1.3 + float(l[1]))
		s.scale = Vector2.ONE * (150.0 + 12.0 * sin(t * 0.9 + float(l[1]))) / 64.0


## Fit the 1920 x 1080 art layer over a control the way a "keep aspect covered" texture is fitted.
static func fit_cover(layer: Control, over: Vector2) -> void:
	var s := maxf(over.x / ART.x, over.y / ART.y)
	layer.scale = Vector2(s, s)
	layer.position = (over - ART * s) * 0.5
