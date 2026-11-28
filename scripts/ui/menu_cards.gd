class_name MenuCards
extends RefCounted
## Card-style menu pieces: paper cards, a sliding carousel, page dots and the tear-off control hint.


## "A SELECT" appears when a controller is attached, "ENTER / CLICK" on a keyboard-and-mouse
## machine; a phone or tablet in touch mode shows neither.
static func hint_tags() -> Array[String]:
	var tags: Array[String] = []
	var controller := not Input.get_connected_joypads().is_empty()
	var touch := DisplayServer.is_touchscreen_available()
	if controller:
		tags.append("A|SELECT")
	if not touch:
		tags.append("|(ENTER) / (CLICK)")
	return tags


static func controller_present() -> bool:
	return not Input.get_connected_joypads().is_empty()


## One torn-off paper tag: an optional round button glyph and a label.
static func tear_tag(glyph: String, text: String, tilt: float) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe3c8")
	sb.border_color = Color("#c9b894")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.23, 0.13, 0.05, 0.3)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 3)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	if glyph != "":
		var g := Label.new()
		g.text = glyph
		g.add_theme_font_size_override("font_size", 15)
		g.add_theme_color_override("font_color", PaperTheme.INK)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.custom_minimum_size = Vector2(24, 24)
		var gp := PanelContainer.new()
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0, 0, 0, 0)
		gs.border_color = PaperTheme.INK
		gs.set_border_width_all(2)
		gs.set_corner_radius_all(14)
		gp.add_theme_stylebox_override("panel", gs)
		gp.add_child(g)
		h.add_child(gp)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", PaperTheme.INK)
	h.add_child(l)
	p.rotation = tilt
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in p.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Paper pop-up for a control: it folds up from its bottom edge with a springy overshoot. Skipped
## when the pop-up effect is switched off in Settings.
static func pop_in(node: Control, delay: float) -> void:
	if not bool(Settings.g("popups")):
		return
	node.pivot_offset = Vector2(node.size.x * 0.5, node.size.y)
	var final_scale := node.scale
	node.scale = Vector2(final_scale.x * 0.94, 0.02)
	node.rotation = -0.03
	var t := node.create_tween()
	t.set_parallel(true)
	if node is Card:
		node.pop_a = 0.0
		t.tween_property(node, "pop_a", 1.0, 0.18).set_delay(delay)
	else:
		node.modulate.a = 0.0
		t.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(delay)
	t.tween_property(node, "scale", final_scale, 0.55).set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation", 0.0, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A big paper card (button). opts: title, desc, image (Texture2D), badge, best, size, title_size, desc_size.
class Card:
	extends Button
	var opts := {}
	var tear: Control
	var _focus_t: Tween
	var base_scale := Vector2.ONE
	var carousel: Control
	var index := 0
	var base_alpha := 1.0
	var pop_a := 1.0

	func _process(_delta: float) -> void:
		modulate = Color(1, 1, 1, base_alpha * pop_a)

	func setup(o: Dictionary) -> Card:
		opts = o
		text = ""
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = o.get("size", Vector2(300, 300))
		size = custom_minimum_size
		add_theme_stylebox_override("normal", PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 8, 6))
		add_theme_stylebox_override("hover", PaperTheme.box(PaperTheme.CREAM_HI, PaperTheme.EDGE, 3, 8, 6))
		add_theme_stylebox_override("pressed", PaperTheme.box(PaperTheme.CREAM_DOWN, PaperTheme.EDGE, 3, 8, 2))
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12 if side != "bottom" else 26)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(margin)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(v)
		var title := Label.new()
		title.text = str(o.get("title", ""))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", int(o.get("title_size", 28)))
		title.add_theme_color_override("font_color", PaperTheme.EDGE)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(title)
		if o.get("image") != null:
			var frame := PanelContainer.new()
			frame.add_theme_stylebox_override("panel", PaperTheme.box(Color("#d8c8a8"), PaperTheme.EDGE, 3, 5, 0))
			frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.clip_contents = true
			var fs: StyleBoxFlat = frame.get_theme_stylebox("panel")
			fs.content_margin_left = 3
			fs.content_margin_right = 3
			fs.content_margin_top = 3
			fs.content_margin_bottom = 3
			v.add_child(frame)
			var img := TextureRect.new()
			img.texture = o.image
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(img)
			if str(o.get("badge", "")) != "":
				var badge := Label.new()
				badge.text = str(o.badge)
				badge.add_theme_font_size_override("font_size", 13)
				badge.add_theme_color_override("font_color", Color("#efe3c8"))
				var bs := StyleBoxFlat.new()
				bs.bg_color = Color(0.25, 0.17, 0.1, 0.78)
				bs.set_corner_radius_all(3)
				bs.content_margin_left = 8
				bs.content_margin_right = 8
				bs.content_margin_top = 2
				bs.content_margin_bottom = 3
				badge.add_theme_stylebox_override("normal", bs)
				badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
				badge.offset_left = 8
				badge.offset_top = -30
				badge.offset_bottom = -8
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				frame.add_child(badge)
			if str(o.get("best", "")) != "":
				var best := Label.new()
				best.text = str(o.best)
				best.add_theme_font_size_override("font_size", 13)
				best.add_theme_color_override("font_color", Color("#f3e9d6"))
				var rs := StyleBoxFlat.new()
				rs.bg_color = Color(0.35, 0.22, 0.12, 0.9)
				rs.set_corner_radius_all(3)
				rs.content_margin_left = 7
				rs.content_margin_right = 7
				rs.content_margin_top = 2
				rs.content_margin_bottom = 3
				best.add_theme_stylebox_override("normal", rs)
				best.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				best.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				best.offset_right = -6
				best.offset_top = -52
				best.offset_bottom = -30
				best.mouse_filter = Control.MOUSE_FILTER_IGNORE
				frame.add_child(best)
		if str(o.get("sub", "")) != "":
			var sub := Label.new()
			sub.text = str(o.sub)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub.add_theme_font_size_override("font_size", int(o.get("sub_size", 20)))
			sub.add_theme_color_override("font_color", PaperTheme.INK)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(sub)
		focus_entered.connect(_on_focus)
		focus_exited.connect(_on_unfocus)
		return self

	## The torn-off control tags hang off the bottom of the focused card.
	func refresh_tear() -> void:
		if tear and is_instance_valid(tear):
			tear.queue_free()
			tear = null
		if not has_focus() or not bool(opts.get("tear", true)):
			return
		var tags := MenuCards.hint_tags()
		if tags.is_empty():
			return
		var holder := HBoxContainer.new()
		holder.add_theme_constant_override("separation", 4)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tilt := -0.03
		for tag in tags:
			var parts := tag.split("|")
			holder.add_child(MenuCards.tear_tag(parts[0], parts[1], tilt))
			tilt = 0.025
		holder.z_index = 4
		add_child(holder)
		tear = holder
		await get_tree().process_frame
		if is_instance_valid(holder):
			holder.reset_size()
			holder.position = Vector2(size.x - holder.size.x - 6, size.y - 22)

	func _on_focus() -> void:
		refresh_tear()
		_lift(1.0)

	func _on_unfocus() -> void:
		refresh_tear()
		_lift(0.0)

	func _lift(on: float) -> void:
		if carousel != null:
			return   # the carousel sizes its cards itself
		pivot_offset = size * 0.5
		if _focus_t:
			_focus_t.kill()
		_focus_t = create_tween()
		_focus_t.tween_property(self, "scale", base_scale * (1.05 if on > 0.5 else 1.0), 0.14)


