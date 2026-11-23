class_name ChaseCamera
extends Camera3D
## Camera views. The chase views use the macro "miniature" lens from the papercraft skill (look.md
## 6): a long lens looking down so the printed ground runs past every frame edge. Bonnet and
## Cockpit are mounted rigidly on the car (no smoothing, no lag) and look at the horizon with a
## paper-sky fog.

const VIEWS := [
	{"name": "Chase", "dist": 50.0, "pitch": 44.0, "fov": 30.0, "lead": 5.0},
	{"name": "Close chase", "dist": 37.0, "pitch": 40.0, "fov": 30.0, "lead": 4.0},
	{"name": "Far chase", "dist": 66.0, "pitch": 47.0, "fov": 30.0, "lead": 7.0},
	{"name": "Bonnet", "dist": 0.0, "pitch": 0.0, "fov": 64.0, "lead": 0.0},
	{"name": "Cockpit", "dist": 0.0, "pitch": 0.0, "fov": 70.0, "lead": 0.0},
]
const BONNET := 3
const COCKPIT := 4

var target: Car
var force_view := -1
var _yaw := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _shake := 0.0
var _init_done := false
var _last_view := -1


static func is_ground_level(v: int) -> bool:
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
		1: return [target.position + fw * 9.0, 25.0]
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
	fov = v["fov"]
	var sh := Vector3.ZERO
	if _shake > 0.001:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, dt * 3.0)
	if is_ground_level(vi):
		var t := target.eye_transform() if vi == COCKPIT else target.bonnet_transform()
		global_transform = Transform3D(t.basis, t.origin + sh * 0.04)
		near = 0.05
		_yaw = target.h
		return
	near = 0.3
	var car_yaw := target.h
	if target.vel.length() > 4.0 and target.v_long > 0.0:
		# Follow the direction of travel when sliding, so drifts read clearly.
		car_yaw = lerp_angle(car_yaw, atan2(target.vel.x, target.vel.y), 0.45)
	if not _init_done:
		_yaw = car_yaw
	_yaw = lerp_angle(_yaw, car_yaw, clampf(dt * 2.6, 0.0, 1.0))
	var fw := Vector3(sin(_yaw), 0, cos(_yaw))
	var car_p := target.position
	var pitch := deg_to_rad(float(v["pitch"]))
	var d: float = v["dist"]
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
