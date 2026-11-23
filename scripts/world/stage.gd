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
	track.generate(int(def["seed"]), float(def["length"]) + Track.POST_FINISH, float(def["twist"]), float(def["width"]))
	var ep: Dictionary = def.get("elev", {})
	track.build_elevation(ep, int(def["seed"]))
	track.build_hazards(int(def["seed"]), wx["kind"], float(def["twist"]))
	track.build_bridges(int(def["seed"]), def.get("bridges", []))
	track.index_watercourses()
	track.build_barriers(int(def["seed"]), def.get("barriers", []))
	track.terrain = Terrain.new()
	track.terrain.build(track, float(ep.get("hills", 10.0)), int(def["seed"]) + 5)
	if def.has("coast"):
		var cst: Dictionary = def["coast"]
		var lo := INF
		for e in track.elev:
			lo = minf(lo, e)
		track.terrain.make_coast(track, lo + float(cst["sea"]), float(cst["edge"]), bool(cst.get("beach", false)), int(def["seed"]) + 9)
		track.add_cliff_barriers()
	for br in track.bridges:
		track.terrain.carve_river(br["a"], br["b"], br["water_y"])
	track.terrain.flatten_disc(parc_center(), 26.0, track.road_h_i(track.index_at(track.length - PARC_BACK)) - 0.1)
	_make_materials()
	_make_lights()
	_make_ground()
	_make_road()
	_make_gantries()
	scenery = Scenery.new()
	scenery.name = "Scenery"
	scenery.lights_on = bool(wx.get("headlights", false))
	add_child(scenery)
	scenery.setup(track, def, paper_mat, float(Settings.g("density")), float(Settings.g("draw_distance")), bool(Settings.g("popups")))
	_make_puddles()
	_make_parc_ferme()
	_make_bridges()
	_make_hazards()
	_make_barriers()
	_make_weather()
	_make_mist()
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
	ground_mat.set_shader_parameter("sea_y", track.terrain.sea_y if def.has("coast") else -10000.0)
	ground_mat.set_shader_parameter("rock_amount", 0.9 if def.has("coast") else 0.55)
	ground_mat.set_shader_parameter("rock", Color(pal["stone"]).lightened(0.25))
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
	env.background_color = _ground_bg()
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
	if is_coastal():
		# The sea: a flat sheet out to the horizon, edged with paper surf where it meets the land.
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/water.gdshader")
		sm.set_shader_parameter("paper_tint", sea_color())
		var sea := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = b.size * 3.0
		sea.mesh = sp
		sea.material_override = sm
		sea.position = Vector3(b.get_center().x, track.terrain.sea_y, b.get_center().y)
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sea)
		_make_coast_dressing()


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
				var wl := track.width * 0.5 + 16.0
				var stream := _water_sheet(wl * 2.0, 3.6, Color("#7895a4"), i)
				stream.position = Vector3(p.x, track.road_h_i(i) + ROAD_Y + 0.025, p.y)
				stream.rotation.y = hd + PI * 0.5
				add_child(stream)
				_riverbanks(stream, wl * 2.0, 3.6, i, track.width * 0.5 + 1.0)
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
		var col: Color = {"gravel": Color(def["pal"]["road"]).lightened(0.18), "mud": Color("#86694c"), "ice": Color("#c9dcea"), "deep snow": Color("#f4f5f8")}[pt["kind"]]
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


const BARRIER_LAT := 0.75   # metres outside the road edge


## Armco (galvanised paper strip with a pressed groove on stubby posts) and post-and-rail fences.
func _make_barriers() -> void:
	var hw := track.width * 0.5 + BARRIER_LAT
	for bar in track.barriers:
		var s0: float = bar["s0"]
		var s1: float = bar["s1"]
		var side: float = bar["side"]
		if bar["kind"] == "parapet":
			continue   # drawn with its bridge
		var armco: bool = bar["kind"] == "armco"
		var s := s0
		while s < s1:
			var s_end := minf(s + 60.0, s1)
			var b := PaperKit.Builder.new(int(s))
			var step := 2.0
			var k := s
			var post_every := 4.0 if armco else 3.0
			var next_post := k
			while k < s_end:
				var i0 := track.index_at(k)
				var i1 := track.index_at(minf(k + step, s_end))
				var p0 := track.pts[i0] + track.nrm[i0] * side * hw
				var p1 := track.pts[i1] + track.nrm[i1] * side * hw
				var y0 := track.elev[i0] - 0.1
				var y1 := track.elev[i1] - 0.1
				if bar["kind"] == "wall":
					_stone_wall(b, p0, p1, y0, y1, track.nrm[i0] * side, k)
				elif armco:
					var lo := 0.42
					var hi := 0.78
					b.slab(Vector3(p0.x, y0 + hi, p0.y), Vector3(p1.x, y1 + hi, p1.y), Vector3(p1.x, y1 + lo, p1.y), Vector3(p0.x, y0 + lo, p0.y), 0.06, Color("#b4b8bb"))
					var o := track.nrm[i0] * -side * 0.04
					b.slab(Vector3(p0.x + o.x, y0 + 0.61, p0.y + o.y), Vector3(p1.x + o.x, y1 + 0.61, p1.y + o.y), Vector3(p1.x + o.x, y1 + 0.57, p1.y + o.y), Vector3(p0.x + o.x, y0 + 0.57, p0.y + o.y), 0.02, Color("#7d8286"))
				else:
					for rh in [0.45, 0.95]:
						b.slab(Vector3(p0.x, y0 + rh + 0.09, p0.y), Vector3(p1.x, y1 + rh + 0.09, p1.y), Vector3(p1.x, y1 + rh - 0.04, p1.y), Vector3(p0.x, y0 + rh - 0.04, p0.y), 0.06, Color("#9a7552"))
				if k >= next_post and bar["kind"] != "wall":
					var ph := 0.85 if armco else 1.15
					var pc := Color("#6d7174") if armco else Color("#6e5038")
					var pp := p0 + track.nrm[i0] * side * 0.08
					b.box(Vector3(pp.x, y0 + ph * 0.5 - 0.2, pp.y), Vector3(0.14, ph + 0.4, 0.14), Transform3D(), pc)
					next_post += post_every
				k += step
			var mi := MeshInstance3D.new()
			mi.mesh = b.mesh()
			mi.material_override = paper_mat
			mi.position = Vector3.ZERO
			add_child(mi)
			s = s_end


