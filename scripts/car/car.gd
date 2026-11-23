class_name Car
extends Node3D
## Arcade rally car on the flat paper ground. Kinematic yaw from steering, friction-limited lateral
## grip (so cars slide and drift when demand exceeds grip), handbrake turns, auto gearbox.
## Car forward is +Z in local space; heading h rotates +Z toward +X.

signal gear_changed(gear: int)
signal impact(strength: float)
signal landed(strength: float)
signal splashed(strength: float)

const BASE_TOP := 33.0
const BASE_ACC := 14.5
const BASE_MU := 17.0
const BRAKE := 28.0
const RADIUS := 1.55
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
var rpm := 900.0
var finished := false
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
var _comp := 0.0
var _comp_v := 0.0
var _wheel_base: Array = []
var _has_prev_gh := false

var _body: Node3D
var _wheels: Array = []
var _spin := 0.0
var _roll := 0.0
var _pitch := 0.0
var _dust: CPUParticles3D
var _last_puddle := false
var _contact: MeshInstance3D
var _eng3d: AudioStreamPlayer3D


func setup(car_stats: Dictionary, num: int, stg: Stage, mat: Material) -> void:
	stats = car_stats
	number = num
	stage = stg
	track = stg.track
	var m := CarModel.build(stats, num, mat)
	add_child(m["root"])
	_body = m["body"]
	_wheels = m["wheels"]
	half_len = float(m["length"]) * 0.5
	half_wid = float(m["width"]) * 0.5
	wheel_r = float(m["wheel_r"])
	head_pos = m["head"]
	lamp_pos = m["lamp"]
	model_root = m["root"]
	_model = m
	_mat = mat
	_make_contact(mat)
	_make_dust()
	_make_rear_lamps()
	if not is_player:
		# AI engines are positional: you hear rivals close behind and alongside.
		_eng3d = AudioStreamPlayer3D.new()
		_eng3d.stream = Sfx.engine_loop()
		_eng3d.bus = "Engine"
		_eng3d.unit_size = 10.0
		_eng3d.max_distance = 90.0
		_eng3d.volume_db = -8.0
		_eng3d.position = Vector3(0, 0.6, 0)
		add_child(_eng3d)
		_eng3d.play()


func _make_contact(mat: Material) -> void:
	var b := PaperKit.Builder.new(2)
	var leak: Color = stage.wx["leak"]
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.012, 0))
	b.card(PaperKit.rrect(2.0, 3.9, 0.7, 0, -1.95), lay, leak.darkened(0.55), {"thick": 0.004, "edge": 0.0, "lip": 0.0, "sides": false})
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_contact = mi


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
	for xs in [-1.0, 1.0]:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.11, 0.03)
		var b := MeshInstance3D.new()
		b.mesh = bm
		b.material_override = red
		b.position = Vector3(xs * half_wid * 0.68, y, z)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		_body.add_child(b)
		_brake_lamps.append(b)
		var rm := BoxMesh.new()
		rm.size = Vector3(0.1, 0.08, 0.03)
		var r := MeshInstance3D.new()
		r.mesh = rm
		r.material_override = white
		r.position = Vector3(xs * half_wid * 0.36, y - 0.02, z)
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
	var braking := brake > 0.08 and v_long > 0.5 and not frozen
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
	for p in [_dust, _spray]:
		if p == null:
			continue
		var k := 0.45 if on else 1.0 / 0.45
		p.scale_amount_min *= k
		p.scale_amount_max *= k
		p.amount = maxi(4, int(p.amount * (0.6 if on else 1.0 / 0.6)))


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
	_dust.emitting = false
	_dust.position = Vector3(0, 0.3, -half_len)
	add_child(_dust)
	_smoke = Puffs.make("exhaust", Color(0.55, 0.53, 0.52), leak)
	_smoke.emitting = false
	_smoke.position = Vector3(0.45, 0.3, -half_len - 0.1)
	add_child(_smoke)


