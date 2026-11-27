class_name Stage
extends Node3D
## Assembles one rally stage: light set, printed ground, road strip, start/finish gantries,
## puddles, scenery and weather (paper rain streaks / paper snow flakes), plus a few paper birds.

const PAPER_SHADER := preload("res://shaders/paper.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")
const ROAD_Y := 0.07
const SWITCHBACK_TUNNELS := {
	"canyon_sprint": Vector2(3804, 16),
	"autumn_classic": Vector2(4074, 20),
	"alpine_classic": Vector2(318, 16)
}
const SWITCHBACK_BRIDGES := {"canyon_classic": 2190.0}

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
var _wind_leaves: CPUParticles3D
var leaf_litter: LeafLitter
var birds: Birds
var _tunnel_roof: MeshInstance3D
var _stacked_deck: MeshInstance3D
var _stacked_road: MeshInstance3D
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
var rx_props: RxProps
var _lighting_mode := 0
var _light_presets: Array[Dictionary] = []
var _light_progress := 0.0
var headlight_level := 0.0
var _sky_mat: ShaderMaterial
var helicopter: Helicopter
var debug_board: Array = []
var arch_stations: Array = []
static var ARCH_STYLE := 2   # night lighting: 0 none, 1 glowing name and trim, 2 LED underside and base glow, 3 floodlit
var _crowd_boost := 0.0
var _crowd: Array = []   # [node, base, phase, is_stand]: spectators that cheer when the action is near
var _car_mat: ShaderMaterial
var _reflect_t := 0.0
var _lamp_level := 0.0
var _head_cache := PackedVector3Array()


func build(stage_def: Dictionary, time_of_day := -1) -> void:
	def = stage_def
	_lighting_mode = int(def.get("tod", 0)) if time_of_day < 0 else time_of_day
	tod = 2 if _lighting_mode == Catalog.SUNRISE else (0 if _lighting_mode == Catalog.SUNSET else clampi(_lighting_mode, 0, 2))
	_light_presets = [Catalog.lighting(def.weather, 0), Catalog.lighting(def.weather, 1), Catalog.lighting(def.weather, 2)]
	if changing_light():
		_light_presets[1].elev = 9.0
	wx = _light_presets[tod].duplicate()
	track.build_stage_route(def, wx.kind)
	var ep: Dictionary = def.get("elev", {})
	track.index_watercourses()
	if not track.rx:
		track.build_barriers(int(def["seed"]), def.get("barriers", []))
	track.terrain = Terrain.new()
	var bank_height: float = {"gorge": 8.5, "canyon": 6.4, "alpine": 7.2, "moor": 3.2, "autumn": 4.2, "pinewood": 2.6}.get(def["loc_id"], 0.0)
	track.terrain.build(track, float(ep.get("hills", 10.0)), int(def["seed"]) + 5, 1.0, bank_height, def["loc_id"] in ["meadow", "moor", "pinewood", "autumn"])
	if def.has("coast"):
		var cst: Dictionary = def["coast"]
		var lo := INF
		for e in track.elev:
			lo = minf(lo, e)
		track.terrain.make_coast(track, lo + float(cst["sea"]), float(cst["edge"]), bool(cst.get("beach", false)), int(def["seed"]) + 9)
		track.add_cliff_barriers()
	if not track.stacked_crossing.is_empty():
		var center: Vector2 = track.stacked_crossing.center
		track.terrain.flatten_disc(center, 14.5, track.road_h(track.stacked_crossing.lower) - 0.20, 11.0)
	if track.rx:
		track.terrain.conform_to_road(track)
	for br in track.bridges:
		if br.get("stacked", false):
			continue
		track.terrain.carve_river(br["a"], br["b"], br["water_y"], br.channel)
	for f in track.features:
		if f["type"] == "splash":
			var i: int = f["i"]
			var reach := track.nrm[i] * (track.width * 0.5 + 16.0)
			track.terrain.carve_river(track.pts[i] - reach, track.pts[i] + reach, f["water_y"], 3.6, 0.38, true)
	if not track.circuit:
		track.terrain.flatten_disc(parc_center(), 26.0, track.road_h_i(track.index_at(track.length - PARC_BACK)) - 0.1)
	_make_materials()
	_make_lights()
	helicopter = Helicopter.new()
	helicopter.name = "Helicopter"
	add_child(helicopter)
	helicopter.setup(track, paper_mat, tod > 0)
	var landmark: RegionalLandmark
	if def["loc_id"] in RegionalLandmark.REGIONS and not track.rx:
		landmark = RegionalLandmark.new()
		if landmark.build(def["loc_id"], track, paper_mat):
			add_child(landmark)
		else:
			landmark.free()
			landmark = null
	scenery = Scenery.new()
	scenery.name = "Scenery"
	scenery.landmark = landmark
	scenery.lights_on = changing_light() or bool(wx.headlights)
	scenery.lamp_level = 0.0 if tod == 0 else 1.0
	add_child(scenery)
	if def.loc_id in ["alpine", "gorge"]:
		_overhead_crossing()
	if def.loc_id == "alpine":
		_avalanche_gallery()
	_make_ground()
	_make_gorge_outcrops()
	_make_road()
	if track.rx:
		_rx_supports()
	_make_gantries()
	if track.rx:
		_make_rx_surfaces()
	scenery.setup(track, def, paper_mat, float(Settings.g("density")), float(Settings.g("draw_distance")), bool(Settings.g("popups")))
	_make_puddles()
	if track.circuit:
		_make_circuit_stands()
	else:
		_make_parc_ferme()
	_make_bridges()
	_make_switchback_tunnel()
	_make_hazards()
	_make_barriers()
	if Settings.fx_level() >= 1:
		_make_edge_banks()
		_make_sponsor_arches()
	if Settings.fx_level() >= 1:
		_make_markers()
	if track.rx:
		rx_props = RxProps.new()
		rx_props.name = "RallycrossProps"
		add_child(rx_props)
		rx_props.build(track, def, paper_mat, tod > 0 or changing_light())
		rx_props.set_lamp_level(_lamp_level)
		for sd: Array in rx_props.solids:
			var sp: Vector2 = sd[0]
			var cell := Vector2i(floori(sp.x / 8.0), floori(sp.y / 8.0))
			if not scenery.obstacles.has(cell):
				scenery.obstacles[cell] = []
			scenery.obstacles[cell].append([sp.x, sp.y, float(sd[1]), -1, false, "rx"])
	_make_weather()
	_make_ambient()
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
	apply_haze()
	if _particles:
		_particles.amount = maxi(16, int(_particles.get_meta("base_amount") * float(Settings.g("particles"))))
	if leaf_litter:
		var quality := float(Settings.g("particles"))
		var amount := roundi(lerpf(24.0, 75.0, quality))
		if _wind_leaves.amount != amount:
			_wind_leaves.amount = amount
		leaf_litter.configure(quality, float(Settings.g("draw_distance")))


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
	if not track.chapters.is_empty():
		var gorge: bool = def.loc_id == "gorge"
		ground_mat.set_shader_parameter("chapter_style", 2 if gorge else 1)
		if not gorge:
			ground_mat.set_shader_parameter("chapter_first", track.chapters[0].ink)
			ground_mat.set_shader_parameter("chapter_middle", track.chapters[1].ink)
			ground_mat.set_shader_parameter("chapter_last", track.chapters[2].ink)
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
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	_sky_mat = sky_mat
	sky_mat.set_shader_parameter("layers", Settings.fx_level() + 1)
	var stormy := kind() == "rain"
	sky_mat.set_shader_parameter("cover", 0.34 if stormy else 0.54)
	sky_mat.set_shader_parameter("storm", 1.0 if stormy else 0.0)
	var wind_dir := float(def.seed % 360) * PI / 180.0
	var wind_speed := 0.030 if stormy else 0.013
	sky_mat.set_shader_parameter("wind", Vector2(cos(wind_dir), sin(wind_dir)) * wind_speed)
	sky_mat.set_shader_parameter("peaks", def.loc_id in ["gorge", "alpine", "canyon"])
	sky_mat.set_shader_parameter("snowcaps", def.loc_id == "alpine")
	sky_mat.set_shader_parameter("offset", Vector2(float(def.seed % 197) / 197.0, float(def.loc) * 0.08))
	sky_mat.set_shader_parameter("paper_noise", noise_tex())
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	if changing_light():
		env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		env.sky.radiance_size = Sky.RADIANCE_SIZE_64

	key_light = DirectionalLight3D.new()
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.6
	key_light.shadow_bias = 0.04
	key_light.shadow_normal_bias = 1.2
	key_light.directional_shadow_max_distance = 70.0
	key_light.directional_shadow_fade_start = 0.85
	add_child(key_light)
	fill_light = DirectionalLight3D.new()
	fill_light.shadow_enabled = false
	add_child(fill_light)
	_apply_lighting(float(tod))


## How strongly street or track lamps light a spot on the ground (0 = not at all), for the cars passing under them.
func street_light_at(p: Vector2) -> float:
	var best := 0.0
	if rx_props:
		for q in rx_props.lamps:
			var d := p.distance_squared_to(q)
			if d < 100.0:
				best = maxf(best, 1.0 - sqrt(d) / 10.0)
	if scenery and scenery.lamp_level > 0.01:
		for q in scenery.lamp_positions():
			var d2 := p.distance_squared_to(q)
			if d2 < 64.0:
				best = maxf(best, (1.0 - sqrt(d2) / 8.0) * scenery.lamp_level)
	return best


## Rain at dusk or night: feed the nearest lamp heads to the road so they mirror in the wet surface.
func _update_wet_reflections(focus: Vector3) -> void:
	if kind() != "rain" or _lamp_level < 0.3 or Settings.fx_level() < 2:
		road_mat.set_shader_parameter("refl", 0.0)
		return
	if _head_cache.is_empty():
		if rx_props:
			_head_cache.append_array(rx_props.lamp_heads)
		if scenery:
			_head_cache.append_array(scenery.lamp_heads())
		if _head_cache.is_empty():
			_head_cache.append(Vector3(0, -1000, 0))
	var near: Array = []
	for h in _head_cache:
		var d := Vector2(h.x - focus.x, h.z - focus.z).length_squared()
		if d < 90000.0:
			near.append([d, h])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var pts := PackedVector3Array()
	for k in mini(8, near.size()):
		pts.append(near[k][1])
	var n := pts.size()
	while pts.size() < 8:
		pts.append(Vector3.ZERO)
	road_mat.set_shader_parameter("lamp_pts", pts)
	road_mat.set_shader_parameter("lamp_n", n)
	road_mat.set_shader_parameter("refl", _lamp_level if n > 0 else 0.0)


func changing_light() -> bool:
	return _lighting_mode in [Catalog.SUNRISE, Catalog.SUNSET]


## Advance the sky with completed course distance, so a retry starts at the
## same light and backing up or resetting cannot roll the sky back.
func advance_lighting(station: float) -> bool:
	if not changing_light():
		return false
	var progress := clampf(inverse_lerp(track.start_s, track.finish_s, station) / 0.94, 0.0, 1.0)
	var next := floorf(progress * 180.0) / 180.0
	if next <= _light_progress:
		return false
	_light_progress = next
	var journey := next * 2.0 if _lighting_mode == Catalog.SUNSET else (1.0 - next) * 2.0
	_apply_lighting(journey)
	return true


func _sky_colors(index: int) -> Array[Color]:
	var stormy := kind() == "rain"
	if index == 2:
		return [Color("#2c3a66"), Color("#070c24"), Color("#3a4468")]
	if index == 1:
		if stormy:
			return [Color("#c9967c"), Color("#5a5878"), Color("#7e7886")]
		return [Color("#f3a46c"), Color("#5f5c94"), Color("#b98a98")]
	match kind():
		"rain": return [Color("#aab6b6"), Color("#566878"), Color("#7e8b92")]
		"snow": return [Color("#e3e7ed"), Color("#8499b8"), Color("#f4f1ea")]
	return [Color("#f1dfc3"), Color("#5f93bf"), Color("#fff2d8")]


