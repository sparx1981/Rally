class_name Car
extends Node3D
## Arcade rally car on the flat paper ground. Kinematic yaw from steering, friction-limited lateral
## grip (so cars slide and drift when demand exceeds grip), handbrake turns, auto gearbox.
## Car forward is +Z in local space; heading h rotates +Z toward +X.

signal gear_changed(gear: int, previous: int)
signal impact(strength: float)
signal landed(strength: float)
signal compressed(strength: float)
signal splashed(strength: float)

const BASE_TOP := 33.0
const BASE_ACC := 14.5
const BASE_MU := 17.0
const BRAKE := 28.0
const HANDBRAKE_DRAG := 3.6   # was 14: stopped the car faster than the pedal and killed powerslides
const RADIUS := 1.55
const GEAR_TORQUE := [1.0, 1.0, 0.88, 0.77, 0.69, 0.62]
const GEARS := [0.0, 8.0, 14.0, 20.0, 26.0, 31.0]
const GRAVITY := 22.0
const MAX_LAUNCH_VY := 4.2

var stats: Dictionary
var driver_name := ""
var is_player := false
var number := 1
var track: Track
var stage: Stage

var pos := Vector2.ZERO
var h := 0.0
var vel := Vector2.ZERO
var yaw_rate := 0.0
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var handbrake := 0.0
var frozen := true

var track_i := 0
var s := 0.0
var lat := 0.0
var on_road := true
var slip := 0.0
var v_long := 0.0
var gear := 1
var _transmission_ratio := 1.0
var rpm := 900.0
var acoustic_rpm := 900.0
var finished := false
var joker_taken := false   # rallycross: has used the Joker lane this race
var lap := 0               # completed laps
var laps_total := 0
var joker_penalty := 0.0
var finish_time := -1.0
var surface := 1.0
var in_puddle := false
var in_water := false
var patch_kind := ""
var y := 0.0
var vy := 0.0
var airborne := false
var air_time := 0.0
var half_len := 2.0
var half_wid := 0.95
var wheel_r := 0.4
var head_pos := Vector3(0.35, 1.3, 0)
var lamp_pos := Vector3(0, 0.6, 2.0)
var model_root: Node3D
var _model: Dictionary
var _mat: Material
var _cockpit: Dictionary = {}
var _trip_centikm := -1
var _lights: Array = []
var _prev_gh := 0.0
var _slope := 0.0
var _suspension_offset := Vector2.ZERO
var _suspension_velocity := Vector2.ZERO
var _suspension_pose := Vector3.ZERO
var _previous_pose := Vector3.ZERO
var render_fraction := 1.0
var _wheel_base := PackedVector3Array()
var _has_prev_gh := false

var _body: Node3D
var _wheels: Array = []
var _spin := 0.0
var _dust: CPUParticles3D
var _last_puddle := false
var _contact: MeshInstance3D
var _rival_engine: RecordedEngine


func setup(car_stats: Dictionary, num: int, stg: Stage, mat: Material) -> void:
	stats = car_stats
	number = num
	stage = stg
	track = stg.track
	var compliant: bool = stg.def.loc_id in ["moor","canyon","gorge","pinewood","meadow","lakes","taiga"]
	suspension_travel = (0.16 if compliant else 0.10) + 0.06*float(stats.offroad)
	var m := CarModel.build(stats, num, mat)
	add_child(m["root"])
	_body = m["body"]
	_wheels = m["wheels"]
	for wheel in _wheels:
		_wheel_base.append(wheel.position)
	half_len = float(m["length"]) * 0.5
	half_wid = float(m["width"]) * 0.5
	wheel_r = float(m["wheel_r"])
	head_pos = m["head"]
	lamp_pos = m["lamp"]
	model_root = m["root"]
	_model = m
	_mat = mat
	_make_contact()
	_make_dust()
	_make_wheel_debris()
	_make_rear_lamps()
	if not is_player:
		# AI engines are positional: you hear rivals close behind and alongside.
		_rival_engine = RecordedEngine.new(self, stats.style, false, Vector3(0, 0.45, -half_len + 0.13))


const SHADOW_DIVISIONS := 4
var _contact_mesh: ImmediateMesh
var _contact_ink: ShaderMaterial
var _shadow_pos := Vector2.INF
var _shadow_heading := INF


func _make_contact() -> void:
	_contact_mesh = ImmediateMesh.new()
	_contact_ink = ShaderMaterial.new()
	_contact_ink.shader = preload("res://shaders/contact_shadow.gdshader")
	_contact_ink.set_shader_parameter("ink", Color(stage.wx.leak).lerp(Color("#403d44"), 0.72))
	var axle: Vector3 = _wheels[0].position
	_contact_ink.set_shader_parameter("wheel_center", Vector2(axle.x / (half_wid * 2.36), axle.z / (half_len * 2.16)))
	_contact = MeshInstance3D.new()
	_contact.mesh = _contact_mesh
	_contact.material_override = _contact_ink
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact)
	_contact.top_level = true


func _update_contact() -> void:
	var ground := track.surface_height(pos, s, lat)
	var lift := maxf(0.0, y - ground)
	_contact.visible = not in_water and not in_puddle and (on_road or not track.overlaps_water(pos, 0.0)) and ground > track.terrain.sea_y and lift < 2.1
	if not _contact.visible:
		return
	_contact_ink.set_shader_parameter("opacity", 0.26 * (1.0 - smoothstep(0.12, 2.1, lift)))
	if pos.distance_squared_to(_shadow_pos) < 0.035 and absf(angle_difference(_shadow_heading, h)) < 0.045:
		return
	_shadow_pos = pos
	_shadow_heading = h
	_contact.global_position = Vector3(pos.x, ground, pos.y)
	var forward := fwd()
	var right := right_axis()
	var course := track.tang[track_i]
	var normal := track.nrm[track_i]
	var vertices := PackedVector3Array()
	for row in SHADOW_DIVISIONS + 1:
		for col in SHADOW_DIVISIONS + 1:
			var uv := Vector2(col, row) / SHADOW_DIVISIONS
			var offset := right * (uv.x - 0.5) * half_wid * 2.36 + forward * (uv.y - 0.5) * half_len * 2.16
			var station := s + offset.dot(course)
			var lateral := lat + offset.dot(normal)
			var on_deck := absf(lateral) <= track.road_half_width(station) + 0.1
			var surface_y := track.surface_height(pos + offset, station, lateral)
			vertices.append(Vector3(offset.x, surface_y - ground + (Stage.ROAD_Y if on_deck else 0.0) + 0.035, offset.y))
	_contact_mesh.clear_surfaces()
	_contact_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride := SHADOW_DIVISIONS + 1
	for row in SHADOW_DIVISIONS:
		for col in SHADOW_DIVISIONS:
			var i := row * stride + col
			for vertex: int in [i, i + stride, i + 1, i + 1, i + stride, i + stride + 1]:
				_contact_mesh.surface_set_uv(Vector2(vertex % stride, vertex / stride) / SHADOW_DIVISIONS)
				_contact_mesh.surface_add_vertex(vertices[vertex])
	_contact_mesh.surface_end()


