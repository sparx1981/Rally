class_name PlayerInput
extends RefCounted
## Combines keyboard, game controller (Bluetooth / USB-C), on-screen touch buttons and tilt steering.

var touch: TouchControls
var _steer := 0.0


func apply(car: Car, dt: float) -> void:
	var s_axis := Input.get_axis("steer_left", "steer_right")
	var thr := Input.get_action_strength("accelerate")
	var brk := Input.get_action_strength("brake")
	var hb := Input.get_action_strength("handbrake")
	if touch and touch.visible:
		thr = maxf(thr, touch.throttle)
		brk = maxf(brk, touch.brake)
		hb = maxf(hb, touch.handbrake)
		if int(Settings.g("touch_mode")) == 1:
			var acc := Input.get_accelerometer()
			var tilt := acc.x / 4.5 * float(Settings.g("tilt_sens"))
			if bool(Settings.g("tilt_invert")):
				tilt = -tilt
			if absf(tilt) > 0.05:
				s_axis = clampf(tilt, -1.0, 1.0)
		elif touch.steer != 0.0:
			s_axis = touch.steer
	# Digital inputs (keys, touch buttons) ramp in; analog sticks pass straight through.
	var analog := absf(s_axis) > 0.0 and absf(s_axis) < 0.98
	if analog:
		_steer = s_axis
	else:
		var rate := 5.0 if absf(s_axis) > absf(_steer) else 9.0
		_steer = move_toward(_steer, s_axis, rate * dt)
	car.steer = _steer
	car.throttle = thr
	car.brake = brk
	car.handbrake = hb