func _apply_lighting(phase: float) -> void:
	var lower := mini(floori(phase), 1)
	var mix_amount := smoothstep(0.0, 1.0, phase - lower)
	var left: Dictionary = _light_presets[lower]
	var right: Dictionary = _light_presets[lower + 1]
	for key: String in ["key", "fill", "amb", "leak", "vig_col", "tint"]:
		wx[key] = left[key].lerp(right[key], mix_amount)
	for key: String in ["key_e", "fill_e", "amb_e", "wrap", "glow", "vig", "contrast", "exposure", "sat", "green_pull"]:
		wx[key] = lerpf(left[key], right[key], mix_amount)

	var altitude := lerpf(left.elev, right.elev, mix_amount)
	var azimuth := lerpf(left.azim, right.azim, mix_amount)
	var sun := _sky_direction(altitude, azimuth)
	var darkness := smoothstep(1.0, 2.0, phase)
	var sky_mat := env.sky.sky_material as ShaderMaterial
	var warm := _sky_colors(lower)
	var cool := _sky_colors(lower + 1)
	var horizon := warm[0].lerp(cool[0], mix_amount)
	sky_mat.set_shader_parameter("horizon", horizon)
	sky_mat.set_shader_parameter("zenith", warm[1].lerp(cool[1], mix_amount))
	sky_mat.set_shader_parameter("cloud_ink", warm[2].lerp(cool[2], mix_amount))
	var glow := sin(clampf(phase, 0.0, 2.0) * PI * 0.5)
	var stormy := kind() == "rain"
	var zen: Color = warm[1].lerp(cool[1], mix_amount)
	var mid_col := horizon.lerp(zen, 0.45).lerp(Color("#d98a92"), glow * 0.55 * (0.35 if stormy else 1.0))
	sky_mat.set_shader_parameter("mid_ink", mid_col)
	paper_mat.set_shader_parameter("rim_color", horizon.lerp(Color.WHITE, 0.35))
	paper_mat.set_shader_parameter("glass_horizon", horizon)
	paper_mat.set_shader_parameter("glass_zenith", zen)
	paper_mat.set_shader_parameter("glass_night", darkness)
	sky_mat.set_shader_parameter("glow_amount", glow)
	sky_mat.set_shader_parameter("glow_ink", Color("#ffcf9a").lerp(Color("#ff6a38"), glow))
	sky_mat.set_shader_parameter("moon_ink", Color("#d4e0ff"))
	sky_mat.set_shader_parameter("light_dir", _sky_direction(lerpf(altitude - 10.0 * glow, -6.0, darkness), azimuth))
	sky_mat.set_shader_parameter("moon_dir", _sky_direction(_light_presets[2].elev, azimuth))
	sky_mat.set_shader_parameter("light_ink", Color("#fff2d1").lerp(Color("#ffa660"), smoothstep(0.0, 1.0, phase)))
	sky_mat.set_shader_parameter("night_amount", darkness)

	env.fog_light_color = horizon
	env.ambient_light_color = wx.amb
	env.ambient_light_energy = float(wx.amb_e) * 0.95
	key_light.basis = Basis.looking_at(-sun, Vector3.UP if absf(sun.y) < 0.99 else Vector3.FORWARD)
	key_light.light_color = wx.key
	key_light.light_energy = float(wx.key_e) * 0.6
	# Low sun: longer, softer, stronger shadows.
	var low_sun := 1.0 - smoothstep(10.0, 40.0, altitude)
	key_light.shadow_blur = lerpf(1.6, 3.4, low_sun) if Settings.fx_level() >= 1 else 1.6
	key_light.directional_shadow_max_distance = lerpf(70.0, 120.0, low_sun) if Settings.fx_level() >= 1 else 70.0
	fill_light.light_color = wx.fill
	fill_light.light_energy = float(wx.fill_e) * 1.7
	for material in [paper_mat, ground_mat, road_mat]:
		material.set_shader_parameter("leak", wx.leak)
		material.set_shader_parameter("wrap", wx.wrap)
	paper_mat.set_shader_parameter("glow", wx.glow)
	headlight_level = 0.34 * smoothstep(0.42, 1.0, phase) + 0.66 * darkness
	_lamp_level = smoothstep(0.45, 1.26, phase)
	if scenery:
		scenery.lamp_level = _lamp_level
	_sync_car_mat()
	if rx_props:
		rx_props.set_lamp_level(_lamp_level)


