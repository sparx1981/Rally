class_name RaceResults
extends HBoxContainer
## The end-of-race screen, built as a small piece of paper theatre:
##  * a cut-paper podium whose three blocks rise one after another, each topped by a little paper car;
##  * the player's finishing place inked in with a rally stamp that lands with a thud;
##  * the classification unfolding strip by strip, with a gap bar behind every time.
## Every animation is a finite tween (about three seconds) and the redraw loop switches itself off afterwards,
## so a results page left open does nothing at all. Any tap skips straight to the finished state.

const GOLD := Color("#e8c05a")
const SILVER := Color("#d6d9dd")
const BRONZE := Color("#cf9a6a")
const GOLD_INK := Color("#b9821a")

var rows: Array = []
var champ := {}
var pos := 1
var _tweens: Array[Tween] = []
var _podium: Podium
var _stamp: Stamp
var _stamp_holder: Control
var _time_label: Label
var _confetti: CPUParticles2D
var _animating := true
var _clock := 0.0
var _landed := false


## r: the race result dictionary. info: championship extras from RaceResults.champ_info(), or {}.
static func champ_info(r: Dictionary) -> Dictionary:
	var rows_in: Array = r["rows"]
	var earned := {}
	var before := {}
	for i in rows_in.size():
		var n: String = rows_in[i]["name"]
		earned[n] = Catalog.POINTS[i] if i < Catalog.POINTS.size() else 0
		before[n] = int(Game.champ_points.get(n, 0)) - int(earned[n])
	var order_before: Array = before.keys()
	order_before.sort_custom(func(a, b): return before[a] > before[b])
	var order_now: Array = Game.standings().map(func(x): return x["name"])
	var rank_move := {}
	for n: String in order_now:
		rank_move[n] = order_before.find(n) - order_now.find(n)   # positive = climbed
	var info := {"earned": earned, "total": Game.champ_points, "move": rank_move, "final": Game.champ_finished(),
		"final_pos": order_now.find("You") + 1}
	if Game.champ_finished():
		var nxt := Game.series_index + 1
		if nxt < Catalog.series().size():
			info["unlock"] = String(Catalog.series()[nxt]["name"])
	return info


func setup(r: Dictionary, info := {}) -> RaceResults:
	rows = r["rows"]
	champ = info
	for i in rows.size():
		if rows[i]["player"]:
			pos = i + 1
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 22)

	_podium = Podium.new()
	_podium.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_podium.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_podium.size_flags_stretch_ratio = 0.9
	_podium.custom_minimum_size = Vector2(380, 360)
	_podium.setup(rows, pos)
	add_child(_podium)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.15
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	right.add_child(_header())
	right.add_child(_classification())
	_confetti = _make_confetti()
	add_child(_confetti)
	_play_intro()
	return self


# --- header: stamp + time ---------------------------------------------------------------------------

