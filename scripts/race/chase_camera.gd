class_name ChaseCamera
extends Camera3D
## Camera views. The chase views use the macro "miniature" lens from the papercraft skill (look.md
## 6): a long lens looking down so the printed ground runs past every frame edge. Bonnet and
## Cockpit are mounted rigidly on the car (no smoothing, no lag) and look at the horizon with a
## paper-sky fog.

const LOW_VIEW_INDEX := 1
const VIEWS := [
	{"name": "Chase", "dist": 50.0, "pitch": 44.0, "fov": 30.0, "lead": 5.0},
	{"name": "Low chase", "dist": 7.8, "pitch": 10.0, "fov": 62.0, "lead": 2.5, "low": true},
	{"name": "Far chase", "dist": 66.0, "pitch": 47.0, "fov": 30.0, "lead": 7.0},
	{"name": "Bonnet", "dist": 0.0, "pitch": 0.0, "fov": 64.0, "lead": 0.0},
	{"name": "Cockpit", "dist": 0.0, "pitch": 0.0, "fov": 70.0, "lead": 0.0},
]
const BONNET := 3
const COCKPIT := 4
const LOW := 1

var target: Car
var force_view := -1
var _yaw := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _shake := 0.0
var _speed_fov := 0.0
var _speed_t := 0.0
var _roll := 0.0
var _init_done := false
var _last_view := -1


## Views at road level that see the horizon (sky, fog and headlight set-up like the bonnet view).
static func is_ground_level(v: int) -> bool:
	return v == BONNET or v == COCKPIT or v == LOW


## The rigid views mounted on the car itself.
static func is_mounted(v: int) -> bool:
	return v == BONNET or v == COCKPIT


static func view_name(i: int) -> String:
	return VIEWS[i]["name"]


func view_index() -> int:
	if force_view >= 0:
		return force_view
	return clampi(int(Settings.g("camera")), 0, VIEWS.size() - 1)


func _ready() -> void:
	near = 0.3
	far = 420.0


func snap() -> void:
	_init_done = false


func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Point the scenery pop-ups should unfold around, and the radius that is on screen.
func view_focus() -> Array:
	var v := view_index()
	if target == null:
		return [global_position, 40.0]
	var fw := Vector3(sin(_yaw), 0, cos(_yaw))
	match v:
		BONNET, COCKPIT: return [target.position + fw * 34.0, 46.0]
		LOW: return [target.position + fw * 30.0, 44.0]
		2: return [target.position + fw * 14.0, 40.0]
	return [target.position + fw * 11.0, 31.0]


func follow(dt: float) -> void:
	if target == null:
		return
	var vi := view_index()
	var v: Dictionary = VIEWS[vi]
	if vi != _last_view:
		_last_view = vi
		_init_done = false
	fov = float(Settings.g("cockpit_fov")) if vi == COCKPIT else float(v["fov"])
	# Speed feel: the view widens a little as the car gets quick, and the camera trembles with engine and road.
	var fast := 0.0
	if bool(Settings.g("speed_fx")) and target != null:
		fast = clampf((target.speed() - 10.0) / 32.0, 0.0, 1.0)
	_speed_fov = lerpf(_speed_fov, fast, clampf(dt * 1.8, 0.0, 1.0))
	fov += _speed_fov * (7.0 if vi == LOW_VIEW_INDEX else (4.0 if is_mounted(vi) else 3.0))
	_speed_t += dt
	var sh := Vector3.ZERO
	if _speed_fov > 0.02:
		var tr := _speed_fov * 0.35
		sh = Vector3(sin(_speed_t * 47.0) + sin(_speed_t * 31.0 + 1.3), sin(_speed_t * 53.0 + 0.7), sin(_speed_t * 41.0 + 2.1)) * tr * (0.0 if is_mounted(vi) else 0.5)
	if _shake > 0.001:
		sh += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, dt * 3.0)
	if is_mounted(vi):
		var t := target.eye_transform() if vi == COCKPIT else target.bonnet_transform()
		# Inside the car the speed tremble is far gentler (it read as vibration), and the head leans into corners.
		var calm := Vector3.ZERO
		if _speed_fov > 0.02:
			calm = Vector3(sin(_speed_t * 9.0), sin(_speed_t * 13.0 + 1.0), 0.0) * _speed_fov * 0.012
		var lat_g := 0.0
		var yaw_rate := 0.0
		if target != null:
			lat_g = target.vel.dot(target.right_axis())
			yaw_rate = target.yaw_rate
		var lean_t := clampf(-yaw_rate * 0.028 - lat_g * 0.004, -0.16, 0.16) * clampf(target.speed() / 20.0, 0.0, 1.0)
		_roll = lerpf(_roll, lean_t, clampf(dt * 5.0, 0.0, 1.0))
		var xf := Transform3D(t.basis, t.origin + sh * 0.01 + t.basis * calm)
		xf.basis = xf.basis * Basis(Vector3.FORWARD, _roll) * Basis(Vector3.UP, -_roll * 0.5)
		xf.origin += t.basis.x * (-_roll * 0.35)   # the head sways with the lean
		global_transform = xf
		near = 0.05
		_yaw = target.h
		return
	near = 0.3
	if v.get("low", false):
		_follow_low(dt, v, sh)
		return
	var car_yaw := target.h
	if target.vel.length() > 4.0 and target.v_long > 0.0:
		# Follow the direction of travel when sliding, so drifts read clearly.
		car_yaw = lerp_angle(car_yaw, atan2(target.vel.x, target.vel.y), 0.45)
	if not _init_done:
		_yaw = car_yaw
	_yaw = lerp_angle(_yaw, car_yaw, clampf(dt * 2.6, 0.0, 1.0))
	var fw := Vector3(sin(_yaw), 0, cos(_yaw))
	var car_p := target.position
	var pitch := deg_to_rad(float(v["pitch"]) - _speed_fov * 3.0)
	var d: float = float(v["dist"]) * (1.0 + 0.14 * _speed_fov)
	var lead: float = float(v["lead"]) + clampf(target.v_long, 0.0, 35.0) * 0.1
	var look := car_p + fw * lead
	var want := look - fw * d * cos(pitch) + Vector3.UP * d * sin(pitch)
	if not _init_done:
		_pos = want
		_look = look
		_init_done = true
	_pos = _pos.lerp(want, clampf(dt * 5.0, 0.0, 1.0))
	_look = _look.lerp(look, clampf(dt * 8.0, 0.0, 1.0))
	global_position = _pos + sh * 0.25
	look_at(_look + sh * 0.12, Vector3.UP)
	_apply_roll(dt)