## Brake lights (bright red) and reversing lights (white): glowing lamp faces on the tail plus a
## small light that washes the road behind.
var _brake_lamps: Array = []
var _rev_lamps: Array = []
var _brake_light: OmniLight3D
var _rev_light: OmniLight3D


func _make_rear_lamps() -> void:
	var lamp: Vector3 = _model["lamp"]
	var y := lamp.y + 0.04
	var z := -half_len - 0.03
	var mk := func(col: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		return m
	var red: StandardMaterial3D = mk.call(Color(1.0, 0.16, 0.1))
	var white: StandardMaterial3D = mk.call(Color(1.0, 0.98, 0.92))
	for index in 2:
		var xs := -1.0 if index == 0 else 1.0
		var lens := Rect2(Vector2(xs*half_wid*0.68,y),Vector2(0.30,0.12))
		if not _model.rear_lenses.is_empty():
			lens = _model.rear_lenses[index]
		var bm := BoxMesh.new()
		bm.size = Vector3(lens.size.x*0.83, lens.size.y*0.78, 0.024)
		var b := MeshInstance3D.new()
		b.mesh = bm
		b.material_override = red
		b.position = Vector3(lens.position.x,lens.position.y,z-0.01)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		_body.add_child(b)
		_brake_lamps.append(b)
		var rm := BoxMesh.new()
		rm.size = Vector3(0.1, 0.08, 0.03)
		var r := MeshInstance3D.new()
		r.mesh = rm
		r.material_override = white
		r.position = Vector3(lens.position.x - signf(lens.position.x)*(lens.size.x*0.5+0.045),lens.position.y,z)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		_body.add_child(r)
		_rev_lamps.append(r)
	_brake_light = OmniLight3D.new()
	_brake_light.light_color = Color("#ff3a24")
	_brake_light.light_energy = 1.4
	_brake_light.omni_range = 4.5
	_brake_light.position = Vector3(0, y, z - 0.5)
	_brake_light.visible = false
	_body.add_child(_brake_light)
	_rev_light = OmniLight3D.new()
	_rev_light.light_color = Color("#fff4e0")
	_rev_light.light_energy = 1.6
	_rev_light.omni_range = 6.0
	_rev_light.position = Vector3(0, y, z - 0.6)
	_rev_light.visible = false
	_body.add_child(_rev_light)


func _update_rear_lamps() -> void:
	var braking := service_brake > 0.08 and not frozen
	var reversing := gear == 0 and not frozen
	for b in _brake_lamps:
		b.visible = braking
	for r in _rev_lamps:
		r.visible = reversing
	_brake_light.visible = braking
	_rev_light.visible = reversing


## Low chase view sits right behind the car: keep the player's own dust and spray low and small
## so the car stays visible through it.
var _low_view := false
func set_low_view(on: bool) -> void:
	if on == _low_view:
		return
	_low_view = on
	if _dust:
		_dust.scale_amount_min = _dust.get_meta("full_min") * (0.45 if on else 1.0)
		_dust.scale_amount_max = _dust.get_meta("full_max") * (0.45 if on else 1.0)
		_dust.amount = int(_dust.get_meta("full_count")) * (0.6 if on else 1.0)



## Grip of a surface patch under this car. Rallycross loose surfaces start the race watered (like
## watered mud) and dry out lap by lap, faster on the racing line than off it; stepping off the line
## costs 15 percent; and a change of surface is eased in over about 0.15 s.
var _rx_grip := 1.0


func _patch_grip(patch: Dictionary, lateral: float) -> float:
	var g := float(patch.get("grip", 1.0))
	if not patch.get("rx", false) or patch["kind"] == "tarmac":
		return g
	var hw := track.road_half_width(s)
	var on_line := absf(lateral) < hw * 0.4
	var wet := 0.12 * maxf(0.0, 1.0 - (0.18 if on_line else 0.08) * float(lap))   # lap 1 is damp, not mud-slick
	if patch["kind"] != "ford" and patch["kind"] != "mud":
		g = lerpf(g, float(Rallycross.SURFACES["mud"].grip), wet)
	if not on_line:
		g *= 0.85
	return g


## Small dirt, gravel and snow flicked back by the driven wheels (subtle, and only on loose ground).
var _debris: Array[CPUParticles3D] = []
var _debris_color := Color(0, 0, 0, 0)


func _make_wheel_debris() -> void:
	var split := drive_split()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.05, 0.075)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material = mat
	for i in 4:
		var driven := (split > 0.2) if i < 2 else (split < 0.8)
		if not driven:
			continue
		var p := CPUParticles3D.new()
		p.local_coords = false
		p.mesh = mesh
		p.amount = maxi(3, int(9.0 * float(Settings.g("particles"))))
		p.lifetime = 0.55
		p.explosiveness = 0.0
		p.randomness = 0.6
		p.direction = Vector3(0.0, 0.75, -1.0)
		p.spread = 26.0
		p.initial_velocity_min = 1.8
		p.initial_velocity_max = 4.2
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.5
		p.angular_velocity_min = -300.0
		p.angular_velocity_max = 300.0
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.emitting = false
		var wp: Vector3 = _wheel_base[i]
		p.position = Vector3(wp.x, wheel_r * 0.55, wp.z - wheel_r * 0.9)
		_body.add_child(p)
		_debris.append(p)