func _header() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_stamp_holder = Control.new()
	_stamp_holder.custom_minimum_size = Vector2(176, 176)
	box.add_child(_stamp_holder)
	_stamp = Stamp.new()
	_stamp.size = Vector2(176, 176)
	_stamp.pivot_offset = Vector2(88, 88)
	var shown_pos := pos
	var word := "WINNER" if pos == 1 else ("PODIUM" if pos <= 3 else "CLASSIFIED")
	if champ.get("final", false):
		shown_pos = int(champ["final_pos"])
		word = "CHAMPION" if shown_pos == 1 else "SEASON"
	_stamp.ink = GOLD_INK if shown_pos == 1 else (PaperTheme.ACCENT if shown_pos <= 3 else PaperTheme.EDGE)
	_stamp.label = "P%d" % shown_pos
	_stamp.word = word
	_stamp.modulate.a = 0.0
	_stamp_holder.add_child(_stamp)

	var facts := VBoxContainer.new()
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 4)
	box.add_child(facts)
	var kicker := Label.new()
	kicker.text = "YOUR TIME" if not champ.has("earned") else "STAGE TIME"
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.add_theme_color_override("font_color", PaperTheme.ACCENT)
	facts.add_child(kicker)
	_time_label = Label.new()
	var my_time: float = float(rows[pos - 1]["time"])
	_time_label.text = Game.fmt_time(0.0)
	_time_label.add_theme_font_size_override("font_size", 52)
	_time_label.add_theme_color_override("font_color", PaperTheme.INK)
	facts.add_child(_time_label)
	var gap := Label.new()
	gap.add_theme_font_size_override("font_size", 20)
	gap.add_theme_color_override("font_color", PaperTheme.INK)
	if pos == 1:
		var margin := float(rows[1]["time"]) - my_time if rows.size() > 1 else 0.0
		gap.text = "Won by %.2f s" % margin if margin > 0.0 else "Winner"
	else:
		gap.text = "%.2f s behind %s" % [my_time - float(rows[0]["time"]), String(rows[0]["name"])]
	if champ.get("final", false) and champ.has("unlock"):
		var unlock := PaperTheme.tag("%s unlocked" % champ["unlock"], 20, Color("#f0cf6a"))
		unlock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		facts.add_child(unlock)
	else:
		facts.add_child(gap)
	if champ.has("earned"):
		var pts: int = int(champ["earned"].get("You", 0))
		var chip := PaperTheme.tag("+%d points" % pts if pts > 0 else "No points", 20, Color("#f0cf6a") if pts >= 8 else PaperTheme.CREAM)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		facts.add_child(chip)
	var count := create_tween()
	count.tween_interval(0.45)
	count.tween_method(func(v: float): _time_label.text = Game.fmt_time(v), 0.0, my_time, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tweens.append(count)
	return box


# --- classification ----------------------------------------------------------------------------------

func _classification() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	var max_gap := 0.1
	for r: Dictionary in rows:
		max_gap = maxf(max_gap, float(r["time"]) - float(rows[0]["time"]))
	for i in rows.size():
		var strip := _strip(i, rows[i], max_gap)
		list.add_child(strip)
		strip.modulate.a = 0.0
		strip.scale.y = 0.15
		strip.resized.connect(func(): strip.pivot_offset = Vector2(0.0, strip.size.y * 0.5))
		var tw := create_tween().set_parallel(true)
		var delay := 1.15 + float(i) * 0.09
		tw.tween_property(strip, "modulate:a", 1.0, 0.18).set_delay(delay)
		tw.tween_property(strip, "scale:y", 1.0, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tweens.append(tw)
	return list


func _strip(i: int, r: Dictionary, max_gap: float) -> Control:
	var you: bool = r["player"]
	var panel := PanelContainer.new()
	var bg := Color("#f0cf6a") if you else PaperTheme.CREAM
	panel.add_theme_stylebox_override("panel", PaperTheme.box(bg, PaperTheme.ACCENT if you else PaperTheme.EDGE, 4 if you else 2, 6, 3))
	panel.custom_minimum_size.y = 40
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var medal := [GOLD, SILVER, BRONZE]
	var pos_box := Panel.new()
	pos_box.custom_minimum_size = Vector2(34, 30)
	var pc: Color = medal[i] if i < 3 else Color("#e6d9bf")
	pos_box.add_theme_stylebox_override("panel", PaperTheme.box(pc, PaperTheme.EDGE, 2, 5, 0))
	var pl := Label.new()
	pl.text = str(i + 1)
	pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 20)
	pos_box.add_child(pl)
	h.add_child(pos_box)
	var name_l := Label.new()
	name_l.text = String(r["name"])
	name_l.custom_minimum_size.x = 150
	name_l.add_theme_font_size_override("font_size", 21)
	h.add_child(name_l)
	var car_l := Label.new()
	car_l.text = String(Catalog.cars()[maxi(int(r["car"]), 0)]["name"])
	car_l.custom_minimum_size.x = 130
	car_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_l.clip_text = true
	car_l.add_theme_font_size_override("font_size", 15)
	car_l.add_theme_color_override("font_color", Color(0.23, 0.16, 0.11, 0.7))
	h.add_child(car_l)
	var gap := float(r["time"]) - float(rows[0]["time"])
	var bar := GapBar.new()
	bar.custom_minimum_size = Vector2(70, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.target = 1.0 if i == 0 else clampf(gap / max_gap, 0.06, 1.0)
	bar.leader = i == 0
	bar.you = you
	h.add_child(bar)
	var tl := Label.new()
	tl.text = Game.fmt_time(float(r["time"])) if i == 0 else "+%.2f" % gap
	tl.custom_minimum_size.x = 92
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.add_theme_font_size_override("font_size", 20)
	h.add_child(tl)
	if champ.has("earned"):
		var name: String = r["name"]
		var pts := Label.new()
		pts.text = "+%d" % int(champ["earned"].get(name, 0))
		pts.custom_minimum_size.x = 42
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts.add_theme_font_size_override("font_size", 19)
		pts.add_theme_color_override("font_color", PaperTheme.ACCENT)
		h.add_child(pts)
		var tot := Label.new()
		var mv: int = int(champ["move"].get(name, 0))
		tot.text = "%d%s" % [int(champ["total"].get(name, 0)), "  ▲%d" % mv if mv > 0 else ("  ▼%d" % -mv if mv < 0 else "")]
		tot.custom_minimum_size.x = 92
		tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tot.add_theme_font_size_override("font_size", 20)
		h.add_child(tot)
	return panel


# --- the show ------------------------------------------------------------------------------------------

func _make_confetti() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.amount = 90
	p.lifetime = 3.2
	p.explosiveness = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(420.0, 6.0)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.z_index = 40
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84])
	g.colors = PackedColorArray([Color("#e8453c"), Color("#f2c630"), Color("#3f8fd8"), Color("#4fc46a"), Color("#f5f0e6"), Color("#e86fb0")])
	p.color_initial_ramp = g
	return p


