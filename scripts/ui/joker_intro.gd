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


# --- drawing: a top-down circuit with its Joker lane ----------------------------------------------

const JOKER_A0 := 3.55   # angles (radians) the Joker lane spans on the loop
const JOKER_A1 := 4.55


func _route(a: float, joker: bool, c: Vector2, rx: float, ry: float) -> Vector2:
	var bump := 0.0
	if joker and a >= JOKER_A0 and a <= JOKER_A1:
		var k := (a - JOKER_A0) / (JOKER_A1 - JOKER_A0)
		bump = pow(sin(PI * k), 0.6) * 0.2
	return c + Vector2(cos(a) * rx * (1.0 + bump), sin(a) * ry * (1.0 + bump))


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.06, 0.12, 0.92))
	var c := Vector2(w * 0.27, h * 0.52)
	var rx := w * 0.2
	var ry := h * 0.3
	var step_i := _step_index()
	# Ground sheet.
	draw_rect(Rect2(Vector2(w * 0.03, h * 0.08), Vector2(w * 0.47, h * 0.84)), Color("#e8d8b4"), true)
	draw_rect(Rect2(Vector2(w * 0.03, h * 0.08), Vector2(w * 0.47, h * 0.84)), PaperTheme.EDGE, false, 3.0)
	var main_pts := PackedVector2Array()
	for k in 97:
		main_pts.append(_route(float(k) / 96.0 * TAU, false, c, rx, ry))
	draw_polyline(main_pts, PaperTheme.EDGE, 44.0, true)
	draw_polyline(main_pts, Color("#8d8274"), 36.0, true)
	var lane_pts := PackedVector2Array()
	for k in 41:
		lane_pts.append(_route(JOKER_A0 + (JOKER_A1 - JOKER_A0) * float(k) / 40.0, true, c, rx, ry))
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var lane_on := step_i >= 1
	draw_polyline(lane_pts, PaperTheme.EDGE, 38.0, true)
	draw_polyline(lane_pts, Color("#b6a68c"), 30.0, true)
	if lane_on:
		var gold := Color("#f2c630")
		gold.a = 0.35 + 0.4 * pulse if step_i == 1 else 0.7
		draw_polyline(lane_pts, gold, 8.0, true)
	# Start / finish line at the bottom.
	var sf := _route(PI * 0.5, false, c, rx, ry)
	draw_line(sf + Vector2(0, -22), sf + Vector2(0, 22), Color("#f3e9d6"), 6.0)
	draw_string(_font, sf + Vector2(-46, 52), "START / FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PaperTheme.INK)
	if lane_on:
		var lp := _route((JOKER_A0 + JOKER_A1) * 0.5, true, c, rx, ry)
		var tag := Rect2(lp + Vector2(-70, -64), Vector2(140, 28))
		draw_rect(tag, Color("#f2c630"), true)
		draw_rect(tag, PaperTheme.EDGE, false, 2.0)
		draw_string(_font, tag.position + Vector2(10, 21), "JOKER LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PaperTheme.INK)
	# Rival cars on the main route, and the player's car.
	for r in 3:
		var ru := fposmod(_t * 0.07 + float(r) * 0.33, 1.0)
		draw_circle(_route(PI * 0.5 + ru * TAU, false, c, rx, ry), 9.0, Color("#3f6fa8") if r != 1 else Color("#2f8a8a"))
	var pu := fposmod(_t * 0.075 + 0.08, 1.0)
	var pa := PI * 0.5 + pu * TAU
	var use_joker := step_i >= 2
	var pp := _route(pa, use_joker, c, rx, ry)
	var ahead := _route(pa + 0.02, use_joker, c, rx, ry)
	var ang := (ahead - pp).angle()
	var car := PackedVector2Array([Vector2(16, 0), Vector2(-12, -9), Vector2(-12, 9)])
	var xf := Transform2D(ang, pp)
	var pts := PackedVector2Array()
	for p in car:
		pts.append(xf * p)
	draw_colored_polygon(pts, PaperTheme.ACCENT)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), PaperTheme.EDGE, 2.0)
	# The on-screen Joker tag, as the player will see it.
	if step_i >= 3:
		var states := ["JOKER: TO DO", "JOKER: NEEDED NOW", "JOKER: DONE"]
		var colours := [Color("#8a5a12"), Color("#b0301f"), Color("#2e7a3a")]
		var si := int(_t * 0.45) % 3 if step_i == 4 else 0
		var box := Rect2(Vector2(w * 0.05, h * 0.82), Vector2(320, 36))
		draw_rect(box, PaperTheme.CREAM, true)
		draw_rect(box, PaperTheme.EDGE, false, 3.0)
		draw_string(_font, box.position + Vector2(14, 26), String(states[si]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, colours[si])
	if step_i == 4:
		var pen := Rect2(Vector2(w * 0.05, h * 0.74), Vector2(320, 36))
		draw_rect(pen, Color("#b0301f"), true)
		draw_string(_font, pen.position + Vector2(14, 26), "+15 s if skipped", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#fff3dc"))
