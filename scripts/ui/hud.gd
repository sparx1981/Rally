class_name Hud
extends Control
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
	pos_tag.offset_top = 20
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


func show_hint(text: String) -> void:
	hint_tag.visible = text != ""
	_txt(hint_tag, text)


func _process(delta: float) -> void:
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0:
			center_card.visible = false
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

	func set_note(c: Dictionary, s: float) -> void:
		if c.is_empty():
			if sev != 0:
				sev = 0
				queue_redraw()
			return
		var nd: float = c["dir"]
		var ns: int = c["sev"]
		var nh: bool = c["hairpin"]
		var ndist := maxf(float(c["s0"]) - s, 0.0)
		if nd != dir or ns != sev or nh != hairpin or absf(ndist - dist) > 4.0:
			dir = nd
			sev = ns
			hairpin = nh
			dist = ndist
			queue_redraw()

	func _draw() -> void:
		if sev == 0:
			return
		var r := Rect2(Vector2.ZERO, size)
		var sb := PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 10, 6)
		draw_style_box(sb, r)
		var c := Vector2(r.size.x * 0.3, r.size.y * 0.45)
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
		draw_string(font, Vector2(r.size.x * 0.7 - ts.x * 0.5, r.size.y * 0.45 + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var dt := "%dm" % int(dist)
		draw_string(font, Vector2(r.size.x * 0.5 - 22, r.size.y - 8), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PaperTheme.INK)


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
