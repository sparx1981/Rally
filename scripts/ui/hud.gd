class_name Hud
extends Control

signal camera_pressed
## In-race overlay drawn as small paper tags: stage time, position, speed and gear, a co-driver
## pace-note card for the next bend, a stage progress strip and big countdown / finish cards.

var time_tag: PanelContainer
var sub_tag: PanelContainer
var speed_tag: PanelContainer
var pos_tag: PanelContainer
var fps_label: Label
var center_card: PanelContainer
var hint_tag: PanelContainer
var pace: PaceNote
var strip: ProgressStrip
var _center_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PaperTheme.get_theme()
	time_tag = PaperTheme.tag("0:00.00", 38)
	_place(time_tag, Vector2(24, 20))
	sub_tag = PaperTheme.tag("", 22)
	_place(sub_tag, Vector2(24, 92))
	pos_tag = PaperTheme.tag("", 34)
	pos_tag.visible = false
	speed_tag = PaperTheme.tag("0 km/h  1", 30)
	add_child(speed_tag)
	speed_tag.anchor_left = 0.5
	speed_tag.anchor_right = 0.5
	speed_tag.anchor_top = 1.0
	speed_tag.anchor_bottom = 1.0
	speed_tag.offset_top = -72
	speed_tag.offset_bottom = -18
	speed_tag.offset_left = -120
	speed_tag.offset_right = 120
	speed_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(pos_tag)
	pos_tag.anchor_left = 1.0
	pos_tag.anchor_right = 1.0
	pos_tag.offset_left = -260
	pos_tag.offset_right = -130
	pos_tag.offset_top = 96
	var cam := CameraButton.new()
	add_child(cam)
	cam.anchor_left = 1.0
	cam.anchor_right = 1.0
	cam.offset_left = -228
	cam.offset_right = -132
	cam.offset_top = 18
	cam.offset_bottom = 88
	cam.pressed.connect(func(): camera_pressed.emit())
	pace = PaceNote.new()
	add_child(pace)
	pace.anchor_left = 0.5
	pace.anchor_right = 0.5
	pace.offset_left = -95
	pace.offset_right = 95
	pace.offset_top = 46
	pace.offset_bottom = 156
	strip = ProgressStrip.new()
	add_child(strip)
	strip.anchor_left = 0.25
	strip.anchor_right = 0.75
	strip.offset_top = 14
	strip.offset_bottom = 38
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_card = PaperTheme.tag("", 72)
	cc.add_child(center_card)
	center_card.visible = false
	hint_tag = PaperTheme.tag("", 22)
	add_child(hint_tag)
	hint_tag.anchor_left = 0.5
	hint_tag.anchor_right = 0.5
	hint_tag.anchor_top = 0.62
	hint_tag.anchor_bottom = 0.62
	hint_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_tag.visible = false
	fps_label = Label.new()
	fps_label.position = Vector2(24, 140)
	fps_label.add_theme_font_size_override("font_size", 18)
	add_child(fps_label)


func _place(c: Control, p: Vector2) -> void:
	add_child(c)
	c.position = p


static func _txt(tag: PanelContainer, text: String) -> void:
	(tag.get_child(0) as Label).text = text


func set_time(t: float) -> void:
	_txt(time_tag, Game.fmt_time(maxf(t, 0.0)))


func set_sub(text: String) -> void:
	sub_tag.visible = text != ""
	_txt(sub_tag, text)


func set_position_text(text: String) -> void:
	pos_tag.visible = text != ""
	_txt(pos_tag, text)


func set_speed(v: float, gear: int) -> void:
	var mph := int(Settings.g("units")) == 1
	var k := v * (2.9 if mph else 4.6)
	var g := "R" if gear == 0 else str(gear)
	_txt(speed_tag, "%d %s   %s" % [int(absf(k)), "mph" if mph else "km/h", g])


