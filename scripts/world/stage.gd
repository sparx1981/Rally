class_name Stage
extends Node3D
## Assembles one rally stage: light set, printed ground, road strip, start/finish gantries,
## puddles, scenery and weather (paper rain streaks / paper snow flakes), plus a few paper birds.

const PAPER_SHADER := preload("res://shaders/paper.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")
const ROAD_Y := 0.07

static var _noise_tex: NoiseTexture2D
static var _fibre_tex: NoiseTexture2D

var def: Dictionary
var wx: Dictionary
var track := Track.new()
var scenery: Scenery
var paper_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var road_mat: ShaderMaterial
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var env: Environment
var weather_fx: Node3D
var _particles: CPUParticles3D
var _birds: Array = []
var _time := 0.0


static func noise_tex() -> NoiseTexture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 3
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 256
		_noise_tex.height = 256
		_noise_tex.seamless = true
		_noise_tex.generate_mipmaps = true
		_noise_tex.noise = n
	return _noise_tex


static func fibre_tex() -> NoiseTexture2D:
	if _fibre_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n.frequency = 0.09
		n.fractal_octaves = 2
		_fibre_tex = NoiseTexture2D.new()
		_fibre_tex.width = 128
		_fibre_tex.height = 128
		_fibre_tex.seamless = true
		_fibre_tex.generate_mipmaps = true
		_fibre_tex.noise = n
	return _fibre_tex


func build(stage_def: Dictionary) -> void:
	def = stage_def
	wx = Catalog.weather(def["weather"])
	track.generate(int(def["seed"]), float(def["length"]), float(def["twist"]), float(def["width"]))
	_make_materials()
	_make_lights()
	_make_ground()
	_make_road()
	_make_gantries()
	scenery = Scenery.new()
	scenery.name = "Scenery"
	add_child(scenery)
	scenery.setup(track, def, paper_mat, float(Settings.g("density")), float(Settings.g("draw_distance")), bool(Settings.g("popups")))
	_make_puddles()
	_make_weather()
	_make_birds()
	apply_settings()
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _on_settings_changed(key: String) -> void:
	if key == "popups":
		scenery.rebuild_visuals(bool(Settings.g("popups")))
	apply_settings()


func apply_settings() -> void:
	var detail := bool(Settings.g("paper_detail"))
	for m in [paper_mat, ground_mat, road_mat]:
		m.set_shader_parameter("fibre_amount", 0.09 if detail else 0.0)
	var sh := int(Settings.g("shadows"))
	key_light.shadow_enabled = sh > 0
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if sh <= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key_light.directional_shadow_max_distance = 60.0 if sh <= 1 else 90.0
	if _particles:
		_particles.amount = maxi(16, int(_particles.get_meta("base_amount") * float(Settings.g("particles"))))


func _make_materials() -> void:
	var leak: Color = wx["leak"]
	var wrap_v: float = wx["wrap"]
	paper_mat = ShaderMaterial.new()
	paper_mat.shader = PAPER_SHADER
	paper_mat.set_shader_parameter("fibre", fibre_tex())
	paper_mat.set_shader_parameter("leak", leak)
	paper_mat.set_shader_parameter("wrap", wrap_v)
	paper_mat.set_shader_parameter("glow", float(wx["glow"]))
	var pal: Dictionary = def["pal"]
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("noise", noise_tex())
	ground_mat.set_shader_parameter("fibre", fibre_tex())
	ground_mat.set_shader_parameter("leak", leak)
	ground_mat.set_shader_parameter("wrap", wrap_v)
	ground_mat.set_shader_parameter("g0", pal["ground"])
	ground_mat.set_shader_parameter("g1", pal["ground2"])
	ground_mat.set_shader_parameter("g2", pal["ground3"])
	ground_mat.set_shader_parameter("cloud_amount", 0.0 if wx["kind"] == "rain" else 0.16)
	road_mat = ShaderMaterial.new()
	road_mat.shader = ROAD_SHADER
	road_mat.set_shader_parameter("noise", noise_tex())
	road_mat.set_shader_parameter("fibre", fibre_tex())
	road_mat.set_shader_parameter("leak", leak)
	road_mat.set_shader_parameter("wrap", wrap_v)
	road_mat.set_shader_parameter("road", pal["road"])
	road_mat.set_shader_parameter("rut", pal["rut"])
	road_mat.set_shader_parameter("edge_col", Color(pal["road"]).lerp(Color(0.24, 0.15, 0.09), 0.7))
	road_mat.set_shader_parameter("wet", 1.0 if wx["kind"] == "rain" else 0.0)


