extends Node
## App shell: the post-process lens, the live diorama behind the menus, all menu screens
## (controller, touch and keyboard navigable), the pause menu, results and the championship flow.

const POST_SHADER := preload("res://shaders/post.gdshader")

var world: Node3D
var race: Race
var post: ColorRect
var menu_layer: CanvasLayer
var menu: Control
var _back: Callable = Callable()
var _paused := false
var _settings_tab := 0
var _settings_return: Callable = Callable()
var _last_result: Dictionary = {}
var _shot := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 0
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = POST_SHADER
	post.material = pm
	post_layer.add_child(post)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 5
	add_child(menu_layer)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = PaperTheme.get_theme()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(menu)
	Settings.changed.connect(func(_k): _apply_post())
	get_tree().get_root().size_changed.connect(_apply_post)
	_parse_args()
	if _shot.is_empty():
		await _start_attract(randi() % Catalog.stages().size())
		_title()
	else:
		_run_shot()


# --- world ------------------------------------------------------------------------------------------

func _clear_race() -> void:
	if race:
		race.queue_free()
		race = null


func _start_attract(stage_i: int) -> void:
	_clear_race()
	await _loading("")
	race = Race.new()
	world.add_child(race)
	race.setup(stage_i, Game.Mode.RACE, [{"name": "Demo", "car": randi() % Catalog.cars().size(), "skill": 0.9, "player": false}], true)
	_apply_post()


func _loading(text: String) -> void:
	_clear_menu()
	if text != "":
		var c := _center_box()
		c.add_child(PaperTheme.tag(text, 34))
	await get_tree().process_frame
	await get_tree().process_frame


func _start_race() -> void:
	get_tree().paused = false
	_paused = false
	_clear_race()
	var sdef: Dictionary = Catalog.stages()[Game.stage_index]
	await _loading("Folding %s..." % sdef["name"])
	var entrants: Array
	match Game.mode:
		Game.Mode.TIME_TRIAL:
			entrants = [{"name": "You", "car": Game.car_index, "skill": 1.0, "player": true}]
		Game.Mode.RACE:
			entrants = Game.make_entrants(int(Settings.g("opponents")))
		_:
			entrants = Game.champ_entrants
			entrants[0]["car"] = Game.car_index
	race = Race.new()
	race.autopilot = _shot.get("autopilot", false)
	if _shot.has("path"):
		race.sim_dt = 1.0 / 30.0
	world.add_child(race)
	race.setup(Game.stage_index, Game.mode, entrants, false)
	race.finished.connect(_on_race_finished)
	race.pause_requested.connect(_pause)
	_apply_post()
	_clear_menu()
	_back = Callable()


func _apply_post() -> void:
	var m := post.material as ShaderMaterial
	var ts := int(Settings.g("tilt_shift"))
	var h := float(DisplayServer.window_get_size().y)
	if h <= 0.0:
		h = 720.0
	m.set_shader_parameter("taps", [0, 8, 16][clampi(ts, 0, 2)])
	m.set_shader_parameter("max_blur_px", (10.0 if ts == 1 else 15.0) * h / 1080.0)
	m.set_shader_parameter("grain", 0.01 if bool(Settings.g("paper_detail")) else 0.0)
	if race and race.stage:
		var wx: Dictionary = race.stage.wx
		m.set_shader_parameter("exposure", wx["exposure"])
		m.set_shader_parameter("contrast", wx["contrast"])
		m.set_shader_parameter("saturation", wx["sat"])
		m.set_shader_parameter("tint", wx["tint"])
		m.set_shader_parameter("green_pull", wx["green_pull"])
		m.set_shader_parameter("vignette", wx["vig"])
		m.set_shader_parameter("vig_color", wx["vig_col"])
		m.set_shader_parameter("shadow_tint", Color(wx["leak"]).darkened(0.6))


# --- menu helpers -------------------------------------------------------------------------------

func _clear_menu() -> void:
	for c in menu.get_children():
		c.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _back.is_valid():
		Sfx.click()
		_back.call()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _paused:
		_resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_tab_next") and menu.has_meta("tabs"):
		_settings_tab = (_settings_tab + 1) % 3
		_settings()
	elif event.is_action_pressed("ui_tab_prev") and menu.has_meta("tabs"):
		_settings_tab = (_settings_tab + 2) % 3
		_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _back.is_valid():
			_back.call()
		elif race and not race.attract and not _paused:
			_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if race and not race.attract and not _paused and race.state == Race.State.RACING:
			_pause()


