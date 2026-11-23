extends Node
## Haptics for game controllers (rumble motors) and the phone's vibration motor.
## Controller rumble gets continuous surface feedback; the phone only gets short, rate-limited pulses.

var _weak := 0.0
var _strong := 0.0
var _refresh := 0.0
var _last_phone_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func enabled() -> bool:
	return bool(Settings.g("haptics"))


func _strength() -> float:
	return clampf(float(Settings.g("haptic_strength")), 0.0, 1.5)


func has_controller() -> bool:
	return Input.get_connected_joypads().size() > 0


## One-off kick: impacts, gear shifts, countdown, landing in a puddle.
func impulse(strength: float, duration := 0.12) -> void:
	if not enabled():
		return
	var s := clampf(strength * _strength(), 0.0, 1.0)
	if s <= 0.01:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, s * 0.55, s, duration)
	_phone(int(duration * 1000.0), s)


## Continuous rumble (road texture, sliding, off-road). Call every frame; 0 stops it.
func rumble(weak: float, strong: float) -> void:
	_weak = clampf(weak, 0.0, 1.0)
	_strong = clampf(strong, 0.0, 1.0)


func stop() -> void:
	_weak = 0.0
	_strong = 0.0
	for d in Input.get_connected_joypads():
		Input.stop_joy_vibration(d)


func tick() -> void:
	impulse(0.25, 0.04)


func pattern_finish() -> void:
	impulse(0.6, 0.18)
	get_tree().create_timer(0.25, true).timeout.connect(func(): impulse(0.8, 0.3))


func _phone(ms: int, amp: float) -> void:
	if not bool(Settings.g("phone_vibration")) or not OS.has_feature("mobile"):
		return
	if has_controller():
		return
	var now := Time.get_ticks_msec()
	if now - _last_phone_ms < 90:
		return
	_last_phone_ms = now
	Input.vibrate_handheld(clampi(ms, 10, 400), clampf(amp, 0.05, 1.0))


func _process(delta: float) -> void:
	if not enabled() or get_tree().paused:
		if _refresh != 0.0:
			_refresh = 0.0
			for d in Input.get_connected_joypads():
				Input.stop_joy_vibration(d)
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.1
	var k := _strength()
	var w := clampf(_weak * k, 0.0, 1.0)
	var s := clampf(_strong * k, 0.0, 1.0)
	for d in Input.get_connected_joypads():
		if w < 0.02 and s < 0.02:
			Input.stop_joy_vibration(d)
		else:
			Input.start_joy_vibration(d, w, s, 0.16)
	# Phone: a light tick now and then when the surface is rough.
	if s > 0.35:
		_phone(14, s * 0.4)
