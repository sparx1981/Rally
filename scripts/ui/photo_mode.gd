class_name PhotoMode
extends Control
## Photo mode (paused): orbit a free camera around the car, adjust the miniature blur, focus and
## warmth, hide the UI and save a picture. Touch drag / mouse drag orbits, pinch / wheel zooms;
## on a controller the sticks orbit and the triggers zoom.

signal closed

var cam: Camera3D
var target: Node3D
var post: ShaderMaterial
var _yaw := 0.0
var _pitch := 0.27
var _dist := 18.0
var _landmark_view := false
var _roadside: Button
var _blur := 1.0
var _warm := 0.0
var _focus := 0.55
var _bar: HBoxContainer
var _toast: PanelContainer
var _touches := {}
var _pinch := 0.0
var _restore_tap := Vector2.INF
var _hidden_by_user := false


func setup(c: Camera3D, t: Node3D, p: ShaderMaterial) -> void:
	cam = c
	target = t
	post = p
	_yaw = t.global_rotation.y + PI * 0.80
	_dist = (t as Car).half_len * 4.2 if t is Car else 9.0
	_position_camera()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	theme = PaperTheme.get_theme()
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	add_child(_bar)
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -78
	_bar.offset_left = 20
	for spec in [["Back", _close], ["Hide UI", _hide_ui], ["Blur -", func(): _adj("blur", -0.25)], ["Blur +", func(): _adj("blur", 0.25)],
			["Focus up", func(): _adj("focus", -0.05)], ["Focus down", func(): _adj("focus", 0.05)], ["Cooler", func(): _adj("warm", -0.03)],
			["Warmer", func(): _adj("warm", 0.03)], ["Save photo", _save]]:
		var b := Button.new()
		b.text = spec[0]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[1])
		_bar.add_child(b)
	if target is Car:
		var car := target as Car
		var mark := car.stage.scenery.landmark
		if mark and absf(mark.station-car.s)<=70.0:
			_roadside = Button.new()
			_roadside.text = "Roadside view"
			_roadside.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			_roadside.offset_left = -215
			_roadside.offset_right = -20
			_roadside.offset_top = 20
			_roadside.pressed.connect(func():
				_landmark_view = not _landmark_view
				_roadside.text = "Orbit view" if _landmark_view else "Roadside view"
				_position_camera())
			add_child(_roadside)
	_toast = PaperTheme.tag("Drag to orbit · Pinch or scroll to zoom\nTap the picture or press A to show hidden controls", 20)
	add_child(_toast)
	_toast.position = Vector2(20, 20)
	await get_tree().process_frame
	for index in _bar.get_child_count():
		var button := _bar.get_child(index) as Button
		button.focus_neighbor_left = button.get_path_to(_bar.get_child(maxi(0, index - 1)))
		button.focus_neighbor_right = button.get_path_to(_bar.get_child(mini(_bar.get_child_count() - 1, index + 1)))
		button.focus_neighbor_top = button.get_path_to(_roadside if _roadside else button)
		button.focus_neighbor_bottom = button.get_path_to(button)
	if _roadside:
		_roadside.focus_neighbor_bottom = _roadside.get_path_to(_bar.get_child(-1))
	(_bar.get_child(0) as Button).grab_focus()
	_apply()


func _adj(what: String, d: float) -> void:
	match what:
		"blur": _blur = clampf(_blur + d, 0.0, 2.5)
		"focus": _focus = clampf(_focus + d, 0.2, 0.85)
		"warm": _warm = clampf(_warm + d, -0.15, 0.15)
	_apply()


func _apply() -> void:
	var h := float(DisplayServer.window_get_size().y)
	post.set_shader_parameter("taps", 16 if _blur > 0.01 else 0)
	post.set_shader_parameter("max_blur_px", 14.0 * _blur * h / 1080.0)
	post.set_shader_parameter("focus_y", _focus)
	post.set_shader_parameter("tint", Vector3(1.0 + _warm, 0.99, 1.0 - _warm))


func _hide_ui() -> void:
	_hidden_by_user = true
	_restore_tap = Vector2.INF
	_bar.hide()
	if _roadside: _roadside.hide()
	_toast.visible = false


func _restore_ui() -> void:
	_hidden_by_user = false
	_restore_tap = Vector2.INF
	_bar.show()
	if _roadside: _roadside.show()
	(_bar.get_child(1) as Button).grab_focus()


func _save() -> void:
	_bar.visible = false
	if _roadside: _roadside.hide()
	_toast.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var name := "paper_rally_%d.png" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/" + name
	img.save_png(path)
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var shown := ProjectSettings.globalize_path(path)
	if pics != "" and DirAccess.make_dir_recursive_absolute(pics + "/Paper Rally") == OK:
		if img.save_png(pics + "/Paper Rally/" + name) == OK:
			shown = pics + "/Paper Rally/" + name
	_bar.visible = true
	if _roadside: _roadside.show()
	(_bar.get_child(-1) as Button).grab_focus()
	(_toast.get_child(0) as Label).text = "Saved: " + shown
	_toast.visible = true
	Sfx.click()


func _close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _hidden_by_user and event.is_action_pressed("ui_accept"):
		_restore_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _gui_input(event: InputEvent) -> void:
	if _hidden_by_user and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			if event.pressed:
				_restore_tap = event.position if _touches.is_empty() else Vector2.INF
			elif _restore_tap.distance_to(event.position) < 12.0:
				_restore_ui()
			else:
				_restore_tap = Vector2.INF
		elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _restore_tap.distance_to(event.position) >= 12.0:
			_restore_tap = Vector2.INF
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and _touches.size() < 2:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, 0.05, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(4.0, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(90.0, _dist * 1.1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch > 0.0:
				_dist = clampf(_dist * _pinch / maxf(d, 1.0), 4.0, 90.0)
			_pinch = d


func _process(delta: float) -> void:
	if cam == null or target == null:
		return
	var pads := Input.get_connected_joypads()
	var pad := int(pads[0]) if not pads.is_empty() else 0
	var rx := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
	if absf(rx) > 0.15:
		_yaw -= rx * delta * 1.8
	if absf(ry) > 0.15:
		_pitch = clampf(_pitch + ry * delta * 1.2, 0.05, 1.45)
	var zoom := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
	if absf(zoom) > 0.1:
		_dist = clampf(_dist * (1.0 - zoom * delta), 4.0, 90.0)
	_position_camera()


func _position_camera() -> void:
	var c := target.global_position + Vector3.UP * 0.8
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	var eye := c+off
	if target is Car:
		var car := target as Car
		if _landmark_view:
			var mark := car.stage.scenery.landmark
			var site := mark.global_position+Vector3.UP*1.4
			var delta := Vector2(site.x-c.x,site.z-c.z)
			var aim := delta.normalized()
			var xy := car.pos-aim*clampf(delta.length()*0.8,10.0,44.0)+aim.orthogonal()*7.0
			eye = Vector3(xy.x,c.y+3.2,xy.y)
			# Raise the roadside lens enough to clear intervening banks.
			for step in range(1,12):
				var t := step/12.0
				var sample := car.pos.lerp(xy,t)
				var clearance := car.track.terrain.height(sample)+0.35
				eye.y = maxf(eye.y,c.y+(clearance-c.y)/t)
			c = c.lerp(site,0.34)
		eye.y = maxf(eye.y,car.track.terrain.height(Vector2(eye.x,eye.z))+0.75)
	cam.global_position = eye
	cam.look_at(c, Vector3.UP)
	if target is Car:
		target.stage.update_tunnel_roof(cam, target.s)