func _center_box() -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	return v


## A full-screen menu page: title tag, a content area and a bottom bar.
func _page(title: String, back: Callable) -> Dictionary:
	_clear_menu()
	menu.remove_meta("tabs")
	_back = back
	var shade := ColorRect.new()
	shade.color = Color(0.23, 0.13, 0.05, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 36 if side in ["left", "right"] else 24)
	menu.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	mc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	top.add_child(PaperTheme.tag(title, 34))
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	v.add_child(content)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	v.add_child(bar)
	if back.is_valid():
		var bb := _button("Back", back)
		bar.add_child(bb)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	return {"top": top, "content": content, "bar": bar}


func _button(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		Sfx.click()
		Haptics.impulse(0.1, 0.02)
		cb.call())
	return b


func _focus_first(root: Node) -> void:
	await get_tree().process_frame
	var f := _find_focusable(root)
	if f:
		f.grab_focus()


func _find_focusable(n: Node) -> Control:
	if n is Control and (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree():
		if not (n is Button and (n as Button).disabled):
			return n
	for c in n.get_children():
		var r := _find_focusable(c)
		if r:
			return r
	return null


# --- title --------------------------------------------------------------------------------------

func _title() -> void:
	get_tree().paused = false
	_paused = false
	_clear_menu()
	menu.remove_meta("tabs")
	_back = Callable()
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 48)
	mc.add_theme_constant_override("margin_top", 36)
	mc.add_theme_constant_override("margin_bottom", 36)
	menu.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mc.add_child(v)
	var logo := PaperTheme.tag("PAPER RALLY", 64)
	v.add_child(logo)
	var sub := PaperTheme.tag("a cut-and-fold rally game", 22)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	v.add_child(gap)
	v.add_child(_button("Time Trial", func(): _choose_mode(Game.Mode.TIME_TRIAL), 360))
	v.add_child(_button("Championship", func(): _choose_mode(Game.Mode.CHAMPIONSHIP), 360))
	v.add_child(_button("Race vs AI", func(): _choose_mode(Game.Mode.RACE), 360))
	v.add_child(_button("Settings", func():
		_settings_return = _title
		_settings(), 360))
	if not OS.has_feature("web"):
		v.add_child(_button("Quit", func(): get_tree().quit(), 360))
	var pads := Input.get_connected_joypads()
	var hint := "Controller connected: %s" % Input.get_joy_name(pads[0]) if pads.size() > 0 else "Tip: pair a Bluetooth or USB-C controller any time"
	var ht := PaperTheme.tag(hint, 18)
	ht.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(ht)
	_focus_first(v)


func _choose_mode(m: int) -> void:
	Game.mode = m
	_car_select()


# --- car select ----------------------------------------------------------------------------------

func _car_select() -> void:
	var pg := _page("Choose your car  -  %s" % Game.mode_name(), _title)
	var content: VBoxContainer = pg["content"]
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	var preview := CarPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.stretch = true
	row.add_child(preview)
	var info := PanelContainer.new()
	info.custom_minimum_size.x = 430
	row.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 8)
	info.add_child(iv)
	var name_l := Label.new()
	name_l.add_theme_font_size_override("font_size", 36)
	iv.add_child(name_l)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.custom_minimum_size.x = 380
	iv.add_child(desc)
	var bars := {}
	for stat in [["Top speed", "top"], ["Acceleration", "accel"], ["Grip", "grip"], ["Handling", "steer"]]:
		var l := Label.new()
		l.text = stat[0]
		l.add_theme_font_size_override("font_size", 18)
		iv.add_child(l)
		var pb := StatBar.new()
		pb.custom_minimum_size = Vector2(380, 18)
		iv.add_child(pb)
		bars[stat[1]] = pb
	var refresh := func():
		var c: Dictionary = Catalog.cars()[Game.car_index]
		name_l.text = c["name"]
		desc.text = c["desc"]
		for k in bars.keys():
			bars[k].value = clampf((float(c[k]) - 0.8) / 0.38, 0.05, 1.0)
			bars[k].queue_redraw()
		preview.show_car(c, Game.car_index + 1)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	iv.add_child(nav)
	var prev := _button("<", func():
		Game.car_index = (Game.car_index + Catalog.cars().size() - 1) % Catalog.cars().size()
		refresh.call(), 80)
	var nxt := _button(">", func():
		Game.car_index = (Game.car_index + 1) % Catalog.cars().size()
		refresh.call(), 80)
	nav.add_child(prev)
	nav.add_child(nxt)
	var go := _button("Select", func():
		Game.save()
		if Game.mode == Game.Mode.CHAMPIONSHIP:
			_series_select()
		else:
			_stage_select(), 200)
	nav.add_child(go)
	refresh.call()
	await get_tree().process_frame
	go.grab_focus()


