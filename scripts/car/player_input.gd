class_name PlayerInput
extends RefCounted
## Combines keyboard, game controller (Bluetooth / USB-C), on-screen touch buttons and tilt steering.

var touch: TouchControls
var _steer := 0.0
var _trigger_down := false
var _brake_down := false
var _previous_pad_brake := 0.0
var _previous_pad_brake_button := false
var _previous_pad_gas := 0.0
var _brake_overridden := false


# Ignore rest noise and allow a slightly short physical throw to reach full pedal.
static func pedal(travel: float) -> float:
	return clampf((travel - 0.08) / (0.90 - 0.08), 0.0, 1.0)


## Poll the current mapped Android axes and buttons. InputMap can retain an
## old action strength across a pad disconnect. Negative and near-rest
## axis values both clear the brake.
func controller_brake(devices: PackedInt32Array, gas := 0.0) -> float:
	var pressure := 0.0
	var button := false
	for device in devices:
		pressure = maxf(pressure, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
		button = button or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
	_brake_down = pressure > (0.12 if _brake_down else 0.17)
	var analog := clampf((pressure - 0.12) / 0.78, 0.0, 1.0) if _brake_down else 0.0
	var brake_request := maxf(analog, float(button))
	var button_reapplied := button and not _previous_pad_brake_button
	var brake_reapplied := brake_request > 0.0 and (is_zero_approx(_previous_pad_brake) or brake_request - _previous_pad_brake >= 0.16)
	var gas_reapplied := gas > 0.11 and _previous_pad_gas <= 0.11
	if button_reapplied:
		_brake_overridden = false
	elif gas_reapplied and _previous_pad_brake > 0.0 and brake_request > 0.0:
		_brake_overridden = true
	elif brake_reapplied or brake_request == 0.0:
		_brake_overridden = false
	_previous_pad_brake_button = button
	_previous_pad_brake = brake_request
	_previous_pad_gas = gas
	return 0.0 if _brake_overridden else brake_request


func apply(car: Car, dt: float) -> void:
	var s_axis := Input.get_axis("steer_left", "steer_right")
	var travel := Input.get_action_raw_strength("throttle_trigger")
	_trigger_down = travel > (0.10 if _trigger_down else 0.18)
	var trigger := pedal(travel) if Settings.g("progressive_trigger") else float(_trigger_down)
	var thr := maxf(Input.get_action_strength("accelerate"), trigger)
	var pads := Input.get_connected_joypads()
	var pad_gas := trigger
	for device in pads:
		if Input.is_joy_button_pressed(device, JOY_BUTTON_A):
			pad_gas = 1.0
	var brk := maxf(Input.get_action_strength("brake"), controller_brake(pads, pad_gas))
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
