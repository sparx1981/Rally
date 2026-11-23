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
var birds: Birds
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


var tod := 0


func build(stage_def: Dictionary, time_of_day := -1) -> void:
	def = stage_def
	tod = int(def.get("tod", 0)) if time_of_day < 0 else time_of_day
	wx = Catalog.lighting(def["weather"], tod)
	track.generate(int(def["seed"]), float(def["length"]), float(def["twist"]), float(def["width"]))
	var ep: Dictionary = def.get("elev", {})
	track.build_elevation(ep, int(def["seed"]))
	track.build_hazards(int(def["seed"]), wx["kind"], float(def["twist"]))
	track.terrain = Terrain.new()
	track.terrain.build(track, float(ep.get("hills", 10.0)), int(def["seed"]) + 5)
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
	_make_hazards()
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
	var holder := Node3D.new()
	holder.name = "Terrain"
	add_child(holder)
	track.terrain.build_meshes(holder, ground_mat)
	# A wide base sheet far below, so high views never see past the landscape edge.
	var b = track.bounds().grow(900.0)
	var pm := PlaneMesh.new()
	pm.size = b.size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = ground_mat
	mi.position = Vector3(b.get_center().x, track.terrain.min_h - 3.0, b.get_center().y)
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
			var hy = ROAD_Y + track.road_h_i(i)
			var slope = (track.road_h_i(mini(i + 1, n - 1)) - track.road_h_i(maxi(i - 1, 0))) / (2.0 * Track.STEP)
			var low = track.elev[i] - 0.6
			var tn := Vector3(-slope * track.tang[i].x, 1.0, -slope * track.tang[i].y).normalized()
			# top-left, top-right, then the side skirts (a built paper ramp where the road rises)
			v.append(Vector3(l.x, hy, l.y)); nn.append(tn); uv.append(Vector2(0, vv)); col.append(Color.WHITE)
			v.append(Vector3(r.x, hy, r.y)); nn.append(tn); uv.append(Vector2(1, vv)); col.append(Color.WHITE)
			var on := Vector3(track.nrm[i].x, 0, track.nrm[i].y)
			v.append(Vector3(l.x, hy, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(l.x, low, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(r.x, hy, r.y)); nn.append(-on); uv.append(Vector2(1, vv)); col.append(Color.BLACK)
			v.append(Vector3(r.x, low, r.y)); nn.append(-on); uv.append(Vector2(1, vv)); col.append(Color.BLACK)
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
		mi.position = Vector3(p.x, track.elev[i], p.y)
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
		line.position = Vector3(p.x, track.road_h_i(i) + ROAD_Y + 0.006, p.y)
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
		var ps: float = track.project(p, track.nearest_global(p))[1]
		mi.position = Vector3(p.x, track.road_h(ps) + ROAD_Y + 0.012, p.y)
		mi.rotation.y = rng.randf() * TAU
		var sc: float = pd[1] / 1.5
		mi.scale = Vector3(sc, 1.0, sc)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = float(Settings.g("draw_distance"))
		add_child(mi)


## Visuals for the hazards: water splashes, chicane bales (solid), surface patches, ramp struts.
func _make_hazards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def["seed"]) + 501
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	for f in track.features:
		var i := track.index_at(f["s"])
		var p := track.pts[i]
		var hd := track.heading_at(i)
		match f["type"]:
			"splash":
				# A stream crossing the road: stepped water tones, wobbly banks, cream ripple dashes.
				var b := PaperKit.Builder.new(rng.randi())
				var wl := track.width * 0.5 + 16.0
				var stream := PackedVector2Array()
				for k in 25:
					var x := lerpf(-wl, wl, k / 24.0)
					stream.append(Vector2(x, 3.6 + sin(k * 0.9) * 0.5))
				for k in 25:
					var x := lerpf(wl, -wl, k / 24.0)
					stream.append(Vector2(x, -3.6 + sin(k * 1.3 + 1.0) * 0.5))
				b.card(stream, lay, Color("#7f98a6"), {"thick": 0.03, "edge": 0.06, "lip": 0.08})
				var inner := PackedVector2Array()
				for q in stream:
					inner.append(Vector2(q.x * 0.97, q.y * 0.55))
				b.card(inner, lay * Transform3D(Basis(), Vector3(0, 0, 0.02)), Color("#6a8494"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
				for k in 10:
					var dx := rng.randf_range(-wl * 0.8, wl * 0.8)
					b.card(PaperKit.rrect(rng.randf_range(0.8, 1.6), 0.12, 0.05, dx, rng.randf_range(-2.0, 2.0)), lay * Transform3D(Basis(), Vector3(0, 0, 0.035)), Color("#e6ecee"), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
				var mi := MeshInstance3D.new()
				mi.mesh = b.mesh()
				mi.material_override = paper_mat
				mi.position = Vector3(p.x, track.road_h_i(i) + ROAD_Y + 0.02, p.y)
				mi.rotation.y = hd
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
			"jump", "crest":
				# Posts under the ramp edges so it reads as a built paper ramp.
				for s_off in range(int(f["s0"]) + 2, int(f["s1"]), 3):
					var j := track.index_at(s_off)
					var h := track.heights[j]
					if h < 0.25:
						continue
					for side in [1.0, -1.0]:
						var q = track.pts[j] + track.nrm[j] * side * (track.width * 0.5 - 0.15)
						var post := MeshInstance3D.new()
						var bm := BoxMesh.new()
						bm.size = Vector3(0.18, h, 0.18)
						post.mesh = bm
						post.material_override = _flat_mat(Color("#6a4a32"))
						bm.size = Vector3(0.18, h + 0.6, 0.18)
						post.position = Vector3(q.x, track.elev[j] - 0.6 + (h + 0.6) * 0.5, q.y)
						add_child(post)
	for pt in track.patches:
		var b := PaperKit.Builder.new(rng.randi())
		var len_s: float = float(pt["s1"]) - float(pt["s0"])
		var wdt: float = float(pt["lat1"]) - float(pt["lat0"])
		var col: Color = {"gravel": Color(def["pal"]["road"]).lightened(0.18), "mud": Color("#5e4632"), "ice": Color("#c9dcea"), "deep snow": Color("#f4f5f8")}[pt["kind"]]
		# Built as several overlapping blobs along the patch so it follows the bend.
		var steps := maxi(2, int(len_s / 6.0))
		for k in steps:
			var sm := lerpf(float(pt["s0"]) + 3.0, float(pt["s1"]) - 3.0, float(k) / maxf(steps - 1, 1))
			var j := track.index_at(sm)
			var latc := (float(pt["lat0"]) + float(pt["lat1"])) * 0.5
			var q := track.pts[j] + track.nrm[j] * latc
			var blob := PaperKit.blob(minf(wdt * 0.48, 4.0), 0, 0, 5, 0.12, rng.randi(), 18, 0.9)
			var xf := Transform3D(Basis(Vector3.UP, track.heading_at(j)), Vector3(q.x, ROAD_Y + track.road_h_i(j) + 0.012, q.y)) * lay
			b.card(blob, xf, col, {"thick": 0.015, "edge": 0.04, "lip": 0.05})
			if pt["kind"] == "ice":
				b.card(PaperKit.rrect(2.0, 0.1, 0.05, rng.randf_range(-1, 1), rng.randf_range(-1, 1)), xf * Transform3D(Basis(), Vector3(0, 0, 0.012)), Color("#f2f6f8"), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


var _flat_mats := {}
func _flat_mat(c: Color) -> Material:
	if not _flat_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_flat_mats[c] = m
	return _flat_mats[c]


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
	birds = Birds.new()
	birds.name = "Birds"
	add_child(birds)
	birds.setup(track, paper_mat, int(def["seed"]), wx["kind"] == "rain")


## Per-frame: keep weather and birds around the focus, aim the frontal fill along the camera.
var _bonnet := false


## Bonnet view looks at the horizon: give it a pale paper sky and a soft fog so the edge of the
## printed ground never shows.
func set_bonnet(on: bool) -> void:
	if on == _bonnet:
		return
	_bonnet = on
	var sky: Color = Color(def["pal"]["ground"]).lerp(Color(wx["fill"]), 0.35).lightened(0.12)
	env.background_color = sky if on else Color(def["pal"]["ground"])
	env.fog_enabled = on
	env.fog_light_color = sky
	env.fog_density = 0.011
	env.fog_sky_affect = 1.0


func update(dt: float, focus: Vector3, radius: float, player_s: float, cam: Camera3D) -> void:
	_time += dt
	if scenery:
		scenery.update(Vector2(focus.x, focus.z), radius, dt)
	weather_fx.position = focus
	if cam:
		fill_light.global_basis = cam.global_basis


func grip() -> float:
	return float(wx["grip"])


func kind() -> String:
	return wx["kind"]