var _smoke: CPUParticles3D
var _spray: CPUParticles3D
var _smoke_t := 0.0


## A big volumetric burst of water when driving through a splash.
func spray(v: float) -> void:
	if _spray == null:
		_spray = Puffs.make("splash", Color("#dde7ec"), stage.wx["leak"])
		_spray.position = Vector3(0, 0.3, 0.6)
		add_child(_spray)
	_spray.amount = clampi(int(v * 2.0), 20, 60)
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
	for xs in [-0.5, 0.5]:
		var sl := SpotLight3D.new()
		sl.light_color = Color("#ffe6c0")
		sl.light_energy = 7.0 if night else 2.4
		sl.spot_range = 60.0 if night else 38.0
		sl.spot_angle = 52.0
		sl.spot_angle_attenuation = 2.6
		sl.spot_attenuation = 0.85 if night else 1.4
		sl.shadow_enabled = shadows and xs > 0.0
		sl.shadow_bias = 0.08
		sl.position = lamp + Vector3(xs * half_wid * 1.2, 0.05, 0.1)
		sl.rotation = Vector3(-0.07, PI + xs * 0.1, 0.0)
		_body.add_child(sl)
		_lights.append(sl)
	var tail := OmniLight3D.new()
	tail.light_color = Color("#ff5a3a")
	tail.light_energy = 0.7
	tail.omni_range = 4.0
	tail.position = Vector3(0, lamp.y, -half_len - 0.4)
	_body.add_child(tail)
	_lights.append(tail)


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
	for light in _brake_lamps + _rev_lamps:
		if not light.has_meta("undamaged_position"):
			light.set_meta("undamaged_position", light.position)
		light.position = _crush_point(light.get_meta("undamaged_position"), light.position, center, outward, radius, crush)
	arrays[Mesh.ARRAY_VERTEX] = vertices
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
	arrays[Mesh.ARRAY_NORMAL] = normals
	var dented := ArrayMesh.new()
	dented.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	shell.mesh = dented
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
	var i := track.index_at(s_pos)
	pos = track.pts[i] + track.nrm[i] * lateral
	h = track.heading_at(i)
	vel = Vector2.ZERO
	yaw_rate = 0.0
	track_i = i
	s = s_pos
	lat = lateral
	y = track.surface_height(pos, s_pos, lateral)
	vy = 0.0
	_prev_gh = y
	airborne = false
	_sync_visual(0.0)


func reset_to_track() -> void:
	var hit: Array = track.project(pos, track_i)
	place_at(maxf(float(hit[1]) - 4.0, 2.0), 0.0)


func fwd() -> Vector2:
	return Vector2(sin(h), cos(h))


func right_axis() -> Vector2:
	return Vector2(cos(h), -sin(h))


func speed() -> float:
	return vel.length()


func top_speed() -> float:
	return BASE_TOP * float(stats["top"])


