class_name JokerIntro
extends Control
## A short animated explainer shown the first time the Circuits section is opened: what the Joker lane is, that
## every race must use it once, what it costs and what skipping it costs. Tap Skip or Next at any point.

signal finished

const STEPS := [
	{"t": 0.0, "title": "Welcome to Rallycross",
		"body": "Circuits are closed loops raced for 3 to 12 laps, side by side with your rivals."},
	{"t": 4.0, "title": "The Joker lane",
		"body": "Every circuit has one extra route, the Joker lane. It splits off the main track and rejoins it a little further on."},
	{"t": 8.5, "title": "Take it once",
		"body": "During the race you must drive through the Joker lane once, on any lap you choose. Stay in the lane until it rejoins the circuit."},
	{"t": 13.0, "title": "It costs time",
		"body": "The lane is longer, so using it costs a few seconds. Choose your moment: after a first-corner scrap, or when you are out of position."},
	{"t": 17.5, "title": "Don't skip it",
		"body": "Cross the line without using the Joker lane and 15 seconds are added to your time. Watch the Joker tag on screen."},
]
const END_T := 22.0

var _t := 0.0
var _title: Label
var _body: Label
var _next: Button
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PaperTheme.get_theme()
	_font = PaperTheme.font()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 10, 8))
	add_child(card)
	card.anchor_left = 0.5
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = 20
	card.offset_right = -40
	card.offset_top = -150
	card.offset_bottom = 150
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", PaperTheme.ACCENT)
	col.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 24)
	_body.add_theme_color_override("font_color", PaperTheme.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 440
	col.add_child(_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var skip := Button.new()
	skip.text = "Skip"
	skip.pressed.connect(_finish)
	row.add_child(skip)
	_next = Button.new()
	_next.text = "Next"
	_next.pressed.connect(_advance)
	row.add_child(_next)
	_set_step(0)


func _step_index() -> int:
	var idx := 0
	for i in STEPS.size():
		if _t >= float(STEPS[i]["t"]):
			idx = i
	return idx


func _set_step(i: int) -> void:
	_title.text = String(STEPS[i]["title"])
	_body.text = String(STEPS[i]["body"])
	_next.text = "Let's race" if i == STEPS.size() - 1 else "Next"


func _advance() -> void:
	var i := _step_index()
	if i >= STEPS.size() - 1:
		_finish()
		return
	Sfx.click()
	_t = float(STEPS[i + 1]["t"]) + 0.01


func _finish() -> void:
	finished.emit()


func _process(delta: float) -> void:
	_t += delta
	var i := _step_index()
	if _title.text != String(STEPS[i]["title"]):
		_set_step(i)
	if _t > END_T + 4.0:
		_t = float(STEPS[STEPS.size() - 1]["t"]) + 0.5   # hold on the last step until the player continues
	queue_redraw()


# --- drawing: a real in-game overhead of Chalk Valley's Joker lane, with animated overlays -------------

const LANE := [Vector2(1430, 915), Vector2(1250, 700), Vector2(1050, 480), Vector2(850, 300), Vector2(700, 190),
	Vector2(560, 110), Vector2(450, 150), Vector2(415, 260)]
var _bg: Texture2D = preload("res://ui/joker_overhead.png")


func _to_screen(p: Vector2) -> Vector2:
	var k := maxf(size.x / 1920.0, size.y / 1080.0)
	return p * k + (size - Vector2(1920, 1080) * k) * 0.5


func _lane_point(u: float) -> Vector2:
	var f := clampf(u, 0.0, 1.0) * float(LANE.size() - 1)
	var i := mini(int(f), LANE.size() - 2)
	return _to_screen((LANE[i] as Vector2).lerp(LANE[i + 1], f - i))


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := maxf(w / 1920.0, h / 1080.0)
	var tw := 1920.0 * k
	var th := 1080.0 * k
	draw_texture_rect(_bg, Rect2((size - Vector2(tw, th)) * 0.5, Vector2(tw, th)), false, Color(0.82, 0.78, 0.74))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.06, 0.12, 0.25))
	var step_i := _step_index()
	var lane := PackedVector2Array()
	for q in LANE.size():
		lane.append(_to_screen(LANE[q]))
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	if step_i >= 1:
		draw_polyline(lane, Color(0.23, 0.13, 0.05, 0.5), 30.0 * k, true)
		var gold := Color("#f2c630")
		gold.a = 0.45 + 0.4 * pulse if step_i == 1 else 0.85
		draw_polyline(lane, gold, 16.0 * k, true)
		# Chevrons flowing along the lane.
		for c in 8:
			var u := fposmod(_t * 0.18 + float(c) / 8.0, 1.0)
			var a := _lane_point(u)
			var b := _lane_point(u + 0.015)
			var dir := (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var ch := PackedVector2Array([a + nrm * 8.0 * k, a + dir * 14.0 * k, a - nrm * 8.0 * k])
			draw_polyline(ch, Color("#fff4d0"), 4.0 * k, true)
	if step_i >= 1:
		var tp := _lane_point(0.55) + Vector2(60, -60) * k
		var tag := Rect2(tp, Vector2(180, 36) * k)
		draw_rect(Rect2(tag.position + Vector2(3, 4), tag.size), PaperTheme.SHADOW)
		draw_rect(tag, Color("#e8b04a"))
		draw_rect(tag, PaperTheme.EDGE, false, 3.0)
		draw_string(_font, tag.position + Vector2(14, 26) * k, "JOKER LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22.0 * k), PaperTheme.INK)
	# The player's car: along the main road at first, then through the lane.
	var cu := fposmod(_t * 0.09, 1.0)
	var car_p := _to_screen(Vector2(1560, 1010).lerp(Vector2(1000, 520), cu)) if step_i < 2 else _lane_point(cu)
	draw_circle(car_p + Vector2(2, 4), 13.0 * k, PaperTheme.SHADOW)
	draw_circle(car_p, 13.0 * k, PaperTheme.ACCENT)
	draw_circle(car_p, 13.0 * k, PaperTheme.EDGE, false, 3.0)
	if step_i >= 3:
		var states := ["JOKER: TO DO", "JOKER: NEEDED NOW", "JOKER: DONE"]
		var colours := [Color("#8a5a12"), Color("#b0301f"), Color("#2e7a3a")]
		var si := int(_t * 0.45) % 3 if step_i == 4 else 0
		var box := Rect2(Vector2(40, h - 130), Vector2(330, 40))
		draw_rect(Rect2(box.position + Vector2(3, 4), box.size), PaperTheme.SHADOW)
		draw_rect(box, PaperTheme.CREAM)
		draw_rect(box, PaperTheme.EDGE, false, 3.0)
		draw_string(_font, box.position + Vector2(14, 29), String(states[si]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colours[si])
	if step_i == 4:
		var pen := Rect2(Vector2(40, h - 80), Vector2(330, 40))
		draw_rect(pen, Color("#b0301f"))
		draw_string(_font, pen.position + Vector2(14, 29), "+15 s if skipped", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#fff3dc"))