## Dry-stone wall: a rough grey core, irregular face stones in mixed tones on both faces, and a
## row of upright coping stones along the top (the classic British field wall).
func _stone_wall(b: PaperKit.Builder, p0: Vector2, p1: Vector2, y0: float, y1: float, out: Vector2, seed_s: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_s * 13.0) + 7
	var tones := [Color("#a39b8c"), Color("#b7ae9c"), Color("#8f887b"), Color("#c3bba8"), Color("#9c9384")]
	var dir := (p1 - p0)
	var seg := dir.length()
	if seg < 0.01:
		return
	var along := Vector3(dir.x, y1 - y0, dir.y) / seg
	var face := Vector3(-dir.y, 0, dir.x) / seg
	if face.dot(Vector3(out.x, 0, out.y)) > 0.0:
		face = -face
	var start := Vector3(p0.x, y0, p0.y)
	var frame := Transform3D(Basis(Vector3(dir.y, 0, -dir.x) / seg, Vector3.UP, along), start)
	b.box(Vector3(0, 0.40, seg * 0.5), Vector3(0.50, 0.86, seg + 0.015), frame, Color("#786f64"))
	# Three staggered courses. Clipped corners and a narrow lighter shoulder
	# pick out each fieldstone against the continuous recessed core.
	for row in 3:
		var u := 0.0
		while u < seg - 0.04:
			var w := minf(rng.randf_range(0.38, 0.76), seg - u)
			if u == 0.0 and row % 2 == 1:
				w *= 0.55
			var h := rng.randf_range(0.24, 0.27)
			var chip := minf(w * 0.15, rng.randf_range(0.045, 0.10))
			var col: Color = tones[rng.randi_range(0, tones.size() - 1)]
			for side: float in [-1.0, 1.0]:
				var n := face * side
				var base := start + along * u + Vector3.UP * (0.015 + row * 0.275) + n * 0.265
				var lo := base + along * 0.014
				var hi := base + along * (w - 0.014)
				var a := lo + Vector3.UP * (h - chip)
				var d := hi + Vector3.UP * (h - chip * 0.65)
				var crown_l := a + along * chip + Vector3.UP * chip - n * 0.012
				var crown_r := d - along * chip + Vector3.UP * (chip * 0.65) - n * 0.012
				b.quad(lo + along * chip * 0.4, hi - along * chip * 0.3, d, a, n, PaperKit.lin(col))
				b.quad(a, d, crown_r, crown_l, (n + Vector3.UP * 0.4).normalized(), PaperKit.lin(col.lightened(0.09)))
			u += w
	var t := 0.0
	while t < seg - 0.04:
		var w := minf(rng.randf_range(0.26, 0.44), seg - t)
		var cap := frame.translated_local(Vector3(0, 0.91, t + w * 0.5))
		cap.basis = cap.basis * Basis(Vector3.FORWARD, rng.randf_range(-0.10, 0.10))
		var col: Color = tones[rng.randi_range(0, tones.size() - 1)]
		b.box(Vector3.ZERO, Vector3(0.57, rng.randf_range(0.20, 0.29), w * 0.95), cap, col, col.lightened(0.09))
		t += w


## A cut-paper channel with pale shallows, a wandering deep seam and long facets.
## Local Z follows the current for both the geometry and the moving ink marks.
func _water_sheet(length: float, half_width: float, water: Color, seed_v: int) -> MeshInstance3D:
	var b := PaperKit.Builder.new(seed_v)
	var steps := maxi(2, ceili(length / 3.5))
	var last := PackedVector3Array()
	var shallows := water.lerp(Color("#b2b39a"), 0.48)
	var depths := [shallows, water.lightened(0.06), water.darkened(0.22), water.darkened(0.17), water, shallows]
	for i in steps + 1:
		var z := length * (float(i) / steps - 0.5)
		var section := PackedVector3Array()
		for x: float in [-1.0, -0.68, -0.24, 0.26, 0.72, 1.0]:
			section.append(Vector3(_channel_x(z, x, half_width, seed_v), 0, z))
		if i > 0:
			for j in range(depths.size() - 1):
				var c := PaperKit.lin(depths[j])
				var d := PaperKit.lin(depths[j + 1])
				b.quad4(last[j], last[j + 1], section[j + 1], section[j], Vector3.UP, c, d, d, c)
		last = section
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# Keep mesh edges and bank toes on exactly the same sampled curve.
func _channel_x(z: float, fraction: float, width: float, seed_v: int) -> float:
	var phase := float(seed_v % 41)
	var bend := sin(z * 0.093 + phase) * 0.18 + sin(z * 0.22 - phase) * 0.065
	var breadth := 1.0 + 0.09 * sin(z * 0.16 + phase)
	return width * (bend + fraction * breadth)


