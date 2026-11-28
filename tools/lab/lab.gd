extends SceneTree
## Shader lab: renders stand-alone test scenes for ideas under evaluation. Nothing here ships in the game.
## godot --rendering-driver opengl3 --resolution 1280x720 --path . -s tools/lab/lab.gd -- --test=glass --out=/tmp/x

var _out := "/tmp"
var _base := ""

func _initialize() -> void:
	var test := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="): test = a.substr(7)
		elif a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--base="): _base = a.substr(7)
	_go.call_deferred(test)

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

func _save(name: String) -> void:
	await _frames(6)
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("LAB saved ", name)

func _go(test: String) -> void:
	if test in ["all", "glass"]: await _glass()
	if test in ["all", "snow"]: await _snow()
	if test in ["all", "water"]: await _water()
	if test in ["all", "land"]: await _land()
	quit()

# ---------------------------------------------------------------- 1: windscreen
func _glass() -> void:
	var tex := ImageTexture.create_from_image(Image.load_from_file(_base))
	var variants := [
		["glass_rain_still", 0, -1.15, -1.15, 0.0, 1.0],
		["glass_rain_wipe", 0, -1.15, -0.05, 1.0, 1.0],
		["glass_dust_still", 1, -1.15, -1.15, 0.0, 1.0],
		["glass_dust_wipe", 1, -1.15, 0.25, 1.0, 1.0],
	]
	for v in variants:
		var layer := CanvasLayer.new()
		root.add_child(layer)
		var rect := ColorRect.new()
		rect.size = Vector2(1280, 720)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://tools/lab/lab_glass.gdshader")
		sm.set_shader_parameter("scene", tex)
		sm.set_shader_parameter("mode", v[1])
		sm.set_shader_parameter("wiper_from", v[2])
		sm.set_shader_parameter("wiper_to", v[3])
		sm.set_shader_parameter("show_blade", v[4])
		sm.set_shader_parameter("amount", v[5])
		rect.material = sm
		layer.add_child(rect)
		await _save(v[0])
		layer.queue_free()
		await _frames(2)

# ---------------------------------------------------------------- 4: snow
func _snow() -> void:
	for mode in [0, 1]:
		var scene := _stage_env(Color("#cfdcee"), Color("#e9eef7"), -16.0, 35.0)
		var pm := PlaneMesh.new()
		pm.size = Vector2(14, 60)
		pm.subdivide_width = 280
		pm.subdivide_depth = 600
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://tools/lab/lab_snow.gdshader")
		mat.set_shader_parameter("mode", mode)
		mi.material_override = mat
		mi.position = Vector3(0, 0, 0)
		scene.add_child(mi)
		var cam := Camera3D.new()
		cam.fov = 52
		cam.position = Vector3(0.2, 1.25, -7.0)
		scene.add_child(cam)
		cam.look_at(Vector3(0.6, 0.0, 3.0))
		cam.current = true
		await _save("snow_%s" % ["flat", "pressed"][mode])
		scene.queue_free()
		await _frames(2)

func _stage_env(sky: Color, ambient: Color, sun_pitch: float, sun_yaw: float) -> Node3D:
	var scene := Node3D.new()
	root.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("#fff2dc")
	scene.add_child(sun)
	return scene

