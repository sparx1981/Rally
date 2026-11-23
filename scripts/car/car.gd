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
var _lights: Array = []
var _prev_gh := 0.0
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


var _damage := 0


## Visual damage: a crumpled, torn paper patch where the bodywork took a hit.
func add_damage(at: Vector2, strength: float) -> void:
	if _damage >= 14 or _body == null:
		return
	_damage += 1
	var local := global_transform.affine_inverse() * Vector3(at.x, global_position.y + 0.5, at.y)
	var top: float = _model["lamp"].y + 0.1
	var nrm := Vector3.ZERO
	var p := local
	if absf(local.x) / half_wid > absf(local.z) / half_len:
		nrm = Vector3(signf(local.x), 0, 0)
		p = Vector3(signf(local.x) * (half_wid + 0.025), clampf(local.y, 0.4, top), clampf(local.z, -half_len + 0.3, half_len - 0.3))
	else:
		nrm = Vector3(0, 0, signf(local.z))
		p = Vector3(clampf(local.x, -half_wid + 0.3, half_wid - 0.3), clampf(local.y, 0.4, top), signf(local.z) * (half_len + 0.025))
	var b := PaperKit.Builder.new(_damage * 31)
	var r := clampf(strength / 30.0, 0.12, 0.35)
	var basis := Basis.looking_at(-nrm, Vector3.UP) if absf(nrm.y) < 0.9 else Basis()
	b.card(PaperKit.blob(r, 0, 0, 7, 0.35, _damage * 7, 16), Transform3D(basis, p), PaperKit.KRAFT, {"thick": 0.015, "edge": 0.025, "lip": 0.0})
	b.card(PaperKit.blob(r * 0.5, r * 0.15, -r * 0.1, 5, 0.4, _damage * 9, 12), Transform3D(basis, p + nrm * 0.012), Color("#8a7a68"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = _mat
	mi.rotation.z = randf_range(-0.5, 0.5)
	_body.add_child(mi)


## The in-car view rig (dashboard, wheel, rev needle), shown only in the cockpit camera.
func cockpit(show: bool) -> void:
	if show and _cockpit.is_empty():
		_cockpit = CarModel.build_cockpit(stats, _model, _mat)
		_body.add_child(_cockpit["root"])
	if not _cockpit.is_empty():
		_cockpit["root"].visible = show
	var body_mesh: Node3D = _body.get_child(0)
	body_mesh.visible = not show
	for wnode in _wheels:
		(wnode as Node3D).visible = not show


## Where the driver's eyes are (for the cockpit camera).
func eye_transform() -> Transform3D:
	var hp: Vector3 = _model["head"]
	return global_transform * _body.transform * Transform3D(Basis(Vector3.UP, PI), hp)


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
	position = Vector3(pos.x, y + (Stage.ROAD_Y if on_road else 0.0), pos.y)
	rotation.y = h
	if _contact:
		# The printed contact shadow stays on the road / ground while the car flies.
		_contact.position.y = track.surface_height(pos, s, lat) - y
	if _body == null:
		return
	# Paper-toy body roll and pitch.
	var lat_acc := yaw_rate * v_long
	_roll = lerpf(_roll, clampf(lat_acc * 0.006, -0.07, 0.07), clampf(delta * 6.0, 0.0, 1.0))
	var pitch_t := (throttle - brake) * -0.025
	if airborne:
		pitch_t = clampf(-vy * 0.03, -0.25, 0.25)
	elif absf(vy) > 0.5 and absf(v_long) > 1.0:
		pitch_t = clampf(-vy / maxf(absf(v_long), 1.0), -0.3, 0.3)
	_pitch = lerpf(_pitch, pitch_t, clampf(delta * 5.0, 0.0, 1.0))
	_body.rotation = Vector3(_pitch, 0.0, _roll)
	_spin += v_long * delta / wheel_r
	if not _cockpit.is_empty() and _cockpit["root"].visible:
		(_cockpit["wheel"] as Node3D).rotation.z = steer * 1.6
		(_cockpit["needle"] as Node3D).rotation.z = 2.2 - clampf(rpm / 7500.0, 0.0, 1.0) * 4.0
	for i in _wheels.size():
		var wnode: Node3D = _wheels[i]
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