func _riverbanks(sheet: MeshInstance3D, length: float, width: float, seed_v: int, ford_gap := 0.0) -> void:
	var b := PaperKit.Builder.new(seed_v)
	var steps := maxi(2, ceili(length / 3.5))
	var mud := PaperKit.lin(Color("#685947"))
	var gravel := PaperKit.lin(Color(def["pal"]["stone"]).darkened(0.14))
	var grass := PaperKit.lin(def["pal"]["ground"])
	var colors := [mud, gravel, grass]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for side: float in [-1.0, 1.0]:
		var last := PackedVector3Array()
		for i in steps + 1:
			var z := length * (float(i) / steps - 0.5)
			if absf(z) < ford_gap:
				last.clear()
				continue
			var edge := _channel_x(z, side, width, seed_v)
			var outer := Vector3(edge + side * 3.8, 0, z)
			var world := sheet.transform * outer
			outer.y = track.terrain.height(Vector2(world.x, world.z)) - sheet.position.y - 0.15
			var ridge := 0.48 + 0.17 * sin(z * 0.43 + side)
			# Short gravel bars build up on one bank, tapering back into the flow.
			var shelf := pow(maxf(0, sin(z * 0.21 + seed_v % 9 + side * 2.0)), 3.0)
			var toe := edge - side * (0.13 + shelf * 1.35)
			var strand := edge + side * (0.48 - shelf * 1.1)
			var row := PackedVector3Array([Vector3(toe, -0.055, z), Vector3(strand, 0.13, z),
				Vector3(edge + side * 1.65, maxf(ridge, outer.y * 0.62), z), outer])
			if not last.is_empty():
				for j in 3:
					var normal := (row[j] - last[j]).cross(last[j + 1] - last[j]).normalized()
					if normal.y < 0:
						normal = -normal
					b.quad(last[j], row[j], row[j + 1], last[j + 1], normal, colors[j])
			if shelf > 0.25 and i > 0 and i < steps:
				for k in 3:
					var stone_z := z + rng.randf_range(-0.65, 0.65)
					var x := strand + side * rng.randf_range(-0.22, 0.35)
					var pebble := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)), Vector3(x, 0.13, stone_z))
					var radius := rng.randf_range(0.10, 0.23)
					b.card(PaperKit.circle(radius, 0, 0, 6), pebble * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), Color(def["pal"]["stone"]).lightened(rng.randf_range(0.02, 0.18)), {"thick": radius * 0.55, "lip": 0.0, "edge": 0.012})
			last = row
	var banks := MeshInstance3D.new()
	banks.mesh = b.mesh()
	banks.material_override = paper_mat
	sheet.add_child(banks)


## Bridges and their rivers.
func _make_bridges() -> void:
	var hw := track.width * 0.5 + BARRIER_LAT
	for br in track.bridges:
		var b := PaperKit.Builder.new(int(br["s"]))
		var sc: float = br["s"]
		var half: float = br["half"]
		var ci: int = br["i"]
		var wy: float = br["water_y"]
		var t2 := track.tang[ci]
		var n2 := track.nrm[ci]
		var c2 := track.pts[ci]
		var a: Vector2 = br["a"]
		var e: Vector2 = br["b"]
		var mid := (a + e) * 0.5
		var along := e - a
		var water := Color("#5d8fae") if def["weather"].begins_with("dry") else Color("#5b7f90")
		var river := _water_sheet(along.length(), 5.5, water, int(sc))
		river.position = Vector3(mid.x, wy, mid.y)
		river.rotation.y = atan2(along.x, along.y)
		add_child(river)
		_riverbanks(river, along.length(), 5.5, int(sc))
		# Local frame at the centre of the deck: x along the road, z across it, y up.
		var ybase := track.road_h_i(ci) - 0.85 if br["kind"] == "stone" else track.road_h_i(ci)
		var org := Vector3(c2.x, 0.0, c2.y)
		var fx := Vector3(t2.x, 0, t2.y)
		var fz := Vector3(n2.x, 0, n2.y)
		if br["kind"] == "stone":
			_stone_bridge(b, org, fx, fz, sc, half, hw, wy, ybase)
		else:
			_covered_bridge(b, org, fx, fz, sc, half, hw, wy, ybase)
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		add_child(mi)


const STONE := Color("#d3c9b6")
const STONE_DARK := Color("#ada08a")