## Colour of what the tyres are throwing, or alpha 0 on tarmac.
func _loose_color() -> Color:
	if patch_kind != "" and Rallycross.SURFACES.has(patch_kind):
		return Color(0, 0, 0, 0) if patch_kind == "tarmac" else Color(Rallycross.SURFACES[patch_kind].color).darkened(0.1)
	match patch_kind:
		"mud": return Color("#5a4632")
		"ice", "deep snow": return Color("#eef2f7")
	if not on_road:
		return Color(stage.def.pal.ground).darkened(0.35)
	match stage.kind():
		"snow": return Color("#eef2f7")
		"rain": return Color("#5a4632")
	return Color(stage.def.pal.road).darkened(0.12)


func _update_wheel_debris() -> void:
	if _debris.is_empty():
		return
	var col := _loose_color()
	var on := col.a > 0.0 and throttle > 0.25 and absf(v_long) > 3.0 and not airborne and not in_water and not frozen
	if col != _debris_color and col.a > 0.0:
		_debris_color = col
		for p in _debris:
			p.color = col
	for p in _debris:
		p.emitting = on
		p.speed_scale = clampf(0.7 + absf(v_long) / 30.0 + slip, 0.7, 1.8)


func _make_dust() -> void:
	var kind := stage.kind()
	var pal: Dictionary = stage.def["pal"]
	var leak: Color = stage.wx["leak"]
	var col: Color
	var k := "dust"
	if kind == "snow":
		col = Color(0.95, 0.96, 1.0)
		k = "snow"
	elif kind == "rain":
		col = Color(pal["road"]).lerp(Color(0.8, 0.84, 0.88), 0.55)
		k = "spray"
	else:
		col = Color(pal["road"]).lightened(0.5)
	_dust = Puffs.make(k, col, leak)
	_dust.set_meta("full_min",_dust.scale_amount_min)
	_dust.set_meta("full_max",_dust.scale_amount_max)
	_dust.set_meta("full_count",_dust.amount)
	_dust.emitting = false
	_dust.position = Vector3(0, 0.3, -half_len)
	add_child(_dust)
	_smoke = Puffs.make("exhaust", Color(0.55, 0.53, 0.52), leak)
	_smoke.emitting = false
	# Smoke comes out of the exhaust tip the model actually has.
	_smoke.position = _model.get("exhaust", Vector3(-0.45, 0.3, -half_len - 0.1))
	_body.add_child(_smoke)


var _smoke: CPUParticles3D
var _spray: CPUParticles3D
var _bow_wakes: Array[CPUParticles3D] = []
var _ford_depth := 0.0
var _smoke_t := 0.0


## A big volumetric burst of water when driving through a splash.
func spray(v: float) -> void:
	if _spray == null:
		_spray = Puffs.make("splash", Color("#dde7ec"), stage.wx["leak"])
		_spray.set_meta("full_min", _spray.scale_amount_min)
		_spray.set_meta("full_max", _spray.scale_amount_max)
		_spray.position = Vector3(0, 0.3, 0.6)
		add_child(_spray)
	var puff_scale := 0.45 if _low_view else 1.0
	_spray.scale_amount_min = _spray.get_meta("full_min") * puff_scale
	_spray.scale_amount_max = _spray.get_meta("full_max") * puff_scale
	_spray.amount = roundi(clampi(int(v * 2.0), 20, 60) * (0.6 if _low_view else 1.0))
	_spray.initial_velocity_max = 4.0 + v * 0.3
	_spray.restart()


## A puff of exhaust smoke (backfires, launches).
func exhaust_puff(dur := 0.25) -> void:
	_smoke_t = maxf(_smoke_t, dur)


## Headlights (and a little red tail glow) for dusk and night. Only the player's beam casts
## shadows, to keep phones fast.
func enable_lights(shadows: bool, night := false) -> void:
	# Two dipped-beam headlamps: a wide, soft-edged spread that lights the road ahead and the verges,
	# brightest close in and fading with distance (no hard central hot-spot).
	var lamp: Vector3 = _model["lamp"]
	var mounts: PackedVector3Array = _model.beam_mounts
	for i in mounts.size():
		var mount := mounts[i]
		var main_lens := mount.z >= half_len - 0.10
		var sl := SpotLight3D.new()
		sl.light_color = Color("#ffe6c0")
		sl.light_energy = (14.0 if night else 4.8) / mounts.size()
		sl.spot_range = 60.0 if night else 38.0
		sl.spot_angle = 36.0 if main_lens else 22.0
		sl.spot_angle_attenuation = 2.6
		sl.spot_attenuation = 0.85 if night else 1.4
		sl.shadow_enabled = shadows and main_lens and (i == 0 or (i > 0 and mount.x*mounts[i-1].x < 0))
		sl.shadow_bias = 0.08
		sl.position = mount
		sl.rotation = Vector3(-0.085, PI + signf(mount.x)*0.035, 0.0)
		_body.add_child(sl)
		_lights.append(sl)
	var tail := OmniLight3D.new()
	tail.light_color = Color("#ff5a3a")
	tail.light_energy = 0.7
	tail.omni_range = 4.0
	tail.position = Vector3(0, lamp.y, -half_len - 0.4)
	_body.add_child(tail)
	_lights.append(tail)


func set_headlight_level(level: float) -> void:
	for node in _lights:
		var light := node as Light3D
		if not light.has_meta("full_energy"):
			light.set_meta("full_energy", light.light_energy)
		light.visible = level > 0.004
		light.light_energy = float(light.get_meta("full_energy")) * level


## Sync the visible car to the physics state now (before the camera follows it), so fast-moving
## close cameras never lag a frame behind.
func sync_now() -> void:
	position = Vector3(pos.x, y + (Stage.ROAD_Y if on_road else 0.0), pos.y)
	rotation.y = h


var _pristine_shell: PackedVector3Array
var _damage_count := 0