func _sky_direction(elevation: float, azimuth: float) -> Vector3:
	var el := deg_to_rad(elevation)
	var az := deg_to_rad(azimuth)
	return Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))


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
	var chunk := 60
	var i0 := 0
	var stack_start := -1
	var stack_end := -1
	if not track.stacked_crossing.is_empty():
		var middle: float = track.stacked_crossing.upper
		var half: float = track.stacked_crossing.half
		stack_start = track.index_at(middle-half)
		stack_end = track.index_at(middle+half)
	while i0 < n - 1:
		var i1 := mini(i0 + chunk, n - 1)
		if stack_start > i0 and stack_start < i1:
			i1 = stack_start
		elif i0 == stack_start:
			i1 = stack_end
		var v := PackedVector3Array()
		var nn := PackedVector3Array()
		var uv := PackedVector2Array()
		var col := PackedColorArray()
		var idx := PackedInt32Array()
		for i in range(i0, i1 + 1):
			var p := track.pts[i]
			var hw := track.road_half_width(track.dist[i])
			var l := p + track.nrm[i] * hw
			var r := p - track.nrm[i] * hw
			var vv := track.dist[i] / track.width
			var base := v.size()
			var hy = ROAD_Y + track.road_h_i(i)
			var slope = (track.road_h_i(mini(i + 1, n - 1)) - track.road_h_i(maxi(i - 1, 0))) / (2.0 * Track.STEP)
			var bank := track.bank_slope(i)
			var tilt := bank * hw   # banked roads rise on one edge and fall on the other
			var low = minf(track.elev[i] - 0.6, hy - absf(tilt) - 0.6)
			var tn := Vector3(-slope * track.tang[i].x - bank * track.nrm[i].x, 1.0, -slope * track.tang[i].y - bank * track.nrm[i].y).normalized()
			# top-left, top-right, then the side skirts (a built paper ramp where the road rises)
			v.append(Vector3(l.x, hy + tilt, l.y)); nn.append(tn); uv.append(Vector2(0, vv)); col.append(Color.WHITE)
			v.append(Vector3(r.x, hy - tilt, r.y)); nn.append(tn); uv.append(Vector2(1, vv)); col.append(Color.WHITE)
			var on := Vector3(track.nrm[i].x, 0, track.nrm[i].y)
			v.append(Vector3(l.x, hy + tilt, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(l.x, low, l.y)); nn.append(on); uv.append(Vector2(0, vv)); col.append(Color.BLACK)
			v.append(Vector3(r.x, hy - tilt, r.y)); nn.append(-on); uv.append(Vector2(1, vv)); col.append(Color.BLACK)
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
		if i0 == stack_start:
			_stacked_road = mi
		i0 = i1


func _quad_idx(idx: PackedInt32Array, v: PackedVector3Array, a: int, b: int, c: int, d: int, want: Vector3) -> void:
	var flip := (v[b] - v[a]).cross(v[c] - v[a]).dot(want) > 0.0
	if flip:
		idx.append_array([a, c, b, a, d, c])
	else:
		idx.append_array([a, b, c, a, c, d])


## Rallycross surface sectors (chalk, clay, granite ...) laid over the tarmac, the Joker lane and kerbs.
func _make_rx_surfaces() -> void:
	for pt in track.patches:
		if not pt.get("rx", false) or pt.kind == "tarmac":
			continue
		if pt.lat0 > 0.0 or pt.lat1 < 0.0:
			continue   # the Joker lane surface is drawn with the lane
		_surface_strip(float(pt.s0), float(pt.s1), Color(Rallycross.SURFACES[pt.kind].color), str(pt.kind))
		_surface_relief(float(pt.s0), float(pt.s1), Color(Rallycross.SURFACES[pt.kind].color), str(pt.kind))
	if not track.joker.is_empty():
		_make_joker_lane()
	_tarmac_wear()
	_make_kerbs()


## A coloured strip over the whole road width for one sector. The ends fade over a few metres, and
## two darker racing grooves run down it.
func _surface_strip(s0: float, s1: float, col: Color, kind: String) -> void:
	var tarmac := Color(Rallycross.SURFACES["tarmac"].color)
	var i0 := track.index_at(s0)
	var i1 := track.index_at(s1)
	var chunk := 40
	var i := i0
	while i < i1:
		var j := mini(i + chunk, i1)
		var b := PaperKit.Builder.new(i)
		for k in range(i, j):
			var d0 := minf(track.dist[k] - s0, s1 - track.dist[k])
			var d1 := minf(track.dist[k + 1] - s0, s1 - track.dist[k + 1])
			var c0 := tarmac.lerp(col, clampf(d0 / 4.0, 0.0, 1.0))
			var c1 := tarmac.lerp(col, clampf(d1 / 4.0, 0.0, 1.0))
			var cm := PaperKit.lin(c0.lerp(c1, 0.5), 1.0)
			var gm := PaperKit.lin(c0.lerp(c1, 0.5).darkened(0.09), 1.0)
			var hw0 := track.road_half_width(track.dist[k]) - 0.15
			var hw1 := track.road_half_width(track.dist[k + 1]) - 0.15
			# edge, groove, centre, groove, edge
			var stops := [-1.0, -0.42, -0.30, 0.30, 0.42, 1.0]
			var cols := [cm, gm, cm, gm, cm]
			for q in 5:
				var a0 := _road_point(k, stops[q] * hw0, 0.045)
				var a1 := _road_point(k + 1, stops[q] * hw1, 0.045)
				var b0 := _road_point(k, stops[q + 1] * hw0, 0.045)
				var b1 := _road_point(k + 1, stops[q + 1] * hw1, 0.045)
				b.quad(a0, a1, b1, b0, Vector3.UP, cols[q])
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i = j


## Snowbanks along both edges of snowy stages (and mud banks on wet ones): plain geometry, built in chunks that
## are hidden when far away.
func _make_edge_banks() -> void:
	if track.rx:
		return
	var snowy: bool = str(def.get("loc_id", "")) in ["alpine", "lakes", "taiga"] or kind() == "snow"
	var muddy: bool = kind() == "rain"
	if not snowy and not muddy:
		return
	var col := Color("#f3f4f8") if snowy else Color(def["pal"]["road"]).lerp(Color(def["pal"]["ground"]), 0.45).darkened(0.1)
	var shade := Color("#dfe5f1") if snowy else col.darkened(0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.seed) * 5 + 17
	var step := 2
	var i := track.index_at(track.start_s)
	var i_end := track.index_at(track.finish_s)
	var chunk := 36
	while i < i_end:
		var j := mini(i + chunk, i_end)
		var b := PaperKit.Builder.new(i)
		for k in range(i, j, step):
			var k2 := mini(k + step, j)
			var hw0 := track.road_half_width(track.dist[k])
			var hw1 := track.road_half_width(track.dist[k2])
			var h0 := (0.42 if snowy else 0.2) * (0.5 + 0.9 * absf(sin(track.dist[k] * 0.11 + float(def.seed))))
			var h1 := (0.42 if snowy else 0.2) * (0.5 + 0.9 * absf(sin(track.dist[k2] * 0.11 + float(def.seed))))
			for side: float in [-1.0, 1.0]:
				# Drifts follow the road, but give way where a barrier or bridge already stands.
				if not track.barriers_at(track.dist[k], side).is_empty() or not track.bridge_at(track.dist[k], 14).is_empty():
					continue
				var f0 := _road_point(k, side * (hw0 + 0.15), 0.03)
				var f1 := _road_point(k2, side * (hw1 + 0.15), 0.03)
				var c0 := _road_point(k, side * (hw0 + 0.9), 0.03 + h0)
				var c1 := _road_point(k2, side * (hw1 + 0.9), 0.03 + h1)
				var o0 := _road_point(k, side * (hw0 + 2.8), -0.05)
				var o1 := _road_point(k2, side * (hw1 + 2.8), -0.05)
				b.quad(f0, f1, c1, c0, Vector3.UP, PaperKit.lin(col, 1.0))
				b.quad(c0, c1, o1, o0, Vector3.UP, PaperKit.lin(shade, 1.0))
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 260.0
		add_child(mi)
		i = j


## Sponsor arches spanning the road (like the slot-car track arches): a black tyre-band arch with yellow side
## trim and the sponsor's name across the front. A few per stage, on straight clear stretches.
func _make_sponsor_arches() -> void:
	var want := 3
	var picked: Array = []
	var s := track.start_s + 90.0
	var cands: Array = []
	while s < track.finish_s - 60.0:
		var ok := track.bridge_at(s, 45).is_empty() and not track.on_stacked_span(s) and not track.on_stacked_span(s + 30.0)
		for f: Dictionary in track.features:
			if absf(float(f.get("s", -999.0)) - s) < 60.0:
				ok = false
		if ok and not track.joker.is_empty() and s > float(track.joker.s0) - 40.0 and s < float(track.joker.s1) + 40.0:
			ok = false
		if ok and track.rx and absf(fposmod(s, track.length)) < 120.0:
			ok = false
		if ok:
			var k := 0.0
			for off in range(-3, 4):
				k += absf(float(track.curv[track.index_at(s + off * 5.0)]))
			cands.append([k, s])
		s += 10.0
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for c: Array in cands:
		var far := true
		var cp := track.point_at(float(c[1]))
		for q: float in picked:
			var dq := absf(q - float(c[1]))
			if track.circuit:
				dq = minf(dq, track.length - dq)
			# Far apart along the lap and not close together on the map (a switchback can fold the road back).
			if dq < 220.0 or track.point_at(q).distance_to(cp) < 170.0:
				far = false
		if far:
			picked.append(float(c[1]))
		if picked.size() >= want:
			break
	var b := PaperKit.Builder.new(303)
	var n := 0
	arch_stations = picked.duplicate()
	for st: float in picked:
		var i := track.index_at(st)
		var hw := track.road_half_width(st) + 0.9
		var tan2 := track.tang[i]
		var base := track.pts[i]
		var nrm2 := track.nrm[i]
		var y0 := track.road_h_i(i)
		var height := 6.6
		var segs := 14
		var band := 1.5
		var depth := 1.1
		var black := PaperKit.lin(Color("#26262b"), 1.0)
		var black2 := PaperKit.lin(Color("#34343a"), 1.0)
		var night_arch := tod > 0 and ARCH_STYLE >= 1
		var yellow := PaperKit.lin(Color("#f2c630"), 0.0 if night_arch else 1.0)
		var fwd3 := Vector3(tan2.x, 0.0, tan2.y)
		var side3 := Vector3(nrm2.x, 0.0, nrm2.y)
		var base3 := Vector3(base.x, y0, base.y)
		for q in segs:
			var a0 := PI * float(q) / segs
			var a1 := PI * float(q + 1) / segs
			var o0 := base3 + side3 * cos(a0) * hw + Vector3(0, sin(a0) * height, 0)
			var o1 := base3 + side3 * cos(a1) * hw + Vector3(0, sin(a1) * height, 0)
			var i0 := base3 + side3 * cos(a0) * (hw - band) + Vector3(0, sin(a0) * (height - band), 0)
			var i1 := base3 + side3 * cos(a1) * (hw - band) + Vector3(0, sin(a1) * (height - band), 0)
			var df := fwd3 * depth * 0.5
			var col := black if q % 2 == 0 else black2
			# front and back faces, outer and inner surfaces
			b.quad(o0 + df, o1 + df, i1 + df, i0 + df, fwd3, col)
			b.quad(o1 - df, o0 - df, i0 - df, i1 - df, -fwd3, col)
			var am := (a0 + a1) * 0.5
			var up := (side3 * cos(am) + Vector3.UP * sin(am)).normalized()
			b.quad(o0 - df, o1 - df, o1 + df, o0 + df, up, col)
			b.quad(i1 - df, i0 - df, i0 + df, i1 + df, -up, col)
			# yellow trim fins along both edges of the outer face
			var fin := up * 0.12
			for sgn: float in [-1.0, 1.0]:
				var d2 := df * sgn
				b.quad(o0 + d2, o1 + d2, o1 + d2 + fin, o0 + d2 + fin, fwd3 * sgn, yellow)
		# feet
		for sx: float in [-1.0, 1.0]:
			b.box(base3 + side3 * sx * (hw - band * 0.5) + Vector3(0, 0.15, 0), Vector3(band + 0.4, 0.3, depth + 0.5), Transform3D(), Color("#1a1a1d"))
		var sp: Array = Pieces.SPONSORS[(n + int(def.seed)) % Pieces.SPONSORS.size()]
		var word := String(sp[0]).to_upper()
		var rxm := hw - band * 0.5
		var rym := height - band * 0.5
		# Letter widths (metres) so the word can be laid along the arch.
		var widths: Array = []
		var total := 0.0
		for ch in word:
			var wch := Pieces.text_width(String(ch), 72) * (0.0105 / 0.009) * 1.08 + 0.04
			widths.append(wch)
			total += wch
		for fb: float in [1.0, -1.0]:
			var dirn := 1.0 if fb > 0.0 else -1.0   # reading direction along increasing/decreasing angle
			var consumed := 0.0
			for li in word.length():
				var centre_o: float = consumed + float(widths[li]) * 0.5 - total * 0.5
				consumed += float(widths[li])
				# Angle at arc distance centre_o from the apex (small steps of the ellipse).
				var ang := PI * 0.5
				var rem := absf(centre_o)
				var sgn := 1.0 if centre_o >= 0.0 else -1.0
				while rem > 0.0:
					var dsda := sqrt(pow(rxm * sin(ang), 2.0) + pow(rym * cos(ang), 2.0))
					var stp := minf(rem, dsda * 0.02)
					ang += sgn * dirn * (stp / dsda)
					rem -= stp
				var lpos := base3 + side3 * cos(ang) * rxm + Vector3(0, sin(ang) * rym, 0)
				var tangent := (-side3 * sin(ang) * rxm + Vector3.UP * cos(ang) * rym).normalized() * dirn
				var zf := fwd3 * fb
				var xdir := tangent
				var ydir := zf.cross(xdir).normalized()
				var label := Label3D.new()
				label.text = String(word[li])
				label.font_size = 72
				label.pixel_size = 0.0105
				label.modulate = Color("#fff2c8") if night_arch else Color("#f4efe4")
				label.outline_size = 0
				label.double_sided = false
				label.shaded = false
				label.transform = Transform3D(Basis(xdir, ydir, zf), lpos + zf * (depth * 0.5 + 0.03))
				add_child(label)
		# Night lighting variants.
		if tod > 0 and ARCH_STYLE >= 1:
			var apex := base3 + Vector3(0, height - band * 0.5, 0)
			var warm := Color("#ffd9a0")
			if ARCH_STYLE == 1:
				var hz := LightHalo.make(warm, 4.5, 0.55)
				add_child(hz)
				hz.global_position = apex + fwd3 * 0.8
			elif ARCH_STYLE == 2:
				# LED strip under the arch (a row of glowing dots) and a pool of light on the road beneath.
				for q in 16:
					var aa := PI * (float(q) + 0.5) / 16.0
					var dot := LightHalo.make(Color("#ffe2a8"), 0.9, 0.9)
					add_child(dot)
					dot.global_position = base3 + side3 * cos(aa) * (hw - band) + Vector3(0, sin(aa) * (height - band) - 0.1, 0)
				var pool := LightHalo.street(Color("#ffd9a0"), height - band, hw * 0.75, 0.55)
				add_child(pool)
				pool.global_position = base3 + Vector3(0, height - band, 0)
			else:
				# Floodlit from the feet: a lamp each side throwing warm light up the arch.
				for sx: float in [-1.0, 1.0]:
					var foot := base3 + side3 * sx * (hw - band * 0.5) + fwd3 * 1.2 + Vector3(0, 0.3, 0)
					var lamp := OmniLight3D.new()
					lamp.light_color = warm
					lamp.light_energy = 2.2
					lamp.omni_range = height
					lamp.position = foot + Vector3(0, 0.6, 0)
					add_child(lamp)
					var gl := LightHalo.make(warm, 2.2, 0.9)
					add_child(gl)
					gl.global_position = foot
		n += 1
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Reflector posts close to the road edge, alternating sides every ~20 m: nearby fast-moving objects are what
## makes speed readable. (Circuits already have walls.)
func _make_markers() -> void:
	if track.rx:
		return
	var b := PaperKit.Builder.new(77)
	var cream := Color("#efe8d6")
	var red := Color("#c8553d")
	var chunk_start := 0
	var side := 1.0
	var s := track.start_s + 14.0
	var count := 0
	var meshes: Array = []
	while s < track.finish_s - 10.0:
		var i := track.index_at(s)
		if track.barriers_at(s, side).is_empty() and track.bridge_at(s, 10).is_empty() and not track.on_stacked_span(s):
			var p: Vector2 = track.pts[i] + track.nrm[i] * side * (track.road_half_width(s) + 1.1)
			var y := (track.terrain.height(p) if track.terrain else track.elev[i]) + 0.0
			var xf := Transform3D(Basis(Vector3.UP, track.heading_at(i)), Vector3(p.x, y, p.y))
			b.box(Vector3(0, 0.45, 0), Vector3(0.11, 0.9, 0.11), xf, cream)
			b.box(Vector3(0, 0.78, 0), Vector3(0.12, 0.16, 0.12), xf, red)
			b.box(Vector3(0, 0.9, 0), Vector3(0.09, 0.03, 0.09), xf, Color("#2b2b2e"))
			count += 1
			if count % 40 == 0:
				var mi := MeshInstance3D.new()
				mi.mesh = b.mesh()
				mi.material_override = paper_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 200.0
				add_child(mi)
				b = PaperKit.Builder.new(77 + count)
		side = -side
		s += 20.0
	var last := MeshInstance3D.new()
	last.mesh = b.mesh()
	last.material_override = paper_mat
	last.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	last.visibility_range_end = 200.0
	add_child(last)


var _wear: Array = []   # [lap needed, MeshInstance3D] grooves that darken as laps pass


## Circuits: the racing grooves in loose sectors get darker and wider lap by lap.
func set_lap_wear(lap: int) -> void:
	for w: Array in _wear:
		(w[1] as MeshInstance3D).visible = lap >= int(w[0])


## Cheap relief for loose sectors (no per-pixel work): loose berms along both shoulders, scattered stones and,
## on mud, dark puddles. It is all plain geometry in the one paper material.
func _surface_relief(s0: float, s1: float, col: Color, kind: String) -> void:
	if kind in ["tarmac", "ford"] or Settings.fx_level() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s0 * 7.0) + kind.hash()
	var b := PaperKit.Builder.new(int(s0) + 3)
	var i0 := track.index_at(s0)
	var i1 := track.index_at(s1)
	var light := PaperKit.lin(col.lightened(0.16), 1.0)
	var dark := PaperKit.lin(col.darkened(0.22), 1.0)
	var hmax: float = float({"sand": 0.045, "mud": 0.07, "snow": 0.16, "chalk": 0.07, "fine_gravel": 0.07}.get(kind, 0.09))
	for k in range(i0, i1):
		var d0 := minf(track.dist[k] - s0, s1 - track.dist[k])
		var d1 := minf(track.dist[k + 1] - s0, s1 - track.dist[k + 1])
		var f0 := clampf(d0 / 8.0, 0.0, 1.0)
		var f1 := clampf(d1 / 8.0, 0.0, 1.0)
		var hw0 := track.road_half_width(track.dist[k]) - 0.15
		var hw1 := track.road_half_width(track.dist[k + 1]) - 0.15
		# A berm that wanders a little in height, so it reads as heaped loose material.
		var w0 := 0.7 + 0.5 * absf(sin(track.dist[k] * 0.37 + s0))
		var w1 := 0.7 + 0.5 * absf(sin(track.dist[k + 1] * 0.37 + s0))
		for side: float in [-1.0, 1.0]:
			var a0 := _road_point(k, side * hw0 * 0.78, 0.045)
			var a1 := _road_point(k + 1, side * hw1 * 0.78, 0.045)
			var c0 := _road_point(k, side * hw0 * 0.88, 0.045 + hmax * f0 * w0)
			var c1 := _road_point(k + 1, side * hw1 * 0.88, 0.045 + hmax * f1 * w1)
			var e0 := _road_point(k, side * hw0 * 0.99, 0.045)
			var e1 := _road_point(k + 1, side * hw1 * 0.99, 0.045)
			b.quad(a0, a1, c1, c0, Vector3.UP, light)
			b.quad(c0, c1, e1, e0, Vector3.UP, dark)
	# Deep ruts in mud and snow: a raised lip along each side of both wheel tracks, and (on circuits) darker
	# worn grooves that appear as laps pass.
	if kind in ["mud", "snow"]:
		var lip_col := PaperKit.lin(col.darkened(0.1) if kind == "mud" else col.lightened(0.04), 1.0)
		var rut_wear := [PaperKit.Builder.new(int(s0) + 9), PaperKit.Builder.new(int(s0) + 10)]
		for k in range(i0, i1):
			var fk0 := clampf(minf(track.dist[k] - s0, s1 - track.dist[k]) / 6.0, 0.0, 1.0)
			var fk1 := clampf(minf(track.dist[k + 1] - s0, s1 - track.dist[k + 1]) / 6.0, 0.0, 1.0)
			var hwk0 := track.road_half_width(track.dist[k]) - 0.15
			var hwk1 := track.road_half_width(track.dist[k + 1]) - 0.15
			for rut: float in [-0.37, 0.37]:
				for edge: float in [-0.3, 0.3]:
					var la0 := rut * hwk0 + edge
					var la1 := rut * hwk1 + edge
					var lip_h := 0.055 * fk0
					var lip_h2 := 0.055 * fk1
					var q0 := _road_point(k, la0 - 0.09, 0.045)
					var q1 := _road_point(k + 1, la1 - 0.09, 0.045)
					var q2 := _road_point(k + 1, la1, 0.045 + lip_h2)
					var q3 := _road_point(k, la0, 0.045 + lip_h)
					var q4 := _road_point(k + 1, la1 + 0.09, 0.045)
					var q5 := _road_point(k, la0 + 0.09, 0.045)
					b.quad(q0, q1, q2, q3, Vector3.UP, lip_col)
					b.quad(q3, q2, q4, q5, Vector3.UP, lip_col)
				if track.circuit:
					for lvl in 2:
						var wb: PaperKit.Builder = rut_wear[lvl]
						var wd := 0.32 + 0.12 * lvl
						var w0 := rut * hwk0
						var w1 := rut * hwk1
						var dark_w := PaperKit.lin(col.darkened(0.38), 1.0)
						wb.quad(_road_point(k, w0 - wd, 0.049), _road_point(k + 1, w1 - wd, 0.049),
							_road_point(k + 1, w1 + wd, 0.049), _road_point(k, w0 + wd, 0.049), Vector3.UP, dark_w)
		if track.circuit:
			for lvl in 2:
				var wm := MeshInstance3D.new()
				wm.mesh = (rut_wear[lvl] as PaperKit.Builder).mesh()
				wm.material_override = paper_mat
				wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wm.visible = false
				add_child(wm)
				_wear.append([2 if lvl == 0 else 4, wm])
	# Stones and clods, gathering toward the shoulders where tyres throw them.
	var s := s0 + 3.0
	while s < s1 - 3.0 and kind != "snow":
		var i := track.index_at(s)
		var hw := track.road_half_width(s) - 0.3
		for q in 4:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lat := side * hw * lerpf(0.15, 0.97, pow(rng.randf(), 0.55))
			var size := rng.randf_range(0.09, 0.26)
			var pos := _road_point(i, lat, 0.045 + size * 0.3)
			var tone := col.darkened(rng.randf_range(-0.1, 0.35))
			b.box(Vector3.ZERO, Vector3(size * rng.randf_range(0.8, 1.5), size * 0.6, size * rng.randf_range(0.8, 1.4)),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos), tone)
		s += 2.6
	if kind == "mud":
		var sp := s0 + 6.0
		while sp < s1 - 8.0:
			var im := track.index_at(sp)
			var lat_m := rng.randf_range(-0.6, 0.6) * (track.road_half_width(sp) - 1.0)
			var len_m := rng.randf_range(3.0, 7.0)
			var wid := rng.randf_range(1.0, 2.4)
			var pud := PaperKit.lin(col.darkened(0.38), 1.0)
			var p00 := _road_point(im, lat_m - wid * 0.5, 0.05)
			var p01 := _road_point(im, lat_m + wid * 0.5, 0.05)
			var im2 := track.index_at(sp + len_m)
			var p10 := _road_point(im2, lat_m - wid * 0.5, 0.05)
			var p11 := _road_point(im2, lat_m + wid * 0.5, 0.05)
			b.quad(p00, p10, p11, p01, Vector3.UP, pud)
			sp += rng.randf_range(10.0, 22.0)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Tarmac wear: darker repair patches and thin cracks scattered round the lap (geometry only).
