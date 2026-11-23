class_name ChaseCamera
extends Camera3D
## Macro "miniature" lens (papercraft skill look.md 6): long lens (~30 deg vertical FOV), looking
## 40-55 deg down so the printed ground runs past every frame edge - no horizon, no sky.
## Two views: chase (behind the car) and a higher diorama view.

var target: Car
var view := 0
var _yaw := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _shake := 0.0
var _init_done := false

const DIST := [40.0, 50.0, 62.0]


func _ready() -> void:
	fov = 30.0
	near = 0.5
	far = 400.0


func snap() -> void:
	_init_done = false


func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


func follow(dt: float) -> void:
	if target == null:
		return
	var d: float = DIST[clampi(int(Settings.g("camera")), 0, 2)]
	var pitch := deg_to_rad(44.0)
	if view == 1:
		d *= 1.35
		pitch = deg_to_rad(54.0)
	var car_yaw := target.h
	# Follow the direction of travel when sliding, so drifts read clearly.
	if target.vel.length() > 4.0 and target.v_long > 0.0:
		var vy := atan2(target.vel.x, target.vel.y)
		car_yaw = lerp_angle(car_yaw, vy, 0.45)
	if not _init_done:
		_yaw = car_yaw
	_yaw = lerp_angle(_yaw, car_yaw, clampf(dt * 2.6, 0.0, 1.0))
	var fw := Vector3(sin(_yaw), 0, cos(_yaw))
	var car_p := target.position
	var lead := 5.0 + clampf(target.v_long, 0.0, 35.0) * 0.1
	var look := car_p + fw * lead
	var want := look - fw * d * cos(pitch) + Vector3.UP * d * sin(pitch)
	if not _init_done:
		_pos = want
		_look = look
		_init_done = true
	_pos = _pos.lerp(want, clampf(dt * 5.0, 0.0, 1.0))
	_look = _look.lerp(look, clampf(dt * 8.0, 0.0, 1.0))
	var sh := Vector3.ZERO
	if _shake > 0.001:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
		_shake = move_toward(_shake, 0.0, dt * 3.0)
	global_position = _pos + sh
	look_at(_look + sh * 0.5, Vector3.UP)