## Press the actual bodywork and its printed detail inward around the contact point.
func add_damage(at: Vector2, strength: float) -> void:
	if _body == null or strength <= 4.0 or _damage_count >= 20:
		return
	var shell := _body.get_child(0) as MeshInstance3D
	var arrays := shell.mesh.surface_get_arrays(0)
	var before: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertices := before.duplicate()
	if _pristine_shell.is_empty():
		_pristine_shell = vertices.duplicate()
	var local := at - pos
	var x := clampf(local.dot(right_axis()), -half_wid, half_wid)
	var z := clampf(local.dot(fwd()), -half_len, half_len)
	var side_hit := absf(x) / half_wid > absf(z) / half_len
	var outward := Vector3(signf(x), 0, 0) if side_hit else Vector3(0, 0, signf(z))
	var center := Vector3(x, _model["lamp"].y, z)
	if side_hit:
		center.x = outward.x * half_wid
	else:
		center.z = outward.z * half_len
	var crush := clampf(strength * 0.012, 0.06, 0.24)
	var radius := 0.75 + crush * 2.2
	for i in vertices.size():
		var original := _pristine_shell[i]
		vertices[i] = _crush_point(original, vertices[i], center, outward, radius, crush)
	for light in _brake_lamps + _rev_lamps + _lights:
		if not light.has_meta("undamaged_position"):
			light.set_meta("undamaged_position", light.position)
		light.position = _crush_point(light.get_meta("undamaged_position"), light.position, center, outward, radius, crush)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, vertices.size(), 3):
		if vertices[i] == before[i] and vertices[i + 1] == before[i + 1] and vertices[i + 2] == before[i + 2]:
			continue
		var normal := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
		if normal.length_squared() > 0.5:
			if normal.dot(normals[i]) < 0.0:
				normal = -normal
			normals[i] = normal
			normals[i + 1] = normal
			normals[i + 2] = normal
			for v in range(i,i+3):
				var shift := before[v].distance_to(vertices[v])
				if shift > 0.035 and normals[v].dot(outward)>0.35:
					var value := colors[v]
					var wear := smoothstep(0.035,0.18,shift)*0.30
					colors[v] = value.lerp(Color(0.28,0.24,0.20,value.a),wear)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var dented := ArrayMesh.new()
	dented.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	shell.mesh = dented
	var nose := _cockpit.get("nose") as MeshInstance3D
	if nose:
		nose.mesh = CarModel.cockpit_nose(dented, _cockpit["nose_clip"])
	_damage_count += 1


func _crush_point(original: Vector3, current: Vector3, center: Vector3, outward: Vector3, radius: float, crush: float) -> Vector3:
	var offset := original - center
	offset.y *= 1.55
	if offset.length_squared() >= radius * radius:
		return current
	var falloff := 1.0 - smoothstep(0.0, radius, offset.length())
	var displacement := current - original + (-outward + Vector3.UP * 0.20) * crush * falloff
	return original + displacement.limit_length(0.30)


## The in-car view rig (dashboard, wheel, rev needle), shown only in the cockpit camera.
func cockpit(show: bool) -> void:
	if show and _cockpit.is_empty():
		_cockpit = CarModel.build_cockpit(stats, _model, _mat)
		_body.add_child(_cockpit["root"])
	if not _cockpit.is_empty():
		_cockpit["root"].visible = show
	var body_mesh: Node3D = _body.get_child(0)
	# The open buggy's cage, exposed wheels and nose are visible from its seat.
	var exterior_visible: bool = not show or stats["style"] == "buggy"
	body_mesh.visible = exterior_visible
	for wnode in _wheels:
		(wnode as Node3D).visible = exterior_visible


## Where the driver's eyes are (for the cockpit camera).
func eye_transform() -> Transform3D:
	# A touch forward and up from the seat back: a clear view over the dash, still inside the cabin.
	var hp: Vector3 = _model["head"] + Vector3(0.0, 0.045, -0.025)
	return global_transform * _body.transform * Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.045), hp)


## Bonnet camera mount: above the front of the bonnet, ahead of any lamp pod.
func bonnet_transform() -> Transform3D:
	var lamp: Vector3 = _model["lamp"]
	var mount := Vector3(0.0, lamp.y + 0.75, lamp.z - 0.25)
	return global_transform * _body.transform * Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.06), mount)


func place_at(s_pos: float, lateral: float) -> void:
	s_pos = track.route_station(s_pos)
	var i := track.index_at(s_pos)
	pos = track.point_at(s_pos) + track.nrm[i] * lateral
	h = track.heading_at(i)
	vel = Vector2.ZERO
	yaw_rate = 0.0
	track_i = i
	s = s_pos
	lat = lateral
	y = track.surface_height(pos, s_pos, lateral)
	vy = 0.0
	longitudinal_accel = 0.0
	rear_lock = 0.0
	_suspension_offset = Vector2.ZERO
	_suspension_velocity = Vector2.ZERO
	_suspension_pose = Vector3.ZERO
	_previous_pose = Vector3.ZERO
	_reverse_hold = 0.0
	service_brake = 0.0
	contact_pitch = track.grade_along(pos,s,lat,fwd())
	gear = 1
	_transmission_ratio = 1.0
	rpm = 900.0
	acoustic_rpm = 900.0
	v_long = 0.0
	slip = 0.0
	_prev_gh = y
	_has_prev_gh = false
	air_time = 0.0
	airborne = false
	wheel_height.fill(y)
	_sync_visual(0.0)


func reset_to_track() -> void:
	var hit: Array = track.project(pos, track_i, y)
	var back := float(hit[1]) - 4.0
	place_at(back if track.circuit else maxf(back, 2.0), 0.0)


func fwd() -> Vector2:
	return Vector2(sin(h), cos(h))


func right_axis() -> Vector2:
	return Vector2(cos(h), -sin(h))


func speed() -> float:
	return vel.length()


func top_speed() -> float:
	return BASE_TOP * float(stats["top"])