func _tarmac_wear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.seed) * 13 + 5
	var b := PaperKit.Builder.new(41)
	var patch_col := PaperKit.lin(Color(Rallycross.SURFACES["tarmac"].color).darkened(0.05), 1.0)
	var crack_col := PaperKit.lin(Color(Rallycross.SURFACES["tarmac"].color).darkened(0.38), 1.0)
	var s := 24.0
	while s < track.length - 24.0:
		var pt: Dictionary = track.patch_at(s, 0.0)
		var tarmac_here: bool = pt.is_empty() or str(pt.get("kind", "tarmac")) == "tarmac"
		if tarmac_here and not track.on_stacked_span(s):
			var i := track.index_at(s)
			var hw := track.road_half_width(s) - 1.0
			if false:
				var lat := rng.randf_range(-0.7, 0.7) * hw
				var len_p := rng.randf_range(2.5, 6.0)
				var wid := rng.randf_range(1.6, 3.4)
				var i2 := track.index_at(s + len_p)
				b.quad(_road_point(i, lat - wid * 0.5, 0.036), _road_point(i2, lat - wid * 0.5, 0.036),
					_road_point(i2, lat + wid * 0.5, 0.036), _road_point(i, lat + wid * 0.5, 0.036), Vector3.UP, patch_col)
			if rng.randf() < 0.5:
				# A crack: a short zig-zag of thin strips.
				var lat_c := rng.randf_range(-0.8, 0.8) * hw
				var step_c := rng.randf_range(0.5, 1.1)
				var cur := lat_c
				var ss := s
				for seg in 5:
					var nxt := cur + rng.randf_range(-0.6, 0.6)
					var ia := track.index_at(ss)
					var ib := track.index_at(ss + step_c)
					b.quad(_road_point(ia, cur - 0.02, 0.037), _road_point(ib, nxt - 0.02, 0.037),
						_road_point(ib, nxt + 0.02, 0.037), _road_point(ia, cur + 0.02, 0.037), Vector3.UP, crack_col)
					cur = nxt
					ss += step_c
		s += rng.randf_range(12.0, 30.0)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## World point at a lateral offset from the centre line, following altitude and banking.
func _road_point(i: int, lat: float, lift: float) -> Vector3:
	var p := track.pts[i] + track.nrm[i] * lat
	return Vector3(p.x, ROAD_Y + track.road_h_i(i) + lat * track.bank_slope(i) + lift, p.y)


## The Joker lane: its own paper road beside the main one, with skirts down to the ground.
func _make_joker_lane() -> void:
	var jk := track.joker
	var col := Color(Rallycross.SURFACES[jk.surf].color)
	var side_col := PaperKit.lin(col.darkened(0.45), 1.0)
	var top := PaperKit.lin(col, 1.0)
	var groove := PaperKit.lin(col.darkened(0.09), 1.0)
	var b := PaperKit.Builder.new(91)
	for k in range(int(jk.i0), int(jk.i1)):
		var band0 := track.joker_band(track.dist[k])
		var band1 := track.joker_band(track.dist[k + 1])
		if is_nan(band0.x) or is_nan(band1.x):
			continue
		var stops := [0.0, 0.33, 0.45, 0.55, 0.67, 1.0]
		for q in 5:
			var cq := top if q % 2 == 0 else groove
			var a0 := _road_point(k, lerpf(band0.x, band0.y, stops[q]), 0.0)
			var a1 := _road_point(k + 1, lerpf(band1.x, band1.y, stops[q]), 0.0)
			var b0 := _road_point(k, lerpf(band0.x, band0.y, stops[q + 1]), 0.0)
			var b1 := _road_point(k + 1, lerpf(band1.x, band1.y, stops[q + 1]), 0.0)
			b.quad(a0, a1, b1, b0, Vector3.UP, cq)
		# Skirts on both lane edges.
		for edge in [0, 1]:
			var e0 := band0.x if edge == 0 else band0.y
			var e1 := band1.x if edge == 0 else band1.y
			var t0 := _road_point(k, e0, 0.0)
			var t1 := _road_point(k + 1, e1, 0.0)
			var low0 := Vector3(t0.x, t0.y - 0.7, t0.z)
			var low1 := Vector3(t1.x, t1.y - 0.7, t1.z)
			var outward := track.nrm[k] * (1.0 if edge == 1 else -1.0)
			b.quad(t0, t1, low1, low0, Vector3(outward.x, 0, outward.y), side_col)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Rumble strips on the inside of the marked corners: raised, domed red and white blocks with their own
## end faces and a darker edge, standing proud of the tarmac like real rumble kerbs.
func _make_kerbs() -> void:
	var b := PaperKit.Builder.new(33)
	var made := false
	for range_f: Array in def.rx.get("kerbs", []):
		var s0 := float(range_f[0]) * track.length
		var s1 := float(range_f[1]) * track.length
		var k := s0
		var n := 0
		while k < s1:
			var i := track.index_at(k)
			var i2 := track.index_at(k + 2.0)
			var base := Color("#c8553d") if n % 2 == 0 else PaperKit.CREAM
			var top := PaperKit.lin(base, 1.0)
			var face := PaperKit.lin(base.darkened(0.22), 1.0)
			for side in [-1.0, 1.0]:
				var hw := track.road_half_width(k)
				var hw2 := track.road_half_width(k + 2.0)
				# Profile across the strip: flush at the inner edge, a ridge in the middle, a lower rounded lip outside.
				var offs := [1.15, 0.65, 0.12]
				var lifts := [0.02, 0.14, 0.07]
				var p0: Array[Vector3] = []
				var p1: Array[Vector3] = []
				for q in 3:
					p0.append(_road_point(i, side * (hw - offs[q]), lifts[q]))
					p1.append(_road_point(i2, side * (hw2 - offs[q]), lifts[q]))
				# Two sloped top faces (inner flank and outer flank).
				b.quad(p0[0], p1[0], p1[1], p0[1], Vector3.UP, top)
				b.quad(p0[1], p1[1], p1[2], p0[2], Vector3.UP, top)
				# Outer lip face down to the road, and the two end faces that give each block its depth.
				var down0 := _road_point(i, side * (hw - offs[2]), 0.0)
				var down1 := _road_point(i2, side * (hw2 - offs[2]), 0.0)
				b.quad(p0[2], p1[2], down1, down0, Vector3(side, 0, 0), face)
				var inner0 := _road_point(i, side * (hw - offs[0]), 0.0)
				var mid0 := _road_point(i, side * (hw - offs[1]), 0.0)
				var inner1 := _road_point(i2, side * (hw2 - offs[0]), 0.0)
				var mid1 := _road_point(i2, side * (hw2 - offs[1]), 0.0)
				b.quad(inner0, p0[0], p0[1], mid0, Vector3(0, 0, -1), face)
				b.quad(mid0, p0[1], p0[2], down0, Vector3(0, 0, -1), face)
				b.quad(p1[0], inner1, mid1, p1[1], Vector3(0, 0, 1), face)
				b.quad(p1[1], mid1, down1, p1[2], Vector3(0, 0, 1), face)
				made = true
			k += 2.0
			n += 1
	if made:
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _make_gantries() -> void:
	if track.rx:
		return   # circuits have their own braced start gantry (RxProps); a second arch would double up
	var timing_lines := [[track.start_s, false]] if track.circuit else [[track.start_s, false], [track.finish_s, true]]
	for pair in timing_lines:
		var s: float = pair[0]
		var i := track.index_at(s)
		var p := track.pts[i]
		var mi := MeshInstance3D.new()
		mi.mesh = Pieces.arch(track.road_half_width(s) * 2.0 + 1.4, pair[1])
		mi.material_override = paper_mat
		mi.position = Vector3(p.x, track.elev[i], p.y)
		mi.rotation.y = track.heading_at(i)
		add_child(mi)
		_marshal_post(s, "finish" if pair[1] else "start")
		# Painted line across the road.
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(track.road_half_width(s) * 2.0, 0.01, 0.5)
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
		var rng := RandomNumberGenerator.new()
		rng.seed = int(def.seed) + i
		for row in 3:
			var approach := s + (row+1)*6.0 * (-1.0 if pair[1] else 1.0)
			var j := track.index_at(approach)
			for side: float in [-1,1]:
				var xy := track.pts[j] + track.nrm[j]*side*(track.width*0.5+1.4)
				if not track.terrain.supports_prop(xy, 1.0):
					continue
				var flag := MeshInstance3D.new()
				flag.mesh = Pieces.feather_flag(rng).mesh
				flag.material_override = paper_mat
				flag.position = Vector3(xy.x, track.terrain.height(xy), xy.y)
				flag.rotation.y = track.heading_at(j) + PI
				add_child(flag)
		var j := track.index_at(s + (-30 if pair[1] else 30))
		var portal := MeshInstance3D.new()
		portal.mesh = Pieces.split_gantry(track.width+4.0)
		portal.position = Vector3(track.pts[j].x,track.road_h_i(j),track.pts[j].y)
		portal.rotation.y = track.heading_at(j)
		portal.material_override = paper_mat
		add_child(portal)
		var sponsor := Label3D.new()
		sponsor.text = "Polyform Studio" if pair[1] else "Paper Rally"
		sponsor.font_size = 64
		sponsor.pixel_size = 0.011
		sponsor.position = Vector3(0,4.5,-0.18)
		sponsor.rotation.y = PI
		portal.add_child(sponsor)
	# Intermediate split banners on clear sections of the organised road rallies.
	if def["loc_id"] in ["meadow", "harbour", "alpine", "autumn"]:
		for fraction: float in [0.34, 0.69]:
			var split := track.length * fraction
			for attempt in 16:
				var idx := track.index_at(split)
				var at := track.pts[idx]
				if track.bridge_at(split, 20).is_empty() and not track.overlaps_water(at, track.width) and absf(track.heights[idx]) < 0.1 and track.feature_at(split, "chicane", 20).is_empty():
					var gantry := MeshInstance3D.new()
					gantry.mesh = Pieces.split_gantry(track.width + 4.0)
					gantry.material_override = paper_mat
					gantry.position = Vector3(at.x, track.road_h_i(idx), at.y)
					gantry.rotation.y = track.heading_at(idx)
					add_child(gantry)
					var sign_text := Label3D.new()
					sign_text.text = "SPLIT  1" if fraction < 0.5 else "SPLIT  2"
					sign_text.font_size = 64
					sign_text.pixel_size = 0.011
					sign_text.modulate = PaperKit.CREAM
					sign_text.outline_size = 0
					sign_text.position = Vector3(0, 4.5, -0.18)
					sign_text.rotation.y = PI
					gantry.add_child(sign_text)
					_marshal_post(split,"split")
					break
				split += 10.0


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
		var tangent := track.tang[track.index_at(ps)]
		var slope := (track.road_h(ps + 1.0) - track.road_h(ps - 1.0)) * 0.5
		var normal := Vector3(-tangent.x * slope, 1.0, -tangent.y * slope).normalized()
		mi.basis = Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf() * TAU)
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
		var i: int = f.get("i", track.index_at(f["s"]))
		var p := track.pts[i]
		var hd := track.heading_at(i)
		match f["type"]:
			"splash":
				var wl := track.width * 0.5 + 16.0
				var stream := _water_sheet(wl * 2.0, 3.6, Color("#7895a4"), i, track.width * 0.5)
				stream.position = Vector3(p.x, float(f["water_y"]), p.y)
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
						var q = track.pts[j] + track.nrm[j] * side * (track.road_half_width(s_off) - 0.15)
						var post := MeshInstance3D.new()
						var bm := BoxMesh.new()
						bm.size = Vector3(0.18, h, 0.18)
						post.mesh = bm
						post.material_override = _flat_mat(Color("#6a4a32"))
						bm.size = Vector3(0.18, h + 0.6, 0.18)
						post.position = Vector3(q.x, track.elev[j] - 0.6 + (h + 0.6) * 0.5, q.y)
						add_child(post)
	for pt in track.patches:
		if pt.get("rx", false):
			continue   # rallycross sectors are drawn by _make_rx_surfaces
		var b := PaperKit.Builder.new(rng.randi())
		var len_s: float = float(pt["s1"]) - float(pt["s0"])
		var col: Color = {"gravel": Color(def["pal"]["road"]).lightened(0.18), "mud": Color("#86694c"), "ice": Color("#c9dcea"), "deep snow": Color("#f4f5f8")}[pt["kind"]]
		# Follow the very same longitudinal and lateral limits used by patch_at.
		var steps := maxi(2,ceili(len_s/2.0))
		var prev := PackedVector3Array()
		for k in steps+1:
			var sm := lerpf(pt.s0,pt.s1,k/float(steps))
			var n := track.nrm[track.index_at(sm)]
			var line := PackedVector3Array()
			for lat: float in [pt.lat0,pt.lat1]:
				var xy := track.point_at(sm)+n*lat
				line.append(Vector3(xy.x,track.road_h(sm)+ROAD_Y+0.027,xy.y))
			if k:
				var ink := PaperKit.lin(col.lightened(0.018*(k%3)))
				b.quad(prev[0],line[0],line[1],prev[1],Vector3.UP,ink)
				if pt.kind == "mud":
					for rut: float in [0.30,0.68]:
						var r0 := prev[0].lerp(prev[1],rut)+Vector3.UP*0.008
						var r1 := line[0].lerp(line[1],rut)+Vector3.UP*0.008
						var width := Vector3(n.x,0,n.y)*0.11
						b.quad(r0-width,r1-width,r1+width,r0+width,Vector3.UP,PaperKit.lin(Color("#715640")))
				if pt.kind == "ice" and k%4 == 2:
					var a := prev[0].lerp(prev[1],0.27)+Vector3.UP*0.009
					var z := line[0].lerp(line[1],0.46)+Vector3.UP*0.009
					var slim := Vector3(n.x,0,n.y)*0.045
					b.quad(a-slim,a+slim,z+slim,z-slim,Vector3.UP,PaperKit.lin(Color("#e0ebee")))
			prev = line
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var relief_kind: String = {"gravel": "fine_gravel", "mud": "mud", "deep snow": "snow"}.get(str(pt["kind"]), "")
		if relief_kind != "":
			_surface_relief(float(pt["s0"]), float(pt["s1"]), col, relief_kind)


const BARRIER_LAT := 0.75   # metres outside the road edge


