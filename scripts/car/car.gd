class_name Car
extends Node3D
## Arcade rally car on the flat paper ground. Kinematic yaw from steering, friction-limited lateral
## grip (so cars slide and drift when demand exceeds grip), handbrake turns, auto gearbox.
## Car forward is +Z in local space; heading h rotates +Z toward +X.

signal gear_changed(gear: int)
signal impact(strength: float)

const BASE_TOP := 33.0
const BASE_ACC := 14.5
const BASE_MU := 17.0
const BRAKE := 28.0
const RADIUS := 1.55
const GEARS := [0.0, 8.0, 14.0, 20.0, 26.0, 31.0]

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

var _body: Node3D
var _wheels: Array = []
var _spin := 0.0
var _roll := 0.0
var _pitch := 0.0
var _dust: CPUParticles3D
var _last_puddle := false


func setup(car_stats: Dictionary, num: int, stg: Stage, mat: Material) -> void:
	stats = car_stats
	number = num
	stage = stg
	track = stg.track
	var m := CarModel.build(stats, num, mat)
	add_child(m["root"])
	_body = m["body"]
	_wheels = m["wheels"]
	_make_contact(mat)
	_make_dust()


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


func _make_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.local_coords = false
	_dust.amount = 36
	_dust.lifetime = 0.9
	_dust.emitting = false
	_dust.explosiveness = 0.0
	_dust.direction = Vector3(0, 0.6, -1)
	_dust.spread = 30.0
	_dust.gravity = Vector3(0, -1.5, 0)
	_dust.initial_velocity_min = 1.5
	_dust.initial_velocity_max = 3.5
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.4
	_dust.angle_min = 0.0
	_dust.angle_max = 360.0
	_dust.position = Vector3(0, 0.25, -1.9)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var kind := stage.kind()
	var pal: Dictionary = stage.def["pal"]
	if kind == "snow":
		mat.albedo_color = Color(0.95, 0.96, 1.0)
	elif kind == "rain":
		mat.albedo_color = Color(pal["road"]).lerp(Color(0.75, 0.8, 0.85), 0.5)
	else:
		mat.albedo_color = Color(pal["road"]).lightened(0.35)
	qm.material = mat
	_dust.mesh = qm
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)


func place_at(s_pos: float, lateral: float) -> void:
	var i := track.index_at(s_pos)
	pos = track.pts[i] + track.nrm[i] * lateral
	h = track.heading_at(i)
	vel = Vector2.ZERO
	yaw_rate = 0.0
	track_i = i
	s = s_pos
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
	surface = wgrip * (1.0 if on_road else 0.82)
	if not on_road and stats["id"] == "badger":
		surface = wgrip * 0.95
	var f := fwd()
	var r := right_axis()
	var vl := vel.dot(f)
	var vt := vel.dot(r)
	var top := top_speed()
	var thr := 0.0 if frozen else throttle
	var brk := 0.0 if frozen else brake
	var hb := 1.0 if frozen else handbrake
	var a := 0.0
	if thr > 0.0 and vl < top:
		var acc := BASE_ACC * float(stats["accel"]) * lerpf(1.0, surface, 0.45)
		a += acc * thr * clampf(1.0 - pow(maxf(vl, 0.0) / top, 2.0), 0.0, 1.0)
	if brk > 0.0:
		if vl > 0.6:
			a -= brk * BRAKE * lerpf(1.0, surface, 0.5)
		elif vl > -9.0:
			a -= brk * 8.0
	if hb > 0.0 and vl > 0.5:
		a -= hb * 5.0
	a -= vl * 0.045 + signf(vl) * 0.5
	if not on_road:
		a -= vl * (0.55 if stats["id"] != "badger" else 0.3)
	if in_puddle:
		a -= vl * 0.5
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
	var target_w := -steer * lim * sf * (1.0 if vl >= 0.0 else -1.0)
	if hb > 0.0 and not frozen:
		target_w *= 1.4
	var resp := clampf(dt * (5.0 + 4.0 * surface), 0.0, 1.0)
	yaw_rate = lerpf(yaw_rate, target_w, resp)
	h += yaw_rate * dt
	# Lateral friction (limited) in the new frame.
	f = fwd()
	r = right_axis()
	vl = vel.dot(f)
	vt = vel.dot(r)
	var mu := BASE_MU * float(stats["grip"]) * surface * (0.42 if (hb > 0.0 and not frozen) else 1.0)
	var max_dv := mu * dt
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


func _sync_visual(delta: float) -> void:
	var y := Stage.ROAD_Y if on_road else 0.0
	position = Vector3(pos.x, y, pos.y)
	rotation.y = h
	if _body == null:
		return
	# Paper-toy body roll and pitch.
	var lat_acc := yaw_rate * v_long
	_roll = lerpf(_roll, clampf(lat_acc * 0.006, -0.07, 0.07), clampf(delta * 6.0, 0.0, 1.0))
	var pitch_t := (throttle - brake) * -0.025
	_pitch = lerpf(_pitch, pitch_t, clampf(delta * 5.0, 0.0, 1.0))
	_body.rotation = Vector3(_pitch, 0.0, _roll)
	_spin += v_long * delta / CarModel.WHEEL_R
	for i in _wheels.size():
		var wnode: Node3D = _wheels[i]
		if i < 2:
			wnode.rotation.y = -steer * 0.45
		wnode.get_child(0).rotation.x = _spin
	# Dust / spray / snow from the wheels.
	if _dust:
		var spd := absf(v_long)
		var emit := spd > 6.0 and (slip > 0.12 or not on_road or stage.kind() != "dry" or spd > 18.0)
		_dust.emitting = emit
		_dust.speed_scale = clampf(0.6 + slip, 0.6, 1.6)