## Wheel forces are expressed as acceleration per unit vehicle mass.
var wheel_grip := PackedFloat32Array([1,1,1,1])
var _tyre_dirt := 0.0   # 0..1: how much loose surface the tyres carry onto tarmac
var wheel_load := PackedFloat32Array([0.25,0.25,0.25,0.25])
var wheel_height := PackedFloat32Array([0,0,0,0])
var wheel_loose := PackedByteArray([0,0,0,0])
var longitudinal_force := Vector2.ZERO
var lateral_capacity := Vector2.ZERO
var axle_demand := Vector2.ZERO
var axle_slip := Vector2.ZERO
var longitudinal_accel := 0.0
var wheel_surface := PackedStringArray(["road", "road", "road", "road"])
var front_weight := 0.53
var lateral_force := Vector2.ZERO
var service_brake := 0.0
var _reverse_hold := 0.0
var contact_pitch := 0.0
var rear_lock := 0.0
var traction_yaw := 0.0
var _edge_spray: Array[CPUParticles3D] = []
var suspension_travel := 0.15
var _bump_cooldown := 0.0
var telemetry_enabled := false
signal handling_sample(data: Dictionary)

func drive_split() -> float:
	match stats.drive:
		"fwd": return 1.0
		"rwd": return 0.0
	return float(stats.get("front_split", 0.48))

func profile_acceleration() -> float:
	var split := drive_split()
	var traction := BASE_MU * stage.grip() * float(stats.grip)
	return minf(BASE_ACC * float(stats.accel), traction * (0.52 if split == 1.0 else (0.56 if split == 0.0 else 1.0)))

func profile_braking() -> float:
	return minf(BRAKE, BASE_MU * stage.grip() * float(stats.grip))


func _sample_wheels(dt: float) -> void:
	var forward := fwd()
	var right := right_axis()
	var course := track.tang[track_i]
	var normal := track.nrm[track_i]
	var wheelbase := 2.0 * _wheel_base[0].z
	front_weight = clampf(0.53 - longitudinal_accel * 0.44 / (9.81 * wheelbase), 0.28, 0.76)
	var roll_load := clampf(-yaw_rate * v_long * 0.013, -0.22, 0.22)
	for i in 4:
		var point: Vector3 = _wheel_base[i]
		var offset := forward * point.z + right * point.x
		var station := clampf(track.route_station(s + offset.dot(course)), 0.0, track.length)
		var lateral := lat + offset.dot(normal)
		var loose := not track.on_road_at(station, lateral, 0.0)
		var patch := track.patch_at(station, lateral)
		var label: String = patch.get("kind", "verge" if loose else "road")
		wheel_surface[i] = label
		wheel_loose[i] = int(loose or label in ["mud", "gravel", "deep snow", "ice"])
		wheel_grip[i] = stage.grip() * (lerpf(0.72, 0.95, stats.offroad) if loose else 1.0) * _patch_grip(patch, lateral)
		wheel_height[i] = track.surface_height(pos + offset, station, lateral)

	var front_h := (wheel_height[0] + wheel_height[1]) * 0.5
	var rear_h := (wheel_height[2] + wheel_height[3]) * 0.5
	var ground_pitch := clampf((front_h - rear_h) / wheelbase, -0.55, 0.55)
	contact_pitch = lerpf(contact_pitch, ground_pitch, minf(dt * 18.0, 1.0))
	_previous_pose = _suspension_pose
	_step_suspension(Vector2(front_h, rear_h) - Vector2.ONE * y, wheelbase, dt)

	# On a banked road the body leans with the cross-slope, so the low-side wheels stay loaded.
	var cross_slope := track.bank_slope(track_i) * right.dot(normal)
	for i in 4:
		var point: Vector3 = _wheel_base[i]
		var gap := y + _suspension_pose.x + point.z * (contact_pitch - _suspension_pose.y) + point.x * cross_slope - wheel_height[i]
		var support := (1.0 - smoothstep(suspension_travel * 0.25, suspension_travel, gap)) * clampf(1.0 - gap * 1.2, 0.82, 1.20)
		var axle_weight := front_weight if i < 2 else 1.0 - front_weight
		wheel_load[i] = support * axle_weight * (0.5 + signf(point.x) * roll_load)
	var side_load := wheel_load[0] + wheel_load[2] - wheel_load[1] - wheel_load[3]
	_suspension_pose.z = lerpf(_suspension_pose.z, clampf(-side_load * 0.13, -0.055, 0.055), minf(dt * 10.0, 1.0))


func _step_suspension(ground: Vector2, wheelbase: float, dt: float) -> void:
	var travel := suspension_travel
	var static_pitch := contact_pitch * wheelbase * 0.5
	var weight_shift := (front_weight - 0.53) * 0.14
	var target := ground - Vector2(static_pitch + weight_shift, -static_pitch - weight_shift)
	_bump_cooldown = maxf(0.0, _bump_cooldown - dt)
	for axle in 2:
		var desired := clampf(target[axle], -travel, travel)
		var offset := _suspension_offset[axle]
		var velocity := _suspension_velocity[axle]
		var damping := 14.0 if velocity > 0.0 else 20.0
		var stop := maxf(absf(offset) - travel * 0.67, 0.0) * signf(offset)
		velocity += ((desired - offset) * (23.0 / travel) - damping * velocity - stop * 420.0) * dt
		var next := clampf(offset + velocity * dt, -travel, travel)
		_suspension_offset[axle] = next
		_suspension_velocity[axle] = (next - offset) / dt
		if not airborne and velocity > 0.68 and desired > travel * 0.48 and _bump_cooldown <= 0.0:
			compressed.emit(clampf(velocity * 0.19, 0.13, 0.46))
			_bump_cooldown = 0.28
	_suspension_pose.x = (_suspension_offset.x + _suspension_offset.y) * 0.5
	_suspension_pose.y = clampf((_suspension_offset.y - _suspension_offset.x) / wheelbase, -0.11, 0.11)


