class_name PaperTheme
extends RefCounted
## Cream card UI with dark-ink cut edges and a soft warm drop shadow (never grey).

const CREAM := Color("#f3e9d6")
const CREAM_HI := Color("#f8dca4")
const CREAM_DOWN := Color("#ecc683")
const INK := Color("#3a2a1c")
const EDGE := Color("#5a3a22")
const SHADOW := Color(0.23, 0.13, 0.05, 0.35)
const ACCENT := Color("#c8553d")

static var _theme: Theme


static func box(bg: Color, border := EDGE, bw := 3, radius := 8, shadow := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = SHADOW
	s.shadow_size = shadow
	s.shadow_offset = Vector2(3, 4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Serif", "Georgia", "DejaVu Serif", "Liberation Serif", "serif"])
	f.font_weight = 600
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 26
	var normal := box(CREAM)
	var hover := box(CREAM_HI)
	var pressed := box(CREAM_DOWN, EDGE, 3, 8, 2)
	var focus := box(Color(0, 0, 0, 0), ACCENT, 4, 10, 0)
	focus.draw_center = false
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	var disabled := box(Color("#e2dacb"), Color("#9a8a78"))
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, disabled)
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, INK)
		t.set_color("font_pressed_color", cls, INK)
		t.set_color("font_focus_color", cls, INK)
		t.set_color("font_hover_pressed_color", cls, INK)
		t.set_color("font_disabled_color", cls, Color("#8a7a68"))
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", box(CREAM, EDGE, 3, 10, 8))
	t.set_stylebox("panel", "Panel", box(CREAM, EDGE, 3, 10, 8))
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color("#c9b08a")
	track_sb.set_corner_radius_all(4)
	track_sb.content_margin_top = 4
	track_sb.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track_sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var sfocus := focus.duplicate()
	t.set_stylebox("focus", "HSlider", sfocus)
	t.set_icon("grabber", "HSlider", _knob(Color("#efe3c8")))
	t.set_icon("grabber_highlight", "HSlider", _knob(CREAM_HI))
	_theme = t
	return t


static func _knob(c: Color) -> Texture2D:
	var img := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 30:
		for x in 30:
			var d := Vector2(x - 14.5, y - 14.5).length()
			if d < 14.0:
				img.set_pixel(x, y, EDGE if d > 11.0 else c)
	return ImageTexture.create_from_image(img)


static func tag(text: String, size := 26, bg := CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, EDGE, 3, 8, 5))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