class StatBar:
	extends Control
	var value := 0.5

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(PaperTheme.box(Color("#e2d2b2"), PaperTheme.EDGE, 2, 5, 0), r)
		var f := Rect2(Vector2(3, 3), Vector2((size.x - 6) * value, size.y - 6))
		var sb := StyleBoxFlat.new()
		sb.bg_color = PaperTheme.ACCENT
		sb.set_corner_radius_all(3)
		draw_style_box(sb, f)


class CarPreview:
	extends SubViewportContainer
	## A turntable of the paper car in its own little world.
	var vp: SubViewport
	var holder: Node3D
	var mat: ShaderMaterial
	var t := 0.0

	func _ready() -> void:
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/paper.gdshader")
		mat.set_shader_parameter("fibre", Stage.fibre_tex())
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#f4eee4")
		env.ambient_light_energy = 0.22
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var key := DirectionalLight3D.new()
		key.light_color = Color("#fbeedd")
		key.light_energy = 0.5
		key.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
		key.shadow_enabled = true
		vp.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.light_color = Color("#f2dcc2")
		fill.light_energy = 0.3
		fill.rotation = Vector3(deg_to_rad(-30), 0, 0)
		vp.add_child(fill)
		var cam := Camera3D.new()
		cam.fov = 28
		cam.position = Vector3(0, 5.2, 8.2)
		vp.add_child(cam)
		cam.look_at(Vector3(0, 0.6, 0))
		var b := PaperKit.Builder.new(9)
		b.card(PaperKit.blob(4.2, 0, 0, 7, 0.05, 3, 30, 0.85), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.04, 0)), Color("#d9d2b4"), {"thick": 0.06, "edge": 0.06})
		var disc := MeshInstance3D.new()
		disc.mesh = b.mesh()
		disc.material_override = mat
		vp.add_child(disc)
		holder = Node3D.new()
		vp.add_child(holder)

	func show_car(c: Dictionary, num: int) -> void:
		for ch in holder.get_children():
			ch.queue_free()
		var m := CarModel.build(c, num, mat)
		holder.add_child(m["root"])

	func _process(delta: float) -> void:
		t += delta
		if holder:
			holder.rotation.y = t * 0.6


# --- stage / series select --------------------------------------------------------------------------

func _weather_style(kind: String) -> StyleBoxFlat:
	var col: Color = {"dry": Color("#f3dfb0"), "rain": Color("#cfd8dc"), "snow": Color("#e4e4f2")}[kind]
	return PaperTheme.box(col)