func _stone_bridge(b: PaperKit.Builder, org: Vector3, fx: Vector3, fz: Vector3, sc: float, half: float, hw: float, wy: float, ybase: float) -> void:
	var L := half + 2.5
	var arch_a := half - 3.2
	var crown := track.road_h(sc) - 0.75
	var spring := wy + 0.4
	for side: float in [-1.0, 1.0]:
		# Spandrel face with the arch cut out of it.
		var poly := PackedVector2Array()
		var u := -L
		while u <= L + 0.01:
			poly.append(Vector2(u, track.road_h(sc + u) - 0.05))
			u += 1.0
		poly.append(Vector2(L, wy - 1.2))
		poly.append(Vector2(arch_a, wy - 1.2))
		for k in range(0, 13):
			var th := float(k) / 12.0 * PI
			poly.append(Vector2(cos(th) * arch_a, spring + sin(th) * (crown - spring)))
		poly.append(Vector2(-arch_a, wy - 1.2))
		poly.append(Vector2(-L, wy - 1.2))
		var xf := Transform3D(Basis(fx, Vector3.UP, fx.cross(Vector3.UP)), org + fz * side * (hw + 0.25))
		var zs := signf(fx.cross(Vector3.UP).dot(fz)) * side   # card +z pointing out of the bridge
		b.card(poly, xf, STONE, {"thick": 0.5, "edge": 0.08, "lip": 0.12, "back": STONE})
		# Voussoirs: darker stones ringing the arch.
		for k in range(0, 11):
			var th0 := (float(k) + 0.1) / 11.0 * PI
			var th1 := (float(k) + 0.9) / 11.0 * PI
			var r0 := Vector2(arch_a, crown - spring)
			var r1 := Vector2(arch_a + 0.55, crown - spring + 0.55)
			var q := PackedVector2Array([
				Vector2(cos(th0) * r0.x, spring + sin(th0) * r0.y), Vector2(cos(th0) * r1.x, spring + sin(th0) * r1.y),
				Vector2(cos(th1) * r1.x, spring + sin(th1) * r1.y), Vector2(cos(th1) * r0.x, spring + sin(th1) * r0.y)])
			b.card(q, xf * Transform3D(Basis(), Vector3(0, 0, zs * 0.27)), STONE_DARK, {"thick": 0.04, "edge": 0.03, "lip": 0.0})
		# Parapet wall and its coping, following the hump.
		var k2 := -L
		while k2 < L - 0.01:
			var k3 := minf(k2 + 1.5, L)
			var y0 := track.road_h(sc + k2)
			var y1 := track.road_h(sc + k3)
			var p0: Vector3 = org + fx * k2 + fz * side * hw
			var p1: Vector3 = org + fx * k3 + fz * side * hw
			b.slab(p0 + Vector3(0, y0 - 0.1, 0), p1 + Vector3(0, y1 - 0.1, 0), p1 + Vector3(0, y1 + 0.9, 0), p0 + Vector3(0, y0 + 0.9, 0), 0.42, STONE)
			b.slab(p0 + Vector3(0, y0 + 0.92, 0) - fz * side * 0.28, p1 + Vector3(0, y1 + 0.92, 0) - fz * side * 0.28, p1 + Vector3(0, y1 + 0.92, 0) + fz * side * 0.28, p0 + Vector3(0, y0 + 0.92, 0) + fz * side * 0.28, 0.1, STONE_DARK)
			k2 = k3
	# Arch soffit (the underside of the barrel vault).
	for k in range(0, 12):
		var th0 := float(k) / 12.0 * PI
		var th1 := float(k + 1) / 12.0 * PI
		var p0 := org + fx * cos(th0) * arch_a + Vector3(0, spring + sin(th0) * (crown - spring), 0)
		var p1 := org + fx * cos(th1) * arch_a + Vector3(0, spring + sin(th1) * (crown - spring), 0)
		b.slab(p0 - fz * (hw + 0.2), p1 - fz * (hw + 0.2), p1 + fz * (hw + 0.2), p0 + fz * (hw + 0.2), 0.08, STONE_DARK)
	# Abutment piers down into the water.
	for sgn: float in [-1.0, 1.0]:
		var pc: Vector3 = org + fx * sgn * (arch_a + 0.6)
		b.box(pc + Vector3(0, wy - 0.4, 0), Vector3(1.6, 1.6, (hw + 0.6) * 2.0), Transform3D(Basis(fx, Vector3.UP, fx.cross(Vector3.UP)), Vector3.ZERO), STONE_DARK)