func step(dt: float) -> void:
	var hit: Array = track.project(pos, track_i)
	track_i = hit[0]
	s = hit[1]
	lat = hit[2]
	on_road = absf(lat) <= track.width * 0.5 + 0.2
	var wgrip := stage.grip()
	var offroad: float = stats.get("offroad", 0.3)
	surface = wgrip * (1.0 if on_road else lerpf(0.8, 0.97, offroad))
	# Loose surface patches (gravel / mud / ice / deep snow).
	var patch := track.patch_at(s, lat)
	var patch_drag := 0.0
	patch_kind = ""
	if not patch.is_empty():
		patch_kind = patch["kind"]
		surface *= float(patch["grip"])
		patch_drag = float(patch["drag"])
		patch_drag *= lerpf(1.0, 0.4, offroad)
	# Water splash: heavy drag, a burst of spray.
	var water := absf(lat) < track.width * 0.5 + 16.0 and not track.feature_at(s, "splash").is_empty()
	if water and not in_water:
		splashed.emit(absf(vel.dot(fwd())))
	in_water = water
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
				_comp_v -= clampf(hit_v * 0.12, 0.0, 1.2)   # body squats onto its springs
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
	var top := top_speed()
	var thr := 0.0 if frozen else throttle
	var brk := 0.0 if frozen else brake
	var hb := 1.0 if frozen else handbrake
	var a := 0.0
	if thr > 0.0 and vl < top and grounded > 0.0:
		var acc := BASE_ACC * float(stats["accel"]) * lerpf(1.0, surface, 0.45)
		a += acc * thr * clampf(1.0 - pow(maxf(vl, 0.0) / top, 2.0), 0.0, 1.0)
	if brk > 0.0 and grounded > 0.0:
		if vl > 0.6:
			a -= brk * BRAKE * lerpf(1.0, surface, 0.5)
		elif vl > -9.0:
			a -= brk * 8.0
	if hb > 0.0 and vl > 0.5:
		a -= hb * 5.0
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
	var drive: String = stats.get("drive", "awd")
	if drive == "fwd" and thr > 0.5:
		lim *= 0.88          # front-drive: understeers on the power
	var target_w := -steer * lim * sf * (1.0 if vl >= 0.0 else -1.0)
	if drive == "rwd" and thr > 0.6 and sp > 6.0:
		# Rear-drive: power slides the tail out.
		target_w *= 1.12
		target_w += -steer * 0.25 * thr
	if hb > 0.0 and not frozen:
		target_w *= 1.4
	var resp := clampf(dt * (5.0 + 4.0 * surface), 0.0, 1.0) * grounded
	yaw_rate = lerpf(yaw_rate, target_w, resp)
	h += yaw_rate * dt
	# Lateral friction (limited) in the new frame.
	f = fwd()
	r = right_axis()
	vl = vel.dot(f)
	vt = vel.dot(r)
	var mu := BASE_MU * float(stats["grip"]) * surface * (0.42 if (hb > 0.0 and not frozen) else 1.0)
	if drive == "rwd" and thr > 0.6:
		mu *= 0.88
	elif drive == "fwd":
		mu *= 1.04
	var max_dv := mu * dt * grounded
	var removed := clampf(vt, -max_dv, max_dv)
	vt -= removed
	vt *= 1.0 - clampf(dt * 0.6, 0.0, 1.0)
	# Sliding scrubs speed; a little lateral energy carries forward (rally momentum).
	slip = clampf(absf(vt) / maxf(absf(vl), 4.0), 0.0, 1.0)
	vl *= 1.0 - slip * 0.35 * dt
	vl += absf(removed) * 0.12 * signf(vl)
	vel = f * vl + r * vt
	v_long = vl
	pos += vel * dt
	_update_gear(vl, thr)