func _stage_select() -> void:
	var pg := _page("Choose a stage  -  %s" % Game.mode_name(), _car_select)
	var content: VBoxContainer = pg["content"]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var first: Button
	for i in Catalog.stages().size():
		var sd: Dictionary = Catalog.stages()[i]
		var wx := Catalog.weather(sd["weather"])
		var best := Game.best_time(i)
		var txt := "%s\n%s  -  %.1f km\nBest %s" % [sd["name"], wx["label"], float(sd["length"]) / 1000.0, Game.fmt_time(best)]
		var idx := i
		var b := _button(txt, func():
			Game.stage_index = idx
			_start_race())
		b.custom_minimum_size = Vector2(380, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_stylebox_override("normal", _weather_style(wx["kind"]))
		b.tooltip_text = sd["desc"]
		grid.add_child(b)
		if i == Game.stage_index:
			first = b
	var desc := PaperTheme.tag("Dry stages grip well. Rain halves your margin. Snow and ice need gentle hands.", 18)
	content.add_child(desc)
	await get_tree().process_frame
	if first:
		first.grab_focus()


func _series_select() -> void:
	var pg := _page("Choose a championship", _car_select)
	var content: VBoxContainer = pg["content"]
	var first: Button
	for i in Catalog.series().size():
		var se: Dictionary = Catalog.series()[i]
		var best := ""
		if Game.cups.has(se["id"]):
			best = "   (best finish: P%d)" % int(Game.cups[se["id"]])
		var idx := i
		var b := _button("%s  -  %s%s" % [se["name"], se["desc"], best], func():
			Game.start_championship(idx)
			_champ_intro(), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(b)
		if first == null:
			first = b
	content.add_child(PaperTheme.tag("Points per stage: 10 - 8 - 6 - 4 - 2 - 1", 20))
	await get_tree().process_frame
	first.grab_focus()


func _champ_intro() -> void:
	var se := Game.current_series()
	var pg := _page("%s  -  Stage %d of %d" % [se["name"], Game.champ_round + 1, Game.champ_total_rounds()], _title)
	var content: VBoxContainer = pg["content"]
	var sd: Dictionary = Catalog.stages()[Game.stage_index]
	var wx := Catalog.weather(sd["weather"])
	content.add_child(PaperTheme.tag("Next: %s  (%s, %.1f km)" % [sd["name"], wx["label"], float(sd["length"]) / 1000.0], 28))
	var dl := PaperTheme.tag(sd["desc"], 20)
	content.add_child(dl)
	_standings_table(content)
	var go := _button("Start stage", _start_race, 260)
	(pg["bar"] as HBoxContainer).add_child(go)
	await get_tree().process_frame
	go.grab_focus()


func _standings_table(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	var panel := PanelContainer.new()
	panel.add_child(grid)
	parent.add_child(panel)
	for h in ["Pos", "Driver", "Car", "Points"]:
		grid.add_child(_cell(h, true))
	var rows := Game.standings()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var you: bool = r["name"] == "You"
		grid.add_child(_cell("%d" % (i + 1), you))
		grid.add_child(_cell(r["name"], you))
		grid.add_child(_cell(Catalog.cars()[int(r["car"])]["name"], you))
		grid.add_child(_cell(str(r["points"]), you))


func _cell(t: String, bold: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22 if not bold else 23)
	if bold:
		l.add_theme_color_override("font_color", PaperTheme.ACCENT)
	return l


# --- pause ----------------------------------------------------------------------------------------

func _pause() -> void:
	if _paused or race == null or race.attract:
		return
	_paused = true
	get_tree().paused = true
	Haptics.stop()
	_pause_menu()


func _pause_menu() -> void:
	_clear_menu()
	menu.remove_meta("tabs")
	_back = _resume
	var v := _center_box()
	v.add_child(PaperTheme.tag("Paused", 44))
	v.add_child(_button("Resume", _resume, 340))
	v.add_child(_button("Restart stage", _start_race, 340))
	v.add_child(_button("Settings", func():
		_settings_return = _pause_menu
		_settings(), 340))
	v.add_child(_button("Quit to menu", func():
		_paused = false
		get_tree().paused = false
		await _start_attract(Game.stage_index)
		_title(), 340))
	_focus_first(v)


func _resume() -> void:
	_paused = false
	_clear_menu()
	_back = Callable()
	get_tree().paused = false
	if race:
		race.resume_input()


# --- settings -------------------------------------------------------------------------------------

func _settings() -> void:
	var pg := _page("Settings", func(): _settings_return.call())
	menu.set_meta("tabs", true)
	var top: HBoxContainer = pg["top"]
	var tabs := ["Graphics", "Controls", "Audio & Haptics"]
	var tab_btns: Array = []
	for i in tabs.size():
		var idx := i
		var b := _button(tabs[i], func():
			_settings_tab = idx
			_settings())
		if i == _settings_tab:
			b.add_theme_stylebox_override("normal", PaperTheme.box(PaperTheme.CREAM_HI))
		top.add_child(b)
		tab_btns.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(pg["content"] as VBoxContainer).add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	match _settings_tab:
		0:
			var pr := HBoxContainer.new()
			pr.add_theme_constant_override("separation", 12)
			var cur: String = Settings.g("preset")
			pr.add_child(_label("Quality preset (%s)" % cur.capitalize(), 420))
			for p in ["low", "medium", "high"]:
				var pn: String = p
				var b := _button(p.capitalize(), func():
					Settings.apply_preset(pn)
					_settings(), 140)
				if p == cur:
					b.add_theme_stylebox_override("normal", PaperTheme.box(PaperTheme.CREAM_HI))
				pr.add_child(b)
			list.add_child(pr)
			list.add_child(_choice("Pop-up scenery animation", ["Off (static, batched)", "On (unfolds as you drive)"], 1 if Settings.g("popups") else 0,
				func(i): Settings.set_value("popups", i == 1)))
			list.add_child(_note("Turn off to keep the paper look but stop scenery unfolding. Off also batches scenery into fewer draw calls."))
			list.add_child(_slider("Render resolution", 0.5, 1.0, 0.05, float(Settings.g("render_scale")), func(v): Settings.set_value("render_scale", v), "%d%%", 100.0))
			list.add_child(_choice("Shadows", ["Off", "Low", "High"], int(Settings.g("shadows")), func(i): Settings.set_value("shadows", i)))
			list.add_child(_choice("Tilt-shift lens blur", ["Off", "Low", "High"], int(Settings.g("tilt_shift")), func(i): Settings.set_value("tilt_shift", i)))
			list.add_child(_choice("Anti-aliasing (MSAA)", ["Off", "2x", "4x"], int(Settings.g("msaa")), func(i): Settings.set_value("msaa", i)))
			list.add_child(_slider("Scenery density", 0.3, 1.0, 0.05, float(Settings.g("density")), func(v): Settings.set_value("density", v), "%d%%", 100.0))
			list.add_child(_slider("Draw distance", 60.0, 160.0, 10.0, float(Settings.g("draw_distance")), func(v): Settings.set_value("draw_distance", v), "%d m", 1.0))
			list.add_child(_slider("Weather particles", 0.2, 1.0, 0.1, float(Settings.g("particles")), func(v): Settings.set_value("particles", v), "%d%%", 100.0))
			list.add_child(_choice("Paper fibre & grain detail", ["Off", "On"], 1 if Settings.g("paper_detail") else 0, func(i): Settings.set_value("paper_detail", i == 1)))
			list.add_child(_choice("Frame rate cap", ["30 fps", "60 fps"], 1 if int(Settings.g("fps")) == 60 else 0, func(i): Settings.set_value("fps", 60 if i == 1 else 30)))
			list.add_child(_choice("Show FPS counter", ["Off", "On"], 1 if Settings.g("show_fps") else 0, func(i): Settings.set_value("show_fps", i == 1)))
			list.add_child(_note("Density and draw distance apply from the next stage you load."))
		1:
			list.add_child(_choice("On-screen controls", ["Auto (hide with controller)", "Always show", "Off"], int(Settings.g("touch_controls")), func(i): Settings.set_value("touch_controls", i)))
			list.add_child(_choice("Touch steering", ["Buttons", "Tilt the phone"], int(Settings.g("touch_mode")), func(i): Settings.set_value("touch_mode", i)))
			list.add_child(_slider("Tilt sensitivity", 0.5, 2.0, 0.1, float(Settings.g("tilt_sens")), func(v): Settings.set_value("tilt_sens", v), "%.1fx", 1.0))
			list.add_child(_choice("Invert tilt", ["Off", "On"], 1 if Settings.g("tilt_invert") else 0, func(i): Settings.set_value("tilt_invert", i == 1)))
			list.add_child(_choice("Camera distance", ["Near", "Normal", "Far"], int(Settings.g("camera")), func(i): Settings.set_value("camera", i)))
			list.add_child(_choice("Speed units", ["km/h", "mph"], int(Settings.g("units")), func(i): Settings.set_value("units", i)))
			list.add_child(_choice("AI difficulty", ["Easy", "Medium", "Hard"], int(Settings.g("ai_difficulty")), func(i): Settings.set_value("ai_difficulty", i)))
			list.add_child(_choice("Opponents (Race / Championship)", ["3", "5"], 1 if int(Settings.g("opponents")) == 5 else 0, func(i): Settings.set_value("opponents", 5 if i == 1 else 3)))
			var pads := Input.get_connected_joypads()
			var pad_txt := "No controller connected." if pads.is_empty() else "Connected: " + ", ".join(pads.map(func(d): return Input.get_joy_name(d)))
			list.add_child(_note(pad_txt + "  Controller: RT/A accelerate, LT/X brake, B/RB handbrake, Y reset, Start pause, Back/LB camera."))
			list.add_child(_note("Keyboard: W/S or arrows, Space handbrake, R reset, C camera, Esc pause."))
		2:
			list.add_child(_choice("Haptics", ["Off", "On"], 1 if Settings.g("haptics") else 0, func(i): Settings.set_value("haptics", i == 1)))
			list.add_child(_slider("Haptic strength", 0.2, 1.5, 0.1, float(Settings.g("haptic_strength")), func(v):
				Settings.set_value("haptic_strength", v)
				Haptics.impulse(0.6, 0.12), "%d%%", 100.0))
			list.add_child(_choice("Phone vibration (when no controller)", ["Off", "On"], 1 if Settings.g("phone_vibration") else 0, func(i): Settings.set_value("phone_vibration", i == 1)))
			list.add_child(_button("Test vibration", func(): Haptics.impulse(0.8, 0.25)))
			list.add_child(_slider("Master volume", 0.0, 1.0, 0.05, float(Settings.g("master_vol")), func(v): Settings.set_value("master_vol", v), "%d%%", 100.0))
			list.add_child(_slider("Effects volume", 0.0, 1.0, 0.05, float(Settings.g("sfx_vol")), func(v): Settings.set_value("sfx_vol", v), "%d%%", 100.0))
			list.add_child(_slider("Engine volume", 0.0, 1.0, 0.05, float(Settings.g("engine_vol")), func(v): Settings.set_value("engine_vol", v), "%d%%", 100.0))
	await get_tree().process_frame
	var f := _find_focusable(list)
	if f:
		f.grab_focus()
	else:
		tab_btns[_settings_tab].grab_focus()


func _label(t: String, w := 420.0) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size.x = w
	l.add_theme_font_size_override("font_size", 23)
	return l


func _note(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("#6a543e"))
	l.custom_minimum_size.x = 600
	return l


## A cycling choice: press (or left / right on a controller) to change.
func _choice(label: String, options: Array, current: int, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_label(label))
	var state := {"i": clampi(current, 0, options.size() - 1)}
	var b := Button.new()
	b.custom_minimum_size.x = 430
	b.focus_mode = Control.FOCUS_ALL
	b.text = "<  %s  >" % options[state["i"]]
	var change := func(d: int):
		state["i"] = (state["i"] + d + options.size()) % options.size()
		b.text = "<  %s  >" % options[state["i"]]
		Sfx.click()
		on_change.call(state["i"])
	b.pressed.connect(func(): change.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left"):
			change.call(-1)
			b.accept_event()
		elif ev.is_action_pressed("ui_right"):
			change.call(1)
			b.accept_event())
	row.add_child(b)
	return row


func _slider(label: String, mn: float, mx: float, stp: float, value: float, on_change: Callable, fmt: String, mul: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_label(label))
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = stp
	s.value = value
	s.custom_minimum_size = Vector2(330, 36)
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var vl := Label.new()
	vl.custom_minimum_size.x = 90
	vl.text = fmt % (value * mul)
	row.add_child(vl)
	s.value_changed.connect(func(v):
		vl.text = fmt % (v * mul))
	s.drag_ended.connect(func(_c): on_change.call(s.value))
	s.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_released("ui_left") or ev.is_action_released("ui_right"):
			on_change.call(s.value))
	return row


# --- results ----------------------------------------------------------------------------------------

func _on_race_finished(result: Dictionary) -> void:
	_last_result = result
	Haptics.stop()
	match Game.mode:
		Game.Mode.TIME_TRIAL:
			_tt_results(result)
		Game.Mode.RACE:
			_race_results(result)
		_:
			Game.record_champ_round(result["rows"])
			_champ_results(result)


func _tt_results(r: Dictionary) -> void:
	var record := Game.submit_time(int(r["stage"]), float(r["player_time"]))
	var pg := _page("Stage complete", Callable())
	var content: VBoxContainer = pg["content"]
	var sd: Dictionary = Catalog.stages()[int(r["stage"])]
	content.add_child(PaperTheme.tag(sd["name"], 30))
	content.add_child(PaperTheme.tag("Time  %s%s" % [Game.fmt_time(r["player_time"]), "   NEW RECORD!" if record else ""], 40))
	var medal_names := ["GOLD", "SILVER", "BRONZE", "No medal"]
	var medal_cols := [Color("#f0cf6a"), Color("#dfe2e6"), Color("#d9a070"), PaperTheme.CREAM]
	var mi := int(r["medal"])
	content.add_child(PaperTheme.tag(medal_names[mi], 36, medal_cols[mi]))
	var m: Array = r["medals"]
	content.add_child(PaperTheme.tag("Gold %s   Silver %s   Bronze %s" % [Game.fmt_time(m[0]), Game.fmt_time(m[1]), Game.fmt_time(m[2])], 20))
	content.add_child(PaperTheme.tag("Best  %s" % Game.fmt_time(Game.best_time(int(r["stage"]))), 22))
	var bar: HBoxContainer = pg["bar"]
	var retry := _button("Retry", _start_race, 180)
	bar.add_child(retry)
	bar.add_child(_button("Next stage", func():
		Game.stage_index = (Game.stage_index + 1) % Catalog.stages().size()
		_start_race(), 220))
	bar.add_child(_button("Stages", func():
		await _start_attract(Game.stage_index)
		_stage_select(), 180))
	bar.add_child(_button("Menu", func():
		await _start_attract(Game.stage_index)
		_title(), 160))
	await get_tree().process_frame
	retry.grab_focus()


func _results_table(parent: Control, rows: Array, with_points: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = 5 if with_points else 4
	grid.add_theme_constant_override("h_separation", 30)
	var panel := PanelContainer.new()
	panel.add_child(grid)
	parent.add_child(panel)
	var heads := ["Pos", "Driver", "Car", "Time"]
	if with_points:
		heads.append("Pts")
	for h in heads:
		grid.add_child(_cell(h, true))
	var lead: float = rows[0]["time"]
	for i in rows.size():
		var r: Dictionary = rows[i]
		var you: bool = r["player"]
		grid.add_child(_cell(str(i + 1), you))
		grid.add_child(_cell(r["name"], you))
		grid.add_child(_cell(Catalog.cars()[maxi(int(r["car"]), 0)]["name"], you))
		var t: float = r["time"]
		grid.add_child(_cell(Game.fmt_time(t) if i == 0 else "+%.2f" % (t - lead), you))
		if with_points:
			grid.add_child(_cell(str(Catalog.POINTS[i] if i < Catalog.POINTS.size() else 0), you))


func _race_results(r: Dictionary) -> void:
	var pg := _page("Race result", Callable())
	var content: VBoxContainer = pg["content"]
	var rows: Array = r["rows"]
	var pos := 1
	for i in rows.size():
		if rows[i]["player"]:
			pos = i + 1
	content.add_child(PaperTheme.tag("You finished P%d of %d" % [pos, rows.size()], 36, Color("#f0cf6a") if pos == 1 else PaperTheme.CREAM))
	_results_table(content, rows, false)
	var bar: HBoxContainer = pg["bar"]
	var retry := _button("Race again", _start_race, 220)
	bar.add_child(retry)
	bar.add_child(_button("Stages", func():
		await _start_attract(Game.stage_index)
		_stage_select(), 180))
	bar.add_child(_button("Menu", func():
		await _start_attract(Game.stage_index)
		_title(), 160))
	await get_tree().process_frame
	retry.grab_focus()


func _champ_results(r: Dictionary) -> void:
	var se := Game.current_series()
	var pg := _page("%s  -  Round %d of %d" % [se["name"], Game.champ_round, Game.champ_total_rounds()], Callable())
	var content: VBoxContainer = pg["content"]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	content.add_child(cols)
	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(PaperTheme.tag("Stage result", 24))
	_results_table(left, r["rows"], true)
	var right := VBoxContainer.new()
	cols.add_child(right)
	right.add_child(PaperTheme.tag("Standings", 24))
	_standings_table(right)
	var bar: HBoxContainer = pg["bar"]
	var b: Button
	if Game.champ_finished():
		var pos := Game.standings().map(func(x): return x["name"]).find("You") + 1
		content.add_child(PaperTheme.tag("Championship over - you finished P%d!" % pos, 30, Color("#f0cf6a") if pos == 1 else PaperTheme.CREAM))
		b = _button("Menu", func():
			await _start_attract(Game.stage_index)
			_title(), 200)
	else:
		b = _button("Next stage", func():
			_champ_intro(), 220)
	bar.add_child(b)
	await get_tree().process_frame
	b.grab_focus()


# --- automated screenshots (development) -------------------------------------------------------------

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot["path"] = a.substr(7)
		elif a.begins_with("--stage="):
			_shot["stage"] = int(a.substr(8))
		elif a.begins_with("--time="):
			_shot["time"] = float(a.substr(7))
		elif a.begins_with("--view="):
			_shot["view"] = a.substr(7)
		elif a.begins_with("--preset="):
			Settings.apply_preset(a.substr(9))
		elif a.begins_with("--popups="):
			Settings.data["popups"] = a.substr(9) == "1"
		elif a.begins_with("--mode="):
			Game.mode = int(a.substr(7))


func _run_bench() -> void:
	# Headless logic check: every stage, autopilot to the finish, in each mode.
	_shot["autopilot"] = true
	Engine.max_fps = 0
	for si in Catalog.stages().size():
		for m in [Game.Mode.TIME_TRIAL, Game.Mode.RACE]:
			Game.mode = m
			Game.stage_index = si
			var t0 := Time.get_ticks_msec()
			await _start_race()
			var build_ms := Time.get_ticks_msec() - t0
			var tr := race.stage.track
			var res := {}
			race.finished.connect(func(r): res["r"] = r)
			var frames := 0
			while res.is_empty() and frames < 30 * 400:
				await get_tree().process_frame
				frames += 1
			if res.is_empty():
				print("BENCH stage=%d mode=%d DID NOT FINISH s=%.0f/%.0f" % [si, m, race.player.s, tr.finish_s])
				continue
			var r: Dictionary = res["r"]
			var rows: Array = r["rows"]
			print("BENCH stage=%d mode=%d len=%.0f corners=%d pieces=%d build=%dms player=%s medals=%s/%s/%s pos=%d/%d slowest=%s" % [si, m, tr.length, tr.corners.size(),
				race.stage.scenery.placements.size(), build_ms, Game.fmt_time(r["player_time"]), Game.fmt_time(r["medals"][0]), Game.fmt_time(r["medals"][1]),
				Game.fmt_time(r["medals"][2]), rows.map(func(x): return x["player"]).find(true) + 1, rows.size(), Game.fmt_time(rows[-1]["time"])])
	get_tree().quit()


func _run_shot() -> void:
	var view: String = _shot.get("view", "race")
	if view == "bench":
		_run_bench()
		return
	var stage_i: int = _shot.get("stage", 0)
	Game.stage_index = stage_i
	_shot["autopilot"] = true
	if view == "race":
		if Game.mode == Game.Mode.CHAMPIONSHIP:
			Game.start_championship(0)
			Game.stage_index = stage_i
		await _start_race()
	else:
		await _start_attract(stage_i)
		match view:
			"title": _title()
			"cars": _car_select()
			"stages": _stage_select()
			"settings": _settings()
	var t: float = _shot.get("time", 6.0)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while frames < int(t * 30.0):
		await get_tree().process_frame
		frames += 1
	print("SHOT fps_avg=%.1f frames=%d" % [frames / t, frames])
	if race and race.player:
		print("SHOT player s=%.1f speed=%.1f lat=%.1f" % [race.player.s, race.player.speed(), race.player.lat])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot["path"])
	print("SHOT saved ", _shot["path"])
	get_tree().quit()
