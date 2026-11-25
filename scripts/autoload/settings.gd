extends Node
## Player settings: graphics presets plus individual options, controls, audio and haptics.
## Saved to user://settings.cfg. Emits `changed(key)` when anything changes.

signal changed(key: String)

const PATH := "user://settings.cfg"

const GRAPHICS_KEYS := ["render_scale", "shadows", "tilt_shift", "density", "draw_distance", "msaa", "particles", "paper_detail"]

const PRESETS := {
	"low": {"render_scale": 0.6, "shadows": 0, "tilt_shift": 0, "density": 0.45, "draw_distance": 80.0, "msaa": 0, "particles": 0.4, "paper_detail": false},
	"medium": {"render_scale": 0.8, "shadows": 1, "tilt_shift": 1, "density": 0.7, "draw_distance": 110.0, "msaa": 1, "particles": 0.7, "paper_detail": true},
	"high": {"render_scale": 1.0, "shadows": 2, "tilt_shift": 2, "density": 1.0, "draw_distance": 150.0, "msaa": 2, "particles": 1.0, "paper_detail": true},
}

var data := {
	"preset": "medium",
	"render_scale": 0.8, "shadows": 1, "tilt_shift": 1, "density": 0.7, "draw_distance": 110.0, "msaa": 1,
	"particles": 0.7, "paper_detail": true,
	"popups": true,            # pop-up / unfolding scenery animation (test toggle)
	"fps": 60, "show_fps": false,
	"ai_difficulty": 1, "opponents": 5, "camera": 0, "units": 0,
	"progressive_trigger": false, "controller_trigger_mode": 0, "cockpit_fov": 58.0,
	"touch_mode": 0, "tilt_sens": 1.0, "tilt_invert": false, "touch_controls": 0,
	"haptics": true, "haptic_strength": 1.0, "phone_vibration": true,
	"master_vol": 0.8, "sfx_vol": 0.8, "engine_vol": 0.7,
	"codriver_voice": "", "codriver_timing": 2, "codriver_volume": 0.66, "crossing_audio": true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_input()
	load_settings()
	data["camera"] = clampi(int(data["camera"]), 0, 4)
	if not FileAccess.file_exists(PATH) and OS.has_feature("mobile"):
		apply_preset("medium")
	apply()


func g(key: String) -> Variant:
	return data.get(key)


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	if key in GRAPHICS_KEYS:
		data["preset"] = _matching_preset()
	save_settings()
	apply()
	changed.emit(key)


func apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	for k in PRESETS[name].keys():
		data[k] = PRESETS[name][k]
	data["preset"] = name
	save_settings()
	apply()
	changed.emit("preset")


func _matching_preset() -> String:
	for name in PRESETS.keys():
		var ok := true
		for k in PRESETS[name].keys():
			if not is_equal_approx(float(PRESETS[name][k]), float(data[k])):
				ok = false
				break
		if ok:
			return name
	return "custom"


func apply() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(float(data["render_scale"]), 0.4, 1.0)
		var m: int = int(data["msaa"])
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(m, 0, 2)]
	Engine.max_fps = int(data["fps"])
	var sh: int = int(data["shadows"])
	RenderingServer.directional_shadow_atlas_set_size(1024 if sh <= 1 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if sh <= 1 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	_set_bus("Master", float(data["master_vol"]))
	_set_bus("SFX", float(data["sfx_vol"]))
	_set_bus("Engine", float(data["engine_vol"]))


func _set_bus(name: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(i, lin <= 0.001)


func _setup_buses() -> void:
	for name in ["SFX", "Engine"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in data.keys():
		cf.set_value("settings", k, data[k])
	cf.save(PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in data.keys():
		if cf.has_section_key("settings", k):
			data[k] = cf.get_value("settings", k)


# --- Input map (keyboard + Bluetooth / USB-C game controllers) ---------------------------------------

func _setup_input() -> void:
	_action("accelerate", 0.1)
	_key("accelerate", KEY_W); _key("accelerate", KEY_UP)

	_action("brake", 0.1)
	_key("brake", KEY_S); _key("brake", KEY_DOWN)

	_action("steer_left", 0.12)
	_key("steer_left", KEY_A); _key("steer_left", KEY_LEFT)
	_joy_axis("steer_left", JOY_AXIS_LEFT_X, -1.0); _joy_btn("steer_left", JOY_BUTTON_DPAD_LEFT)

	_action("steer_right", 0.12)
	_key("steer_right", KEY_D); _key("steer_right", KEY_RIGHT)
	_joy_axis("steer_right", JOY_AXIS_LEFT_X, 1.0); _joy_btn("steer_right", JOY_BUTTON_DPAD_RIGHT)

	_action("handbrake", 0.3)
	_key("handbrake", KEY_SPACE); _joy_btn("handbrake", JOY_BUTTON_B); _joy_btn("handbrake", JOY_BUTTON_RIGHT_SHOULDER)

	_action("reset_car", 0.5)
	_key("reset_car", KEY_R); _joy_btn("reset_car", JOY_BUTTON_Y)

	_action("pause", 0.5)
	_key("pause", KEY_ESCAPE); _key("pause", KEY_P); _joy_btn("pause", JOY_BUTTON_START)

	_action("camera", 0.5)
	_key("camera", KEY_C); _joy_btn("camera", JOY_BUTTON_BACK); _joy_btn("camera", JOY_BUTTON_LEFT_SHOULDER)

	# Bind the standard Android gamepad layout for every device ID, including hot-plugged pads.
	for action in ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)
	_joy_btn("ui_accept", JOY_BUTTON_A)
	_joy_btn("ui_cancel", JOY_BUTTON_B)
	_joy_btn("ui_left", JOY_BUTTON_DPAD_LEFT)
	_joy_btn("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_btn("ui_up", JOY_BUTTON_DPAD_UP)
	_joy_btn("ui_down", JOY_BUTTON_DPAD_DOWN)
	_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)

	# Menus: shoulder buttons page through tabs.
	_action("ui_tab_prev", 0.5)
	_key("ui_tab_prev", KEY_Q); _joy_btn("ui_tab_prev", JOY_BUTTON_LEFT_SHOULDER)
	_action("ui_tab_next", 0.5)
	_key("ui_tab_next", KEY_E); _joy_btn("ui_tab_next", JOY_BUTTON_RIGHT_SHOULDER)


func _action(name: String, deadzone: float) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, deadzone)


func _key(action: String, code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	InputMap.action_add_event(action, e)


func _joy_btn(action: String, btn: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	e.device = -1
	InputMap.action_add_event(action, e)


func _joy_axis(action: String, axis: JoyAxis, sign_v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = sign_v
	e.device = -1
	InputMap.action_add_event(action, e)