func _covered_bridge(b: PaperKit.Builder, org: Vector3, fx: Vector3, fz: Vector3, sc: float, half: float, hw: float, wy: float, ybase: float) -> void:
	var wood := Color("#b0663f")
	var wood_dark := Color("#875038")
	var roof := Color("#8a7a70")
	var y := track.road_h(sc)
	var H := 4.2
	var bas := Basis(fx, Vector3.UP, fx.cross(Vector3.UP))
	# Side walls with a row of windows.
	for side: float in [-1.0, 1.0]:
		var wpos: Vector3 = org + fz * side * (hw + 0.15)
		var poly := PackedVector2Array([Vector2(-half, y - 0.4), Vector2(half, y - 0.4), Vector2(half, y + H), Vector2(-half, y + H)])
		var xf := Transform3D(bas, wpos)
		b.card(poly, xf, wood, {"thick": 0.16, "edge": 0.06, "lip": 0.1, "back": wood.darkened(0.15)})
		var u := -half + 2.5
		while u < half - 2.0:
			var win := PaperKit.rect(1.1, 0.7, u, y + 2.0)
			b.card(win, xf * Transform3D(Basis(), Vector3(0, 0, side * 0.1)), Color("#2a221c"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
			b.card(win, xf * Transform3D(Basis(), Vector3(0, 0, -side * 0.1)), Color("#2a221c"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
			u += 3.2
		# Vertical board battens.
		var v := -half + 0.8
		while v < half:
			b.box(wpos + fx * v + fz * side * 0.1 + Vector3(0, y + H * 0.5 - 0.2, 0), Vector3(0.12, H + 0.4, 0.05), Transform3D(bas, Vector3.ZERO), wood_dark)
			v += 1.6
	# Gable ends: portal openings big enough for the cars.
	var gw := hw + 0.45
	for sgn: float in [-1.0, 1.0]:
		var gpos: Vector3 = org + fx * sgn * half
		var gx := Basis(fz, Vector3.UP, fz.cross(Vector3.UP))
		var poly := PackedVector2Array([
			Vector2(-gw, y + H), Vector2(0, y + H + 2.2), Vector2(gw, y + H), Vector2(gw, y + H - 0.6),
			Vector2(gw - 0.6, y + H - 0.6), Vector2(gw - 0.6, y + H - 0.2), Vector2(-gw + 0.6, y + H - 0.2), Vector2(-gw + 0.6, y + H - 0.6), Vector2(-gw, y + H - 0.6)])
		b.card(poly, Transform3D(gx, gpos), wood_dark, {"thick": 0.16, "edge": 0.06, "lip": 0.1, "back": wood_dark})
	# Roof.
	var ov := 0.9
	for side: float in [-1.0, 1.0]:
		var e0: Vector3 = org + fz * side * (gw + 0.5) + Vector3(0, y + H - 0.3, 0)
		var r0 := org + Vector3(0, y + H + 2.25, 0)
		b.slab(e0 - fx * (half + ov), e0 + fx * (half + ov), r0 + fx * (half + ov), r0 - fx * (half + ov), 0.14, roof)
	# Stone abutments and timber trestles.
	for sgn: float in [-1.0, 1.0]:
		b.box(org + fx * sgn * (half - 1.0) + Vector3(0, (y + wy - 1.2) * 0.5, 0), Vector3(2.2, y - wy + 1.2, (hw + 0.6) * 2.0), Transform3D(bas, Vector3.ZERO), STONE_DARK)
	for u in [-half * 0.35, half * 0.35]:
		b.box(org + fx * u + Vector3(0, (y + wy - 1.0) * 0.5 - 0.3, 0), Vector3(0.5, y - wy + 0.4, (hw + 0.2) * 2.0), Transform3D(bas, Vector3.ZERO), wood_dark)
	# Deck underside.
	b.slab(org - fx * half - fz * (hw + 0.2) + Vector3(0, y - 0.45, 0), org + fx * half - fz * (hw + 0.2) + Vector3(0, y - 0.45, 0), org + fx * half + fz * (hw + 0.2) + Vector3(0, y - 0.45, 0), org - fx * half + fz * (hw + 0.2) + Vector3(0, y - 0.45, 0), 0.3, wood_dark)


func is_coastal() -> bool:
	return def.has("coast")


func sea_color() -> Color:
	var c := Color("#4f86a8") if wx.get("kind", "dry") == "dry" else Color("#557886")
	return c if tod == 0 else (c.darkened(0.3) if tod == 1 else c.darkened(0.85))


## Surf lines along the shore, boats on the water, a lighthouse on the headlands and, at the
## harbour, stone quays with moored fishing boats near the start.
func _make_coast_dressing() -> void:
	var tr := track.terrain
	var cst: Dictionary = def["coast"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def["seed"]) + 404
	var b := PaperKit.Builder.new(int(def["seed"]))
	var lay := Basis(Vector3.RIGHT, -PI * 0.5)
	var surf := Color("#eef2ee")
	var shore: Array = []      # sea cells touching land, near enough to the road to be seen
	var open_sea: Array = []
	for z in range(1, tr.nz - 1):
		for x in range(1, tr.nx - 1):
			var k := z * tr.nx + x
			if tr.sea[k] != 1 or tr._mind[k] > track.width * 0.5 + 260.0:
				continue
			var p := Vector2(tr.origin.x + x * tr.cell, tr.origin.y + z * tr.cell)
			if tr.sea[k - 1] == 0 or tr.sea[k + 1] == 0 or tr.sea[k - tr.nx] == 0 or tr.sea[k + tr.nx] == 0:
				shore.append(p)
			elif tr._mind[k] > 40.0:
				open_sea.append(p)
	# Surf: short pale cut strips hugging the shoreline.
	for p in shore:
		if rng.randf() < 0.55:
			var yaw := rng.randf() * TAU
			b.card(PaperKit.rrect(rng.randf_range(2.5, 5.5), 0.45, 0.2, 0, -0.22), Transform3D(Basis(Vector3.UP, yaw) * lay, Vector3(p.x + rng.randf_range(-2, 2), tr.sea_y + 0.05, p.y + rng.randf_range(-2, 2))), surf, {"thick": 0.02, "edge": 0.0, "lip": 0.0, "sides": false})
	# Wave dashes further out.
	for i in mini(open_sea.size(), 260):
		var p: Vector2 = open_sea[rng.randi() % open_sea.size()]
		b.card(PaperKit.rrect(rng.randf_range(1.5, 3.5), 0.22, 0.1, 0, -0.11), Transform3D(Basis(Vector3.UP, 0.5) * lay, Vector3(p.x + rng.randf_range(-3, 3), tr.sea_y + 0.04, p.y + rng.randf_range(-3, 3))), sea_color().lightened(0.25), {"thick": 0.02, "edge": 0.0, "lip": 0.0, "sides": false})
	# Boats out on the water.
	open_sea.shuffle()
	var nb := mini(open_sea.size(), 6 + int(track.length / 1500.0))
	for i in nb:
		var p: Vector2 = open_sea[i]
		_boat(b, Vector3(p.x, tr.sea_y, p.y), rng.randf() * TAU, rng, rng.randf() < 0.5)
	# Lighthouses on headlands: land cells beside the sea, well clear of the road.
	if cst.get("lighthouse", false):
		var placed: Array = []
		shore.shuffle()
		for p in shore:
			if placed.size() >= maxi(1, int(track.length / 4000.0)):
				break
			if track.clearance(p) < 40.0:
				continue
			var land := Vector2.ZERO
			var found := false
			for d in [Vector2(tr.cell, 0), Vector2(-tr.cell, 0), Vector2(0, tr.cell), Vector2(0, -tr.cell)]:
				if not tr.is_sea(p + d * 2.0):
					land = p + d * 2.0
					found = true
					break
			if not found or track.clearance(land) < 35.0:
				continue
			var far_enough := true
			for q in placed:
				if q.distance_to(land) < 900.0:
					far_enough = false
			if far_enough:
				placed.append(land)
				_lighthouse(b, Vector3(land.x, tr.height(land), land.y))
	# Harbour: quays and moored boats near the start of the stage.
	if cst.get("harbour", false):
		var start := track.pts[0]
		shore.sort_custom(func(a, c): return a.distance_to(start) < c.distance_to(start))
		var quays := 0
		var used: Array = []
		for p in shore:
			if quays >= 3:
				break
			var ok := true
			for q in used:
				if q.distance_to(p) < 45.0:
					ok = false
			if not ok:
				continue
			# Point the quay from the land out to sea.
			var out := Vector2.ZERO
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				if tr.is_sea(p + d * tr.cell * 3.0):
					out += d
			if out.length() < 0.5:
				continue
			out = out.normalized()
			used.append(p)
			quays += 1
			var yaw := atan2(out.x, out.y)
			var qb := Basis(Vector3.UP, yaw)
			var qc := Vector3(p.x, tr.sea_y, p.y) + Vector3(out.x, 0, out.y) * 6.0
			b.box(qc + Vector3(0, 0.4, 0), Vector3(4.0, 2.2, 26.0), Transform3D(qb, Vector3.ZERO), Color("#b8b2a4"), Color("#cfc8b8"))
			for k in 4:
				var bollard := qc + qb * Vector3(1.6, 1.7, -9.0 + k * 6.0)
				b.box(bollard, Vector3(0.3, 0.5, 0.3), Transform3D(), Color("#3a3a40"))
			for side in [-1.0, 1.0]:
				for k in 2:
					var bp := qc + qb * Vector3(side * 4.4, 0.0, -6.0 + k * 9.0)
					_boat(b, bp, yaw + rng.randf_range(-0.1, 0.1), rng, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A little paper fishing boat (or sailing dinghy) sitting on the water.
func _boat(b: PaperKit.Builder, at: Vector3, yaw: float, rng: RandomNumberGenerator, sail: bool) -> void:
	var cols := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#ece6d8")]
	var hull: Color = cols[rng.randi() % cols.size()]
	var L := rng.randf_range(4.5, 7.0)
	var bas := Basis(Vector3.UP, yaw)
	var xf := Transform3D(bas * Basis(Vector3.UP, PI * 0.5), at)
	# Hull: a side-profile prism (bow raked up), extruded across the beam.
	var prof := PackedVector2Array([Vector2(-L * 0.5, 0.75), Vector2(-L * 0.42, -0.15), Vector2(L * 0.3, -0.15), Vector2(L * 0.5, 0.95)])
	b.card(prof, xf, hull, {"thick": 1.9, "edge": 0.06, "lip": 0.1, "back": hull})
	b.box(at + bas * Vector3(0, 0.8, 0), Vector3(1.6, 0.06, L * 0.85), Transform3D(), Color("#d8c8a8"))
	if sail:
		b.box(at + bas * Vector3(0, 3.0, 0.3), Vector3(0.1, 4.4, 0.1), Transform3D(), Color("#6e5038"))
		var sp := PackedVector2Array([Vector2(0, 1.2), Vector2(0, 5.0), Vector2(-L * 0.4, 1.3)])
		b.card(sp, Transform3D(bas * Basis(Vector3.UP, PI * 0.5), at + bas * Vector3(0, 0, 0.3)), Color("#f4efe2"), {"thick": 0.02, "edge": 0.03, "lip": 0.0})
	else:
		# Wheelhouse and a short mast.
		b.box(at + bas * Vector3(0, 1.45, -L * 0.1), Vector3(1.3, 1.3, 1.5), Transform3D(bas, Vector3.ZERO), Color("#ece6d8"), Color("#4a5a6a"))
		b.box(at + bas * Vector3(0, 1.6, -L * 0.1 - 0.76), Vector3(0.9, 0.4, 0.02), Transform3D(bas, Vector3.ZERO), Color("#2a3440"))
		b.box(at + bas * Vector3(0, 2.6, L * 0.2), Vector3(0.08, 2.6, 0.08), Transform3D(), Color("#6e5038"))


## A striped lighthouse with a lamp room.
func _lighthouse(b: PaperKit.Builder, at: Vector3) -> void:
	var sides := 8
	for band in 6:
		var y0 := band * 2.6
		var r0 := 2.4 - band * 0.22
		var r1 := 2.4 - (band + 1) * 0.22
		var col := Color("#c8553d") if band % 2 == 1 else Color("#f1ece2")
		for k in sides:
			var a0 := float(k) / sides * TAU
			var a1 := float(k + 1) / sides * TAU
			b.slab(at + Vector3(cos(a0) * r0, y0, sin(a0) * r0), at + Vector3(cos(a1) * r0, y0, sin(a1) * r0),
				at + Vector3(cos(a1) * r1, y0 + 2.6, sin(a1) * r1), at + Vector3(cos(a0) * r1, y0 + 2.6, sin(a0) * r1), 0.08, col)
	var top := at + Vector3(0, 15.6, 0)
	b.box(top + Vector3(0, 0.15, 0), Vector3(3.6, 0.3, 3.6), Transform3D(), Color("#3a3a40"))
	b.box(top + Vector3(0, 1.1, 0), Vector3(1.8, 1.6, 1.8), Transform3D(), Color("#ffe9a8"), Color(-1, 0, 0), tod > 0)
	b.box(top + Vector3(0, 2.2, 0), Vector3(2.2, 0.6, 2.2), Transform3D(), Color("#3a3a40"))
	b.box(at + Vector3(3.2, 1.4, 0), Vector3(4.0, 2.8, 3.2), Transform3D(), Color("#f1ece2"), Color("#4a5a6a"))


## Parc fermé layout: the lot covers the last stretch of road past the flying finish.
const PARC_BACK := 16.0          # lot centre, metres before the road's end
const PARC_LATS := [-10.0, 10.0, -5.0, 5.0]


## Centre of the parc fermé lot.
func parc_center() -> Vector2:
	return track.point_at(track.length - PARC_BACK)


## Parking bay k (in order of arrival): [stop distance along the road, lateral offset].
static func parc_bay(length: float, k: int) -> Array:
	return [length - 8.0 - (k / 4) * 7.0, PARC_LATS[k % 4]]


## Parc fermé: a flat gravel lot where the road ends, with marked parking bays, service gazebos and
## vans, a PARC FERMÉ gantry, and spectators behind tape.
func _make_parc_ferme() -> void:
	var c := parc_center()
	var i := track.index_at(track.length - PARC_BACK)
	var hd := track.heading_at(i)
	var y := track.road_h_i(i)
	var root := Node3D.new()
	root.position = Vector3(c.x, y, c.y)
	root.rotation.y = hd
	add_child(root)
	var b := PaperKit.Builder.new(int(def["seed"]))
	var lay := Basis(Vector3.RIGHT, -PI * 0.5)
	var gravel: Color = Color(def["pal"]["road"]).lightened(0.12)
	# Gravel lot (local +z = direction of travel).
	b.card(PaperKit.rrect(34.0, 36.0, 2.0, 0, -18.0), Transform3D(lay, Vector3(0, ROAD_Y - 0.02, 0)), gravel, {"thick": 0.06, "edge": 0.08, "lip": 0.1})
	# Bay lines for two rows of four.
	for row in 2:
		var zc := 8.0 - row * 7.0
		for lx in [-12.5, -7.5, -2.5, 2.5, 7.5, 12.5]:
			b.box(Vector3(lx, ROAD_Y + 0.05, zc), Vector3(0.16, 0.02, 5.2), Transform3D(), PaperKit.CREAM)
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(side * 7.5, ROAD_Y + 0.05, zc + 2.6), Vector3(10.0, 0.02, 0.16), Transform3D(), PaperKit.CREAM)
	# Service gazebos past the end of the road, each with a van and a tyre stack.
	var cols := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a")]
	for k in 4:
		var gx := -13.5 + k * 9.0
		var gz := 22.0
		for px in [-1.4, 1.4]:
			for pz in [-1.4, 1.4]:
				b.box(Vector3(gx + px, 1.25, gz + pz), Vector3(0.08, 2.5, 0.08), Transform3D(), Color("#d8d4cc"))
		var cc: Color = cols[k]
		b.slab(Vector3(gx - 1.7, 2.5, gz - 1.7), Vector3(gx + 1.7, 2.5, gz - 1.7), Vector3(gx, 3.3, gz), Vector3(gx, 3.3, gz), 0.04, cc)
		b.slab(Vector3(gx + 1.7, 2.5, gz + 1.7), Vector3(gx - 1.7, 2.5, gz + 1.7), Vector3(gx, 3.3, gz), Vector3(gx, 3.3, gz), 0.04, cc.darkened(0.12))
		b.slab(Vector3(gx + 1.7, 2.5, gz - 1.7), Vector3(gx + 1.7, 2.5, gz + 1.7), Vector3(gx, 3.3, gz), Vector3(gx, 3.3, gz), 0.04, cc.lightened(0.1))
		b.slab(Vector3(gx - 1.7, 2.5, gz + 1.7), Vector3(gx - 1.7, 2.5, gz - 1.7), Vector3(gx, 3.3, gz), Vector3(gx, 3.3, gz), 0.04, cc.lightened(0.05))
		b.box(Vector3(gx - 0.6, 0.45, gz), Vector3(1.6, 0.9, 0.7), Transform3D(), Color("#8a6a48"))
		b.box(Vector3(gx + 0.4, 1.15, gz + 5.2), Vector3(2.1, 2.3, 4.8), Transform3D(), PaperKit.CREAM, Color("#d8d4cc"))
		b.box(Vector3(gx + 0.4, 1.0, gz + 2.79), Vector3(2.12, 0.35, 0.02), Transform3D(), cc)
		for t in 3:
			b.box(Vector3(gx + 1.2, 0.15 + t * 0.3, gz - 0.9), Vector3(0.7, 0.28, 0.7), Transform3D(), Color("#2b2420"))
	# Tape lines down both sides with spectators behind them.
	for side: float in [-1.0, 1.0]:
		for z in range(-16, 18, 4):
			b.box(Vector3(side * 16.5, 0.5, z), Vector3(0.06, 1.0, 0.06), Transform3D(), Color("#d8d4cc"))
		b.box(Vector3(side * 16.5, 0.9, 0.0), Vector3(0.02, 0.08, 32.0), Transform3D(), Color("#e8b04a"))
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	root.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def["seed"]) + 77
	for side: float in [-1.0, 1.0]:
		for k in 5:
			var crowd: Dictionary = Pieces.spectators(def["pal"], rng)
			var smi := MeshInstance3D.new()
			smi.mesh = crowd["mesh"]
			smi.material_override = paper_mat
			smi.position = Vector3(side * (18.0 + rng.randf() * 1.0), 0.0, -12.0 + k * 6.5 + rng.randf() * 1.5)
			smi.rotation.y = -side * PI * 0.5
			root.add_child(smi)
	# PARC FERMÉ gantry over the entrance, lettered on both faces.
	var gate := MeshInstance3D.new()
	gate.mesh = Pieces.arch(track.width + 3.0, false)
	gate.material_override = paper_mat
	gate.position = Vector3(0, 0, -17.0)
	root.add_child(gate)
	for face in [0, 1]:
		var l := Label3D.new()
		l.text = "PARC FERMÉ"
		l.font = PaperTheme.font()
		l.font_size = 96
		l.pixel_size = 0.01
		l.modulate = Color("#2b2b2b")
		l.outline_size = 0
		l.shaded = true
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.position = Vector3(0, 5.15, -17.0 + (0.09 if face == 1 else -0.09))
		l.rotation.y = 0.0 if face == 1 else PI
		root.add_child(l)
	parc_root = root


var parc_root: Node3D
var _flat_mats := {}
func _flat_mat(c: Color) -> Material:
	if not _flat_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_flat_mats[c] = m
	return _flat_mats[c]


## Autumn: dry leaves gusting across the road around the camera, tumbling as they go.
func _make_leaves() -> void:
	var lp := CPUParticles3D.new()
	lp.local_coords = false
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# A leaf: a pointed oval cut from paper.
	var leaf := PackedVector2Array()
	for k in 10:
		var a := TAU * k / 10.0
		leaf.append(Vector2(cos(a) * 0.11, sin(a) * 0.17 * (1.0 + 0.35 * signf(sin(a)) * absf(sin(a)))))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in leaf.size():
		var a0 := leaf[k]
		var a1 := leaf[(k + 1) % leaf.size()]
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(a1.x, a1.y, 0))
		st.add_vertex(Vector3(a0.x, a0.y, 0))
	var lm := st.commit()
	lm.surface_set_material(0, mat)
	lp.mesh = lm
	lp.amount = 220
	lp.lifetime = 5.0
	lp.preprocess = 5.0
	lp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	lp.emission_box_extents = Vector3(28, 0.8, 28)
	lp.position = Vector3(0, 1.1, 0)
	lp.direction = Vector3(1.0, 0.1, 0.35)
	lp.spread = 35.0
	lp.initial_velocity_min = 2.5
	lp.initial_velocity_max = 6.0
	lp.gravity = Vector3(0.8, -0.4, 0.25)
	lp.damping_min = 0.2
	lp.damping_max = 0.6
	lp.angular_velocity_min = -320.0
	lp.angular_velocity_max = 320.0
	lp.angle_min = 0.0
	lp.angle_max = 360.0
	lp.scale_amount_min = 0.8
	lp.scale_amount_max = 1.5
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.85, 1.0])
	g.colors = PackedColorArray([Color("#c8553d"), Color("#e8a040"), Color("#d0682e"), Color("#a8452e"), Color("#e8c05a")])
	lp.color_initial_ramp = g
	lp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weather_fx.add_child(lp)