## Armco (galvanised paper strip with a pressed groove on stubby posts) and post-and-rail fences.
func _make_barriers() -> void:
	var shadow_b := PaperKit.Builder.new(5)
	var board_b := PaperKit.Builder.new(6)
	var board_count := 0
	var next_board := 0.0
	for bar in track.barriers:
		next_board = float(bar["s0"]) + 14.0
		var s0: float = bar["s0"]
		var s1: float = bar["s1"]
		var side: float = bar["side"]
		if bar["kind"] in ["parapet", "tunnel"]:
			continue   # drawn with its bridge
		var kind: String = bar["kind"]
		var armco: bool = kind == "armco"
		var s := s0
		while s < s1:
			var s_end := minf(s + 60.0, s1)
			var b := PaperKit.Builder.new(int(s))
			var step := 2.0 if not (kind in ["tyre", "jersey", "island"]) else 3.0
			var k := s
			var post_every := 4.0 if armco else 3.0
			var next_post := k
			while k < s_end:
				var k2 := minf(k + step, s_end)
				var i0 := track.index_at(k)
				var i1 := track.index_at(k2)
				var p0 := track.pts[i0] + track.nrm[i0] * side * track.barrier_wall(bar, k)
				var p1 := track.pts[i1] + track.nrm[i1] * side * track.barrier_wall(bar, k2)
				var y0 := track.elev[i0] - 0.1 + track.bank_slope(i0) * side * track.barrier_wall(bar, k)
				var y1 := track.elev[i1] - 0.1 + track.bank_slope(i1) * side * track.barrier_wall(bar, k2)
				if kind == "wall":
					_stone_wall(b, p0, p1, y0, y1, track.nrm[i0] * side, k)
				elif kind in ["tyre", "jersey", "island", "hay"]:
					_rx_wall(b, kind, p0, p1, y0, y1, track.nrm[i0] * side, int(k / step))
					# Soft contact shadow on the road in front of the wall.
					var toward := -track.nrm[i0] * side
					var toward1 := -track.nrm[i1] * side
					var w_in := 0.35
					var w_out := 2.0 if kind != "hay" else 1.4
					var dark := Color(0.08, 0.06, 0.09, 0.62)
					var clear := Color(0.08, 0.06, 0.09, 0.0)
					var lift := 0.06
					shadow_b.quad4(
						Vector3(p0.x + toward.x * w_in, y0 + 0.1 + lift, p0.y + toward.y * w_in),
						Vector3(p1.x + toward1.x * w_in, y1 + 0.1 + lift, p1.y + toward1.y * w_in),
						Vector3(p1.x + toward1.x * w_out, y1 + 0.1 + lift, p1.y + toward1.y * w_out),
						Vector3(p0.x + toward.x * w_out, y0 + 0.1 + lift, p0.y + toward.y * w_out),
						Vector3.UP, dark, dark, clear, clear)
					# Sponsor boards on long straight runs.
					if kind in ["tyre", "jersey"] and k >= next_board and board_count < 70:
						var ahead := track.index_at(minf(k + 12.0, s1))
						var behind := track.index_at(maxf(k - 12.0, s0))
						if absf(wrapf(track.heading_at(ahead) - track.heading_at(behind), -PI, PI)) < 0.05 and s1 - s0 > 60.0:
							var sp: Array = Pieces.SPONSORS[(board_count + int(side) + 3) % Pieces.SPONSORS.size()]
							var mid := (p0 + p1) * 0.5
							var face := 0.5 if kind == "tyre" else 0.36
							var bc := Vector3(mid.x + toward.x * (face + 0.04), (y0 + y1) * 0.5 + (0.55 if kind == "tyre" else 0.5), mid.y + toward.y * (face + 0.04))
							_sponsor_board(board_b, bc, Vector2(toward.x, toward.y), sp, 0.72 if kind == "tyre" else 0.6)
							board_count += 1
							next_board = k + 30.0
				elif armco:
					var lo := 0.42
					var hi := 0.78
					b.slab(Vector3(p0.x, y0 + hi, p0.y), Vector3(p1.x, y1 + hi, p1.y), Vector3(p1.x, y1 + lo, p1.y), Vector3(p0.x, y0 + lo, p0.y), 0.06, Color("#b4b8bb"))
					var o := track.nrm[i0] * -side * 0.04
					b.slab(Vector3(p0.x + o.x, y0 + 0.61, p0.y + o.y), Vector3(p1.x + o.x, y1 + 0.61, p1.y + o.y), Vector3(p1.x + o.x, y1 + 0.57, p1.y + o.y), Vector3(p0.x + o.x, y0 + 0.57, p0.y + o.y), 0.02, Color("#7d8286"))
				else:
					for rh in [0.45, 0.95]:
						b.slab(Vector3(p0.x, y0 + rh + 0.09, p0.y), Vector3(p1.x, y1 + rh + 0.09, p1.y), Vector3(p1.x, y1 + rh - 0.04, p1.y), Vector3(p0.x, y0 + rh - 0.04, p0.y), 0.06, Color("#9a7552"))
				if kind in ["armco", "fence"] and k >= next_board and board_count < 70 and s1 - s0 > 80.0:
					var ahead2 := track.index_at(minf(k + 12.0, s1))
					var behind2 := track.index_at(maxf(k - 12.0, s0))
					if absf(wrapf(track.heading_at(ahead2) - track.heading_at(behind2), -PI, PI)) < 0.04:
						var sp2: Array = Pieces.SPONSORS[(board_count + int(side) + 1) % Pieces.SPONSORS.size()]
						var mid2 := (p0 + p1) * 0.5
						var tw2 := -track.nrm[i0] * side
						var bc2 := Vector3(mid2.x + tw2.x * 0.16, (y0 + y1) * 0.5 + (0.6 if kind == "armco" else 0.72), mid2.y + tw2.y * 0.16)
						_sponsor_board(board_b, bc2, Vector2(tw2.x, tw2.y), sp2, 0.5 if kind == "armco" else 0.62)
						board_count += 1
						next_board = k + 36.0
				if k >= next_post and (kind == "armco" or kind == "fence"):
					var ph := 0.85 if armco else 1.15
					var pc := Color("#6d7174") if armco else Color("#6e5038")
					var pp := p0 + track.nrm[i0] * side * 0.08
					b.box(Vector3(pp.x, y0 + ph * 0.5 - 0.2, pp.y), Vector3(0.14, ph + 0.4, 0.14), Transform3D(), pc)
					next_post += post_every
				k = k2
			var mi := MeshInstance3D.new()
			mi.mesh = b.mesh()
			mi.material_override = paper_mat
			mi.position = Vector3.ZERO
			add_child(mi)
			s = s_end

	var smi := MeshInstance3D.new()
	smi.mesh = shadow_b.mesh()
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	smi.material_override = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)
	var bmi := MeshInstance3D.new()
	bmi.mesh = board_b.mesh()
	bmi.material_override = paper_mat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)


## A sponsor board hung on a barrier: a printed card facing the road with its name on it.
func _sponsor_board(b: PaperKit.Builder, centre: Vector3, toward: Vector2, sp: Array, height: float) -> void:
	var n3 := Vector3(toward.x, 0.0, toward.y).normalized()
	if debug_board.is_empty():
		debug_board = [centre, n3]
	var right := Vector3.UP.cross(n3).normalized()
	var width := clampf(Pieces.text_width(sp[0], 64) + 0.5, 2.2, 3.6)
	var basis := Basis(right, Vector3.UP, n3)
	var xf := Transform3D(basis, centre)
	b.card(PaperKit.rrect(width, height, 0.04, 0, -height * 0.5), xf, Color(sp[1]), {"thick": 0.04, "edge": 0.03, "lip": 0.0, "glow": tod > 0})
	var label := Label3D.new()
	label.text = String(sp[0])
	label.font_size = 64
	label.pixel_size = height * 0.5 / 64.0
	label.modulate = Color(sp[2])
	label.outline_size = 0
	label.double_sided = false
	label.transform = Transform3D(basis, centre + n3 * 0.05)
	add_child(label)



## Rallycross edge walls: belted tyre stacks, FIA concrete with a catch fence, foam blocks, hay.
func _rx_wall(b: PaperKit.Builder, kind: String, p0: Vector2, p1: Vector2, y0: float, y1: float, out: Vector2, n: int) -> void:
	var dir := p1 - p0
	var seg := dir.length()
	if seg < 0.01:
		return
	var yaw := atan2(dir.x, dir.y)
	var frame := Transform3D(Basis(Vector3.UP, yaw), Vector3((p0.x + p1.x) * 0.5, (y0 + y1) * 0.5, (p0.y + p1.y) * 0.5))
	match kind:
		"tyre":
			# Stacks of three painted tyres, red and white in turn, standing side by side along the wall.
			b.box(Vector3(0, 0.47, 0), Vector3(0.62, 0.94, seg + 0.02), frame, Color("#26262a"))
			var stacks := maxi(1, roundi(seg / 0.95))
			var pitch := seg / float(stacks)
			var sides := 8
			var big := 0.46
			var small := 0.22
			var dark := PaperKit.lin(Color("#1c1c1f"), 1.0)
			var bas := frame.basis
			for k in stacks:
				var z := -seg * 0.5 + pitch * (k + 0.5)
				var paint := Color("#c93a30") if (n * 3 + k) % 2 == 0 else Color("#eee8dc")
				for t in 3:
					var y_lo := 0.01 + t * 0.33
					var y_hi := y_lo + 0.32
					var col := PaperKit.lin(paint if t != 1 else paint.darkened(0.14), 1.0)
					for q in sides:
						var a0 := TAU * float(q) / sides
						var a1 := TAU * float(q + 1) / sides
						var am := (a0 + a1) * 0.5
						var o0 := Vector3(cos(a0) * big, 0, z + sin(a0) * big)
						var o1 := Vector3(cos(a1) * big, 0, z + sin(a1) * big)
						var nrm := bas * Vector3(cos(am), 0, sin(am))
						b.quad(frame * (o1 + Vector3(0, y_lo, 0)), frame * (o0 + Vector3(0, y_lo, 0)), frame * (o0 + Vector3(0, y_hi, 0)), frame * (o1 + Vector3(0, y_hi, 0)), nrm, col)
				# Top face of the stack is a ring, with the hole running down through it.
				for q in sides:
					var a0 := TAU * float(q) / sides
					var a1 := TAU * float(q + 1) / sides
					var am := (a0 + a1) * 0.5
					var o0 := Vector3(cos(a0) * big, 0.99, z + sin(a0) * big)
					var o1 := Vector3(cos(a1) * big, 0.99, z + sin(a1) * big)
					var i0 := Vector3(cos(a0) * small, 0.99, z + sin(a0) * small)
					var i1 := Vector3(cos(a1) * small, 0.99, z + sin(a1) * small)
					b.quad(frame * o1, frame * i1, frame * i0, frame * o0, bas * Vector3.UP, PaperKit.lin(paint.lightened(0.05), 1.0))
					b.quad(frame * i0, frame * i1, frame * (i1 - Vector3(0, 0.99, 0)), frame * (i0 - Vector3(0, 0.99, 0)), bas * Vector3(-cos(am), 0, -sin(am)), dark)
		"jersey":
			b.box(Vector3(0, 0.50, 0), Vector3(0.55, 1.0, seg + 0.02), frame, Color("#bfbab0"), Color("#d0cbc0"))
			b.box(Vector3(0, 0.12, 0), Vector3(0.75, 0.24, seg + 0.02), frame, Color("#aaa59b"))
			# Catch fence on posts above the block.
			if n % 2 == 0:
				b.box(Vector3(0, 1.75, 0), Vector3(0.07, 1.5, 0.07), frame, Color("#5a5d62"))
			b.box(Vector3(0, 2.2, 0), Vector3(0.04, 0.5, seg), frame, Color("#8d9298"))
			b.box(Vector3(0, 1.45, 0), Vector3(0.04, 0.5, seg), frame, Color("#8d9298"))
		"island":
			# Interlocking foam blocks, alternating red and white.
			b.box(Vector3(0, 0.55, 0), Vector3(1.0, 1.1, seg + 0.02), frame, Color("#c8553d") if n % 2 == 0 else PaperKit.CREAM)
		"hay":
			b.box(Vector3(0, 0.45, 0), Vector3(1.1, 0.9, seg + 0.02), frame, Color("#d6b45a"), Color("#e6c870"))
			b.box(Vector3(0, 0.45, 0), Vector3(1.12, 0.07, seg + 0.04), frame, Color("#b8963e"))


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
func _water_sheet(length: float, half_width: float, water: Color, seed_v: int, ford_half_road := 0.0) -> MeshInstance3D:
	var b := PaperKit.Builder.new(seed_v)
	var steps := maxi(2, ceili(length / 3.5))
	var last := PackedVector3Array()
	var shallows := water.lerp(Color("#b2b39a"), 0.48)
	var depths := [shallows, water.lightened(0.06), water.darkened(0.22), water.darkened(0.17), water, shallows]
	for i in steps + 1:
		var z := length * (float(i) / steps - 0.5)
		var section := PackedVector3Array()
		for x: float in [-1.0, -0.68, -0.24, 0.26, 0.72, 1.0]:
			var breadth := half_width
			if ford_half_road > 0.0:
				breadth = Track.ford_width(z, ford_half_road)
			section.append(Vector3(Track.channel_x(z, x, breadth, seed_v), 0, z))
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
func _riverbanks(sheet: MeshInstance3D, length: float, width: float, seed_v: int, ford_gap := 0.0) -> void:
	var b := PaperKit.Builder.new(seed_v)
	var steps := maxi(2, ceili(length / 3.5))
	var mud := PaperKit.lin(Color(def["pal"]["ground2"]).lerp(Color(def["pal"]["stone"]), 0.30).darkened(0.34))
	var gravel := PaperKit.lin(Color(def["pal"]["stone"]).lerp(Color(def["pal"]["ground2"]), 0.42))
	var turf := PaperKit.Builder.new(seed_v)
	var colors := [mud, gravel]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for side: float in [-1.0, 1.0]:
		var last := PackedVector3Array()
		for i in steps + 1:
			var z := length * (float(i) / steps - 0.5)
			if absf(z) < ford_gap:
				last.clear()
				continue
			var edge := Track.channel_x(z, side, width, seed_v)
			var outer := Vector3(edge + side * 5.4, 0, z)
			var world := sheet.transform * outer
			outer.y = track.terrain.height(Vector2(world.x, world.z)) - sheet.position.y - 0.15
			var taper := smoothstep(0.0, 5.0, length * 0.5 - absf(z))
			if ford_gap > 0:
				taper *= smoothstep(ford_gap, ford_gap + 6.0, absf(z))
			var ridge := ((1.12 if ford_gap == 0.0 else 0.66) + 0.20 * sin(z * 0.43 + side)) * taper
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
					if j == 2:
						turf.quad(last[j], row[j], row[j + 1], last[j + 1], normal, Color.WHITE)
					else:
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
	var turf_mesh := MeshInstance3D.new()
	turf_mesh.mesh = turf.mesh()
	turf_mesh.material_override = ground_mat
	sheet.add_child(turf_mesh)


