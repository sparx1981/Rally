class_name PlayerInput
extends RefCounted
## Combines keyboard, game controller (Bluetooth / USB-C), on-screen touch buttons and tilt steering.

enum TriggerMode { AUTO, ZERO_REST, HALF_REST, BUTTON_BRAKE }

var touch: TouchControls
var detect_android_range := OS.has_feature("android")
var _steer := 0.0
var _trigger_down := false
var _ranges := {}
var _brake_waiting_for_rest := {}
var _devices := PackedInt32Array()


func _update_devices(devices: PackedInt32Array) -> void:
	if devices == _devices:
		return
	for device in _devices:
		if device not in devices:
			_ranges.erase(device)
			_brake_waiting_for_rest.erase(device)
	_devices = devices.duplicate()


## Some Android full-axis mappings shift a physical 0..1 pedal into 0.5..1.
## Evidence below the midpoint identifies an ordinary axis. An exact midpoint
## identifies the shifted mapping until lower, positive travel proves otherwise.
func trigger_value(device: int, axis: JoyAxis) -> float:
	var raw := Input.get_joy_axis(device, axis)
	var mode := int(Settings.g("controller_trigger_mode"))
	if mode == TriggerMode.ZERO_REST or (not detect_android_range and mode != TriggerMode.HALF_REST):
		return clampf(raw, 0.0, 1.0)
	if mode == TriggerMode.HALF_REST:
		return clampf((raw - 0.50) * 2.0, 0.0, 1.0)

	var ranges: Dictionary = _ranges.get_or_add(device, {})
	if raw > 0.045 and raw < 0.475:
		ranges[axis] = 0.0
	elif not ranges.has(axis) and absf(raw - 0.50) <= 0.002:
		ranges[axis] = 0.50
	var rest := float(ranges.get(axis, 0.0))
	return clampf((raw - rest) / (1.0 - rest), 0.0, 1.0)


func controller_accelerator(devices: PackedInt32Array) -> float:
	_update_devices(devices)
	var pressure := 0.0
	var button := false
	for device in devices:
		pressure = maxf(pressure, trigger_value(device, JOY_AXIS_TRIGGER_RIGHT))
		button = button or Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	_trigger_down = pressure > (0.10 if _trigger_down else 0.18)
	var trigger := clampf((pressure - 0.08) / 0.82, 0.0, 1.0) if Settings.g("progressive_trigger") else float(_trigger_down)
	return maxf(trigger, float(button))


## Throttle takes priority over the controller's analog brake. After that
## override, require a neutral LT sample before accepting LT again. This also
## prevents reverse engagement if a missing release outlasts the throttle.
func controller_brake(devices: PackedInt32Array, gas := 0.0) -> float:
	_update_devices(devices)
	var request := 0.0
	var button_only := int(Settings.g("controller_trigger_mode")) == TriggerMode.BUTTON_BRAKE
	for device in devices:
		if Input.is_joy_button_pressed(device, JOY_BUTTON_X):
			request = 1.0
		var pressure := trigger_value(device, JOY_AXIS_TRIGGER_LEFT)
		if pressure <= 0.12:
			_brake_waiting_for_rest.erase(device)
			continue
		if gas > 0.0:
			_brake_waiting_for_rest[device] = true
		if not button_only and not _brake_waiting_for_rest.has(device):
			request = maxf(request, clampf((pressure - 0.12) / 0.78, 0.0, 1.0))
	return request


func apply(car: Car, dt: float) -> void:
	var s_axis := Input.get_axis("steer_left", "steer_right")
	var pads := PackedInt32Array(Input.get_connected_joypads())
	var thr := maxf(Input.get_action_strength("accelerate"), controller_accelerator(pads))
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
	brk = maxf(brk, controller_brake(pads, thr))
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