func _axle_forces(vl: float, thr: float, brk: float, hb: float, dt: float) -> float:
	var split := drive_split()
	_transmission_ratio = move_toward(_transmission_ratio, float(GEAR_TORQUE[gear]), dt * 2.0)
	var ratio := _transmission_ratio
	var torque := 0.87 + 0.21*sin(PI*clampf((rpm-900.0)/6300.0,0.0,1.0))
	var drive := BASE_ACC * float(stats.accel) * ratio * torque * thr * clampf(1.0-pow(maxf(vl,0.0)/top_speed(),2.0),0.0,1.0)
	if brk > 0.08 and thr < 0.05 and absf(vl) < 0.65:
		_reverse_hold += dt
	elif brk <= 0.08 or thr >= 0.05 or vl >= 0.65:
		_reverse_hold = 0.0
	var reverse := _reverse_hold >= 0.22 and vl <= 0.12
	if reverse:
		drive = -brk * 8.0 * clampf(1.0 + vl / 9.0, 0.0, 1.0)
	service_brake = 0.0 if reverse else brk
	if service_brake > 0.0:
		drive = 0.0
	if vl > 1.0 and thr < 0.05 and service_brake == 0.0:
		drive -= ratio * 1.3
	rear_lock = move_toward(rear_lock,hb,dt*(12.0 if hb>rear_lock else 3.8))
	var bias := float(stats.get("differential_bias",1.0))
	traction_yaw = 0.0
	var limits := Vector2.ZERO
	var capacities := Vector4.ZERO
	for i in 4:
		capacities[i] = wheel_load[i] * wheel_grip[i] * BASE_MU * float(stats.grip)
	for axle in 2:
		var right := capacities[axle * 2]
		var left := capacities[axle * 2 + 1]
		limits[axle] = minf(right + left, minf(right, left) * (1.0 + bias))
	var engine_demand := Vector2(split, 1.0 - split) * drive
	if split > 0.0 and split < 1.0:
		# Limited centre transfer sends some surplus torque to the axle with
		# reserve grip, while the sum of both demands stays at engine output.
		var spare := limits - engine_demand.abs()
		var transfer := clampf(spare.y, 0.0, maxf(0.0, -spare.x)) - clampf(spare.x, 0.0, maxf(0.0, -spare.y))
		engine_demand -= Vector2(transfer, -transfer) * signf(drive) * 0.48
	for axle in 2:
		var a := capacities[axle * 2]
		var b := capacities[axle * 2 + 1]
		var engine := engine_demand[axle]
		var axle_limit := limits[axle]
		var service := service_brake * BRAKE * (0.64 if axle == 0 else 0.36) * signf(vl) if absf(vl) > 0.03 else 0.0
		# The handbrake locks the rears for rotation, not for stopping: a modest drag lets slides carry speed.
		var parking := rear_lock * HANDBRAKE_DRAG * signf(vl) if axle == 1 and absf(vl) > 0.2 else 0.0
		axle_demand[axle] = engine-service-parking
		var transmitted := clampf(engine,-axle_limit,axle_limit)
		# Start with equal wheel torque. An LSD can transfer unmet torque to
		# the wheel with more grip, up to the axle torque-bias limit above.
		var right_force := clampf(transmitted*0.5,-a,a)
		var left_force := clampf(transmitted-right_force,-b,b)
		right_force = clampf(transmitted-left_force,-a,a)
		right_force = clampf(right_force-(service+parking)*0.5,-a,a)
		left_force = clampf(left_force-(service+parking)*0.5,-b,b)
		longitudinal_force[axle] = right_force+left_force
		traction_yaw += (left_force-right_force)*half_wid / ((half_len*half_len+half_wid*half_wid)/3.0)
		axle_slip[axle] = clampf(absf(axle_demand[axle]-longitudinal_force[axle])/maxf(1.0,a+b),0,1)
		lateral_capacity[axle] = sqrt(maxf(0.0,a*a-right_force*right_force))+sqrt(maxf(0.0,b*b-left_force*left_force))
		if axle==1:
			lateral_capacity.y *= 1.0-0.85*rear_lock
	return longitudinal_force.x+longitudinal_force.y