## Bridges and their rivers.
func _make_bridges() -> void:
	for br in track.bridges:
		var hw := track.road_half_width(br.s) + (0.0 if br.kind == "stone" else BARRIER_LAT)
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
		if not br.dry:
			var river := _water_sheet(along.length(), br.channel, water, int(sc))
			river.position = Vector3(mid.x, wy, mid.y)
			river.rotation.y = atan2(along.x, along.y)
			add_child(river)
			_riverbanks(river, along.length(), br.channel, int(sc))
		# Local frame at the centre of the deck: x along the road, z across it, y up.
		var ybase := track.road_h_i(ci) - 0.85 if br["kind"] == "stone" else track.road_h_i(ci)
		var org := Vector3(c2.x, 0.0, c2.y)
		var fx := Vector3(t2.x, 0, t2.y)
		var fz := Vector3(n2.x, 0, n2.y)
		if br["kind"] == "stone":
			_stone_bridge(b, org, fx, fz, sc, half, hw, wy, ybase)
		elif br.kind in ["truss", "girder"]:
			_long_bridge(b, br, hw)
		else:
			_covered_bridge(b, org, fx, fz, sc, half, hw, wy, ybase)
		if br.get("stacked", false):
			# The deck follows the road's own height and banking, a hair below its surface, so the two are level.
			var steps := maxi(4, int(half * 2.0 / 3.0))
			var prev_a := Vector3.ZERO
			var prev_b := Vector3.ZERO
			for k in steps + 1:
				var sk := sc - half + half * 2.0 * k / float(steps)
				var ik := track.index_at(sk)
				var yk := ROAD_Y + track.road_h_i(ik) - 0.37
				var tilt_k := track.bank_slope(ik) * hw
				var a_pt := track.pts[ik] - track.nrm[ik] * hw
				var b_pt := track.pts[ik] + track.nrm[ik] * hw
				var va := Vector3(a_pt.x, yk - tilt_k, a_pt.y)
				var vb := Vector3(b_pt.x, yk + tilt_k, b_pt.y)
				if k > 0:
					b.slab(prev_a, va, vb, prev_b, 0.6, Color("#66636b"))
				prev_a = va
				prev_b = vb
			# Concrete piers under both ends of the span, so the deck is plainly held up.
			for end_sign in [-1.0, 1.0]:
				var se: float = sc + end_sign * (half - 1.5)
				var ie := track.index_at(se)
				for side_p in [-1.0, 1.0]:
					var q: Vector2 = track.pts[ie] + track.nrm[ie] * side_p * (hw - 0.9)
					var top: float = ROAD_Y + track.road_h_i(ie) + track.bank_slope(ie) * side_p * (hw - 0.9) - 0.7
					var bottom: float = track.terrain.height(q) - 0.6
					if top - bottom > 0.8:
						b.box(Vector3.ZERO, Vector3(1.3, top - bottom, 1.3), Transform3D(Basis(), Vector3(q.x, (top + bottom) * 0.5, q.y)), Color("#a9a49a"))
				var ia := track.pts[ie] - track.nrm[ie] * (hw - 0.9)
				var ib := track.pts[ie] + track.nrm[ie] * (hw - 0.9)
				var yb := ROAD_Y + track.road_h_i(ie) - 0.95
				b.box(Vector3.ZERO, Vector3(hw * 2.0, 0.7, 1.2), Transform3D(Basis(Vector3.UP, track.heading_at(ie)), Vector3((ia.x + ib.x) * 0.5, yb, (ia.y + ib.y) * 0.5)), Color("#a9a49a"))
		var mi := MeshInstance3D.new()
		mi.mesh = b.mesh()
		mi.material_override = paper_mat
		add_child(mi)
		if br.get("stacked", false):
			mi.name = "StackedBridge"
			_stacked_deck = mi


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
		b.box(Vector3.ZERO, Vector3(1.6, 1.6, (hw + 0.6) * 2.0), Transform3D(Basis(fx, Vector3.UP, fx.cross(Vector3.UP)), pc + Vector3.UP*(wy-0.4)), STONE_DARK)


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
	var station := 75.0
	while station < track.finish_s:
		var i := track.index_at(station)
		var placed := false
		for offset: float in [38.0, 50.0, 64.0, 80.0]:
			for side: float in [-1.0, 1.0]:
				var p := track.pts[i] + track.nrm[i] * offset * side
				if _boat_fits(p):
					_boat(b, Vector3(p.x, tr.sea_y, p.y), rng.randf() * TAU, rng, rng.randf() < 0.56)
					placed = true
					break
			if placed:
				break
		station += rng.randf_range(230.0, 410.0) if placed else 45.0
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
				if tr.supports_prop(p + d * 2.0,3.0):
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
			b.box(Vector3(0, 0.4, 0), Vector3(4.0, 2.2, 26.0), Transform3D(qb, qc), Color("#b8b2a4"), Color("#cfc8b8"))
			for k in 4:
				var bollard := qc + qb * Vector3(1.6, 1.7, -9.0 + k * 6.0)
				b.box(bollard, Vector3(0.3, 0.5, 0.3), Transform3D(), Color("#3a3a40"))
			for side in [-1.0, 1.0]:
				for k in 2:
					var bp := qc + qb * Vector3(side * 4.4, 0.0, -6.0 + k * 9.0)
					if not _boat_fits(Vector2(bp.x, bp.z)):
						continue
					_boat(b, bp, yaw + rng.randf_range(-0.1, 0.1), rng, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _boat_fits(p: Vector2) -> bool:
	for point: Vector2 in [Vector2.ZERO, Vector2(-4, -4), Vector2(-4, 4), Vector2(4, -4), Vector2(4, 4)]:
		if not track.terrain.is_sea(p + point) or track.terrain.height(p + point) >= track.terrain.sea_y:
			return false
	return true


## A little paper fishing boat (or sailing dinghy) sitting on the water.
func _boat(b: PaperKit.Builder, at: Vector3, yaw: float, rng: RandomNumberGenerator, sail: bool) -> void:
	var cols := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#ece6d8")]
	var hull: Color = cols[rng.randi() % cols.size()]
	var L := rng.randf_range(4.5, 7.0)
	var bas := Basis(Vector3.UP, yaw)
	var boat := Transform3D(bas, at)
	var xf := Transform3D(bas * Basis(Vector3.UP, PI * 0.5), at)
	# Hull: a side-profile prism (bow raked up), extruded across the beam.
	var prof := PackedVector2Array([Vector2(-L * 0.5, 0.75), Vector2(-L * 0.42, -0.15), Vector2(L * 0.3, -0.15), Vector2(L * 0.5, 0.95)])
	b.card(prof, xf, hull, {"thick": 1.9, "edge": 0.06, "lip": 0.1, "back": hull})
	b.box(Vector3(0, 0.8, 0), Vector3(1.6, 0.06, L * 0.85), boat, Color("#d8c8a8"))
	if sail:
		b.box(Vector3(0, 3.0, 0.3), Vector3(0.1, 4.4, 0.1), boat, Color("#6e5038"))
		var sp := PackedVector2Array([Vector2(0, 1.2), Vector2(0, 5.0), Vector2(-L * 0.4, 1.3)])
		b.card(sp, Transform3D(bas * Basis(Vector3.UP, PI * 0.5), at + bas * Vector3(0, 0, 0.3)), Color("#f4efe2"), {"thick": 0.02, "edge": 0.03, "lip": 0.0})
		var jib := PackedVector2Array([Vector2(0.18, 1.25), Vector2(0.18, 4.7), Vector2(L * 0.36, 1.45)])
		b.card(jib, xf.translated_local(Vector3(0, 0, 0.04)), hull.lightened(0.2), {"thick": 0.02, "edge": 0.025, "lip": 0.0})
	else:
		# Wheelhouse and a short mast.
		b.box(Vector3(0, 1.45, -L * 0.1), Vector3(1.3, 1.3, 1.5), boat, Color("#ece6d8"), Color("#4a5a6a"))
		b.box(Vector3(0, 1.6, -L * 0.1 - 0.76), Vector3(0.9, 0.4, 0.02), boat, Color("#2a3440"))
		b.box(Vector3(0, 2.6, L * 0.2), Vector3(0.08, 2.6, 0.08), boat, Color("#6e5038"))


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
			_crowd.append([smi, smi.position.y, rng.randf() * TAU, false])
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
## Gentle ambient life near the camera: dust and pollen motes in dry weather, light flurries on snowy stages that
## are not actually snowing. (Autumn already has falling leaves.)
func _make_ambient() -> void:
	var snowy_loc: bool = str(def.get("loc_id", "")) in ["alpine", "lakes", "taiga"]
	var raining: bool = kind() == "rain"
	var snowing: bool = kind() == "snow"
	if raining or snowing or not weather_fx or Settings.fx_level() < 1:
		return
	var p := CPUParticles3D.new()
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.55) if snowy_loc else Color(1.0, 0.92, 0.7, 0.35)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.mesh = q
	p.amount = roundi(lerpf(14.0, 46.0, float(Settings.g("particles"))))
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 3.0, 18)
	p.direction = Vector3(1, -0.1, 0.4)
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0.2, -0.25 if snowy_loc else 0.04, 0.1)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5 if snowy_loc else 1.0
	p.position = Vector3(0, 2.0, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weather_fx.add_child(p)
	p.emitting = true


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
	lp.amount = roundi(lerpf(24.0, 75.0, float(Settings.g("particles"))))
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
	_wind_leaves = lp


func _make_weather() -> void:
	weather_fx = Node3D.new()
	add_child(weather_fx)
	var kind: String = wx["particles"]
	Sfx.set_ambience(kind)
	if def.get("leaves", false):
		_make_leaves()
		leaf_litter = LeafLitter.new()
		leaf_litter.name = "LeafLitter"
		add_child(leaf_litter)
		leaf_litter.build(track, int(def.seed))
	if kind == "":
		return
	_particles = CPUParticles3D.new()
	_particles.local_coords = false
	var qm := QuadMesh.new()
	if kind == "rain":
		qm.size = Vector2(0.05, 1.1)
		var streak := ShaderMaterial.new()
		streak.shader = preload("res://shaders/rain.gdshader")
		qm.material = streak
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
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		qm.material = mat
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
	birds.setup(track, paper_mat, int(def["seed"]), wx["kind"] == "rain", def["loc_id"])


## Per-frame: keep weather and birds around the focus, aim the frontal fill along the camera.
var _bonnet := false


## Bonnet view looks at the horizon: give it a pale paper sky and a soft fog so the edge of the
## printed ground never shows.
func _ground_bg() -> Color:
	var g: Color = sea_color() if is_coastal() else Color(def["pal"]["ground"])
	return g if tod < 2 else g.darkened(0.85)


## Distance haze: far hills fade toward the sky colour; at dawn a thicker low mist lies over the valleys.
## The paper material for cars: identical to the stage's, with a thin rim of sky-tinted light on panel edges.
func car_material() -> ShaderMaterial:
	if _car_mat == null:
		_car_mat = paper_mat.duplicate() as ShaderMaterial
	_sync_car_mat()
	return _car_mat


func _sync_car_mat() -> void:
	if _car_mat == null:
		return
	for u in paper_mat.shader.get_shader_uniform_list():
		var nm: String = u["name"]
		_car_mat.set_shader_parameter(nm, paper_mat.get_shader_parameter(nm))
	_car_mat.set_shader_parameter("rim", (1.9 if kind() == "rain" else 1.0) if Settings.fx_level() >= 1 else 0.0)


## Crowds near the action jump and wave for a couple of seconds (jumps, splashes).
var _storm_next := 9.0
var _flash := 0.0
var _thunder_in := -1.0
var _base_key := 0.0


## Storm stages: now and then a flash lights the sky and the scene, and thunder rolls in a little later.
func _update_storm(dt: float) -> void:
	if kind() != "rain" or key_light == null or Settings.fx_level() < 1:
		return
	_storm_next -= dt
	if _storm_next <= 0.0 and _flash <= 0.0:
		_storm_next = randf_range(9.0, 24.0)
		_flash = 1.0
		_thunder_in = randf_range(0.8, 3.2)
		_base_key = key_light.light_energy
	if _thunder_in >= 0.0:
		_thunder_in -= dt
		if _thunder_in < 0.0:
			Sfx.play("thud", -3.0, 0.42)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 3.2)
		# Two quick pulses.
		var pulse := _flash * (0.6 + 0.4 * sin(_flash * 22.0))
		if _sky_mat:
			_sky_mat.set_shader_parameter("flash", pulse)
		key_light.light_energy = maxf(_base_key, 0.0) + pulse * 1.6
		env.ambient_light_energy = float(wx.amb_e) * 0.95 + pulse * 0.6
		if _flash <= 0.0:
			if _sky_mat:
				_sky_mat.set_shader_parameter("flash", 0.0)
			key_light.light_energy = _base_key
			env.ambient_light_energy = float(wx.amb_e) * 0.95