# ---------------------------------------------------------------- 5: water
func _water_plane(scene: Node3D, rings: float, wake: float, time: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/lab/lab_water.gdshader")
	mat.set_shader_parameter("rings", rings)
	mat.set_shader_parameter("wake", wake)
	mat.set_shader_parameter("time", time)
	mat.set_shader_parameter("car", Vector2(0, 0))
	mi.material_override = mat
	scene.add_child(mi)

func _water() -> void:
	# rain rings on a pond
	var s1 := _stage_env(Color("#e9cfae"), Color("#c9d3e0"), -30.0, 20.0)
	_water_plane(s1, 1.0, 0.0, 0.8)
	var c1 := Camera3D.new()
	c1.fov = 55
	c1.position = Vector3(0, 2.2, 8)
	s1.add_child(c1)
	c1.look_at(Vector3(0, 0, -2))
	c1.current = true
	await _save("water_rings")
	s1.queue_free()
	await _frames(2)
	# splash crown + wake behind a car crossing a ford
	for t in [0.10, 0.28, 0.55]:
		var s2 := _stage_env(Color("#e9cfae"), Color("#c9d3e0"), -30.0, 20.0)
		_water_plane(s2, 0.0, 1.0, 0.0)
		var car := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 0.9, 1.7)
		car.mesh = bm
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color("#efe3c8")
		car.material_override = cm
		car.position = Vector3(0, 0.62, 0)
		s2.add_child(car)
		var cab := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(1.9, 0.6, 1.4)
		cab.mesh = bm2
		cab.material_override = cm
		cab.position = Vector3(-0.2, 1.15, 0)
		s2.add_child(cab)
		var stripe := MeshInstance3D.new()
		var bm3 := BoxMesh.new()
		bm3.size = Vector3(4.02, 0.12, 1.72)
		stripe.mesh = bm3
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("#c8553d")
		stripe.material_override = sm
		stripe.position = Vector3(0, 0.7, 0)
		s2.add_child(stripe)
		for wx in [1.35, -1.35]:
			for wz in [0.9, -0.9]:
				var wh := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.42
				cyl.bottom_radius = 0.42
				cyl.height = 0.35
				wh.mesh = cyl
				var wm := StandardMaterial3D.new()
				wm.albedo_color = Color("#2b2420")
				wh.material_override = wm
				wh.rotation_degrees = Vector3(90, 0, 0)
				wh.position = Vector3(wx, 0.36, wz)
				s2.add_child(wh)
		_crown(s2, Vector3(1.45, 0.0, 0.95), t, 1)
		_crown(s2, Vector3(1.45, 0.0, -0.95), t, 2)
		_crown(s2, Vector3(-1.4, 0.0, 0.95), t * 0.9, 3)
		_crown(s2, Vector3(-1.4, 0.0, -0.95), t * 0.9, 4)
		var c2 := Camera3D.new()
		c2.fov = 50
		c2.position = Vector3(-8.5, 3.0, 7.0)
		s2.add_child(c2)
		c2.look_at(Vector3(-3.5, 0.3, 0))
		c2.current = true
		await _save("water_wake_%d" % int(t * 100))
		s2.queue_free()
		await _frames(2)

func _crown(scene: Node3D, origin: Vector3, t: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.96, 0.99, 1.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	var n := 140
	mm.instance_count = n
	for i in n:
		var th := rng.randf() * TAU
		var v := rng.randf_range(3.4, 6.2)
		var el := deg_to_rad(rng.randf_range(48.0, 72.0))
		var vel := Vector3(cos(th) * cos(el) * v + 3.0, sin(el) * v, sin(th) * cos(el) * v)
		var p := origin + vel * t + Vector3(0, -4.9 * t * t, 0) - Vector3(3.0 * t, 0, 0) * 0.0
		p.y = maxf(p.y, 0.0)
		var sz := rng.randf_range(0.10, 0.22) * (1.0 - t * 0.4)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sz), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	scene.add_child(mmi)
	# translucent sheet: a flared ring that thins as it rises
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55 + t * 1.6
	cyl.bottom_radius = 0.3 + t * 0.9
	cyl.height = 0.22 + t * 0.7
	cyl.radial_segments = 14
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.9, 0.96, 1.0, maxf(0.0, 0.62 - t * 0.7))
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = cmat
	var sheet := MeshInstance3D.new()
	sheet.mesh = cyl
	sheet.position = origin + Vector3(0.5 * t, cyl.height * 0.5, 0)
	scene.add_child(sheet)