func step(dt: float) -> void:
	var hit: Array = track.project(pos, track_i, y)
	track_i = hit[0]
	s = hit[1]
	lat = hit[2]
	on_road = track.on_road_at(s, lat)
	var wgrip := stage.grip()
	if track.rx:
		wgrip = lerpf(1.0, wgrip, 0.5)   # lap wetness already models the damp; don't count rain twice
	var offroad: float = stats.get("offroad", 0.3)
	surface = wgrip * (1.0 if on_road else lerpf(0.8, 0.97, offroad))
	# Loose surface patches (gravel / mud / ice / deep snow).
	var patch := track.patch_at(s, lat)
	var patch_drag := 0.0
	patch_kind = ""
	if not patch.is_empty():
		patch_kind = patch["kind"]
		_rx_grip = move_toward(_rx_grip, _patch_grip(patch, lat), dt / 0.15 * 0.4) if patch.get("rx", false) else 1.0
		surface *= _rx_grip if patch.get("rx", false) else _patch_grip(patch, lat)
		patch_drag = float(patch["drag"])
		patch_drag *= lerpf(1.0, 0.4, offroad)
		if patch.get("rx", false):
			# Dirty tyres: leaving loose ground onto tarmac starts at 0.88 grip and recovers over seconds.
			var loose_rx: bool = patch["kind"] != "tarmac"
			_tyre_dirt = move_toward(_tyre_dirt, 1.0 if loose_rx else 0.0, dt / (0.4 if loose_rx else 3.2))
			if not loose_rx:
				surface *= 1.0 - 0.12 * _tyre_dirt
	# Water splash: heavy drag, a burst of spray.
	var water := track.inside_ford(pos, s)
	if water and not in_water and speed() > 1.0:
		splashed.emit(absf(vel.dot(fwd())))
	in_water = water
	_ford_depth = maxf(0.0,float(track.feature_at(s,"splash",3.0).water_y)-track.surface_height(pos,s,lat)-Stage.ROAD_Y) if water else 0.0
	# Vertical: follow the road over crests and ramps; leave it when it falls away faster than gravity.
	var gh := track.surface_height(pos, s, lat)
	var ground_vy := (gh - _prev_gh) / dt if _has_prev_gh else 0.0
	_prev_gh = gh
	_has_prev_gh = true
	if airborne:
		air_time += dt
		# Air drag on the horizontal speed, and stronger gravity on long flights.
		vel *= 1.0 - 0.12 * dt
		vy -= GRAVITY * dt * (1.0 if air_time < 0.8 else 1.8)
		y += vy * dt
		if y <= gh:
			var hit_v := ground_vy - vy
			y = gh
			vy = ground_vy
			airborne = false
			if air_time > 0.12:
				landed.emit(hit_v)
				_suspension_velocity -= Vector2.ONE * clampf(hit_v * 0.10, 0.0, 1.0)
	else:
		# Ballistic if the ground drops away faster than gravity can pull the car down.
		var predicted := y + vy * dt - 0.5 * GRAVITY * dt * dt
		if gh < predicted - 0.02 and vy > ground_vy + 0.5:
			airborne = true
			air_time = 0.0
			# Cap the launch so ramps and crests give a short, controlled hop, never a fling.
			vy = minf(vy, MAX_LAUNCH_VY)
			vy -= GRAVITY * dt
			y += vy * dt
		else:
			vy = ground_vy
			y = gh
	var grounded := 0.0 if airborne else 1.0
	var f := fwd()
	var r := right_axis()
	var vl := vel.dot(f)
	var vt := vel.dot(r)
	var thr := 0.0 if frozen else throttle
	var brk := 0.0 if frozen else brake
	var hb := 1.0 if frozen else handbrake
	_sample_wheels(dt)
	var a := _axle_forces(vl, thr, brk, hb, dt)
	a -= vl * 0.045 + signf(vl) * 0.5
	if not on_road:
		a -= vl * lerpf(0.55, 0.12, offroad)
	if in_puddle:
		a -= vl * 0.5
	if water:
		a -= vl * 1.1
	a -= vl * patch_drag
	# Gravity along the slope: climbs cost speed, descents add it.
	if grounded > 0.0:
		a -= 9.0 * clampf(track.grade_along(pos, s, lat, f) , -0.4, 0.4)
	longitudinal_accel = lerpf(longitudinal_accel,a,minf(dt*10.0,1.0))
	var nvl := vl + a * dt
	if vl != 0.0 and signf(nvl) != signf(vl):
		nvl = 0.0
	if absf(nvl) < 0.15 and thr == 0.0 and brk == 0.0:
		nvl = 0.0
	vl = nvl
	vel = f * vl + r * vt
	# Steering: yaw rate target falls off with speed; reverses when reversing.
	var sp := absf(vl)
	var sf := clampf(sp / 4.0, 0.0, 1.0)
	var lim := float(stats["steer"]) * 2.5 / (1.0 + sp / 24.0)
	var balance := (lateral_capacity.x - lateral_capacity.y) / maxf(2.0,lateral_capacity.x+lateral_capacity.y)
	var target_w := -steer * lim * sf * (1.0 if vl >= 0.0 else -1.0) * clampf(1.0+balance*0.32,0.70,1.30)
	if hb > 0.0 and not frozen:
		target_w *= 1.0 + 0.95 * hb * smoothstep(2.0, 9.0, sp)
	var resp := clampf(dt * (5.0 + 4.0 * surface), 0.0, 1.0) * clampf((wheel_load[0]+wheel_load[1])*2.4,0.0,1.0)
	yaw_rate = lerpf(yaw_rate, target_w, resp) + traction_yaw*dt
	h += yaw_rate * dt
	# Lateral friction (limited) in the new frame.
	f = fwd()
	r = right_axis()
	vl = vel.dot(f)
	vt = vel.dot(r)
	if track.rx and grounded > 0.0:
		# Banking: gravity pulls the car down the cross-slope, so a banked corner asks less of the tyres.
		var downhill := -track.nrm[track_i] * 9.0 * clampf(track.bank_slope(track_i), -0.25, 0.25)
		vt += downhill.dot(r) * dt
		vl += downhill.dot(f) * dt
	var lateral_wish := vt / dt
	var applied_front := clampf(lateral_wish * front_weight, -lateral_capacity.x, lateral_capacity.x)
	var applied_rear := clampf(lateral_wish - applied_front, -lateral_capacity.y, lateral_capacity.y)
	lateral_force = Vector2(clampf(lateral_wish - applied_rear, -lateral_capacity.x, lateral_capacity.x), applied_rear)
	var removed := (lateral_force.x + lateral_force.y) * dt
	vt -= removed
	vt *= 1.0 - clampf(dt * lerpf(0.6, 0.30, hb), 0.0, 1.0)
	# Sliding scrubs speed; a little lateral energy carries forward (rally momentum).
	slip = clampf(absf(vt) / maxf(absf(vl), 4.0), 0.0, 1.0)
	vl *= 1.0 - slip * 0.35 * dt
	vl += absf(removed) * 0.12 * signf(vl)
	vel = f * vl + r * vt
	v_long = vl
	pos += vel * dt
	_update_gear(vl, thr)
	if telemetry_enabled:
		handling_sample.emit({"throttle": thr, "brake": brk, "service_brake": service_brake, "steer": steer,
			"handbrake": hb, "surface": wheel_surface.duplicate(), "load": wheel_load.duplicate(),
			"grip": wheel_grip.duplicate(), "demand": axle_demand, "force": longitudinal_force,
			"slip": axle_slip, "lateral": lateral_force, "suspension": _suspension_offset})