## Cards that slide past a centre point; the focused one is large. Left/right (and the shoulder
## buttons) move through them, tapping a side card brings it to the centre.
class Carousel:
	extends Control
	signal chosen(index: int)
	signal moved(index: int)
	var cards: Array[Card] = []
	var selected := 0
	var _pos := 0.0
	var big := Vector2(340, 330)
	var small := Vector2(220, 250)
	var _press_x := 0.0
	var _tracking := false
	var _block_taps_until := 0

	func setup(items: Array, start: int) -> void:
		clip_contents = true
		for i in items.size():
			var c := Card.new().setup(items[i])
			c.carousel = self
			c.index = i
			c.pressed.connect(_on_card_pressed.bind(i))
			c.focus_entered.connect(_on_card_focus.bind(i))
			add_child(c)
			cards.append(c)
		selected = clampi(start, 0, cards.size() - 1)
		_pos = float(selected)
		_layout()

	func _on_card_focus(i: int) -> void:
		selected = i
		moved.emit(i)

	func _on_card_pressed(i: int) -> void:
		if Time.get_ticks_msec() < _block_taps_until:
			return   # the finger swiped across this card: it was a swipe, not a tap
		if i != selected:
			cards[i].grab_focus()   # a tap on a side card brings it forward first
		else:
			chosen.emit(i)

	func select(i: int) -> void:
		i = clampi(i, 0, cards.size() - 1)
		cards[i].grab_focus()

	func _process(delta: float) -> void:
		_pos = lerpf(_pos, float(selected), clampf(delta * 11.0, 0.0, 1.0))
		_layout()

	## Swipes are read at viewport level so they work wherever the finger lands, including on top of a card
	## (cards are buttons and swallow the press before the carousel itself would see it).
	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tracking = get_global_rect().has_point(event.position)
				_press_x = event.position.x
			elif _tracking:
				_tracking = false
				if absf(event.position.x - _press_x) > 60.0:
					_block_taps_until = Time.get_ticks_msec() + 300
					select(selected + (1 if event.position.x < _press_x else -1))

	func _unhandled_input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
				select(selected - 1)
				get_viewport().set_input_as_handled()
			elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				select(selected + 1)
				get_viewport().set_input_as_handled()

	func _layout() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		for i in cards.size():
			var d := float(i) - _pos
			var t := clampf(1.0 - absf(d), 0.0, 1.0)
			var sz := small.lerp(big, t)
			var dist := absf(d) * 340.0 if absf(d) <= 1.0 else 340.0 + (absf(d) - 1.0) * 255.0
			var c := cards[i]
			c.size = sz
			c.position = Vector2(cx + signf(d) * dist - sz.x * 0.5, cy - sz.y * 0.5 + (1.0 - t) * 10.0)
			c.z_index = 2 if t > 0.5 else 0
			c.base_alpha = lerpf(0.82, 1.0, t)
			if c.tear and is_instance_valid(c.tear):
				c.tear.position = Vector2(sz.x - c.tear.size.x - 6, sz.y - 22)


## A row of page dots under a carousel.
class Dots:
	extends HBoxContainer
	var _dots: Array[Panel] = []

	func setup(count: int) -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 10)
		for i in count:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(16, 16)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(p)
			_dots.append(p)
		show_page(0)

	func show_page(page: int) -> void:
		for i in _dots.size():
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(9)
			sb.set_border_width_all(2)
			sb.border_color = PaperTheme.EDGE
			sb.bg_color = PaperTheme.ACCENT if i == page else PaperTheme.CREAM
			_dots[i].add_theme_stylebox_override("panel", sb)