func cheer_crowd() -> void:
	_crowd_boost = 2.2


func apply_haze() -> void:
	if _bonnet:
		return
	var lvl := Settings.fx_level()
	env.fog_enabled = lvl >= 1
	var dawn := 0.0
	if _lighting_mode == Catalog.SUNRISE:
		dawn = clampf(1.0 - _light_progress * 1.6, 0.0, 1.0)
	elif tod == 1 and _lighting_mode != Catalog.SUNSET:
		dawn = 0.3
	env.fog_density = 0.0018 + 0.0035 * dawn
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0


func set_bonnet(on: bool) -> void:
	if on == _bonnet:
		return
	_bonnet = on
	env.fog_enabled = on
	env.fog_density = 0.008 if tod < 2 else 0.005
	env.fog_sky_affect = 0.16
	if not on:
		apply_haze()


func update(dt: float, focus: Vector3, radius: float, player_s: float, cam: Camera3D) -> void:
	_time += dt
	if _sky_mat:
		_sky_mat.set_shader_parameter("t", _time)
	if helicopter:
		helicopter.update(dt, player_s)
	_crowd_boost = maxf(0.0, _crowd_boost - dt)
	_update_storm(dt)
	if rx_props:
		rx_props.set_focus(focus)
	for c: Array in _crowd:
		var cn: Node3D = c[0]
		var near := cn.global_position.distance_to(focus) < 70.0
		var boost := 1.0 + 3.5 * clampf(_crowd_boost, 0.0, 1.0)
		var cheer := absf(sin(_time * 7.0 * (1.0 + 0.5 * clampf(_crowd_boost, 0.0, 1.0)) + float(c[2]))) * (1.0 if near else 0.0)
		if bool(c[3]):
			cn.scale.y = 1.0 + 0.012 * cheer * boost
		else:
			cn.position.y = float(c[1]) + 0.07 * cheer * boost
	_reflect_t -= dt
	if _reflect_t <= 0.0:
		_reflect_t = 0.25
		_update_wet_reflections(focus)
	if scenery:
		scenery.update(Vector2(focus.x, focus.z), radius, dt)
	if leaf_litter:
		leaf_litter.advance(dt)
	weather_fx.position = focus
	if cam:
		fill_light.global_basis = cam.global_basis
		update_tunnel_roof(cam, player_s)


func grip() -> float:
	return float(wx["grip"])


func kind() -> String:
	return wx["kind"]


func _long_bridge(b: PaperKit.Builder, br: Dictionary, hw: float) -> void:
	var paint := Color("#586e70") if br.kind == "truss" else Color("#835f4f")
	for side: float in [-1, 1]:
		for bay in 8:
			var ends: Array[Vector3] = []
			for k in [bay, bay + 1]:
				var s := float(br.s) + lerpf(-float(br.half), float(br.half), k / 8.0)
				var i := track.index_at(s)
				var xy := track.pts[i] + track.nrm[i] * hw * side
				ends.append(Vector3(xy.x, track.road_h_i(i), xy.y))
			var a := ends[0]
			var z := ends[1]
			var rise := Vector3.UP * (3.4 if br.kind == "truss" else 1.0)
			_structural_member(b, a - Vector3.UP*0.42, z - Vector3.UP*0.42, 0.38, 0.85, paint)
			_structural_member(b, a + rise, z + rise, 0.16, 0.19, paint)
			_structural_member(b, a, a + rise, 0.15, 0.16, paint)
			if br.kind == "truss":
				_structural_member(b, a + rise if bay % 2 else a, z if bay % 2 else z + rise, 0.14, 0.16, paint)
			if bay == 7:
				_structural_member(b, z, z + rise, 0.15, 0.16, paint)
			if bay in [1, 7]:
				var footing := track.terrain.height(Vector2(a.x,a.z)) - 1.6
				_structural_member(b, Vector3(a.x, minf(footing, a.y-1.0), a.z), a, 1.45, 1.6, STONE_DARK)


func _structural_member(b: PaperKit.Builder, a: Vector3, z: Vector3, w: float, h: float, ink: Color) -> void:
	var dir := a.direction_to(z)
	var up := Vector3.BACK if absf(dir.y) > 0.98 else Vector3.UP
	b.box(Vector3.ZERO, Vector3(w,h,a.distance_to(z)), Transform3D(Basis.looking_at(dir,up), (a+z)*0.5), ink)


func _overhead_crossing() -> void:
	var ski: bool = def.loc_id == "alpine"
	var choice := -1
	var score := -INF
	var start_fraction := 0.38 if ski else 0.26
	var end_fraction := 0.64 if ski else 0.75
	for i in range(track.index_at(track.finish_s * start_fraction), track.index_at(track.finish_s * end_fraction), 5):
		var s := track.dist[i]
		if not track.bridge_at(s, 35).is_empty() or absf(track.heights[i]) > 0.05 or track.overlaps_water(track.pts[i], 18):
			continue
		var slope := absf(track.terrain.height(track.pts[i]+track.nrm[i]*19)-track.terrain.height(track.pts[i]-track.nrm[i]*19))
		var rank := slope - 50.0*track.curv_abs[i]
		if rank > score:
			choice = i
			score = rank
	if choice < 0:
		return
	var center := track.pts[choice]
	var origin := Vector3(center.x,track.road_h_i(choice),center.y)
	var t := track.tang[choice]
	var span := Vector3(-t.y,0,t.x)
	var along := Vector3(t.x,0,t.y)
	var b := PaperKit.Builder.new(choice)
	var steel := Color("#576566")
	var half := 19.0 if ski else 12.0
	var deck := 10.0 if ski else 6.3
	if ski:
		scenery.tower_approach = track.point_at(track.dist[choice]-48.0)
		scenery.tower_position = center + track.nrm[choice] * half
	for side: float in [-1,1]:
		var post := span * half * side
		var floor_y := track.terrain.height(center+Vector2(post.x,post.z)) - origin.y
		if not ski:
			var toe := post + span*side*11.0
			var toe_y := track.terrain.height(center+Vector2(toe.x,toe.z))-origin.y
			var lip := post + Vector3.UP*(deck-0.2)
			toe.y = toe_y
			b.slab(lip-along*2.25,lip+along*2.25,toe+along*2.25,toe-along*2.25,0.35,STONE_DARK)
			for edge: float in [-1,1]:
				b.slab(lip+along*edge*2.25,toe+along*edge*2.25,toe+along*edge*3.4-Vector3.UP,post+along*edge*3.4+Vector3.UP*(floor_y-1),0.15,STONE_DARK)
		for rail: float in [-1,1]:
			var base := post + along * rail * 1.6
			var xy := center + Vector2(base.x,base.z)
			scenery.fixed_supports.append(Vector3(xy.x,xy.y,0.46 if ski else 0.95))
			_structural_member(b,base+Vector3.UP*(minf(floor_y,deck-1)-0.4),base+Vector3.UP*deck,0.32 if ski else 1.3,0.35 if ski else 1.4,steel)
		_structural_member(b,post-along*2.1+Vector3.UP*deck,post+along*2.1+Vector3.UP*deck,0.4,0.4,steel)
	for rail: float in [-1,1]:
		var offset := along*rail*1.6
		for section in 10:
			var a := lerpf(-half,half,section/10.0)
			var z := lerpf(-half,half,(section+1)/10.0)
			var left := span*a+offset+Vector3.UP*(deck - (1.1*(1.0-pow(a/half,2)) if ski else 0.0))
			var right := span*z+offset+Vector3.UP*(deck - (1.1*(1.0-pow(z/half,2)) if ski else 0.0))
			_structural_member(b,left,right,0.064 if ski else 0.32,0.064 if ski else 0.65,steel)
			if ski and section % 4 == (1 if rail<0 else 3):
				_structural_member(b,left,left-Vector3.UP*1.65,0.09,0.09,steel)
				_structural_member(b,left-Vector3.UP*1.65-along*0.75,left-Vector3.UP*1.65+along*0.75,0.62,0.15,Color("#b95443"))
				_structural_member(b,left-Vector3.UP*1.43-along*0.75-span*0.26,left-Vector3.UP*1.43+along*0.75-span*0.26,0.12,0.45,steel)
			elif not ski:
				for sleeper in 3:
					var at := left.lerp(right,sleeper/3.0)
					_structural_member(b,at-along*rail*1.6,at+along*rail*0.4,0.28,0.16,Color("#916e53"))
	var uphill := 1.0 if track.terrain.height(center+Vector2(span.x,span.z)*half) > track.terrain.height(center-Vector2(span.x,span.z)*half) else -1.0
	var at := span*half*uphill+along*4.6
	var xy := center+Vector2(at.x,at.z)
	at.y = track.terrain.height(xy)-origin.y
	var frame := Transform3D(Basis(along,Vector3.UP,along.cross(Vector3.UP)),at)
	if ski:
		b.box(Vector3(0,1.18,0),Vector3(3.7,2.36,3.2),frame,Color("#a25d4d"))
		b.box(Vector3(0,2.47,0),Vector3(4.1,0.27,3.7),frame,PaperKit.CREAM)
		b.box(Vector3(0,1.48,-uphill*1.62),Vector3(1.32,0.92,0.09),frame,Color("#cbd6b7"))
		for k in 3:
			b.box(Vector3((k-1)*0.27,1.47+(k%2)*0.15,-uphill*1.68),Vector3(0.21,0.09,0.035),frame,Color("#4d807c"))
		for rail: float in [-1,1]:
			var pulley := span*uphill*half+along*rail*1.6+Vector3.UP*(deck-0.04)
			b.card(PaperKit.circle(0.43,0,0,12),Transform3D(frame.basis.rotated(Vector3.UP,PI/2),pulley),Color("#484f51"),{"thick":0.18})
		for k in 3:
			var q := at+along*(2.6+k*1.2)-span*uphill*1.0
			q.y = track.terrain.height(center+Vector2(q.x,q.z))-origin.y
			_structural_member(b,q,q+Vector3.UP*1.0,0.09,0.09,steel)
			if k < 2:
				var next := q+along*1.2
				next.y = track.terrain.height(center+Vector2(next.x,next.z))-origin.y
				_structural_member(b,q+Vector3.UP*0.82,next+Vector3.UP*0.82,0.055,0.055,Color("#aa6144"))
	else:
		# The disused platform and ballast follow the railway off the deck.
		for k in 12:
			var off := half+0.65+k*1.2
			var p := span*uphill*off
			var rail_xy := center+Vector2(p.x,p.z)
			var ground := track.terrain.height(rail_xy)-origin.y
			if ground > deck+0.4 and track.clearance(rail_xy)>track.width*0.5+5.5:
				var cut := minf(ground,deck+0.4)
				track.terrain.flatten_disc(rail_xy,2.15,origin.y+cut,2.5)
				ground = cut
			p.y = lerpf(deck,ground+0.18,smoothstep(half,half+11.0,off))
			var bed := Transform3D(frame.basis,p)
			b.box(Vector3.ZERO,Vector3(3.6,0.32,1.26),bed,STONE_DARK)
			b.box(Vector3(0,0.20,0),Vector3(2.4,0.13,0.24),bed,Color("#76604d"))
			for rail: float in [-0.78,0.78]:
				b.box(Vector3(rail,0.30,0),Vector3(0.09,0.13,1.28),bed,steel)
			if k < 7:
				b.box(Vector3(2.45,0.52,0),Vector3(1.8,0.9,1.25),bed,Color("#948678"))
				var landing := center+Vector2(p.x+along.x*2.45,p.z+along.z*2.45)
				scenery.fixed_supports.append(Vector3(landing.x,landing.y,0.97))
	if ski:
		scenery.fixed_supports.append(Vector3(xy.x,xy.y,2.1))
	var mi := MeshInstance3D.new()
	mi.name = "Chairlift" if ski else "RailOverpass"
	mi.mesh = b.mesh()
	mi.position = origin
	mi.material_override = paper_mat
	add_child(mi)