func show_center(text: String, dur := 1.0, size := 72) -> void:
	_txt(center_card, text)
	(center_card.get_child(0) as Label).add_theme_font_size_override("font_size", size)
	center_card.visible = true
	_center_t = dur
	# Paper flip-in: rotate about the bottom crease (no scaling or fading).
	center_card.pivot_offset = Vector2(center_card.size.x * 0.5, center_card.size.y)
	center_card.rotation = -0.25
	var tw := create_tween()
	tw.tween_property(center_card, "rotation", 0.03, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(center_card, "rotation", -0.015, 0.12)
	tw.tween_property(center_card, "rotation", 0.0, 0.1)


var _hint_t := 0.0


func show_hint_timed(text: String, dur: float) -> void:
	show_hint(text)
	_hint_t = dur


func show_hint(text: String) -> void:
	hint_tag.visible = text != ""
	_txt(hint_tag, text)


func _process(delta: float) -> void:
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0:
			center_card.visible = false
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			show_hint("")
	fps_label.visible = bool(Settings.g("show_fps"))
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()


class PaceNote:
	extends Control
	## A co-driver card: arrow for the direction and the bend's severity (1 = hairpin ... 6 = flat out).
	var dir := 0.0
	var sev := 0
	var hairpin := false
	var dist := 0.0
	var kind := ""

	func set_note(c: Dictionary, s: float) -> void:
		if c.is_empty():
			if kind != "":
				kind = ""
				queue_redraw()
			return
		var nk: String = c.get("kind", "corner")
		var nd: float = c["dir"]
		var ns: int = c["sev"]
		var nh: bool = c["hairpin"]
		var ndist := maxf(float(c["s0"]) - s, 0.0)
		if nk != kind or nd != dir or ns != sev or nh != hairpin or absf(ndist - dist) > 4.0:
			kind = nk
			dir = nd
			sev = ns
			hairpin = nh
			dist = ndist
			queue_redraw()

	func _draw() -> void:
		if kind == "":
			return
		var r := Rect2(Vector2.ZERO, size)
		var sb := PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 10, 6)
		draw_style_box(sb, r)
		if kind != "corner":
			_draw_hazard(r)
			return
		var c := Vector2(r.size.x * 0.25, r.size.y * 0.45)
		var col := PaperTheme.ACCENT if sev <= 2 else PaperTheme.INK
		# Arrow: a chunky bent shape pointing left or right.
		var d := dir
		var pts := PackedVector2Array([c + Vector2(-8 * d, 30), c + Vector2(8 * d, 30), c + Vector2(8 * d, 0), c + Vector2(18 * d, 0),
			c + Vector2(18 * d, 14), c + Vector2(40 * d, -6), c + Vector2(18 * d, -26), c + Vector2(18 * d, -12), c + Vector2(-8 * d, -12)])
		if d < 0.0:
			pts.reverse()
		draw_colored_polygon(pts, col)
		var font := get_theme_default_font()
		var txt := "HP" if hairpin else str(sev)
		var fs := 40 if hairpin else 48
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(r.size.x * 0.73 - ts.x * 0.5, r.size.y * 0.45 + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var dt := "%dm" % int(dist)
		draw_string(font, Vector2(r.size.x * 0.5 - 22, r.size.y - 8), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PaperTheme.INK)


	func _draw_hazard(r: Rect2) -> void:
		var font := get_theme_default_font()
		var ink := PaperTheme.INK
		var red := PaperTheme.ACCENT
		var c := Vector2(r.size.x * 0.5, r.size.y * 0.36)
		match kind:
			"jump":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-46, 18), c + Vector2(10, 18), c + Vector2(10, -6)]), red)
				draw_arc(c + Vector2(28, 14), 22.0, PI * 1.05, PI * 1.85, 10, ink, 4.0)
			"crest":
				var pts := PackedVector2Array()
				for k in 17:
					var x := -48.0 + k * 6.0
					pts.append(c + Vector2(x, 18.0 - 26.0 * pow(cos(x / 48.0 * PI * 0.5), 2.0)))
				pts.append(c + Vector2(48, 20))
				pts.append(c + Vector2(-48, 20))
				draw_colored_polygon(pts, red)
			"splash":
				for row in 2:
					var pts := PackedVector2Array()
					for k in 13:
						pts.append(c + Vector2(-48.0 + k * 8.0, -4.0 + row * 16.0 + sin(k * 1.4) * 5.0))
					draw_polyline(pts, Color("#3f6fa8"), 5.0)
			"chicane":
				draw_polyline(PackedVector2Array([c + Vector2(-10, 24), c + Vector2(-10, 6), c + Vector2(12, -4), c + Vector2(12, -22)]), red, 7.0)
				draw_rect(Rect2(c + Vector2(-44, -8), Vector2(22, 14)), Color("#e3c06a"))
				draw_rect(Rect2(c + Vector2(24, 2), Vector2(22, 14)), Color("#e3c06a"))
			_:
				for k in 9:
					draw_circle(c + Vector2(-36 + (k % 5) * 18, -8 + (k / 5) * 16 + (k % 2) * 4), 5.0, ink if kind != "ice" else Color("#6c84b0"))
		var label: String = {"jump": "JUMP", "crest": "CREST", "splash": "SPLASH", "chicane": "CHICANE"}.get(kind, kind.to_upper())
		var fs := 24
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(r.size.x * 0.5 - ts.x * 0.5, r.size.y * 0.78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red if kind in ["jump", "chicane", "ice"] else ink)
		draw_string(font, Vector2(r.size.x - 50, r.size.y - 8), "%dm" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)


class CameraButton:
	extends Control
	## A paper camera icon: tap / click to cycle camera views.
	signal pressed
	var _down := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Change camera view"

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_down = event.pressed
			if not event.pressed:
				pressed.emit()
			queue_redraw()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := PaperTheme.CREAM_DOWN if _down else PaperTheme.CREAM
		draw_style_box(PaperTheme.box(bg, PaperTheme.EDGE, 3, 12, 0 if _down else 5), r)
		var c := r.get_center()
		var ink := PaperTheme.INK
		draw_rect(Rect2(c + Vector2(-26, -14), Vector2(52, 32)), ink)
		draw_rect(Rect2(c + Vector2(-12, -22), Vector2(22, 10)), ink)
		draw_circle(c + Vector2(0, 2), 11.0, PaperTheme.CREAM)
		draw_circle(c + Vector2(0, 2), 6.5, ink)
		draw_circle(c + Vector2(17, -8), 3.0, PaperTheme.ACCENT)


class ProgressStrip:
	extends Control
	var marks: Array = []   # [fraction, Color, is_player]

	func _draw() -> void:
		var r := Rect2(Vector2(0, size.y * 0.3), Vector2(size.x, size.y * 0.4))
		draw_style_box(PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 2, 6, 3), r)
		for m in marks:
			var x := clampf(float(m[0]), 0.0, 1.0) * size.x
			var rad := 9.0 if m[2] else 6.0
			draw_circle(Vector2(x, size.y * 0.5), rad + 2.0, PaperTheme.EDGE)
			draw_circle(Vector2(x, size.y * 0.5), rad, m[1])