## Forza Horizon style: low and close behind the car, looking past it down the road. Trails the
## car's heading with a little lag so slides swing into view, rides over crests with the car, and
## never dips into the ground.
var _low_h := 0.0
func _follow_low(dt: float, v: Dictionary, sh: Vector3) -> void:
	near = 0.15
	var car_yaw := target.h
	if target.vel.length() > 4.0 and target.v_long > 0.0:
		car_yaw = lerp_angle(car_yaw, atan2(target.vel.x, target.vel.y), 0.35)
	if not _init_done:
		_yaw = car_yaw
	_yaw = lerp_angle(_yaw, car_yaw, clampf(dt * 4.0, 0.0, 1.0))
	var fw := Vector3(sin(_yaw), 0, cos(_yaw))
	var car_p := target.position
	var spd := clampf(target.v_long, 0.0, 40.0)
	var d: float = float(v["dist"]) * (1.0 + 0.2 * _speed_fov)
	var hgt := 2.75 + spd * 0.008 - 0.35 * _speed_fov
	var want := car_p - fw * d + Vector3.UP * hgt
	# Keep clear of the ground behind the car (crests, banks, the far side of a dip).
	var gp := Vector2(want.x, want.z)
	var gh := target.track.terrain.height(gp) if target.track.terrain else -INF
	gh = maxf(gh, target.track.surface_height(gp, target.s - d, target.lat))
	want.y = maxf(want.y, gh + 1.3)
	var look := car_p + fw * (float(v["lead"]) + spd * 0.12) + Vector3.UP * 1.15
	if not _init_done:
		_pos = want
		_look = look
		_low_h = want.y
		_init_done = true
	# Tight horizontally, softer vertically so jumps and landings read without jolting.
	var p2 := Vector2(want.x, want.z)
	_low_h = lerpf(_low_h, want.y, clampf(dt * 5.0, 0.0, 1.0))
	_low_h = maxf(_low_h, gh + 1.1)
	_pos = Vector3(p2.x, _low_h, p2.y)
	_look = _look.lerp(look, clampf(dt * 10.0, 0.0, 1.0))
	fov = float(v["fov"]) + _speed_fov * 7.0
	global_position = _pos + sh * 0.08
	look_at(_look + sh * 0.05, Vector3.UP)
	_apply_roll(dt)


## A small lean into corners: the view rolls against the car's sideways motion, scaled by speed.
func _apply_roll(dt: float) -> void:
	var want := 0.0
	if bool(Settings.g("speed_fx")) and target != null:
		var lateral: float = target.vel.dot(target.right_axis())
		var yaw_rate: float = target.yaw_rate
		want = clampf(-yaw_rate * 0.018 - lateral * 0.0016, -0.07, 0.07) * clampf(target.speed() / 25.0, 0.0, 1.0)
	_roll = lerpf(_roll, want, clampf(dt * 4.0, 0.0, 1.0))
	rotate_object_local(Vector3.FORWARD, _roll)