func _marshal_post(s: float, role: String) -> void:
	var i := track.index_at(s)
	var preferred := -1.0 if role == "finish" else 1.0
	var side := preferred
	var xy := Vector2.ZERO
	var supported := false
	var stations := PackedFloat32Array([0.0])
	for distance in range(4, 49, 4):
		stations.append(-distance)
		stations.append(distance)
	for offset in stations:
		i = track.index_at(clampf(s + offset, 0.0, track.dist[-1]))
		for setback: float in [4.2, 2.8, 6.5, 9.0, 12.0]:
			for bank: float in [preferred, -preferred]:
				xy = track.pts[i] + track.nrm[i] * bank * (track.width * 0.5 + setback)
				if track.terrain.supports_prop(xy, 2.0) and not track.overlaps_water(xy, 2.0):
					side = bank
					supported = true
					break
			if supported:
				break
		if supported:
			break
	if not supported:
		return
	var b := PaperKit.Builder.new(i)
	var frame := Transform3D.IDENTITY
	var cover := Vector3(side*1.0,0.48,0)
	var steel := Color("#505c61")
	b.box(cover,Vector3(0.4,0.96,3.1),frame,Color("#a99c83"))
	var tripod := Vector3(side*0.42,1.28,-0.8)
	for k in 3:
		var dir := Vector2.from_angle(k*TAU/3)
		_structural_member(b,tripod,Vector3(tripod.x+dir.x*0.4,0,tripod.z+dir.y*0.4),0.055,0.055,steel)
	b.box(tripod+Vector3.UP*0.12,Vector3(0.31,0.27,0.33),frame,steel)
	for coil in 3:
		var xf := Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0.84,0.06+coil*0.06,-1.1))
		b.card(PaperKit.circle(0.27,0,0,12),xf,steel,{"thick":0.035})
		b.card(PaperKit.circle(0.17,0,0,12),xf.translated_local(Vector3.BACK*0.025),STONE_DARK,{"thick":0.015})
	for k in 3:
		b.box(Vector3(0.85,0.37,0.55+k*0.14),Vector3(0.68,0.09,0.12),frame,PaperKit.CREAM if k%2 else Color("#bf6b49"))
	var person := Vector3(0,0,0.32)
	for leg: float in [-0.12,0.12]:
		b.box(person+Vector3(leg,0.39,0),Vector3(0.15,0.76,0.21),frame,steel)
	b.box(person+Vector3.UP*1.06,Vector3(0.49,0.64,0.28),frame,Color("#d58344"))
	b.box(person+Vector3.UP*1.03,Vector3(0.51,0.08,0.29),frame,PaperKit.CREAM)
	b.box(person+Vector3.UP*1.54,Vector3(0.27,0.32,0.24),frame,Color("#ae8369"))
	b.box(person+Vector3.UP*1.71,Vector3(0.31,0.10,0.31),frame,steel)
	var hand := person+Vector3(-0.39,1.6 if role=="start" else 1.08,0.21)
	_structural_member(b,person+Vector3(-0.22,1.30,0),hand,0.14,0.14,Color("#b47244"))
	_structural_member(b,person+Vector3(0.22,1.30,0),person+Vector3(0.16,1.04,0.23),0.13,0.13,Color("#b47244"))
	if role == "start":
		b.box(hand+Vector3.UP*0.2,Vector3(0.038,0.48,0.038),frame,steel)
		b.box(hand+Vector3(0.13,0.4,0),Vector3(0.26,0.21,0.035),frame,Color("#72935a"))
	elif role == "finish":
		b.box(hand,Vector3(0.32,0.08,0.38),frame,PaperKit.CREAM)
	else:
		b.box(hand,Vector3(0.09,0.23,0.1),frame,steel)
	var mi := MeshInstance3D.new()
	mi.name = "Marshal_"+role
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.position = Vector3(xy.x,track.terrain.height(xy),xy.y)
	mi.rotation.y = track.heading_at(i)
	mi.visibility_range_end = 135
	add_child(mi)
	scenery.fixed_supports.append(Vector3(xy.x,xy.y,1.55))


func _avalanche_gallery() -> void:
	var best := -INF
	var chosen := 0
	var side := 1.0
	for i in range(track.index_at(track.finish_s*0.12),track.index_at(track.finish_s*0.25),4):
		if not track.bridge_at(track.dist[i],24).is_empty() or absf(track.heights[i]) > 0.05:
			continue
		var offset := track.nrm[i]*12
		var slope := track.terrain.height(track.pts[i]+offset)-track.terrain.height(track.pts[i]-offset)
		var score := absf(slope)-100*track.curv_abs[i]
		if score > best:
			best = score
			chosen = i
			side = signf(slope) if slope else 1.0
	if not chosen:
		return
	var b := PaperKit.Builder.new(chosen)
	var origin := track.pts[chosen]
	var prev: Array[Vector3] = []
	for bay in 7:
		var i := chosen+(bay-3)*2
		var p := track.pts[i]-origin
		var ends: Array[Vector3] = []
		for flank: float in [-1,1]:
			var offset := track.nrm[i]*flank*side*(track.width*0.5+1.7)
			var xy := track.pts[i]+offset
			var top := Vector3(p.x+offset.x,track.road_h_i(i)+5.6+flank*0.20,p.y+offset.y)
			var base := Vector3(top.x,minf(track.terrain.height(xy)-0.45,top.y-1),top.z)
			_structural_member(b,base,top,0.55,0.55,STONE_DARK)
			scenery.fixed_supports.append(Vector3(xy.x,xy.y,0.43))
			ends.append(top)
		if bay:
			b.slab(prev[0],prev[1],ends[1],ends[0],0.32,PaperKit.CREAM)
			b.slab(prev[1],ends[1],ends[1]-Vector3.UP*5.9,prev[1]-Vector3.UP*5.9,0.32,STONE_DARK)
			var mid := (prev[1]+ends[1])*0.5
			scenery.fixed_supports.append(Vector3(origin.x+mid.x,origin.y+mid.z,1.88))
		prev = ends
	var mi := MeshInstance3D.new()
	mi.name = "AvalancheGallery"
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	mi.position = Vector3(origin.x,0,origin.y)
	mi.visibility_range_end = 220
	add_child(mi)

## Keep the bore open to the driving and photo cameras when viewed from above.
func update_tunnel_roof(cam: Camera3D, station: float) -> void:
	if _stacked_deck:
		var lower: float = track.stacked_crossing.lower
		var cutaway := absf(station-lower) < 16.0 and cam.global_position.y > track.road_h(lower) + 9.0
		_stacked_road.visible = not cutaway
		_stacked_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if cutaway else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if not _tunnel_roof:
		return
	var overhead := cam.global_position.y > track.road_h(station) + 4.9
	_tunnel_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if overhead and track.tunnel_at(station, 3.0) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _make_switchback_tunnel() -> void:
	if track.tunnels.is_empty():
		return
	var extent := track.tunnels[0]
	var walls := PaperKit.Builder.new(int(extent.s0))
	var roof := PaperKit.Builder.new(int(extent.s0) + 31)
	var entry_ink := Color("#ad865e") if def.loc_id == "canyon" else Color("#9a9da2")
	var wall_ink := entry_ink.darkened(0.24)
	var cap_ink: Color = def.pal.ground2
	var mouth := track.width * 0.5 + 0.9
	var past := PackedVector3Array()
	var first := track.index_at(extent.s0)
	var last := track.index_at(extent.s1)
	for i in range(first, last + 1):
		var p := track.pts[i]
		var lateral := track.nrm[i]
		var y := track.road_h_i(i) + ROAD_Y
		var ring := PackedVector3Array()
		# A straight lower wall and angled shoulders leave 4.6 m over the lanes.
		for point: Vector2 in [Vector2(-mouth, -0.3), Vector2(-mouth, 3.4),
				Vector2(-mouth + 1.35, 4.6), Vector2(mouth - 1.35, 4.6), Vector2(mouth, 3.4), Vector2(mouth, -0.3)]:
			var xy := p + lateral * point.x
			ring.append(Vector3(xy.x, y + point.y, xy.y))
		if not past.is_empty():
			for j in range(5):
				var builder := walls if j in [0, 4] else roof
				builder.slab(past[j], past[j+1], ring[j+1], ring[j], 0.28, wall_ink.lightened((i % 4) * 0.016))
			for side: float in [-1, 1]:
				var back := p + lateral * side * (mouth + 5.2)
				var last_back := track.pts[i-1] + track.nrm[i-1] * side * (mouth + 5.2)
				var slope := Vector3(back.x, track.terrain.height(back) + 0.06, back.y)
				var last_slope := Vector3(last_back.x, track.terrain.height(last_back) + 0.06, last_back.y)
				var j := 1 if side < 0.0 else 4
				roof.slab(past[j] + Vector3.UP * 0.16, last_slope, slope, ring[j] + Vector3.UP * 0.16, 0.17, cap_ink)
		if i == first or i == last:
			for j in 5:
				_structural_member(walls, ring[j], ring[j+1], 0.56, 0.56, entry_ink.lightened(0.16))
			for side: float in [-1, 1]:
				var xy := p + lateral * side * (mouth + 0.48)
				var face := Transform3D(Basis(Vector3.UP, track.heading_at(i)), Vector3(xy.x, y, xy.y))
				for band in 6:
					walls.box(Vector3(0, 0.30 + band * 0.22, 0), Vector3(0.27, 0.225, 0.74), face,
						PaperKit.CREAM if band % 2 else Color("#aa6245"))
		if (i - first) % 5 == 2:
			for side: float in [-1, 1]:
				var xy := p + lateral * side * (mouth - 0.20)
				var lamp := Vector3(xy.x, y + 2.9, xy.y)
				walls.box(lamp, Vector3(0.35, 0.14, 0.42), Transform3D.IDENTITY, Color("#e4b86e"), Color(-1, 0, 0), true)
		past = ring
	var lining := MeshInstance3D.new()
	lining.name = "TunnelPortalsAndWalls"
	lining.mesh = walls.mesh()
	lining.material_override = paper_mat
	add_child(lining)
	_tunnel_roof = MeshInstance3D.new()
	_tunnel_roof.name = "TunnelRoof"
	_tunnel_roof.mesh = roof.mesh()
	_tunnel_roof.material_override = paper_mat
	add_child(_tunnel_roof)


## Route-based rock forms reinforce the three printed terrain sections.
func _make_gorge_outcrops() -> void:
	if def.loc_id != "gorge":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.seed) + 83
	for chapter in 3:
		for cluster in 3:
			var fraction := (float(chapter) + 0.30 + 0.22 * cluster) / 3.0
			var i := track.index_at(track.finish_s * fraction)
			var b := PaperKit.Builder.new(i)
			var base := track.pts[i]
			for sign_v: float in [1.0, -1.0]:
				for slab in 8:
					var at := base + track.nrm[i] * sign_v * rng.randf_range(11.0, 24.0) + track.tang[i] * rng.randf_range(-14, 14)
					if track.clearance(at) < 9.5 or track.overlaps_water(at, 2.8):
						continue
					var y := track.terrain.height(at)
					var width := rng.randf_range(1.1, 2.8)
					var height := rng.randf_range(1.5, 3.4) if chapter == 1 else rng.randf_range(0.35, 1.65)
					if height > 1.1:
						scenery.fixed_supports.append(Vector3(at.x, at.y, width * 0.54))
					var ink := [Color("#ae8968"), Color("#55515f"), Color("#d5c4aa")][chapter] as Color
					var lean := rng.randf_range(-0.30, 0.30)
					var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, lean)
					var origin := Vector3(at.x-base.x, y + height*0.29, at.y-base.y)
					b.box(Vector3.ZERO, Vector3(width, height, 0.65 if chapter == 1 else width * 0.62), Transform3D(tilt, origin), ink.lightened(rng.randf_range(-0.12, 0.08)))
					if chapter == 2:
						b.box(Vector3.UP * height * 0.29, Vector3(width * 0.95, 0.12, width * 0.66), Transform3D(tilt, origin), Color("#efe0c7"))
			var outcrop := MeshInstance3D.new()
			outcrop.mesh = b.mesh()
			outcrop.material_override = paper_mat
			outcrop.position = Vector3(base.x, 0, base.y)
			outcrop.visibility_range_end = 190.0
			add_child(outcrop)


func _make_circuit_stands() -> void:
	var b := PaperKit.Builder.new(47)
	for station: float in [16.0, 47.0]:
		var i := track.index_at(station)
		var p := track.pts[i] - track.nrm[i] * (track.width * 0.5 + 8.0)
		var xf := Transform3D(Basis(Vector3.UP, track.heading_at(i) - PI * 0.5),
			Vector3(p.x, track.terrain.height(p) - 0.35, p.y))
		var frame := Color("#736456")
		b.box(Vector3(0, 0.45, 0), Vector3(24.0, 1.8, 6.8), xf, frame)
		for tier in 5:
			var h := 1.42 + tier * 0.45
			b.box(Vector3(0, h - 0.6, 2.35 - tier * 1.08), Vector3(23.5, 1.2, 1.15), xf, Color("#b49d7e"))
			for seat in 31:
				if (tier * 13 + seat * 7) % 9 < 3:
					continue
				var col: Color = [Color("#c8553d"), Color("#2f8a8a"), Color("#e8b04a"), Color("#526d9d")][(tier + seat) % 4]
				var at := Vector3((seat - 15) * 0.71, h + 0.32, 2.35 - tier * 1.08)
				b.box(at, Vector3(0.28, 0.54, 0.26), xf, col)
				b.box(at + Vector3.UP * 0.35, Vector3(0.18, 0.18, 0.19), xf, Color("#d7ab82"))
		for x: float in [-11.5, 0.0, 11.5]:
			b.box(Vector3(x, 2.65, -2.8), Vector3(0.21, 6.0, 0.24), xf, frame)
		b.box(Vector3(0, 5.64, -0.38), Vector3(24.8, 0.20, 6.3), xf, Color("#a64b37"))
		b.box(Vector3(0, 5.43, 2.7), Vector3(24.8, 0.35, 0.19), xf, Color("#e6c68e"))
	var stand := MeshInstance3D.new()
	stand.mesh = b.mesh()
	stand.material_override = paper_mat
	add_child(stand)
	_crowd.append([stand, 1.0, randf() * TAU, true])


## Rallycross: concrete piers and a cross beam under any stretch of road that stands clear of the ground,
## so no deck or ramp appears to float.
func _rx_supports() -> void:
	var b := PaperKit.Builder.new(4242)
	var concrete := Color("#a9a49a")
	var count := 0
	var s := 8.0
	while s < track.length - 8.0:
		if not track.on_stacked_span(s, 2.0):
			var i := track.index_at(s)
			var hw := track.road_half_width(s)
			var deck_c := track.road_h_i(i)
			var floor_c := track.terrain.height(track.pts[i])
			if deck_c - floor_c > 1.8:
				var left := track.pts[i] - track.nrm[i] * (hw - 1.4)
				var right := track.pts[i] + track.nrm[i] * (hw - 1.4)
				for q: Vector2 in [left, right]:
					var lat := (q - track.pts[i]).dot(track.nrm[i])
					var top := deck_c + lat * track.bank_slope(i) - 0.5
					var bottom := minf(track.terrain.height(q), top - 0.5) - 0.3
					_structural_member(b, Vector3(q.x, bottom, q.y), Vector3(q.x, top, q.y), 1.1, 1.1, concrete)
				_structural_member(b, Vector3(left.x, deck_c - 0.7, left.y), Vector3(right.x, deck_c - 0.7, right.y), 0.9, 0.9, concrete)
				count += 1
		s += 12.0
	if count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "RxSupports"
	mi.mesh = b.mesh()
	mi.material_override = paper_mat
	add_child(mi)