func _update_gear(vl: float, thr: float) -> void:
	var v := absf(vl)
	var g := 1
	for i in range(1, GEARS.size()):
		if v >= GEARS[i] * float(stats["top"]) * (0.90 if gear > i else 1.0):
			g = i + 1
	g = clampi(g, 1, 5)
	if vl < -0.5:
		g = 0
	if g != gear and not frozen:
		var previous := gear
		gear = g
		gear_changed.emit(g, previous)
	var lo: float = GEARS[maxi(gear - 1, 0)] * float(stats["top"])
	var hi: float = (GEARS[gear] if gear < GEARS.size() else GEARS[-1] + 6.0) * float(stats["top"])
	var t := clampf((v - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var target := 1100.0 + t * 5800.0
	if frozen:
		target = 900.0 + thr * 5500.0
	if slip > 0.3:
		target += slip * 900.0
	rpm = lerpf(rpm, target, 0.2)
	# Exhaust pitch follows a fixed ratio in each gear. A shift drops to the
	# next ratio, while the handling model keeps its original torque curve.
	var speed_at_redline := GEARS[1] if gear == 0 else float(GEARS[gear])
	var coupled := 6900.0 * v / (speed_at_redline * float(stats.top))
	var free_rev := 900.0 + thr * 5500.0
	var clutch := smoothstep(1.0, 4.0, v)
	var driven_rpm := clampf(lerpf(minf(free_rev, 2500.0), coupled, clutch), 900.0, 7600.0)
	acoustic_rpm = lerpf(acoustic_rpm, free_rev if frozen else driven_rpm, 0.20)


func _process(delta: float) -> void:
	_sync_visual(delta)
	if _rival_engine:
		_rival_engine.mix(acoustic_rpm, throttle, lerpf(0.29, 0.74, throttle))


func _sync_visual(delta: float) -> void:
	if _brake_light:
		_update_rear_lamps()
	position = Vector3(pos.x, y + (Stage.ROAD_Y if on_road else 0.0), pos.y)
	if _contact:
		_update_contact()
	if _body == null:
		return
	# The whole car (body and wheels together) follows the slope, so nothing separates on hills.
	var slope_t := 0.0
	if airborne:
		slope_t = clampf(-vy * 0.03, -0.25, 0.25)
	else:
		slope_t = -atan(contact_pitch)
	_slope = lerpf(_slope, slope_t, clampf(delta * 8.0, 0.0, 1.0))
	rotation = Vector3(_slope, h, 0.0)
	# Body on its springs: small roll and pitch about the axle line, plus compression on landings.
	var pose := _previous_pose.lerp(_suspension_pose, render_fraction)
	var pivot := Vector3(0, wheel_r, 0)
	var bb := Basis.from_euler(Vector3(pose.y, 0.0, pose.z))
	_body.transform = Transform3D(bb, pivot - bb * pivot + Vector3(0, pose.x, 0))
	_spin += v_long * delta / wheel_r
	if not _cockpit.is_empty() and _cockpit["root"].visible:
		(_cockpit["wheel"] as Node3D).rotation.z = steer * 1.6
		(_cockpit["needle"] as Node3D).rotation.z = lerpf(-2.2, 1.8, clampf(acoustic_rpm / 7500.0, 0.0, 1.0))
		var leds: MultiMesh = _cockpit["shift_leds"]
		leds.visible_instance_count = clampi(1 + floori((acoustic_rpm - 4200.0) / 525.0), 0, 5) if gear > 0 else 0
		var gear_readout: Label3D = _cockpit["gear_readout"]
		if gear_readout:
			gear_readout.text = str(gear) if gear > 0 else "R"
			var speed_readout: Label3D = _cockpit["speed_readout"]
			speed_readout.text = str(roundi(speed() * (2.23694 if int(Settings.g("units")) == 1 else 3.6)))
		var trip_display: Label3D = _cockpit["trip_display"]
		var distance := floori(maxf(s, 0.0) / 10.0)
		if trip_display and distance != _trip_centikm:
			_trip_centikm = distance
			trip_display.text = "%.2f" % (distance * 0.01)
		var speed_hand: Node3D = _cockpit["speed_hand"]
		if speed_hand:
			speed_hand.rotation.z = lerpf(2.2, -1.8, clampf(speed() * 3.6 / 240.0, 0.0, 1.0))
	# Suspension travel: wheels droop in the air and jiggle over rough ground, within the arches.
	for i in _wheels.size():
		var wnode: Node3D = _wheels[i]
		var travel := clampf(wheel_height[i] - y - contact_pitch * _wheel_base[i].z, -suspension_travel, suspension_travel * 0.62)
		wnode.position.y = lerpf(wnode.position.y, float(_wheel_base[i].y) + travel, clampf(delta * 12.0, 0.0, 1.0))
		if i < 2:
			wnode.rotation.y = -steer * 0.45
		wnode.get_child(0).rotation.x = _spin
	_update_wheel_debris()
	# Dust / spray / snow from the wheels.
	if _dust:
		var spd := absf(v_long)
		var emit := spd > 6.0 and (slip > 0.12 or not on_road or stage.kind() != "dry" or spd > 18.0)
		_dust.emitting = emit and not airborne and not in_water
		_dust.speed_scale = clampf(0.7 + slip, 0.7, 1.6)
	var mixed_edge := wheel_loose.has(1) and wheel_loose.has(0)
	if is_player and mixed_edge and _edge_spray.is_empty():
		for i in 4:
			var puff := Puffs.make("spray",Color(stage.def.pal.road).lightened(0.18),stage.wx.leak)
			puff.amount = 9
			puff.emitting = false
			puff.lifetime = 0.38
			puff.position = Vector3(_wheels[i].position.x,0.09,_wheels[i].position.z)
			puff.direction = Vector3(signf(puff.position.x)*0.4,0.6,-0.65)
			add_child(puff)
			_edge_spray.append(puff)
	for i in _edge_spray.size():
		_edge_spray[i].emitting = mixed_edge and wheel_loose[i] and wheel_load[i]>0.04 and speed()>4.0 and not in_water
	if mixed_edge and not _edge_spray.is_empty():
		_dust.emitting = false
	if in_water and speed()>1.5 and _bow_wakes.is_empty():
		for side: float in [-1,1]:
			var wake := Puffs.make("spray",Color("#c8d9dd"),stage.wx.leak)
			wake.amount = 14
			wake.lifetime = 0.42
			wake.position = Vector3(side*(half_wid-0.15),0.16,half_len-0.8)
			wake.direction = Vector3(side*0.82,0.54,-0.35)
			add_child(wake)
			_bow_wakes.append(wake)
	for wake in _bow_wakes:
		wake.emitting = in_water and not airborne and speed()>1.5
		if wake.emitting:
			wake.initial_velocity_max = clampf(1.0+_ford_depth*speed()*1.2,1.3,5.0)
	if _smoke:
		_smoke_t -= delta
		# Launch smoke and backfire smoke.
		_smoke.emitting = not in_water and (_smoke_t > 0.0 or (throttle > 0.8 and absf(v_long) < 6.0 and not frozen))