func _update_gear(vl: float, thr: float) -> void:
	var v := absf(vl)
	var g := 1
	for i in range(1, GEARS.size()):
		if v >= GEARS[i] * float(stats["top"]):
			g = i + 1
	g = clampi(g, 1, 5)
	if vl < -0.5:
		g = 0
	if g != gear and not frozen:
		gear = g
		gear_changed.emit(g)
	var lo: float = GEARS[maxi(gear - 1, 0)] * float(stats["top"])
	var hi: float = (GEARS[gear] if gear < GEARS.size() else GEARS[-1] + 6.0) * float(stats["top"])
	var t := clampf((v - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var target := 1100.0 + t * 5800.0
	if frozen:
		target = 900.0 + thr * 5500.0
	if slip > 0.3:
		target += slip * 900.0
	rpm = lerpf(rpm, target, 0.2)


func _process(delta: float) -> void:
	_sync_visual(delta)
	if _eng3d:
		_eng3d.pitch_scale = 0.62 + clampf((rpm - 900.0) / 6200.0, 0.0, 1.0) * 1.25


func _sync_visual(delta: float) -> void:
	if _brake_light:
		_update_rear_lamps()
	position = Vector3(pos.x, y + (Stage.ROAD_Y if on_road else 0.0), pos.y)
	if _contact:
		# The printed contact shadow stays on the road / ground while the car flies.
		_contact.position.y = track.surface_height(pos, s, lat) - y
	if _body == null:
		return
	# The whole car (body and wheels together) follows the slope, so nothing separates on hills.
	var slope_t := 0.0
	if airborne:
		slope_t = clampf(-vy * 0.03, -0.25, 0.25)
	else:
		slope_t = -atan(clampf(track.grade_along(pos, s, lat, fwd()), -0.5, 0.5))
	_slope = lerpf(_slope, slope_t, clampf(delta * 8.0, 0.0, 1.0))
	rotation = Vector3(_slope, h, 0.0)
	# Body on its springs: small roll and pitch about the axle line, plus compression on landings.
	var lat_acc := yaw_rate * v_long
	_roll = lerpf(_roll, clampf(lat_acc * 0.004, -0.035, 0.035), clampf(delta * 6.0, 0.0, 1.0))
	_pitch = lerpf(_pitch, (throttle - brake) * -0.022, clampf(delta * 5.0, 0.0, 1.0))
	_comp_v += (-_comp * 160.0 - _comp_v * 16.0) * delta
	_comp = clampf(_comp + _comp_v * delta, -0.07, 0.04)
	var pivot := Vector3(0, wheel_r, 0)
	var bb := Basis.from_euler(Vector3(_pitch, 0.0, _roll))
	_body.transform = Transform3D(bb, pivot - bb * pivot + Vector3(0, _comp, 0))
	_spin += v_long * delta / wheel_r
	if not _cockpit.is_empty() and _cockpit["root"].visible:
		(_cockpit["wheel"] as Node3D).rotation.z = steer * 1.6
		(_cockpit["needle"] as Node3D).rotation.z = lerpf(-2.2, 1.8, clampf(rpm / 7500.0, 0.0, 1.0))
		var trip_display: Label3D = _cockpit["trip_display"]
		var distance := floori(maxf(s, 0.0) / 10.0)
		if trip_display and distance != _trip_centikm:
			_trip_centikm = distance
			trip_display.text = "%.2f" % (distance * 0.01)
		var speed_hand: Node3D = _cockpit["speed_hand"]
		if speed_hand:
			speed_hand.rotation.z = lerpf(2.2, -1.8, clampf(speed() * 3.6 / 240.0, 0.0, 1.0))
	# Suspension travel: wheels droop in the air and jiggle over rough ground, within the arches.
	var rough := 0.0 if on_road else clampf(absf(v_long) / 25.0, 0.0, 1.0) * 0.025
	for i in _wheels.size():
		var wnode: Node3D = _wheels[i]
		if _wheel_base.size() < _wheels.size():
			_wheel_base.append(wnode.position)
		var travel := -0.09 if airborne else sin(_spin * 0.7 + i * 1.9) * rough
		wnode.position.y = lerpf(wnode.position.y, float(_wheel_base[i].y) + travel, clampf(delta * 12.0, 0.0, 1.0))
		if i < 2:
			wnode.rotation.y = -steer * 0.45
		wnode.get_child(0).rotation.x = _spin
	# Dust / spray / snow from the wheels.
	if _dust:
		var spd := absf(v_long)
		var emit := spd > 6.0 and (slip > 0.12 or not on_road or stage.kind() != "dry" or spd > 18.0)
		_dust.emitting = emit and not airborne
		_dust.speed_scale = clampf(0.7 + slip, 0.7, 1.6)
	if _smoke:
		_smoke_t -= delta
		# Launch smoke and backfire smoke.
		_smoke.emitting = _smoke_t > 0.0 or (throttle > 0.8 and absf(v_long) < 6.0 and not frozen)
