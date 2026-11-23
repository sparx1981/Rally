class_name TouchControls
extends Control
## On-screen paper buttons for phones without a controller: steer left / right (or tilt steering),
## accelerate, brake, handbrake and pause. Multi-touch; each finger is tracked by index.

signal pause_pressed

var steer := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := 0.0

var _touches := {}   # finger index -> button name
var _rects := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PaperTheme.get_theme()
	resized.connect(_layout)
	_layout()


func should_show() -> bool:
	var mode := int(Settings.g("touch_controls"))
	if mode == 2:
		return false
	if mode == 1:
		return true
	return DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var u := minf(h / 720.0, w / 1280.0) * 1.0
	var bs := 150.0 * u
	var m := 36.0 * u
	_rects = {}
	if int(Settings.g("touch_mode")) == 0:
		_rects["left"] = Rect2(m, h - bs - m, bs, bs)
		_rects["right"] = Rect2(m * 1.6 + bs, h - bs - m, bs, bs)
	_rects["gas"] = Rect2(w - bs * 1.15 - m, h - bs * 1.15 - m, bs * 1.15, bs * 1.15)
	_rects["brake"] = Rect2(w - bs * 2.15 - m * 1.6, h - bs * 0.85 - m, bs * 0.95, bs * 0.85)
	_rects["hb"] = Rect2(w - bs * 1.0 - m * 1.1, h - bs * 2.0 - m * 1.7, bs * 0.9, bs * 0.7)
	_rects["pause"] = Rect2(w - 92.0 * u - m * 0.5, m * 0.5, 92.0 * u, 70.0 * u)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _hit(event.position)
			if b != "":
				_touches[event.index] = b
				if b == "pause":
					pause_pressed.emit()
				Haptics.impulse(0.12, 0.02)
		else:
			_touches.erase(event.index)
		_refresh()
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			var b := _hit(event.position)
			if b != "" and b != "pause":
				_touches[event.index] = b
			_refresh()


func _hit(p: Vector2) -> String:
	for k in _rects.keys():
		var r: Rect2 = _rects[k]
		if r.grow(18.0).has_point(p):
			return k
	return ""


func _refresh() -> void:
	var vals := {}
	for k in _touches.values():
		vals[k] = true
	steer = (1.0 if vals.has("right") else 0.0) - (1.0 if vals.has("left") else 0.0)
	throttle = 1.0 if vals.has("gas") else 0.0
	brake = 1.0 if vals.has("brake") else 0.0
	handbrake = 1.0 if vals.has("hb") else 0.0
	queue_redraw()


func release_all() -> void:
	_touches.clear()
	_refresh()


func _draw() -> void:
	var font := get_theme_default_font()
	var held := {}
	for k in _touches.values():
		held[k] = true
	var labels := {"left": "<", "right": ">", "gas": "GAS", "brake": "BRAKE", "hb": "HAND", "pause": "II"}
	for k in _rects.keys():
		var r: Rect2 = _rects[k]
		var on := held.has(k)
		var bg := PaperTheme.CREAM_DOWN if on else PaperTheme.CREAM
		bg.a = 0.82
		var sh := r
		sh.position += Vector2(3, 4) if not on else Vector2(1, 1)
		draw_style_box(_sb(PaperTheme.SHADOW, Color(0, 0, 0, 0)), sh)
		draw_style_box(_sb(bg, PaperTheme.EDGE), r)
		var fs := int(r.size.y * (0.42 if labels[k].length() <= 2 else 0.2))
		var ts := font.get_string_size(labels[k], HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, r.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.32), labels[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PaperTheme.INK)


func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3 if border.a > 0.0 else 0)
	s.set_corner_radius_all(18)
	s.anti_aliasing = true
	return s