func _play_intro() -> void:
	var podium := create_tween()
	podium.tween_interval(0.15)
	podium.tween_method(func(v: float): _podium.rise[2] = v, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	podium.tween_method(func(v: float): _podium.rise[1] = v, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	podium.tween_method(func(v: float): _podium.rise[0] = v, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(podium)
	var cars := create_tween()
	cars.tween_interval(0.85)
	cars.tween_method(func(v: float): _podium.drop = v, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tweens.append(cars)
	var rays := create_tween()
	rays.tween_interval(1.0)
	rays.tween_method(func(v: float): _podium.star = v, 0.0, 1.0, 0.6)
	_tweens.append(rays)

	var stamp := create_tween().set_parallel(true)
	stamp.tween_property(_stamp, "modulate:a", 1.0, 0.05).set_delay(1.5)
	stamp.tween_method(func(v: float): _stamp.scale = Vector2.ONE * v, 2.8, 1.0, 0.17).set_delay(1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	stamp.tween_method(func(v: float): _stamp.rotation = v, -0.45, -0.1, 0.17).set_delay(1.5)
	stamp.chain().tween_callback(_stamp_landed)
	_tweens.append(stamp)
	var shock := create_tween()
	shock.tween_interval(1.67)
	shock.tween_method(func(v: float): _stamp.shock = v, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(shock)


func _stamp_landed() -> void:
	if _landed:
		return
	_landed = true
	Sfx.play("thud", -2.0, 0.8)
	Haptics.impulse(0.55, 0.14)
	var shake := create_tween()
	shake.tween_method(func(v: float): _podium.shake = Vector2(sin(v * 60.0), cos(v * 47.0)) * 6.0 * (1.0 - v), 0.0, 1.0, 0.3)
	_tweens.append(shake)
	if pos <= 3 or champ.get("final_pos", 9) == 1:
		var vw := get_viewport_rect().size.x
		_confetti.position = Vector2(vw * 0.5, -8.0)
		_confetti.emission_rect_extents = Vector2(vw * 0.4, 6.0)
		_confetti.emitting = true
		Sfx.play("go", -8.0, 1.5)


func _process(delta: float) -> void:
	_clock += delta
	_podium.spin += delta * 0.35
	_podium.queue_redraw()
	_stamp.queue_redraw()
	if _clock > 4.5:
		_finish_animation()


func _finish_animation() -> void:
	if not _animating:
		return
	_animating = false
	for tw in _tweens:
		if tw.is_valid():
			tw.custom_step(100.0)
	_stamp_landed_silent()
	_podium.queue_redraw()
	_stamp.queue_redraw()
	set_process(false)


func _stamp_landed_silent() -> void:
	_landed = true
	_stamp.shock = 1.0
	_stamp.modulate.a = 1.0
	_stamp.scale = Vector2.ONE
	_stamp.rotation = -0.1
	_podium.shake = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if _animating and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
			or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
		_finish_animation()


## The finished page does nothing: stop every tween and particle the moment it leaves the tree.
func _exit_tree() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()


# --- drawing pieces ------------------------------------------------------------------------------------

class GapBar:
	extends Control
	var target := 0.5
	var leader := false
	var you := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.23, 0.16, 0.11, 0.16))
		var col := Color("#d9a441") if leader else (PaperTheme.ACCENT if you else Color("#9b7a55"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * target, size.y)), col)
		draw_rect(Rect2(Vector2.ZERO, size), PaperTheme.EDGE, false, 1.5)


class Stamp:
	extends Control
	var ink := PaperTheme.ACCENT
	var label := "P1"
	var word := "WINNER"
	var shock := 1.0
	var _font: Font = PaperTheme.font()

	func _draw() -> void:
		var c := size * 0.5
		var font := _font
		draw_circle(c, 82.0, Color(ink, 0.09))
		draw_arc(c, 82.0, 0.0, TAU, 64, ink, 7.0, true)
		draw_arc(c, 68.0, 0.0, TAU, 56, ink, 2.5, true)
		var sz := 74 if label.length() <= 2 else 56
		draw_string(font, Vector2(c.x - 80.0, c.y + 12.0), label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, sz, ink)
		draw_line(Vector2(c.x - 52.0, c.y + 24.0), Vector2(c.x + 52.0, c.y + 24.0), ink, 2.5)
		draw_string(font, Vector2(c.x - 80.0, c.y + 50.0), word, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 19 if word.length() < 8 else 14, ink)
		# Small stars around the inner ring, like a rally stamp.
		for i in 10:
			var a := TAU * float(i) / 10.0 - PI * 0.5
			if absf(sin(a)) > 0.95:
				continue
			draw_circle(c + Vector2(cos(a), sin(a)) * 75.0, 2.4, ink)
		# Worn ink: little paper-coloured specks over the print.
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 60:
			var ang := rng.randf() * TAU
			var rad := rng.randf_range(20.0, 90.0)
			draw_circle(c + Vector2(cos(ang), sin(ang)) * rad, rng.randf_range(0.8, 3.2), Color(PaperTheme.CREAM, rng.randf_range(0.35, 0.8)))
		if shock > 0.0 and shock < 1.0:
			draw_arc(c, 82.0 + shock * 60.0, 0.0, TAU, 64, Color(ink, (1.0 - shock) * 0.6), 5.0 * (1.0 - shock) + 1.0, true)


class Podium:
	extends Control
	var top: Array = []
	var you_row := {}
	var you_pos := 1
	var rise: Array = [0.0, 0.0, 0.0]   # indexed by place - 1
	var drop := 0.0
	var star := 0.0
	var spin := 0.0
	var shake := Vector2.ZERO
	var _font: Font = PaperTheme.font()

	func setup(all_rows: Array, player_pos: int) -> void:
		clip_contents = true
		top = all_rows.slice(0, mini(3, all_rows.size()))
		you_pos = player_pos
		if player_pos > 3:
			you_row = all_rows[player_pos - 1]

	func _draw() -> void:
		draw_set_transform(shake, 0.0, Vector2.ONE)
		var font := _font
		var edge := PaperTheme.EDGE
		var bw := minf(138.0, (size.x - 110.0) / 3.0)
		var depth := 16.0
		var total := bw * 3.0 + 12.0 + depth
		var x0 := (size.x - total) * 0.5 - (44.0 if not you_row.is_empty() else 0.0)
		var base := size.y - 22.0
		var scale := clampf((size.y - 150.0) / 210.0, 0.55, 1.0)
		var full: Array = [210.0 * scale, 156.0 * scale, 116.0 * scale]
		var xs: Array = [x0 + bw + 6.0, x0, x0 + (bw + 6.0) * 2.0]   # place 1 centre, 2 left, 3 right
		var cols: Array = [RaceResults.GOLD, RaceResults.SILVER, RaceResults.BRONZE]
		# Rays of light behind the winner.
		if star > 0.0 and top.size() > 0:
			var sc := Vector2(xs[0] + bw * 0.5, base - full[0] - 60.0)
			for i in 14:
				var a := spin + TAU * float(i) / 14.0
				var r := 260.0 * star
				draw_colored_polygon(PackedVector2Array([sc, sc + Vector2(cos(a - 0.07), sin(a - 0.07)) * r, sc + Vector2(cos(a + 0.07), sin(a + 0.07)) * r]), Color(RaceResults.GOLD, 0.2 * star))
		# Floor and its soft shadow.
		draw_rect(Rect2(8.0, base + 2.0, size.x - 16.0, 8.0), Color(0.23, 0.13, 0.05, 0.28))
		for place in range(top.size()):
			var k: float = rise[place]
			var h: float = full[place] * k
			if h < 1.0:
				continue
			var x: float = xs[place]
			var y := base - h
			var front := Rect2(x, y, bw, h)
			var col: Color = cols[place]
			draw_rect(Rect2(x + 6.0, y + 6.0, bw + depth, h), Color(0.23, 0.13, 0.05, 0.22))
			draw_colored_polygon(PackedVector2Array([Vector2(x + bw, y), Vector2(x + bw + depth, y - 10.0), Vector2(x + bw + depth, y + h - 10.0), Vector2(x + bw, y + h)]), col.darkened(0.22))
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + depth, y - 10.0), Vector2(x + bw + depth, y - 10.0), Vector2(x + bw, y)]), col.lightened(0.28))
			draw_rect(front, col)
			draw_rect(front, edge, false, 3.0)
			draw_polyline(PackedVector2Array([Vector2(x + bw, y), Vector2(x + bw + depth, y - 10.0), Vector2(x + bw + depth, y + h - 10.0), Vector2(x + bw, y + h)]), edge, 3.0)
			draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + depth, y - 10.0), Vector2(x + bw + depth, y - 10.0)]), edge, 3.0)
			var nsz := int(clampf(h * 0.55, 20.0, 84.0))
			draw_string(font, Vector2(x, y + h * 0.5 + nsz * 0.36), str(place + 1), HORIZONTAL_ALIGNMENT_CENTER, bw, nsz, edge)
			if bool(top[place]["player"]):
				draw_rect(Rect2(x - 4.0, y - 4.0, bw + 8.0, h + 8.0), PaperTheme.ACCENT, false, 4.0)
			_token(font, top[place], Vector2(x + bw * 0.5, y - 6.0), bool(top[place]["player"]), "", place == 0)
		if not you_row.is_empty():
			var ex := size.x - 54.0
			_token(font, you_row, Vector2(ex, base - 4.0), true, "P%d" % you_pos, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A little paper car dropping onto its block, with a name flag above it.
	func _token(font: Font, row: Dictionary, foot: Vector2, you: bool, tag: String, winner: bool) -> void:
		var d := (1.0 - drop) * -150.0
		var f := Vector2(foot.x, foot.y + d)
		var car: Dictionary = Catalog.cars()[maxi(int(row["car"]), 0)]
		var body: Color = car["body"]
		var acc: Color = car["accent"]
		var edge := PaperTheme.EDGE
		# wheels
		for wx in [-26.0, 26.0]:
			draw_circle(f + Vector2(wx, -9.0), 10.0, edge)
			draw_circle(f + Vector2(wx, -9.0), 4.0, Color("#e6d9bf"))
		# lower body and cabin
		var lower := PackedVector2Array([f + Vector2(-46, -10), f + Vector2(-44, -24), f + Vector2(44, -24), f + Vector2(47, -10)])
		draw_colored_polygon(lower, body)
		draw_polyline(PackedVector2Array([lower[0], lower[1], lower[2], lower[3], lower[0]]), edge, 2.5)
		var cabin := PackedVector2Array([f + Vector2(-24, -24), f + Vector2(-14, -40), f + Vector2(18, -40), f + Vector2(32, -24)])
		draw_colored_polygon(cabin, body.lightened(0.12))
		draw_polyline(PackedVector2Array([cabin[0], cabin[1], cabin[2], cabin[3]]), edge, 2.5)
		draw_colored_polygon(PackedVector2Array([f + Vector2(-17, -26), f + Vector2(-10, -37), f + Vector2(-1, -37), f + Vector2(-1, -26)]), Color("#2a3a4a"))
		draw_colored_polygon(PackedVector2Array([f + Vector2(3, -26), f + Vector2(3, -37), f + Vector2(15, -37), f + Vector2(25, -26)]), Color("#2a3a4a"))
		draw_line(f + Vector2(-44, -17), f + Vector2(46, -17), acc, 3.0)
		# name flag
		var name := String(row["name"]) if tag == "" else "YOU  " + tag
		if you and tag == "":
			name = "YOU"
		var fs := 17
		var wdt := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		var rect := Rect2(f.x - wdt * 0.5, f.y - 76.0, wdt, 26.0)
		draw_style_box(PaperTheme.box(PaperTheme.ACCENT if you else PaperTheme.CREAM, edge, 2, 5, 0), rect)
		draw_string(font, Vector2(rect.position.x, rect.position.y + 19.0), name, HORIZONTAL_ALIGNMENT_CENTER, wdt, fs, Color.WHITE if you else PaperTheme.INK)
		draw_line(Vector2(f.x, rect.end.y), Vector2(f.x, f.y - 42.0), edge, 2.0)
		if winner and drop > 0.9:
			var cx := f.x
			var cy := f.y - 92.0
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 15, cy), Vector2(cx - 18, cy - 14), Vector2(cx - 8, cy - 7), Vector2(cx, cy - 18), Vector2(cx + 8, cy - 7), Vector2(cx + 18, cy - 14), Vector2(cx + 15, cy)]), RaceResults.GOLD)
			draw_polyline(PackedVector2Array([Vector2(cx - 15, cy), Vector2(cx - 18, cy - 14), Vector2(cx - 8, cy - 7), Vector2(cx, cy - 18), Vector2(cx + 8, cy - 7), Vector2(cx + 18, cy - 14), Vector2(cx + 15, cy), Vector2(cx - 15, cy)]), edge, 2.0)