func _make_lights() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = def["pal"]["ground"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = wx["amb"]
	env.ambient_light_energy = float(wx["amb_e"]) * 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	key_light = DirectionalLight3D.new()
	key_light.light_color = wx["key"]
	key_light.light_energy = float(wx["key_e"]) * 0.6
	var el := deg_to_rad(float(wx["elev"]))
	var az := deg_to_rad(float(wx["azim"]))
	var sun := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	key_light.basis = Basis.looking_at(-sun, Vector3.UP if absf(sun.y) < 0.99 else Vector3.FORWARD)
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.6
	key_light.shadow_bias = 0.04
	key_light.shadow_normal_bias = 1.2
	key_light.directional_shadow_max_distance = 70.0
	key_light.directional_shadow_fade_start = 0.85
	add_child(key_light)
	fill_light = DirectionalLight3D.new()
	fill_light.light_color = wx["fill"]
	fill_light.light_energy = float(wx["fill_e"]) * 1.7
	fill_light.shadow_enabled = false
	add_child(fill_light)


func _make_ground() -> void:
	var b := track.bounds().grow(260.0)
	var pm := PlaneMesh.new()
	pm.size = b.size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = ground_mat
	mi.position = Vector3(b.get_center().x, 0.0, b.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _make_road() -> void:
	var n := track.pts.size()
	var hw := track.width * 0.5
	var chunk := 60
	var i0 := 0
	while i0 < n - 1:
		var i1 := mini(i0 + chunk, n - 1)
		var v := PackedVector3Array()
		var nn := PackedVector3Array()
		var uv := PackedVector2Array()
		var col := PackedColorArray()
		var idx := PackedInt32Array()
		for i in range(i0, i1 + 1):
			var p := track.pts[i]
			var l := p + track.nrm[i] * hw
			var r := p - track.nrm[i] * hw
			var vv := track.dist[i] / track.width
			var base := v.size()
			# top-left, top-right, bottom-left, bottom-right
			v.append(Vector3(l.x, ROAD_Y, l.y)); nn.append(Vector3.UP); uv.append(Vector2(0, vv)); col.append(Color.WHITE)
			v.append(Vector3(r.x, ROAD_Y, r.y)); nn.append(Vector3.UP); uv.append(Vector2(1, vv)); col.append(Color.WHITE)
			var on := Vector3(track.nrm[i].x, 0, track.nrm[i].y)
			v.append(Vector3(l.x, ROAD_Y, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(l.x, -0.01, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(r.x, ROAD_Y, r.y)); nn.append(-on); uv.append(Vector2(1, vv)); col.append(Color.BLACK)
			v.append(Vector3(r.x, -0.01, r.y)); nn.append(-on); uv.append(Vector2(1, vv)); col.append(Color.BLACK)
			if i > i0:
				var pb := base - 6
				_quad_idx(idx, v, pb + 0, pb + 1, base + 1, base + 0, Vector3.UP)
				_quad_idx(idx, v, pb + 2, base + 2, base + 3, pb + 3, on)
				_quad_idx(idx, v, pb + 4, pb + 5, base + 5, base + 4, -on)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = road_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i0 = i1


func _quad_idx(idx: PackedInt32Array, v: PackedVector3Array, a: int, b: int, c: int, d: int, want: Vector3) -> void:
	var flip := (v[b] - v[a]).cross(v[c] - v[a]).dot(want) > 0.0
	if flip:
		idx.append_array([a, c, b, a, d, c])
	else:
		idx.append_array([a, b, c, a, c, d])


func _make_gantries() -> void:
	for pair in [[track.start_s, false], [track.finish_s, true]]:
		var s: float = pair[0]
		var i := track.index_at(s)
		var p := track.pts[i]
		var mi := MeshInstance3D.new()
		mi.mesh = Pieces.arch(track.width + 1.4, pair[1])
		mi.material_override = paper_mat
		mi.position = Vector3(p.x, 0.0, p.y)
		mi.rotation.y = track.heading_at(i)
		add_child(mi)
		# Painted line across the road.
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(track.width, 0.01, 0.5)
		line.mesh = bm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("#efe3c8")
		lm.roughness = 1.0
		lm.metallic_specular = 0.0
		line.material_override = lm
		line.position = Vector3(p.x, ROAD_Y + 0.006, p.y)
		line.rotation.y = track.heading_at(i)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)


func _make_puddles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def["seed"]) + 99
	var meshes: Array = []
	for i in 3:
		meshes.append(Pieces.puddle(rng))
	for pd in scenery.puddles:
		var p: Vector2 = pd[0]
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[rng.randi() % meshes.size()]
		mi.material_override = paper_mat
		mi.position = Vector3(p.x, ROAD_Y + 0.012, p.y)
		mi.rotation.y = rng.randf() * TAU
		var sc: float = pd[1] / 1.5
		mi.scale = Vector3(sc, 1.0, sc)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = float(Settings.g("draw_distance"))
		add_child(mi)


func _make_weather() -> void:
	weather_fx = Node3D.new()
	add_child(weather_fx)
	var kind: String = wx["particles"]
	Sfx.set_ambience(kind)
	if kind == "":
		return
	_particles = CPUParticles3D.new()
	_particles.local_coords = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	var qm := QuadMesh.new()
	if kind == "rain":
		qm.size = Vector2(0.05, 1.1)
		mat.albedo_color = Color(0.78, 0.82, 0.86)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		_particles.set_meta("base_amount", 900)
		_particles.lifetime = 0.9
		_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_particles.emission_box_extents = Vector3(32, 1, 32)
		_particles.direction = Vector3(0.12, -1, 0.05)
		_particles.spread = 2.0
		_particles.gravity = Vector3.ZERO
		_particles.initial_velocity_min = 26.0
		_particles.initial_velocity_max = 30.0
		_particles.position = Vector3(0, 22, 0)
	else:
		qm.size = Vector2(0.2, 0.2)
		mat.albedo_color = Color(0.97, 0.97, 1.0)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_particles.set_meta("base_amount", 700)
		_particles.lifetime = 7.0
		_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_particles.emission_box_extents = Vector3(32, 1, 32)
		_particles.direction = Vector3(0.3, -1, 0.1)
		_particles.spread = 25.0
		_particles.gravity = Vector3(0.2, -0.25, 0)
		_particles.initial_velocity_min = 2.0
		_particles.initial_velocity_max = 3.2
		_particles.angular_velocity_min = -200.0
		_particles.angular_velocity_max = 200.0
		_particles.angle_min = 0.0
		_particles.angle_max = 360.0
		_particles.scale_amount_min = 0.6
		_particles.scale_amount_max = 1.3
		_particles.position = Vector3(0, 16, 0)
	qm.material = mat
	_particles.mesh = qm
	_particles.amount = int(_particles.get_meta("base_amount"))
	_particles.preprocess = _particles.lifetime
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weather_fx.add_child(_particles)


func _make_birds() -> void:
	if wx["kind"] == "rain":
		return
	var body := Pieces.bird_body()
	var wing := Pieces.bird_wing()
	for i in 3:
		var bird := Node3D.new()
		bird.scale = Vector3.ONE * 0.8
		var bmi := MeshInstance3D.new()
		bmi.mesh = body
		bmi.material_override = paper_mat
		bird.add_child(bmi)
		var wings: Array = []
		for side in [1.0, -1.0]:
			var wp := Node3D.new()
			var wmi := MeshInstance3D.new()
			wmi.mesh = wing
			wmi.material_override = paper_mat
			wmi.scale = Vector3(side, 1, 1)
			wp.add_child(wmi)
			bird.add_child(wp)
			wings.append(wp)
		add_child(bird)
		_birds.append({"node": bird, "wings": wings, "phase": i * 1.7, "rad": 7.0 + i * 2.5, "h": 7.5 + i * 0.8, "spd": 0.35 + i * 0.07})


## Per-frame: keep weather and birds around the focus, aim the frontal fill along the camera.
func update(dt: float, focus: Vector3, player_s: float, cam: Camera3D) -> void:
	_time += dt
	if scenery:
		scenery.update(player_s, dt)
	weather_fx.position = Vector3(focus.x, 0, focus.z)
	if cam:
		fill_light.global_basis = cam.global_basis
	for bd in _birds:
		var a: float = _time * float(bd["spd"]) + float(bd["phase"])
		var r: float = bd["rad"]
		var center := focus + Vector3(6.0, 0, 6.0)
		var n: Node3D = bd["node"]
		n.position = center + Vector3(cos(a) * r, float(bd["h"]) + sin(a * 2.0) * 0.4, sin(a) * r)
		n.rotation.y = -a
		var flap := sin(_time * 7.0 + float(bd["phase"])) * 0.6
		bd["wings"][0].rotation.z = flap
		bd["wings"][1].rotation.z = -flap


func grip() -> float:
	return float(wx["grip"])


func kind() -> String:
	return wx["kind"]