func _make_weather() -> void:
	weather_fx = Node3D.new()
	add_child(weather_fx)
	var kind: String = wx["particles"]
	Sfx.set_ambience(kind)
	if def.get("leaves", false):
		_make_leaves()
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


## Low paper mist lying in the valleys below the road (rain, dusk, night and the misty locations).
func _make_mist() -> void:
	var misty: bool = wx["kind"] == "rain" or tod > 0 or def["id"].begins_with("moor") or def["id"].begins_with("pinewood") or def["id"].begins_with("alpine")
	if not misty or is_coastal():
		return   # (over the sea the low mist sheets would read as floating ice)
	var road_min := 1e9
	for e in track.elev:
		road_min = minf(road_min, e)
	var b := track.bounds().grow(220.0)
	var col := Color("#eceae2") if tod < 2 else Color("#2a3150")
	if wx["kind"] == "snow":
		col = Color("#f2f3f8") if tod < 2 else Color("#343c60")
	var k := 0
	for off in [0.6, 2.2, 4.2]:
		var y = road_min - off
		if y < track.terrain.min_h + 0.3:
			continue
		var pm := PlaneMesh.new()
		pm.size = b.size
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/mist.gdshader")
		m.set_shader_parameter("noise", noise_tex())
		m.set_shader_parameter("col", col.darkened(0.04 * k))
		m.set_shader_parameter("leak", wx["leak"])
		m.set_shader_parameter("cut", 0.5 + k * 0.04)
		m.set_shader_parameter("seed", float(k) * 0.37)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = m
		mi.position = Vector3(b.get_center().x, y, b.get_center().y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		k += 1


func _make_birds() -> void:
	birds = Birds.new()
	birds.name = "Birds"
	add_child(birds)
	birds.setup(track, paper_mat, int(def["seed"]), wx["kind"] == "rain")


## Per-frame: keep weather and birds around the focus, aim the frontal fill along the camera.
var _bonnet := false


## Bonnet view looks at the horizon: give it a pale paper sky and a soft fog so the edge of the
## printed ground never shows.
func _ground_bg() -> Color:
	var g: Color = sea_color() if is_coastal() else Color(def["pal"]["ground"])
	return g if tod < 2 else g.darkened(0.85)


func set_bonnet(on: bool) -> void:
	if on == _bonnet:
		return
	_bonnet = on
	var sky: Color = Color(def["pal"]["ground"]).lerp(Color(wx["fill"]), 0.35).lightened(0.12)
	if tod == 1:
		sky = Color("#8a7fa8")
	elif tod == 2:
		sky = Color("#070a1a")
	env.background_color = sky if on else _ground_bg()
	env.fog_enabled = on
	env.fog_light_color = sky
	env.fog_density = 0.011 if tod < 2 else 0.007
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