# ---------------------------------------------------------------- 6: landforms
func _land() -> void:
	var names := ["rolling", "dunes", "yardang", "strata"]
	for k in names.size():
		var scene := _stage_env(Color("#f1d3b0"), Color("#c9b8a0"), -38.0, 55.0)
		var mi := MeshInstance3D.new()
		mi.mesh = _heightfield(names[k])
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.0
		mi.material_override = mat
		scene.add_child(mi)
		var cam := Camera3D.new()
		cam.fov = 44
		cam.far = 2000
		cam.position = Vector3(-300, 170, 430)
		scene.add_child(cam)
		cam.look_at(Vector3(0, 10, 0))
		cam.current = true
		await _save("land_" + names[k])
		scene.queue_free()
		await _frames(2)

func _hfunc(kind: String, x: float, z: float, n: FastNoiseLite, n2: FastNoiseLite) -> float:
	match kind:
		"rolling":
			return n.get_noise_2d(x * 0.5, z * 0.5) * 30.0 + 12.0
		"dunes":
			var warp := n.get_noise_2d(x * 0.3, z * 0.3) * 3.4
			var ph := x * 0.0085 + warp + z * 0.0015
			var f := ph - floorf(ph)
			var prof := pow(f / 0.8, 1.5) if f < 0.8 else (1.0 - f) / 0.2
			var amp := 20.0 + n2.get_noise_2d(x * 0.25, z * 0.25) * 8.0
			return prof * amp
		"yardang":
			var s := n.get_noise_2d(x * 0.15, z * 1.15)
			var ridge := smoothstep(-0.05, 0.38, s)
			var floor_ripple := n2.get_noise_2d(x * 3.0, z * 3.0) * 0.45
			return ridge * (26.0 + n2.get_noise_2d(x * 0.3, z * 0.3) * 8.0) + floor_ripple
		_:
			var base := n.get_noise_2d(x * 0.22, z * 0.22) * 0.5 + 0.5
			var layers := 7.0
			var q := base * layers
			var fl := floorf(q)
			var step_h := (fl + smoothstep(0.78, 1.0, q - fl)) / layers
			var gully := absf(n2.get_noise_2d(x * 0.6, z * 0.6))
			return step_h * 55.0 - (1.0 - smoothstep(0.0, 0.10, gully)) * 9.0
	return 0.0

func _heightfield(kind: String) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = 11
	n.frequency = 0.012
	n.fractal_octaves = 2
	var n2 := FastNoiseLite.new()
	n2.seed = 5
	n2.frequency = 0.02
	n2.fractal_octaves = 2
	var res := 140
	var size := 760.0
	var step := size / float(res)
	var hs: Array = []
	for j in res + 1:
		for i in res + 1:
			hs.append(_hfunc(kind, (float(i) - res * 0.5) * step, (float(j) - res * 0.5) * step, n, n2))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var cols := [Color("#d9a566"), Color("#c4854e"), Color("#9a6140"), Color("#eac98a")]
	for j in res:
		for i in res:
			var idx := [j * (res + 1) + i, j * (res + 1) + i + 1, (j + 1) * (res + 1) + i + 1, (j + 1) * (res + 1) + i]
			var pts: Array = []
			for q in idx:
				var ii: int = q % (res + 1)
				var jj: int = q / (res + 1)
				pts.append(Vector3((float(ii) - res * 0.5) * step, hs[q], (float(jj) - res * 0.5) * step))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = pts[tri[0]]
				var b: Vector3 = pts[tri[1]]
				var c: Vector3 = pts[tri[2]]
				var nrm := (b - a).cross(c - a).normalized()
				var h := (a.y + b.y + c.y) / 3.0
				var col: Color = cols[0].lerp(cols[3], clampf(h / 28.0, 0.0, 1.0))
				col = col.lerp(cols[2], clampf((1.0 - absf(nrm.y)) * 1.6, 0.0, 0.7))
				col = col.lightened(0.03 * float((i * 7 + j * 13) % 3))
				for p in [a, b, c]:
					st.set_color(col)
					st.add_vertex(p)
	st.generate_normals()
	return st.commit()
