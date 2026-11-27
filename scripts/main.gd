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
	if _shot.has("introreal"):
		Game.no_save = false
	governor = PerfGovernor.new()
	add_child(governor)
	if _shot.is_empty():
		await _start_attract(randi() % Catalog.stages().size(), true)
		_title()
		governor.run_self_check()
	else:
		_run_shot()


# --- world ------------------------------------------------------------------------------------------

func _clear_race() -> void:
	if race:
		race.queue_free()
		race = null


func _start_attract(stage_i: int, startup := false) -> void:
	Catalog.apply_weather(stage_i, -1)
	_clear_race()
	if startup:
		await _loading_stage(Catalog.stages()[stage_i], true)
	else:
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


const TIPS := [
	"Brake in a straight line before the bend, then turn in. Braking mid-corner unsettles the car.",
	"The pace note number is the bend's severity: 1 is a hairpin, 6 is nearly flat out.",
	"A tap of the handbrake swings the tail round tight hairpins.",
	"Hay bales and snowbanks will cost you a lot of speed. Rocks and trees will stop you dead.",
	"Rain makes the mud slick and puddles throw the car about. Ease off on wet stages.",
	"Ice and snow have very little grip: smooth inputs, early braking.",
	"Jumps launch you further the faster you go. Land straight to keep your speed.",
	"Beat the Gold time to earn a gold medal. Your best run comes back as a ghost car.",
	"Tap the camera icon to try the Low chase, Bonnet or Cockpit views.",
	"On the clifftops, the Armco is there for a reason.",
	"Off the racing line the gravel is loose: you will slide and lose time.",
	"At dusk and night your headlights light the road. Look further ahead.",
]


## Loading screen: a cut-paper sunrise or sunset, the stage name in large type, a preview card and a tip.
func _loading_stage(sdef: Dictionary, startup := false) -> void:
	_clear_menu()
	var tod_i := Game.race_tod()
	if tod_i < 0:
		tod_i = int(sdef.get("tod", 0))
	var sunrise := (int(sdef.get("seed", 0)) % 2 == 0 or tod_i == Catalog.SUNRISE) and tod_i != 1
	var sky := TextureRect.new()
	sky.texture = preload("res://ui/boot.png") if startup else preload("res://ui/loading_hero.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(sky)
	if startup:
		var boot_wait := Label.new()
		boot_wait.text = "Folding the paper…"
		boot_wait.add_theme_font_override("font", PaperTheme.font())
		boot_wait.add_theme_font_size_override("font_size", 22)
		boot_wait.add_theme_color_override("font_color", Color("#fff3dc"))
		boot_wait.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.1, 0.85))
		boot_wait.add_theme_constant_override("outline_size", 6)
		boot_wait.anchor_left = 0.0
		boot_wait.anchor_top = 1.0
		boot_wait.anchor_bottom = 1.0
		boot_wait.offset_left = 56
		boot_wait.offset_top = -64
		boot_wait.offset_bottom = -28
		sky.add_child(boot_wait)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		return
	var scrim := TextureRect.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gr.colors = PackedColorArray([Color(0.08, 0.04, 0.12, 0.0), Color(0.08, 0.04, 0.12, 0.35), Color(0.08, 0.04, 0.12, 0.88)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0.0)
	gt.fill_to = Vector2(0, 1.0)
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.anchor_top = 0.35
	scrim.offset_top = 0
	sky.add_child(scrim)
	var font := PaperTheme.font()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.anchor_left = 0.0
	left.anchor_top = 1.0
	left.anchor_right = 0.62
	left.anchor_bottom = 1.0
	left.offset_left = 56
	left.offset_bottom = -52
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sky.add_child(left)
	var over := Label.new()
	over.text = "PAPER RALLY  ·  %s" % ("NOW FOLDING" if startup else ("RALLYCROSS CIRCUIT" if sdef.get("circuit", false) else "RALLY STAGE"))
	over.add_theme_font_override("font", font)
	over.add_theme_font_size_override("font_size", 20)
	over.add_theme_color_override("font_color", Color("#ffd9a8"))
	left.add_child(over)
	var title := Label.new()
	title.text = String(sdef["name"])
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color("#fff6e4"))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.12, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(title)
	if not startup:
		var sub := Label.new()
		sub.text = String(sdef["variant_name"])
		sub.add_theme_font_override("font", font)
		sub.add_theme_font_size_override("font_size", 32)
		sub.add_theme_color_override("font_color", Color("#ffc08a"))
		sub.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.12, 0.9))
		sub.add_theme_constant_override("outline_size", 5)
		left.add_child(sub)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 10)
		var distance := "%d laps" % Game.circuit_laps if sdef.get("circuit", false) else "%.1f km" % (float(sdef["length"]) / 1000.0)
		for txt in [distance, Catalog.weather(sdef["weather"])["label"], Catalog.TOD_NAMES[clampi(tod_i, 0, Catalog.TOD_NAMES.size() - 1)]]:
			chips.add_child(PaperTheme.tag(String(txt), 22))
		left.add_child(chips)
		var tip := PanelContainer.new()
		tip.add_theme_stylebox_override("panel", PaperTheme.box(Color(0.1, 0.05, 0.14, 0.62), Color("#ffd9a8"), 1, 8, 0))
		tip.custom_minimum_size = Vector2(620, 0)
		var tip_text := Label.new()
		tip_text.text = "TIP   " + String(TIPS.pick_random())
		tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_text.add_theme_font_size_override("font_size", 20)
		tip_text.add_theme_color_override("font_color", Color("#fff1da"))
		tip.add_child(tip_text)
		left.add_child(tip)
	if not startup:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 6, 10))
		var pic := TextureRect.new()
		pic.texture = Catalog.stage_preview(sdef)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(380, 228)
		card.add_child(pic)
		card.anchor_left = 1.0
		card.anchor_right = 1.0
		card.anchor_top = 0.0
		card.anchor_bottom = 0.0
		card.offset_left = -440
		card.offset_right = -56
		card.offset_top = 56
		card.offset_bottom = 296
		card.rotation = deg_to_rad(-1.6)
		sky.add_child(card)
	var wait := Label.new()
	wait.text = "Folding the course…"
	wait.add_theme_font_size_override("font_size", 18)
	wait.add_theme_color_override("font_color", Color("#ffd9a8"))
	wait.anchor_left = 1.0
	wait.anchor_right = 1.0
	wait.anchor_top = 1.0
	wait.anchor_bottom = 1.0
	wait.offset_left = -300
	wait.offset_right = -56
	wait.offset_top = -64
	wait.offset_bottom = -30
	wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sky.add_child(wait)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _start_race() -> void:
	get_tree().paused = false
	_paused = false
	_clear_race()
	Catalog.apply_weather(Game.stage_index, -1 if Game.mode == Game.Mode.CHAMPIONSHIP else Game.weather_override)
	var sdef: Dictionary = Catalog.stages()[Game.stage_index]
	await _loading_stage(sdef)
	var entrants: Array
	match Game.mode:
		Game.Mode.TIME_TRIAL:
			entrants = [{"name": "You", "car": Game.car_index, "skill": 1.0, "player": true}]
		Game.Mode.RACE:
			var opponents := int(Settings.g("opponents"))
			if sdef.has("rx"):
				opponents = mini(opponents, int(sdef.rx.racers) - 1)   # the circuit's grid limit
			entrants = Game.make_entrants(opponents)
		_:
			entrants = Game.champ_entrants
			entrants[0]["car"] = Game.car_index
	race = Race.new()
	race.autopilot = _shot.get("autopilot", false)
	if _shot.has("path"):
		race.sim_dt = 1.0 / 30.0
	world.add_child(race)
	race.setup(Game.stage_index, Game.mode, entrants, false, Game.race_tod())
	race.lighting_changed.connect(_apply_post)
	race.finished.connect(_on_race_finished)
	race.pause_requested.connect(_pause)
	if _shot.has("hazard"):
		race.skip_to_hazard(_shot["hazard"])
	if _shot.has("at"):
		var at: float = _shot["at"]
		race.skip_to_s(at if at >= 0.0 else race.stage.track.finish_s + at)
		if _shot.has("lat"):
			race.player.place_at(float(at), float(_shot["lat"]))
	_apply_post()
	_clear_menu()
	_back = Callable()


func _apply_post() -> void:
	var m := post.material as ShaderMaterial
	var ts := int(Settings.g("tilt_shift"))
	var h := float(DisplayServer.window_get_size().y)
	if h <= 0.0:
		h = 720.0
	var bonnet := race != null and not race.attract and ChaseCamera.is_ground_level(int(Settings.g("camera")))
	m.set_shader_parameter("taps", 0 if bonnet else [0, 8, 16][clampi(ts, 0, 2)])
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
	_back = Callable()
	if menu.has_meta("tabs"):
		menu.remove_meta("tabs")
	for c in menu.get_children():
		menu.remove_child(c)
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
func _page(title: String, back: Callable, plain_title := false) -> Dictionary:
	_clear_menu()
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
	if plain_title:
		var heading := Label.new()
		heading.text = title
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", 37)
		heading.add_theme_color_override("font_outline_color", Color("#eee4d4"))
		heading.add_theme_constant_override("outline_size", 3)
		top.add_child(heading)
	else:
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
	var rows: Array = []
	for button in _focus_controls(root):
		rows.append([button])
	if not rows.is_empty():
		_focus_rows(rows, rows[0][0])


# --- title --------------------------------------------------------------------------------------

func _title() -> void:
	get_tree().paused = false
	_paused = false
	_clear_menu()
	_back = _quit_prompt if not OS.has_feature("web") else Callable()
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
		v.add_child(_button("Quit", _quit_prompt, 360))
	var pads := Input.get_connected_joypads()
	var hint := "Controller connected: %s" % Input.get_joy_name(pads[0]) if pads.size() > 0 else "Tip: pair a Bluetooth or USB-C controller any time"
	var ht := PaperTheme.tag(hint, 18)
	ht.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(ht)
	_focus_first(v)


func _quit_prompt() -> void:
	_clear_menu()
	_back = _title
	var v := _center_box()
	v.add_child(PaperTheme.tag("Quit Paper Rally?", 36))
	v.add_child(_button("Keep playing", _title, 300))
	v.add_child(_button("Quit", func(): get_tree().quit(), 300))
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
		var c: Dictionary = Catalog.livery(Catalog.cars()[Game.car_index], Game.livery)
		name_l.text = c["name"]
		desc.text = "%s  -  %s drive\n%s" % [c["class"], {"rwd": "Rear", "fwd": "Front", "awd": "Four-wheel"}[c["drive"]], c["desc"]]
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
	var liv := _button("Livery: %s" % Catalog.LIVERY_NAMES[Game.livery], func(): pass, 0)
	liv.pressed.connect(func():
		Game.livery = (Game.livery + 1) % 3
		liv.text = "Livery: %s" % Catalog.LIVERY_NAMES[Game.livery]
		refresh.call())
	iv.add_child(liv)
	var go := _button("Select", func():
		Game.save()
		if Game.mode == Game.Mode.CHAMPIONSHIP:
			_series_select()
		else:
			_event_type(), 200)
	nav.add_child(go)
	refresh.call()
	_focus_rows([[prev, nxt, go], [liv], _focus_controls(pg.bar)], go)


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
		cam.position = Vector3(0, 6.2, 9.8)
		vp.add_child(cam)
		cam.look_at(Vector3(0, 0.6, 0))
		var b := PaperKit.Builder.new(9)
		b.card(PaperKit.blob(3.3, 0, 0, 7, 0.05, 3, 30, 0.85), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.04, 0)), Color("#d9d2b4"), {"thick": 0.06, "edge": 0.06})
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


var governor: PerfGovernor
var _blur := 0.0


## Mild radial speed blur (High quality only): the screen edges smear a little as the car gets quick.
func _process(delta: float) -> void:
	if post == null or post.material == null:
		return
	var want := 0.0
	if Settings.fx_level() >= 2 and bool(Settings.g("speed_fx")) and race != null and not race.attract and race.player != null \
			and race._intro_t < 0.0 and race.state == Race.State.RACING:
		want = clampf((race.player.speed() - 18.0) / 30.0, 0.0, 1.0)
	_blur = lerpf(_blur, want, clampf(delta * 3.0, 0.0, 1.0))
	(post.material as ShaderMaterial).set_shader_parameter("speed_blur", _blur)
	var hot := 0.0
	if Settings.fx_level() >= 2 and race != null and race.stage != null and race.stage.kind() == "dry" and race.stage.tod == 0:
		hot = 1.0
	(post.material as ShaderMaterial).set_shader_parameter("shimmer", hot)


# --- stage / series select --------------------------------------------------------------------------

func _weather_style(kind: String) -> StyleBoxFlat:
	var col: Color = {"dry": Color("#f3dfb0"), "rain": Color("#cfd8dc"), "snow": Color("#e4e4f2")}[kind]
	return PaperTheme.box(col)


## Short surface line shown on a location's card.
const STAGE_BADGES := {
	"meadow": "GRAVEL • ROLLING LANES", "canyon": "GRAVEL • ROCKY CLIMBS", "gorge": "GRAVEL • STONE GORGE",
	"autumn": "GRAVEL • FOREST RIDGE", "moor": "GRAVEL • OPEN MOORLAND", "pinewood": "GRAVEL • DENSE PINES",
	"harbour": "COBBLES • COASTAL VILLAGE", "alpine": "SNOW • HAIRPIN CLIMB", "lakes": "ICE • FROZEN LAKES",
	"taiga": "SNOW • TWILIGHT FOREST", "cliffs": "GRAVEL • CLIFFTOP ROAD", "arena": "SAND • CLOSED CIRCUIT",
}


func _navigation_tip(noun: String) -> String:
	if MenuCards.controller_present():
		return "Tip: Use your controller or arrow keys to navigate."
	if DisplayServer.is_touchscreen_available():
		return "Tip: Swipe left/right to browse more %s." % noun
	return "Tip: Use the arrow keys or click to browse %s." % noun


func _tip_tag(text: String, bar: HBoxContainer) -> void:
	var tag := PaperTheme.tag(text, 18)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(tag)


func _subtitle(content: VBoxContainer, text: String) -> void:
	var sub := PaperTheme.tag(text, 22)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(sub)


## Choose between point-to-point stages and closed circuits.
func _event_type() -> void:
	var pg := _page(Game.mode_name(), _car_select)
	var content: VBoxContainer = pg.content
	_subtitle(content, "Select Event Type")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	center.add_child(row)
	var arena_index := Catalog.locations().size() * Catalog.VARIANTS.size()
	var defs := [
		{"title": "STAGES", "sub": "Point-to-point rally routes with unique terrain challenges.",
			"image": Catalog.stage_preview(Catalog.stages()[1]), "circuits": false},
		{"title": "CIRCUITS", "sub": "Closed-loop rallycross with mixed-surface challenges.",
			"image": Catalog.stage_preview(Catalog.stages()[arena_index]), "circuits": true},
	]
	var cards: Array = []
	for d in defs:
		var card := MenuCards.Card.new().setup({"title": d.title, "sub": d.sub, "image": d.image, "size": Vector2(500, 400), "title_size": 56, "sub_size": 22})
		var circuits: bool = d.circuits
		card.pressed.connect(func():
			Sfx.click()
			if circuits and not bool(Settings.g("joker_intro_seen")):
				_joker_intro(func(): _stage_carousel(true))
			else:
				_stage_carousel(circuits))
		row.add_child(card)
		cards.append(card)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pg.bar.add_child(spacer)
	_tip_tag(_navigation_tip("options"), pg.bar)
	_focus_rows([cards, _focus_controls(pg.bar)], cards[1 if Game.stage_index >= arena_index else 0])
	await get_tree().process_frame
	for i in cards.size():
		MenuCards.pop_in(cards[i], 0.05 + i * 0.1)


## Settings > Benchmark: a card over the menu that shows progress, then the results.
func _benchmark_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.06, 0.12, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(overlay)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 3, 10, 8))
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	centre.add_child(card)
	card.custom_minimum_size = Vector2(620, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.text = "Benchmark"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", PaperTheme.ACCENT)
	col.add_child(title)
	var body := Label.new()
	body.text = "Running the demo race at your current settings…"
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", PaperTheme.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(0, 24)
	col.add_child(bar)
	var close := _button("Close", func(): overlay.queue_free(), 160)
	close.visible = false
	col.add_child(close)
	if DisplayServer.get_name() == "headless" or governor == null:
		body.text = "The benchmark needs a device with a screen."
		close.visible = true
		bar.visible = false
		return
	governor.benchmark_progress.connect(func(f): if is_instance_valid(bar): bar.value = f)
	governor.benchmark_done.connect(func(r: Dictionary):
		if not is_instance_valid(body):
			return
		var avg: float = r.avg_fps
		var low1: float = r.low1_fps
		var target := 1000.0 / float(r.target_ms)
		var verdict := "Smooth" if avg >= target * 0.95 and low1 >= target * 0.7 else ("Playable" if avg >= target * 0.75 else "Too heavy: try a lower preset")
		body.text = "Average: %.0f fps (target %.0f)\nSlowest 1%%: %.0f fps\n95%% of frames under %.1f ms\nDraw calls %d, triangles %dk, render scale %d%%\nResult: %s" % [
			avg, target, low1, r.p95_ms, r.draw_calls, int(r.triangles) / 1000, int(float(r.scale) * 100.0), verdict]
		bar.visible = false
		close.visible = true, CONNECT_ONE_SHOT)
	governor.run_benchmark()


## First visit to Circuits: the animated Joker explainer, then on to the circuit carousel.
func _joker_intro(done: Callable) -> void:
	var intro := JokerIntro.new()
	menu.add_child(intro)
	intro.finished.connect(func():
		Settings.set_value("joker_intro_seen", true)
		intro.queue_free()
		done.call())


## A sliding carousel of locations (or circuits) with previews, best times and page dots.
func _stage_carousel(circuits: bool, focus := -1) -> void:
	var pg := _page(Game.mode_name(), _event_type)
	var content: VBoxContainer = pg.content
	_subtitle(content, "Select Circuit" if circuits else "Select Stage")
	var routes := Catalog.VARIANTS.size()
	var location_count := Catalog.locations().size()
	var entries: Array = []
	if circuits:
		entries = Catalog.stages().slice(location_count * routes)
	else:
		entries = Catalog.locations().duplicate()
	var variant := int(Catalog.stages()[Game.stage_index].variant)
	var items: Array = []
	for i in entries.size():
		var sd: Dictionary = entries[i]
		var item := {"title": sd.name, "title_size": 25, "size": Vector2(260, 280), "badge": STAGE_BADGES.get(sd.get("loc_id", sd.id), ""),
			"image": Catalog.stage_preview(sd if circuits else Catalog.stages()[i * routes + variant])}
		if not circuits:
			var best := Game.best_time(i * routes + variant)
			if best > 0.0:
				item["best"] = "BEST: " + Game.fmt_time(best)
		items.append(item)
	var holder := HBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 8)
	content.add_child(holder)
	var prev := _arrow_button("<", "L")
	holder.add_child(prev)
	var carousel := MenuCards.Carousel.new()
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.custom_minimum_size.y = 350
	holder.add_child(carousel)
	var nxt := _arrow_button(">", "R")
	holder.add_child(nxt)
	var start := clampi(focus if focus >= 0 else (Game.stage_index - location_count * routes if (circuits and Game.stage_index >= location_count * routes) else (int(Catalog.stages()[Game.stage_index].loc) if not circuits else 0)), 0, items.size() - 1)
	carousel.setup(items, start)
	var dots := MenuCards.Dots.new()
	dots.setup(ceili(items.size() / 4.0))
	content.add_child(dots)
	dots.show_page(start / 4)
	carousel.moved.connect(func(i: int): dots.show_page(i / 4))
	prev.get_child(0).pressed.connect(func(): carousel.select(carousel.selected - 1))
	nxt.get_child(0).pressed.connect(func(): carousel.select(carousel.selected + 1))
	carousel.chosen.connect(func(i: int):
		Sfx.click()
		_stage_details(i + (location_count if circuits else 0)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pg.bar.add_child(spacer)
	_tip_tag(_navigation_tip("circuits" if circuits else "stages"), pg.bar)
	_focus_rows([carousel.cards, _focus_controls(pg.bar)], carousel.cards[start])
	await get_tree().process_frame
	for i in carousel.cards.size():
		if absi(i - start) <= 2:
			MenuCards.pop_in(carousel.cards[i], 0.04 + absi(i - start) * 0.08)


## A "<" / ">" touch button with the shoulder-button tab under it when a controller is attached.
func _arrow_button(glyph: String, shoulder: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := Button.new()
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 56)
	b.add_theme_font_size_override("font_size", 28)
	box.add_child(b)
	if MenuCards.controller_present():
		var tab := PaperTheme.tag(shoulder, 15)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(tab)
	return box


func _stage_select(focus_location := -1) -> void:
	var pg := _page("Choose a location", _car_select)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pg.content.add_child(grid)
	var selected := int(Catalog.stages()[Game.stage_index].loc) if focus_location < 0 else focus_location
	var rows: Array = []
	var cards: Array[Control] = []
	var locations := Catalog.locations().duplicate()
	var stage_route_count := locations.size() * Catalog.VARIANTS.size()
	if Game.mode == Game.Mode.RACE:
		locations.append_array(Catalog.stages().slice(stage_route_count))
	for location in locations.size():
		var sd: Dictionary = locations[location]
		var circuit: bool = sd.get("circuit", false)
		var wx := Catalog.weather(sd.weather)
		var b := _button("%s\n%s" % [sd.name, "Rallycross" if circuit else wx.label], _stage_details.bind(location))
		var variant := int(Catalog.stages()[Game.stage_index].variant)
		b.icon = Catalog.stage_preview(sd if circuit else Catalog.stages()[location * Catalog.VARIANTS.size() + variant])
		b.expand_icon = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(210, 165)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("icon_max_width", 230)
		b.add_theme_stylebox_override("normal", _weather_style(wx.kind))
		grid.add_child(b)
		if location % grid.columns == 0:
			rows.append([])
		rows[-1].append(b)
		cards.append(b)
	rows.append(_focus_controls(pg.bar))
	if selected < 0 and Game.mode == Game.Mode.RACE:
		selected = Catalog.locations().size() + Game.stage_index - stage_route_count
	_focus_rows(rows, cards[clampi(selected, 0, cards.size() - 1)])


func _stage_details(location: int) -> void:
	var routes := Catalog.VARIANTS.size()
	var location_count := Catalog.locations().size()
	var circuit := location >= location_count
	var circuit_index := location_count * routes + location - location_count
	var sd: Dictionary = Catalog.stages()[circuit_index] if circuit else Catalog.locations()[location]
	var pg := _page(sd.name, func(): _stage_carousel(circuit, location - (location_count if circuit else 0)))
	var content: VBoxContainer = pg.content
	var selection := {"variant": int(Catalog.stages()[Game.stage_index].variant), "time": Game.time_of_day, "laps": Game.circuit_laps, "weather": Game.weather_override}
	var overview := HBoxContainer.new()
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview.add_theme_constant_override("separation", 16)
	content.add_child(overview)

	var preview := TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(0, 220)
	overview.add_child(preview)

	var details := PanelContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(details)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	details.add_child(right)
	var description := _note(sd.desc)
	description.custom_minimum_size.x = 0.0
	if Catalog.CHAPTERS.has(sd.id):
		var chapter_names := PackedStringArray()
		for chapter: Dictionary in Catalog.CHAPTERS[sd.id]:
			chapter_names.append(chapter.name)
		description.text += "\n" + "  ·  ".join(chapter_names)
	right.add_child(description)
	var map := StageRouteMap.new()
	map.custom_minimum_size.y = 136
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(map)
	var map_key := Label.new()
	map_key.text = "■ Start / Finish" if circuit else "● Start                 ■ Finish"
	map_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_key.add_theme_font_size_override("font_size", 15)
	right.add_child(map_key)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 18)
	right.add_child(caption)

	var distance_names: Array[String] = []
	for variant in Catalog.VARIANTS:
		distance_names.append("%s · %.0f km" % [variant[0], float(variant[1]) / 1000.0])
	var time_names := ["Default · %s" % Catalog.TOD_NAMES[int(sd.get("tod", 0))]] + Catalog.TOD_NAMES
	var refresh := func():
		var index := circuit_index if circuit else location * routes + int(selection.variant)
		map.show_route(Catalog.stages()[index])
		preview.texture = Catalog.stage_preview(Catalog.stages()[index])
		caption.text = "%.2f km per lap" % (map.route_length / 1000.0) if circuit else "Best %s" % Game.fmt_time(Game.best_time(index))
	var distance: Array
	if circuit:
		var lap_names: Array = range(3, 13).map(func(lap): return str(lap))
		var lap_row := _choice("Laps", lap_names, int(selection.laps) - 3, func(index): selection.laps = index + 3)
		content.add_child(lap_row)
		distance = _focus_controls(lap_row)
	else:
		distance = _stage_options(content, "Distance", distance_names, selection.variant, func(index: int):
			selection.variant = index
			refresh.call())
	var times := _stage_options(content, "Time of day", time_names, selection.time + 1, func(index: int):
		selection.time = index - 1)
	var weather_names := ["Default · %s" % Catalog.weather(sd.weather).label] + Catalog.WEATHER_NAMES
	var weather := _stage_options(content, "Weather", weather_names, selection.weather + 1, func(index: int):
		selection.weather = index - 1)
	var race_option := _button("", func(): pass, 200)
	race_option.toggle_mode = true
	var ai_race := Game.mode == Game.Mode.RACE
	var option_label := "Impact with AI" if ai_race else "Show ghost"
	race_option.button_pressed = Game.ai_contact if ai_race else Game.show_ghost
	race_option.text = option_label + (" · On" if race_option.button_pressed else " · Off")
	race_option.toggled.connect(func(enabled: bool):
		race_option.text = option_label + (" · On" if enabled else " · Off"))
	pg.bar.add_child(race_option)
	var start := _button("Start race", func():
		Game.stage_index = circuit_index if circuit else location * routes + int(selection.variant)
		if circuit:
			Game.circuit_laps = int(selection.laps)
		Game.time_of_day = int(selection.time)
		Game.weather_override = int(selection.weather)
		if ai_race:
			Game.ai_contact = race_option.button_pressed
		else:
			Game.show_ghost = race_option.button_pressed
		_start_race(), 200)
	pg.bar.add_child(start)
	refresh.call()
	_focus_rows([distance, times, weather, _focus_controls(pg.bar)], distance[0 if circuit else selection.variant])


func _stage_options(parent: VBoxContainer, title: String, options: Array, active: int, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	row.add_child(_label(title, 150))
	var group := ButtonGroup.new()
	var buttons: Array = []
	for index in options.size():
		var button := _button(options[index], on_change.bind(index))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = index == active
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 19)
		row.add_child(button)
		buttons.append(button)
	return buttons


## Link physical rows in display order. Vertical movement crosses to the nearest
## column and a short final row stays reachable from every column above it.
func _focus_rows(rows: Array, initial: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(initial) or not initial.is_inside_tree():
		return
	var order: Array = []
	for row in rows:
		order.append_array(row)
	for row_index in rows.size():
		var row: Array = rows[row_index]
		for column in row.size():
			var button: Control = row[column]
			button.focus_neighbor_left = button.get_path_to(row[maxi(0, column - 1)])
			button.focus_neighbor_right = button.get_path_to(row[mini(row.size() - 1, column + 1)])
			button.focus_neighbor_top = button.get_path_to(_nearest_column(button, rows[maxi(0, row_index - 1)]) if row_index > 0 else button)
			button.focus_neighbor_bottom = button.get_path_to(_nearest_column(button, rows[mini(rows.size() - 1, row_index + 1)]) if row_index + 1 < rows.size() else button)
			var index := order.find(button)
			button.focus_next = button.get_path_to(order[(index + 1) % order.size()])
			button.focus_previous = button.get_path_to(order[posmod(index - 1, order.size())])
	initial.grab_focus()


func _nearest_column(button: Control, row: Array) -> Control:
	var x := button.get_global_rect().get_center().x
	var closest: Control = row[0]
	for item: Control in row:
		if absf(item.get_global_rect().get_center().x - x) < absf(closest.get_global_rect().get_center().x - x):
			closest = item
	return closest


func _focus_controls(node: Node) -> Array:
	var controls: Array = []
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not (node is Button and node.disabled):
		controls.append(node)
	for child in node.get_children():
		controls.append_array(_focus_controls(child))
	return controls


func _series_select() -> void:
	var pg := _page("Championship", _car_select)
	var content: VBoxContainer = pg["content"]
	_subtitle(content, "Select Championship")
	var items: Array = []
	for i in Catalog.series().size():
		var se: Dictionary = Catalog.series()[i]
		var sub := "%s\n%d stages" % [se["desc"], se["stages"].size()]
		if Game.cups.has(se["id"]):
			sub += "  ·  best finish P%d" % int(Game.cups[se["id"]])
		items.append({"title": se["name"], "title_size": 25, "sub": sub, "sub_size": 15, "size": Vector2(260, 300),
			"image": Catalog.stage_preview(Catalog.stages()[int(se["stages"][0])]), "badge": "NIGHT" if se.get("night", false) else ""})
	var holder := HBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 8)
	content.add_child(holder)
	var prev := _arrow_button("<", "L")
	holder.add_child(prev)
	var carousel := MenuCards.Carousel.new()
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.custom_minimum_size.y = 370
	carousel.big = Vector2(350, 350)
	carousel.small = Vector2(230, 270)
	holder.add_child(carousel)
	var nxt := _arrow_button(">", "R")
	holder.add_child(nxt)
	carousel.setup(items, clampi(Game.series_index, 0, items.size() - 1))
	var dots := MenuCards.Dots.new()
	dots.setup(ceili(items.size() / 4.0))
	content.add_child(dots)
	dots.show_page(carousel.selected / 4)
	carousel.moved.connect(func(i: int): dots.show_page(i / 4))
	prev.get_child(0).pressed.connect(func(): carousel.select(carousel.selected - 1))
	nxt.get_child(0).pressed.connect(func(): carousel.select(carousel.selected + 1))
	carousel.chosen.connect(func(i: int):
		Sfx.click()
		Game.start_championship(i)
		_champ_intro())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pg.bar.add_child(spacer)
	_tip_tag("Points per stage: 10 - 8 - 6 - 4 - 2 - 1", pg.bar)
	_focus_rows([carousel.cards, _focus_controls(pg.bar)], carousel.cards[carousel.selected])
	await get_tree().process_frame
	for i in carousel.cards.size():
		if absi(i - carousel.selected) <= 2:
			MenuCards.pop_in(carousel.cards[i], 0.04 + absi(i - carousel.selected) * 0.08)


func _champ_intro() -> void:
	var se := Game.current_series()
	var pg := _page("%s  -  Stage %d of %d" % [se["name"], Game.champ_round + 1, Game.champ_total_rounds()], _title)
	var content: VBoxContainer = pg["content"]
	var sd: Dictionary = Catalog.stages()[Game.stage_index]
	var wx := Catalog.weather(sd["weather"])
	content.add_child(PaperTheme.tag("Next: %s  (%s, %.1f km%s)" % [Catalog.stage_title(Game.stage_index), wx["label"], float(sd["length"]) / 1000.0, ", night" if Game.race_tod() == 2 else ""], 28))
	var dl := PaperTheme.tag(sd["desc"], 20)
	content.add_child(dl)
	_standings_table(content)
	var go := _button("Start stage", _start_race, 260)
	(pg["bar"] as HBoxContainer).add_child(go)
	_focus_rows([_focus_controls(pg.bar)], go)


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
	race.set_overlay_visible(false)
	Haptics.stop()
	_pause_menu()


func _pause_menu() -> void:
	_clear_menu()
	_back = _resume
	var v := _center_box()
	v.add_child(PaperTheme.tag("Paused", 44))
	v.add_child(_button("Resume", _resume, 340))
	v.add_child(_button("Restart stage", _start_race, 340))
	v.add_child(_button("Photo mode", _photo_mode, 340))
	v.add_child(_button("Settings", func():
		_settings_return = _pause_menu
		_settings(), 340))
	v.add_child(_button("Quit to menu", func():
		_paused = false
		get_tree().paused = false
		await _start_attract(Game.stage_index)
		_title(), 340))
	_focus_first(v)


func _photo_mode() -> void:
	_clear_menu()
	_back = Callable()
	if race._hud_layer:
		race._hud_layer.visible = false
	var cockpit_view := race.camera.view_index() == ChaseCamera.COCKPIT
	race.player.cockpit(false)
	var orbit := Camera3D.new()
	orbit.fov = 50.0
	orbit.far = race.camera.far
	race.add_child(orbit)
	orbit.global_transform = race.camera.global_transform
	var driving_post := post.material
	post.material = driving_post.duplicate()
	var pm := PhotoMode.new()
	pm.setup(orbit, race.player, post.material)
	orbit.make_current()
	menu.add_child(pm)
	pm.closed.connect(func():
		pm.queue_free()
		race.player.cockpit(cockpit_view)
		race.camera.make_current()
		orbit.queue_free()
		post.material = driving_post
		_apply_post()
		race.camera.snap()
		_pause_menu())


func _resume() -> void:
	_paused = false
	if race:
		race.set_overlay_visible(true)
	_clear_menu()
	_back = Callable()
	get_tree().paused = false
	if race:
		race.resume_input()


# --- settings -------------------------------------------------------------------------------------

func _settings() -> void:
	var pg := _page("Settings", func(): _settings_return.call(), true)
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
	scroll.follow_focus = true
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
			var fps_vals := [30, 60, 90, 120, 0]
			list.add_child(_choice("Frame rate", ["30 fps", "60 fps", "90 fps", "120 fps", "Match display"], maxi(0, fps_vals.find(int(Settings.g("fps")))), func(i): Settings.set_value("fps", fps_vals[i])))
			list.add_child(_note("Match display runs at your screen's full refresh rate (120 Hz on the Galaxy S26 Ultra if Motion smoothness is set to Adaptive). Higher rates use more battery."))
			list.add_child(_choice("Show FPS counter", ["Off", "On"], 1 if Settings.g("show_fps") else 0, func(i): Settings.set_value("show_fps", i == 1)))
			list.add_child(_button("Replay the Joker explainer", func(): _joker_intro(func(): _settings()), 360))
			list.add_child(_button("Run benchmark (12 s, current settings)", func(): _benchmark_ui(), 460))
			list.add_child(_choice("Automatic resolution", ["Off", "On (keeps the frame rate steady)"], 1 if Settings.g("dynamic_res") else 0, func(i): Settings.set_value("dynamic_res", i == 1)))
			list.add_child(_choice("Speed effects (wider view, shake)", ["Off", "On"], 1 if Settings.g("speed_fx") else 0, func(i): Settings.set_value("speed_fx", i == 1)))
			list.add_child(_choice("Debug panel (for bug reports)", ["Off", "On"], 1 if Settings.g("debug_hud") else 0, func(i): Settings.set_value("debug_hud", i == 1)))
			list.add_child(_choice("Light glow (night)", ["Off", "On"], 1 if Settings.g("light_halos") else 0, func(i): Settings.set_value("light_halos", i == 1)))
			list.add_child(_note("Shows car, track, sector, surface and speed in the corner of the race screen. Include it in screenshots when reporting a problem."))
			list.add_child(_note("Density and draw distance apply from the next stage you load."))
		1:
			list.add_child(_choice("On-screen controls", ["Auto (hide with controller)", "Always show", "Off"], int(Settings.g("touch_controls")), func(i): Settings.set_value("touch_controls", i)))
			list.add_child(_choice("Touch steering", ["Buttons", "Tilt the phone"], int(Settings.g("touch_mode")), func(i): Settings.set_value("touch_mode", i)))
			list.add_child(_slider("Tilt sensitivity", 0.5, 2.0, 0.1, float(Settings.g("tilt_sens")), func(v): Settings.set_value("tilt_sens", v), "%.1fx", 1.0))
			list.add_child(_choice("Invert tilt", ["Off", "On"], 1 if Settings.g("tilt_invert") else 0, func(i): Settings.set_value("tilt_invert", i == 1)))
			list.add_child(_choice("Camera view", ChaseCamera.VIEWS.map(func(v): return v["name"]), int(Settings.g("camera")), func(i): Settings.set_value("camera", i)))
			list.add_child(_slider("Cockpit field of view", 58, 90, 1, float(Settings.g("cockpit_fov")), func(v): Settings.set_value("cockpit_fov", v), "%d°", 1.0))
			list.add_child(_choice("Accelerator trigger", ["Match touch", "Progressive"], int(Settings.g("progressive_trigger")), func(i): Settings.set_value("progressive_trigger", i == 1)))
			list.add_child(_choice("Controller triggers", ["Auto", "Zero rest", "Half rest", "Brake with X only"], int(Settings.g("controller_trigger_mode")), func(i):
				Settings.set_value("controller_trigger_mode", i)))
			var pedal_test := PedalReadout.new()
			pedal_test.add_theme_font_size_override("font_size", 18)
			pedal_test.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(pedal_test)
			list.add_child(_choice("Speed units", ["km/h", "mph"], int(Settings.g("units")), func(i): Settings.set_value("units", i)))
			list.add_child(_choice("AI difficulty", ["Easy", "Medium", "Hard"], int(Settings.g("ai_difficulty")), func(i): Settings.set_value("ai_difficulty", i)))
			list.add_child(_choice("Opponents (Race / Championship)", ["3", "5"], 1 if int(Settings.g("opponents")) == 5 else 0, func(i): Settings.set_value("opponents", 5 if i == 1 else 3)))
			var pads := Input.get_connected_joypads()
			var pad_txt := "No controller connected." if pads.is_empty() else "Connected: " + ", ".join(pads.map(func(d): return Input.get_joy_name(d)))
			list.add_child(_note(pad_txt + "  Menus: D-pad or left stick to move, A to select, B to go back. Driving: RT/A accelerate, LT/X brake, B/RB handbrake, Y reset, Start pause, Back/LB or the camera icon cycles camera views."))
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
			if ResourceLoader.exists(Race.CO_DRIVER_SCRIPT):
				var voice_script := load(Race.CO_DRIVER_SCRIPT)
				var voices: Array[String] = voice_script.available_voices()
				if voices.size() > 1:
					var voice_names := voices.map(func(id): return voice_script.VOICE_NAMES[id])
					var voice_index := voices.find(voice_script.selected_voice(voices))
					list.add_child(_choice("Co-driver voice", voice_names, voice_index,
						func(i): Settings.set_value("codriver_voice", voices[i])))
				list.add_child(_choice("Co-driver voice timing", ["Off", "Late", "Normal", "Early"], int(Settings.g("codriver_timing")),
					func(i): Settings.set_value("codriver_timing", i)))
				list.add_child(_slider("Co-driver volume", 0.0, 1.0, 0.05, float(Settings.g("codriver_volume")), func(v): Settings.set_value("codriver_volume", v), "%d%%", 100.0))
			if ResourceLoader.exists(Race.CROSSING_AUDIO_SCRIPT):
				list.add_child(_choice("Crossing sounds", ["Off", "On"], int(Settings.g("crossing_audio")), func(i): Settings.set_value("crossing_audio", i == 1)))
	var rows: Array = [tab_btns]
	for child in list.get_children():
		var controls := _focus_controls(child)
		if not controls.is_empty():
			rows.append(controls)
	rows.append(_focus_controls(pg.bar))
	_focus_rows(rows, tab_btns[_settings_tab])


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
		Sfx.toggle()
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
	if race:
		race.set_overlay_visible(false)
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


func _results_back() -> void:
	await _start_attract(Game.stage_index)
	if Game.mode == Game.Mode.CHAMPIONSHIP:
		_title()
	else:
		_stage_select()


func _tt_results(r: Dictionary) -> void:
	var record := Game.submit_time(int(r["stage"]), float(r["player_time"]))
	var pg := _page("Stage complete", Callable())
	_back = _results_back
	var content: VBoxContainer = pg["content"]
	var sd: Dictionary = Catalog.stages()[int(r["stage"])]
	content.add_child(PaperTheme.tag(Catalog.stage_title(int(r["stage"])), 30))
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
	_focus_rows([_focus_controls(pg.bar)], retry)


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
	_back = _results_back
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
	_focus_rows([_focus_controls(pg.bar)], retry)


func _champ_results(r: Dictionary) -> void:
	var se := Game.current_series()
	var pg := _page("%s  -  Round %d of %d" % [se["name"], Game.champ_round, Game.champ_total_rounds()], Callable())
	_back = _results_back
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
	_focus_rows([_focus_controls(pg.bar)], b)


# --- automated screenshots (development) -------------------------------------------------------------

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			Game.no_save = true
			_shot["path"] = a.substr(7)
		elif a.begins_with("--stage="):
			_shot["stage"] = int(a.substr(8))
		elif a.begins_with("--time="):
			_shot["time"] = float(a.substr(7))
		elif a.begins_with("--view="):
			_shot["view"] = a.substr(7)
		elif a.begins_with("--preset="):
			Settings.apply_preset(a.substr(9))
		elif a.begins_with("--halo="):
			Settings.data["light_halos"] = a.substr(7) == "1"
		elif a == "--introreal":
			_shot["introreal"] = true
		elif a == "--debughud":
			Settings.data["debug_hud"] = true
		elif a.begins_with("--popups="):
			Settings.data["popups"] = a.substr(9) == "1"
		elif a.begins_with("--camera="):
			Settings.data["camera"] = int(a.substr(9))
		elif a.begins_with("--tod="):
			Game.time_of_day = int(a.substr(6))
		elif a.begins_with("--weather="):
			Game.weather_override = int(a.substr(10))
		elif a == "--overview":
			_shot["overview"] = true
		elif a == "--nohud":
			_shot["nohud"] = true
		elif a.begins_with("--thumb="):
			_shot["thumb"] = int(a.substr(8))
		elif a.begins_with("--ox="):
			_shot["ox"] = float(a.substr(5))
		elif a.begins_with("--oz="):
			_shot["oz"] = float(a.substr(5))
		elif a.begins_with("--overhead="):
			_shot["overhead"] = float(a.substr(11))
		elif a.begins_with("--lightat="):
			_shot["lightat"] = float(a.substr(10))
		elif a.begins_with("--skyyaw="):
			_shot["skyyaw"] = float(a.substr(9))
		elif a.begins_with("--skypitch="):
			_shot["skypitch"] = float(a.substr(11))
		elif a.begins_with("--skyt="):
			_shot["skyt"] = float(a.substr(7))
		elif a.begins_with("--at="):
			_shot["at"] = float(a.substr(5))
		elif a.begins_with("--lat="):
			_shot["lat"] = float(a.substr(6))
		elif a.begins_with("--zoom="):
			_shot["zoom"] = float(a.substr(7))
		elif a.begins_with("--hazard="):
			_shot["hazard"] = a.substr(9)
		elif a.begins_with("--mode="):
			Game.mode = int(a.substr(7))


## Test view: every car on a paper plinth.
func _lineup() -> void:
	var w := Node3D.new()
	add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e6dcc4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0da")
	env.ambient_light_energy = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.6
	key.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	key.shadow_enabled = true
	w.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.rotation = Vector3(deg_to_rad(-35), deg_to_rad(10), 0)
	w.add_child(fill)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/paper.gdshader")
	mat.set_shader_parameter("fibre", Stage.fibre_tex())
	var cars := Catalog.cars()
	var pick := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cars="):
			pick = a.substr(7)
	if pick != "":
		var want := pick.split(",")
		var sel: Array = []
		for c in cars:
			if want.has(str(c.get("style", ""))):
				sel.append(c)
		var cx := 0.0
		for i in sel.size():
			var m2 := CarModel.build(sel[i], i + 1, mat)
			var r2: Node3D = m2["root"]
			r2.position = Vector3(i * 4.2 - (sel.size() - 1) * 2.1, 0, 0)
			r2.rotation.y = 0.6
			w.add_child(r2)
			cx += 1.0
		var cam2 := Camera3D.new()
		cam2.fov = 38
		w.add_child(cam2)
		var span := maxf(4.0, sel.size() * 4.2)
		cam2.position = Vector3(0, 2.6, span * 0.62 + 4.0)
		cam2.look_at(Vector3(0, 0.8, 0))
		cam2.current = true
		post.visible = false
		return
	for i in cars.size():
		var m := CarModel.build(cars[i], i + 1, mat)
		var r: Node3D = m["root"]
		r.position = Vector3((i % 5) * 6.0 - 12.0, 0, (i / 5) * 6.5 - 10.0)
		r.rotation.y = 1.25
		w.add_child(r)
	var cam := Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.position = Vector3(0, 15, 25)
	cam.look_at(Vector3(0, 0, 0))
	cam.current = true
	post.visible = false


func _run_bench() -> void:
	# Headless logic check: every stage, autopilot to the finish, in each mode.
	_shot["autopilot"] = true
	Engine.max_fps = 0
	var list: Array = range(Catalog.stages().size())
	if OS.get_cmdline_user_args().has("--mini"):
		list = [0, 13, 24]
	elif OS.get_cmdline_user_args().has("--quick"):
		list = range(0, Catalog.stages().size(), 4)
		list.append(35)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			list = [int(a.substr(7))]
		elif a == "--rx":
			list = Catalog.rallycross_indices()
	Game.circuit_laps = 3
	if OS.get_cmdline_user_args().has("--rxbump"):
		await _run_rxbump(list)
		return
	if OS.get_cmdline_user_args().has("--rxcheck"):
		await _run_rxcheck(list)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--rxaccel"):
		await _run_rxaccel(list)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--rxwall"):
		await _run_rxwall(list)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--rxgrind"):
		await _run_rxgrind(list)
		get_tree().quit()
		return
	for si in list:
		for m in ([Game.Mode.TIME_TRIAL] if si == 35 else ([Game.Mode.TIME_TRIAL] if Catalog.stages()[si].has("rx") and not OS.get_cmdline_user_args().has("--grid") else ([Game.Mode.RACE] if Catalog.stages()[si].has("rx") else [Game.Mode.TIME_TRIAL, Game.Mode.RACE]))):
			Game.mode = m
			Game.stage_index = si
			var t0 := Time.get_ticks_msec()
			await _start_race()
			var build_ms := Time.get_ticks_msec() - t0
			if race.drivers.has(race.player):
				race.drivers[race.player].joker_lap = 2
			var tr := race.stage.track
			var res := {}
			race.finished.connect(func(r): res["r"] = r)
			var frames := 0
			var bounce_air := false
			var bounce_gh := 0.0
			var bounce_s := 0.0
			var jokers := {}
			var sec := {}       # lap -> [time at section start, time at section end]
			var prev_s := race.player.s
			while res.is_empty() and frames < 30 * 1500:
				await get_tree().process_frame
				frames += 1
				if OS.get_cmdline_user_args().has("--rxbounce"):
					var bp: Car = race.player
					var gh_now: float = race.stage.track.surface_height(bp.pos, bp.s, bp.lat)
					if absf(gh_now - bounce_gh) > 0.10 and frames > 5:
						print("RXJUMP s=%.2f(prev %.2f) lat=%.2f gh=%.2f prev=%.2f idx=%d" % [bp.s, bounce_s, bp.lat, gh_now, bounce_gh, bp.track_i])
					bounce_gh = gh_now
					bounce_s = bp.s
					if bp.airborne != bounce_air:
						if bp.airborne:
							print("RXAIR s=%.0f lat=%.1f lap=%d v=%.1f vy=%.2f" % [bp.s, bp.lat, bp.lap, bp.v_long, bp.vy])
						bounce_air = bp.airborne
				var jt: Dictionary = race.stage.track.joker
				if not jt.is_empty() and race.player.laps_total > 0:
					var a: float = float(jt.s0) - 60.0
					var b: float = minf(float(jt.s1) + 60.0, race.stage.track.length - 4.0)
					var ps: float = race.player.s
					var lp: int = race.player.lap
					if prev_s < a and ps >= a and ps - prev_s < 30.0:
						sec[lp] = [race._race_time_for_bench(), 0.0]
					if prev_s < b and ps >= b and ps - prev_s < 30.0 and sec.has(lp):
						sec[lp][1] = race._race_time_for_bench()
					prev_s = ps
				if frames % 30 == 0 and OS.get_cmdline_user_args().has("--rxstuck") and race.player.lap >= 1 and absf(race.player.v_long) < 1.5 and race.player.s > 20.0:
					var ps: Car = race.player
					print("RXSTUCK t=%ds lap=%d s=%.0f lat=%.1f v=%.1f y=%.2f airborne=%s on_road=%s steer=%.2f thr=%.2f brk=%.2f walls=%s" % [frames / 30, ps.lap, ps.s, ps.lat, ps.v_long, ps.y, str(ps.airborne), str(ps.on_road), ps.steer, ps.throttle, ps.brake, race.stage.track.barriers_at(ps.s, signf(ps.lat)).map(func(b): return "%s:%.1f" % [b.kind, race.stage.track.barrier_wall(b, ps.s)])])
				if frames % 8 == 0 and OS.get_cmdline_user_args().has("--rxtrace") and Catalog.stages()[si].has("rx") and race.player.s > _arg_float("--rxlo=", 1250.0) and race.player.s < _arg_float("--rxhi=", 1480.0):
					var pl: Car = race.player
					print("RXPROGRESS t=%ds lap=%d gate=%d s=%.0f lat=%.1f v=%.1f joker=%s on_road=%s steer=%.2f thr=%.2f brk=%.2f gear=%d rpm=%.0f wl=%s wg=%s y=%.2f air=%s slip=%.2f acc=%.2f surf=%.2f grade=%.3f patch=%s h=%.2f tang=%.2f walls=%s hw=%.1f" % [frames / 30, pl.lap, int(race._circuit_progress[pl].gate), pl.s, pl.lat, pl.v_long, pl.joker_taken, pl.on_road, pl.steer, pl.throttle, pl.brake, pl.gear, pl.rpm, pl.wheel_load, pl.wheel_grip, pl.y, pl.airborne, pl.slip, pl.longitudinal_accel, pl.surface, race.stage.track.grade_along(pl.pos, pl.s, pl.lat, pl.fwd()), pl.patch_kind, pl.h, race.stage.track.heading_at(pl.track_i), race.stage.track.barriers_at(pl.s, signf(pl.lat)).map(func(b): return "%s:%.1f" % [b.kind, race.stage.track.barrier_wall(b, pl.s)]), race.stage.track.road_half_width(pl.s)])
			if res.is_empty():
				print("BENCH stage=%d mode=%d DID NOT FINISH s=%.0f/%.0f" % [si, m, race.player.s, tr.finish_s])
				continue
			var r: Dictionary = res["r"]
			var rows: Array = r["rows"]
			if race.stage.track.rx:
				var laps_log: Array = race._lap_log[race.player]
				var splits := []
				var last := 0.0
				for t in laps_log:
					splits.append(snappedf(t - last, 0.01))
					last = t
				var sect := []
				for k in sec.keys():
					sect.append(snappedf(float(sec[k][1]) - float(sec[k][0]), 0.01))
				print("RXBENCH %s lap_splits=%s joker_taken=%s joker_target_delta=%.1f section_times=%s" % [Catalog.stages()[si].id, splits, race.player.joker_taken, race.stage.track.rx_info.get("delta", 0.0), sect])
			print("BENCH stage=%d mode=%d len=%.0f corners=%d pieces=%d build=%dms player=%s medals=%s/%s/%s pos=%d/%d slowest=%s" % [si, m, tr.length, tr.corners.size(),
				race.stage.scenery.placements.size(), build_ms, Game.fmt_time(r["player_time"]), Game.fmt_time(r["medals"][0]), Game.fmt_time(r["medals"][1]),
				Game.fmt_time(r["medals"][2]), rows.map(func(x): return x["player"]).find(true) + 1, rows.size(), Game.fmt_time(rows[-1]["time"])])
	get_tree().quit()


func _run_shot() -> void:
	var view: String = _shot.get("view", "race")
	if view == "bench":
		_run_bench()
		return
	if view == "loading":
		await _loading_stage(Catalog.stages()[int(_shot.get("stage", 0))])
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot["path"])
		print("SHOT saved ", _shot["path"])
		get_tree().quit()
		return
	if view == "lineup":
		_lineup()
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot["path"])
		get_tree().quit()
		return
	var stage_i: int = _shot.get("stage", 0)
	Game.stage_index = stage_i
	_shot["autopilot"] = true
	if view == "crash":
		Game.mode = Game.Mode.RACE
		await _start_race()
		var a: Car = race.cars[0]
		var b: Car = race.cars[1]
		for c in race.cars:
			c.frozen = false
			c.place_at(200.0 + race.cars.find(c) * 40.0, 3.5)
		race.state = Race.State.RACING
		race.drivers.clear()
		a.place_at(300.0, 0.0)
		b.place_at(312.0, 0.6)
		a.vel = a.fwd() * 30.0
		var max_b := 0.0
		var max_a_after := 0.0
		for k in 90:
			a.throttle = 0.0
			await get_tree().process_frame
			max_b = maxf(max_b, b.speed())
			if k > 20:
				max_a_after = maxf(max_a_after, a.speed())
		print("CRASH rear-end: hitter 30.0 -> %.1f, struck car max %.1f, struck car lat %.1f yaw %.2f" % [max_a_after, max_b, b.lat, b.yaw_rate])
		# Into a solid prop at speed.
		var tr := race.stage.track
		var sol: Array = []
		for o in race.stage.scenery.props_near(tr.point_at(600.0)):
			if float(o[2]) > 0.5 and not o[4]:
				sol = o
				break
		if not sol.is_empty():
			var op := Vector2(sol[0], sol[1])
			a.pos = op - Vector2(0, 8)
			a.h = 0.0
			a.vel = Vector2(0, 30)
			var mx := 0.0
			for k in 60:
				await get_tree().process_frame
				if k > 10:
					mx = maxf(mx, a.speed())
			print("CRASH tree at 30 m/s: speed afterwards max %.1f, distance from tree %.1f" % [mx, a.pos.distance_to(op)])
		get_tree().quit()
		return
	if view == "results":
		await _start_race()
		for k in 60:
			await get_tree().process_frame
		_on_race_finished({"rows": [{"name": "You", "time": 35.3, "car": Game.car_index, "player": true}], "player_time": 35.3, "medal": 0,
			"medals": [42.38, 47.91, 54.54], "stage": Game.stage_index})
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot["path"])
		get_tree().quit()
		return
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
			"events": _event_type()
			"carousel": _stage_carousel(false, int(_shot.get("stage", 0)))
			"circuits": _stage_carousel(true)
			"jokerintro": _joker_intro(func(): _event_type())
			"series": _series_select()
			"details": _stage_details(int(_shot.get("stage", 0)))
			"settings": _settings()
			"benchmark": _benchmark_ui()
	var t: float = _shot.get("time", 6.0)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while frames < int(t * 30.0):
		await get_tree().process_frame
		frames += 1
	print("SHOT fps_avg=%.1f frames=%d" % [frames / t, frames])
	if race and OS.get_cmdline_user_args().has("--kinds"):
		var cnt := {}
		for pl in race.stage.scenery.placements:
			cnt[pl["kind"]] = cnt.get(pl["kind"], 0) + 1
		print("SHOT kinds ", cnt)
		var bk := {}
		for bar in race.stage.track.barriers:
			bk[bar["kind"]] = bk.get(bar["kind"], 0) + 1
		print("SHOT barriers ", bk, " player s=", race.player.s)
	if race and race.skids:
		print("SHOT skid marks: %d" % race.skids.multimesh.visible_instance_count)
	if race and race.player:
		print("SHOT player s=%.1f speed=%.1f lat=%.1f pos=%s y=%.1f" % [race.player.s, race.player.speed(), race.player.lat, race.player.pos, race.player.y])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	if _shot.has("overhead") and race:
		# Debug: look straight down on the player from a height (or from the side with --side).
		var oc := Camera3D.new()
		race.add_child(oc)
		var pp: Vector3 = race.player.global_position
		var hgt: float = _shot["overhead"]
		if _shot.has("overview"):
			var box := race.stage.track.bounds()
			var cen := box.get_center()
			pp = Vector3(cen.x, race.stage.track.elev[0], cen.y)
			hgt = maxf(box.size.x, box.size.y) * 0.62 * float(_shot.get("zoom", 1.0))
		oc.position = pp + Vector3(hgt * float(_shot.get("ox", 0.35)), hgt, hgt * float(_shot.get("oz", 0.35)))
		oc.look_at(pp)
		oc.current = true
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--party") and race and race.stage.rx_props:
		race.stage.rx_props.celebrate()
		await get_tree().create_timer(2.6).timeout
	if OS.get_cmdline_user_args().has("--lights") and race and race.stage.rx_props:
		race.stage.rx_props.set_start_lights(4)
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--heli") and race:
		var hc: Helicopter = race.stage.helicopter
		hc._begin(race.player.s + 60.0)
		for k in 20:
			hc.update(0.1, race.player.s)
		var hcam := Camera3D.new()
		hcam.fov = 55
		race.add_child(hcam)
		hcam.global_position = hc.global_position + Vector3(14, 3, 16)
		hcam.look_at(hc.global_position)
		hcam.current = true
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--conetest") and race and race.stage.rx_props:
		var rp: RxProps = race.stage.rx_props
		print("CONETEST cones=", rp.cones.size())
		var cone: Dictionary = rp.cones[0]
		race.player.pos = cone.pos
		race.player.y = float(cone.y)
		race.player.vel = Vector2(0, 12)
		var n0 := rp.knock_cones(race.player)
		await get_tree().create_timer(0.8).timeout
		print("CONETEST hit=", n0, " moved=", (cone.node as Node3D).position.distance_to(Vector3(cone.pos.x, cone.y, cone.pos.y)), " rest=", cone.rest)
	if OS.get_cmdline_user_args().has("--atboard") and race and not race.stage.debug_board.is_empty():
		var bc: Vector3 = race.stage.debug_board[0]
		var bn: Vector3 = race.stage.debug_board[1]
		var bcam := Camera3D.new()
		bcam.fov = 50
		race.add_child(bcam)
		bcam.global_position = bc + bn * 3.2 + Vector3(0, 0.3, 0)
		bcam.look_at(bc)
		bcam.current = true
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--jokermap") and race:
		var jm := JokerMock.new()
		jm.track = race.stage.track
		jm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var jl := CanvasLayer.new()
		jl.layer = 200
		add_child(jl)
		jl.add_child(jm)
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--atarch") and race and not race.stage.arch_stations.is_empty():
		race.player.place_at(float(race.stage.arch_stations[0]) - 24.0, 0.0)
		race.camera.snap()
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--jokerinfo") and race:
		var jt: Dictionary = race.stage.track.joker
		print("JOKERINFO s0=", jt.s0, " s1=", jt.s1, " len=", race.stage.track.length)
	if OS.get_cmdline_user_args().has("--atchicane") and race:
		for f in race.stage.track.features:
			if f["type"] == "chicane" and str(f.get("kind", "")) == "tyre":
				print("TCHICANE s=", f["s"])
				race.player.place_at(float(f["s"]) - 22.0, 0.0)
				race.camera.snap()
				break
		await get_tree().process_frame
	if race:
		for ia in OS.get_cmdline_user_args():
			if ia.begins_with("--introat="):
				race._intro_t = float(ia.substr(10)) * Race.INTRO_LEN
				race._intro_camera(0.0)
				await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--lodstats") and race and race.stage.scenery:
		var cnt := {}
		for pl in race.stage.scenery.placements:
			var kk := "%s|%d" % [pl["kind"], pl["var"]]
			cnt[kk] = int(cnt.get(kk, 0)) + 1
		var total := 0
		for kk in cnt.keys():
			var parts: PackedStringArray = str(kk).split("|")
			var info: Dictionary = race.stage.scenery.lib[parts[0]][int(parts[1])]
			var m: Mesh = info["mesh"]
			var tris := 0
			for sidx in m.get_surface_count():
				var arr := m.surface_get_arrays(sidx)
				tris += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
			total += tris * int(cnt[kk])
			print("LOD ", kk, " count=", cnt[kk], " tris_each=", tris, " total=", tris * int(cnt[kk]))
		print("LOD total_placed_tris=", total)
	if OS.get_cmdline_user_args().has("--perf") and race:
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		print("PERF draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			" prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			" tex_mem_MB=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576,
			" buf_mem_MB=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576)
	if _shot.has("lightat") and race:
		var tr2 := race.stage.track
		race.stage.advance_lighting(lerpf(tr2.start_s, tr2.finish_s, float(_shot["lightat"])))
		race.player.set_headlight_level(race.stage.headlight_level)
		await get_tree().process_frame
		print("LIGHTS level=", race.stage.headlight_level, " n=", race.player._lights.size())
		for lt in race.player._lights:
			print("  ", lt.get_class(), " vis=", lt.visible, " energy=", (lt as Light3D).light_energy, " in_tree=", lt.is_inside_tree(), " broken=", lt.get_meta("broken", false))
	if OS.get_cmdline_user_args().has("--hero") and race:
		await _hero_setup()
	if _shot.has("skyyaw") and race:
		# Debug: look at the sky from the player's position (yaw 0 = along +Z, degrees).
		var sc := Camera3D.new()
		sc.fov = 75
		race.add_child(sc)
		sc.global_position = race.player.global_position + Vector3(0, 3.0, 0)
		var yaw := deg_to_rad(float(_shot["skyyaw"]))
		var pit := deg_to_rad(float(_shot.get("skypitch", 20.0)))
		sc.look_at(sc.global_position + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)))
		sc.current = true
		if _shot.has("skyt") and race.stage:
			race.stage.update(float(_shot["skyt"]), race.player.global_position, 100.0, race.player.s, null)
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--tyres") and race and race.stage.rx_props:
		var rr: Vector2 = race.player.right_axis()
		race.stage.rx_props.knock_tyres(race.player.pos + rr * 3.0, -rr, 14.0, race.player.y)
		await get_tree().create_timer(1.2).timeout
		for tt in race.stage.rx_props.tyres:
			print("TYRE pos=", (tt.node as Node3D).global_position, " rest=", tt.rest, " player=", race.player.global_position)
	if OS.get_cmdline_user_args().has("--fw") and race and race.stage.rx_props:
		var pp3: Vector3 = race.player.global_position
		for q in 3:
			race.stage.rx_props._spawn_firework(pp3 + Vector3(40.0 + q * 6.0, 22.0 + q * 3.0, -14.0 + q * 14.0))
		await get_tree().create_timer(0.5).timeout
	if _shot.has("nohud") and race:
		race.set_overlay_visible(false)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _shot.has("thumb"):
		var tw: int = _shot["thumb"]
		img.resize(tw, int(tw * 9.0 / 16.0), Image.INTERPOLATE_LANCZOS)
	img.save_png(_shot["path"])
	print("SHOT saved ", _shot["path"])
	get_tree().quit()


## Hero art for the loading screen: the car backlit by the low sun, soft focus, bloom.
func _hero_setup() -> void:
	var car: Car = race.player
	var st: Stage = race.stage
	var sun: Vector3 = st.key_light.global_basis.z
	var flat := Vector3(sun.x, 0.0, sun.z).normalized()
	var yaw_off := deg_to_rad(_arg_float("--heroyaw=", 30.0))
	var face := (-flat).rotated(Vector3.UP, yaw_off)
	car.h = atan2(face.x, face.z) + _arg_float("--carturn=", 0.62)
	car.vel = Vector2.ZERO
	car.frozen = true
	car.sync_now()
	var base := car.global_position
	var cam := Camera3D.new()
	cam.fov = _arg_float("--herofov=", 36.0)
	race.add_child(cam)
	var dist := _arg_float("--herodist=", 8.5)
	cam.global_position = base + face * dist + Vector3(0, _arg_float("--heroh=", 0.85), 0)
	var aim := base + Vector3(0, _arg_float("--heroaim=", 1.55), 0)
	var right := Vector3.UP.cross((aim - cam.global_position).normalized()).normalized()
	cam.look_at(aim + right * _arg_float("--heroshift=", 0.0))
	cam.current = true
	race.set_overlay_visible(false)
	var m := post.material as ShaderMaterial
	_apply_post()
	m.set_shader_parameter("taps", 24)
	m.set_shader_parameter("focus_y", _arg_float("--herofocus=", 0.62))
	m.set_shader_parameter("band", 0.16)
	m.set_shader_parameter("ramp", 0.30)
	m.set_shader_parameter("max_blur_px", 26.0 * float(DisplayServer.window_get_size().y) / 1080.0)
	m.set_shader_parameter("near_gain", 1.4)
	m.set_shader_parameter("bloom", _arg_float("--herobloom=", 0.5))
	m.set_shader_parameter("bloom_px", 22.0 * float(DisplayServer.window_get_size().y) / 1080.0)
	m.set_shader_parameter("bloom_cut", _arg_float("--herocut=", 0.85))
	m.set_shader_parameter("vignette", 0.35)
	if OS.get_cmdline_user_args().has("--herotitle"):
		var title := Label.new()
		title.text = "Paper Rally"
		title.add_theme_font_override("font", PaperTheme.font())
		title.add_theme_font_size_override("font_size", 120)
		title.add_theme_color_override("font_color", Color("#fff3dc"))
		title.add_theme_color_override("font_shadow_color", Color(0.18, 0.06, 0.1, 0.65))
		title.add_theme_constant_override("shadow_offset_x", 5)
		title.add_theme_constant_override("shadow_offset_y", 7)
		title.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.1, 0.85))
		title.add_theme_constant_override("outline_size", 10)
		title.position = Vector2(110, 130)
		var top := CanvasLayer.new()
		top.layer = 100
		add_child(top)
		top.add_child(title)
	await get_tree().create_timer(0.6).timeout


func _arg_float(prefix: String, fallback: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return fallback


## Geometry audit: where the road surface sits against the landscape, across the road and Joker lane.
## Hidden lumps: places where the driving surface rises or dips against its own surroundings within a few metres.
func _run_rxbump(list: Array) -> void:
	Game.mode = Game.Mode.TIME_TRIAL
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rxs="):
			only = a.substr(6)
	for si in list:
		if not Catalog.stages()[si].has("rx"):
			continue
		Game.stage_index = si
		await _start_race()
		var tr := race.stage.track
		var found: Array = []
		for lat: float in [-4.0, 0.0, 4.0]:
			var s := 6.0
			while s < tr.length - 6.0:
				if not tr.on_stacked_span(s) and tr.on_road_at(s, lat, 0.0):
					var i := tr.index_at(s)
					var h0 := _surf(tr, s, lat)
					var ha := _surf(tr, s - 3.0, lat)
					var hb := _surf(tr, s + 3.0, lat)
					var bump := h0 - (ha + hb) * 0.5
					if absf(bump) > 0.07:
						found.append([absf(bump), s, lat, bump])
				s += 1.0
		found.sort_custom(func(a, b): return a[0] > b[0])
		var shown := 0
		var last_s := -99.0
		var line := ""
		for f in found:
			if absf(float(f[1]) - last_s) < 6.0:
				continue
			last_s = float(f[1])
			line += " [s=%.0f lat=%.0f bump=%+.2f]" % [f[1], f[2], f[3]]
			shown += 1
			if shown >= 8:
				break
		print("RXBUMP ", Catalog.stages()[si]["name"], " n=", found.size(), line)
		if OS.get_cmdline_user_args().has("--rxprof"):
			var s0 := _arg_float("--rxlo=", 140.0)
			if s0 > tr.length - 20.0:
				var seam := ""
				var q := tr.length - 6.0
				while q < tr.length + 6.0:
					seam += " %.2f:%.3f" % [q, _surf(tr, q, 0.0)]
					q += 0.5
				print("RXSEAM L=", tr.length, " n=", tr.pts.size(), " step=", tr._sample_step, seam)
			var line2 := ""
			var s3 := s0
			var plat := _arg_float("--rxlat=", -4.4)
			while s3 < s0 + 12.0:
				line2 += " %.2f:%.3f" % [s3, _surf(tr, s3, plat)]
				s3 += 0.25
			print("RXPROF lat=-4.4 s:surf/terrain", line2)
			var line3 := ""
			for lt in range(-9, 10):
				line3 += " %d:%.2f" % [lt, _surf(tr, s0 + 10.0, float(lt))]
			print("RXPROF across at s=", s0 + 10.0, line3, " half_w=", tr.road_half_width(s0 + 10.0))
		if OS.get_cmdline_user_args().has("--rxfine"):
			for lat: float in [-3.0, 0.6, 3.0]:
				var sharp := ""
				var s2 := 4.0
				var last2 := -99.0
				while s2 < tr.length - 4.0:
					if not tr.on_stacked_span(s2) and tr.on_road_at(s2, lat, 0.0):
						var d2 := _surf(tr, s2 + 0.5, lat) - 2.0 * _surf(tr, s2, lat) + _surf(tr, s2 - 0.5, lat)
						if absf(d2) > 0.03 and absf(s2 - last2) > 1.5:
							sharp += " [s=%.1f d2=%+.2f]" % [s2, d2]
							last2 = s2
					s2 += 0.5
				print("RXFINE lat=", lat, sharp)
	get_tree().quit()


func _surf(tr: Track, s: float, lat: float) -> float:
	var i := tr.index_at(fposmod(s, tr.length))
	var p: Vector2 = tr.pts[i] + tr.nrm[i] * lat
	return tr.surface_height(p, fposmod(s, tr.length), lat)


func _run_rxcheck(list: Array) -> void:
	Game.mode = Game.Mode.TIME_TRIAL
	for si in list:
		if not Catalog.stages()[si].has("rx"):
			continue
		Game.stage_index = si
		await _start_race()
		var tr := race.stage.track
		var buried := 0
		var perched := 0
		var worst_b := 0.0
		var worst_p := 0.0
		var wb := ""
		var wp := ""
		var total := 0
		var s := 0.0
		while s < tr.length:
			if not tr.on_stacked_span(s):
				var i := tr.index_at(s)
				var ext := tr.road_extent(s)
				var lat := -ext
				while lat <= ext:
					if tr.on_road_at(s, lat, 0.0):
						var p: Vector2 = tr.pts[i] + tr.nrm[i] * lat
						var ry := tr.surface_height(p, s, lat)
						var ty := tr.terrain.height(p)
						total += 1
						if ty > ry + 0.05:
							buried += 1
							if ty - ry > worst_b:
								worst_b = ty - ry
								wb = "s=%.0f lat=%.1f" % [s, lat]
						elif ry - ty > 0.6:
							perched += 1
							if ry - ty > worst_p:
								worst_p = ry - ty
								wp = "s=%.0f lat=%.1f" % [s, lat]
					lat += 2.0
			s += 4.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rxs="):
				var ss := float(a.substr(6))
				var ii := tr.index_at(ss)
				var line := "RXPROBE %s s=%.0f road_h=%.2f ext=%.1f stacked=%s |" % [Catalog.stages()[si].id, ss, tr.road_h(ss), tr.road_extent(ss), tr.on_stacked_span(ss)]
				for off in [0.0, 6.0, 10.0, 14.0, 20.0, 30.0, 45.0]:
					var q: Vector2 = tr.pts[ii] + tr.nrm[ii] * (tr.road_extent(ss) + off)
					line += " +%.0f:%.1f" % [off, tr.terrain.height(q)]
				print(line)
		if OS.get_cmdline_user_args().has("--rxnodes"):
			var stack: Array = [race.stage]
			while not stack.is_empty():
				var nd: Node = stack.pop_back()
				for ch in nd.get_children():
					stack.append(ch)
				if nd is MeshInstance3D and nd.mesh:
					var bb: AABB = nd.global_transform * nd.mesh.get_aabb()
					if bb.size.y > 12.0 or maxf(bb.size.x, bb.size.z) > 60.0:
						print("RXNODE %s %s size=(%.0f,%.0f,%.0f) pos=(%.0f,%.0f,%.0f)" % [Catalog.stages()[si].id, nd.get_path(), bb.size.x, bb.size.y, bb.size.z, bb.position.x, bb.position.y, bb.position.z])
		var on_road := 0
		var first_bad := ""
		var kinds := {}
		for key in race.stage.scenery.obstacles.keys():
			for o in race.stage.scenery.obstacles[key]:
				var q := Vector2(float(o[0]), float(o[1]))
				var bi := 0
				var bd := 1e18
				for pi in range(0, tr.pts.size(), 2):
					var dd := q.distance_squared_to(tr.pts[pi])
					if dd < bd:
						bd = dd
						bi = pi
				var lt: float = (q - tr.pts[bi]).dot(tr.nrm[bi])
				var st: float = tr.dist[bi]
				var ex := tr.road_half_width(st)
				var bnd := tr.joker_band(st)
				if not is_nan(bnd.x):
					if lt > 0.0 and bnd.y > 0.0:
						ex = maxf(ex, bnd.y)
					elif lt < 0.0 and bnd.x < 0.0:
						ex = maxf(ex, -bnd.x)
				if float(o[2]) > 0.0 and absf(lt) - ex < absf(float(o[2])) and not tr.on_stacked_span(st):
					on_road += 1
					var kk := str(o[5]) if o.size() > 5 else "?"
					kinds[kk] = int(kinds.get(kk, 0)) + 1
					if first_bad == "":
						first_bad = "%s@s=%.0f lat=%.1f ext=%.1f r=%.1f" % [kk, st, lt, ex, float(o[2])]
		var drive := {}
		var drive_n := 0
		var drive_first := ""
		for key in race.stage.scenery.obstacles.keys():
			for o in race.stage.scenery.obstacles[key]:
				var q2 := Vector2(float(o[0]), float(o[1]))
				var bi2 := 0
				var bd2 := 1e18
				for pi in range(0, tr.pts.size(), 2):
					var dd2 := q2.distance_squared_to(tr.pts[pi])
					if dd2 < bd2:
						bd2 = dd2
						bi2 = pi
				var lt2: float = (q2 - tr.pts[bi2]).dot(tr.nrm[bi2])
				var st2: float = tr.dist[bi2]
				if absf(lt2) < tr.road_half_width(st2) - 0.3 and not tr.on_stacked_span(st2):
					var k2 := str(o[5]) if o.size() > 5 else "?"
					drive[k2] = int(drive.get(k2, 0)) + 1
					drive_n += 1
					if drive_first == "":
						drive_first = "%s@s=%.0f lat=%.1f r=%.1f" % [k2, st2, lt2, float(o[2])]
		print("RXDRIVE %s on_driving_surface=%d first=%s kinds=%s" % [Catalog.stages()[si].id, drive_n, drive_first, str(drive)])
		print("RXOBJ %s solid_on_road=%d %s kinds=%s" % [Catalog.stages()[si].id, on_road, first_bad, str(kinds)])
		var nlast := tr.pts.size() - 1
		for pl in race.stage.scenery.placements:
			var ps: float = float(pl.s)
			if minf(absf(ps), absf(ps - tr.length)) < 14.0:
				print("RXNEAR %s kind=%s s=%.1f pos=(%.1f,%.1f)" % [Catalog.stages()[si].id, str(pl.kind), ps, pl.pos.x, pl.pos.y])
		var probe := Vector3(tr.pts[0].x, tr.elev[0] + 0.6, tr.pts[0].y)
		var stack2: Array = [race.stage]
		while not stack2.is_empty():
			var n2: Node = stack2.pop_back()
			for ch in n2.get_children():
				stack2.append(ch)
			if n2 is MeshInstance3D and n2.mesh:
				var bb2: AABB = n2.global_transform * n2.mesh.get_aabb()
				if bb2.grow(0.3).has_point(probe) and bb2.size.y > 0.4:
					print("RXHIT %s %s size=(%.1f,%.1f,%.1f) pos=(%.1f,%.1f,%.1f)" % [Catalog.stages()[si].id, n2.get_path(), bb2.size.x, bb2.size.y, bb2.size.z, bb2.position.x, bb2.position.y, bb2.position.z])
		for bar in tr.barriers:
			var kk := float(bar["s0"])
			while kk < float(bar["s1"]):
				var k2 := minf(kk + 3.0, float(bar["s1"]))
				var q0: Vector2 = tr.pts[tr.index_at(kk)] + tr.nrm[tr.index_at(kk)] * float(bar["side"]) * tr.barrier_wall(bar, kk)
				var q1: Vector2 = tr.pts[tr.index_at(k2)] + tr.nrm[tr.index_at(k2)] * float(bar["side"]) * tr.barrier_wall(bar, k2)
				if q0.distance_to(q1) > 6.0:
					print("RXWALL %s bar kind=%s ref=%s side=%.0f s0=%.1f s1=%.1f seg at k=%.1f..%.1f len=%.1f wall0=%.1f wall1=%.1f idx=%d,%d" % [Catalog.stages()[si].id, bar["kind"], bar.get("ref", ""), float(bar["side"]), float(bar["s0"]), float(bar["s1"]), kk, k2, q0.distance_to(q1), tr.barrier_wall(bar, kk), tr.barrier_wall(bar, k2), tr.index_at(kk), tr.index_at(k2)])
				kk = k2
		var cl := ""
		for cn in tr.corners:
			cl += " [%.0f-%.0f sev%d %s]" % [float(cn.s0), float(cn.s1), int(cn.sev), "L" if float(cn.dir) < 0.0 else "R"]
		if not tr.joker.is_empty():
			var folds := 0
			var worst_f := 0.0
			var where_f := 0.0
			var jside: float = float(tr.joker.side)
			for ji in range(int(tr.joker.i0), int(tr.joker.i1) + 1):
				var band_f := tr.joker_band(tr.dist[ji])
				if is_nan(band_f.x):
					continue
				var far_edge := maxf(absf(band_f.x), absf(band_f.y))
				var ti: float = tr.tang[ji].x * tr.tang[mini(ji + 1, tr.pts.size() - 1)].y - tr.tang[ji].y * tr.tang[mini(ji + 1, tr.pts.size() - 1)].x
				var kk := absf(float(tr.curv[ji]))
				if ti * jside > 0.0 and kk * far_edge > 0.8:
					folds += 1
					if kk * far_edge > worst_f:
						worst_f = kk * far_edge
						where_f = tr.dist[ji]
			print("RXFOLD %s lane %.0f-%.0f (%.0f m) fold_samples=%d worst=%.2f at s=%.0f" % [Catalog.stages()[si].id, float(tr.joker.s0), float(tr.joker.s1), float(tr.joker.s1) - float(tr.joker.s0), folds, worst_f, where_f])
		if not tr.joker.is_empty() and OS.get_cmdline_user_args().has("--rxband"):
			for sb in range(int(float(tr.joker.s0)) - 10, int(float(tr.joker.s1)) + 10, 8):
				var bd := tr.joker_band(float(sb))
				print("RXBAND %s s=%d hw=%.1f band=(%.1f,%.1f) on_road(lat=-8.2)=%s" % [Catalog.stages()[si].id, sb, tr.road_half_width(float(sb)), bd.x, bd.y, str(tr.on_road_at(float(sb), -8.2 * float(tr.joker.side) * -1.0))])
		var steps := ""
		for sti in range(0, tr.pts.size() - 1):
			var dh := tr.road_h_i(sti + 1) - tr.road_h_i(sti)
			if absf(dh) > 0.3:
				steps += " s=%.0f:%+.2f" % [tr.dist[sti], dh]
		print("RXSTEP %s steps>0.3m/sample:%s" % [Catalog.stages()[si].id, steps])
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rxnear="):
				var sn := float(a.substr(9))
				var pn: Vector2 = tr.pts[tr.index_at(sn)]
				var out := ""
				for oi in range(0, tr.pts.size(), 3):
					if absf(tr.dist[oi] - sn) > 70.0 and tr.pts[oi].distance_to(pn) < 26.0:
						out += " s=%.0f d=%.1f h=%.1f" % [tr.dist[oi], tr.pts[oi].distance_to(pn), tr.road_h_i(oi)]
				print("RXNEAR2 %s s=%.0f h=%.1f width=%.1f others:%s" % [Catalog.stages()[si].id, sn, tr.road_h(sn), tr.road_half_width(sn) * 2.0, out])
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rxlat="):
				var sl := float(a.substr(8))
				var il := tr.index_at(sl)
				var line := "RXLAT %s s=%.0f road_h=%.2f hw=%.1f |" % [Catalog.stages()[si].id, sl, tr.road_h(sl), tr.road_half_width(sl)]
				for latv in range(-12, 13, 2):
					var q: Vector2 = tr.pts[il] + tr.nrm[il] * float(latv)
					line += " %d:%.1f(%.1f)" % [latv, tr.terrain.height(q), tr.surface_height(q, sl, float(latv))]
				print(line)
		if OS.get_cmdline_user_args().has("--rxgaps"):
			for g in tr.joker_gaps():
				var jb := tr.joker_band(float(g.s))
				print("RXGAP %s s=%.0f gap_lat=%.1f band=(%.1f,%.1f)" % [Catalog.stages()[si].id, float(g.s), float(g.lat), jb.x, jb.y])
		print("RXCORNERS %s len=%.0f joker=%s corners=%s" % [Catalog.stages()[si].id, tr.length, str([float(tr.joker.get("s0", 0.0)), float(tr.joker.get("s1", 0.0))]), cl])
		var gl := ""
		var sg := 0.0
		while sg < tr.length:
			gl += " %.0f:%.1f" % [sg, 100.0 * (tr.road_h(sg + 8.0) - tr.road_h(sg - 8.0)) / 16.0]
			sg += 40.0
		print("RXGRADE %s grade%% every 40m:%s" % [Catalog.stages()[si].id, gl])
		print("RXSEAMN %s nrm0=%s nrmN=%s tang0=%s tangN=%s n=%d" % [Catalog.stages()[si].id, str(tr.nrm[0]), str(tr.nrm[nlast]), str(tr.tang[0]), str(tr.tang[nlast]), tr.pts.size()])
		print("RXSEAMGAP %s gap=%.2f start_s=%.1f finish_s=%.1f len=%.1f" % [Catalog.stages()[si].id, tr.pts[nlast].distance_to(tr.pts[0]), tr.start_s, tr.finish_s, tr.length])
		print("RXSEAM %s elev[0]=%.2f elev[last]=%.2f road_h(0)=%.2f road_h(L-1)=%.2f road_h(L-10)=%.2f road_h(10)=%.2f heights0=%.2f heightsN=%.2f bank0=%.3f bankN=%.3f" % [Catalog.stages()[si].id, tr.elev[0], tr.elev[nlast], tr.road_h(0.0), tr.road_h(tr.length - 1.0), tr.road_h(tr.length - 10.0), tr.road_h(10.0), tr.heights[0], tr.heights[nlast], tr.bank_slope(0), tr.bank_slope(nlast)])
		print("RXCROSS %s %s" % [Catalog.stages()[si].id, str(tr.stacked_crossing)])
		print("RXCHECK %s samples=%d buried=%d worst=%.2f@%s perched=%d worst=%.2f@%s" % [Catalog.stages()[si].id, total, buried, worst_b, wb, perched, worst_p, wp])


## Wall test: hold full throttle with the nose angled into the wall and watch speed, then try to drive away.
func _run_rxgrind(list: Array) -> void:
	Game.mode = Game.Mode.TIME_TRIAL
	for si in list:
		Game.stage_index = si
		await _start_race()
		var tr := race.stage.track
		var c: Car = race.player
		race.drivers.erase(c)
		while race.state != Race.State.RACING:
			await get_tree().process_frame
		for case_i in 3:
			var s0 := 40.0
			var side := 1.0 if case_i != 1 else -1.0
			c.place_at(s0, side * (tr.road_half_width(s0) - 1.2) if case_i < 2 else 0.0)
			var i := tr.index_at(s0)
			var tang := tr.tang[i]
			c.h = atan2(tang.x, tang.y) + (side * -0.07 if case_i < 2 else 0.0)   # nose slightly toward the wall (case 2: control, no wall)
			c.vel = tang * 20.0
			c.throttle = 1.0
			c.steer = 0.0
			var t := 0.0
			var line := "RXGRIND %s case=%d side=%.0f speed:" % [Catalog.stages()[si].id, case_i, side]
			for f in 480:
				await get_tree().physics_frame
				t += 1.0 / 60.0
				if f % 60 == 59:
					line += " %.1f" % c.vel.length()
				if case_i == 2 and f % 30 == 0 and f < 210:
					print("  GRIND f=%d v=%.1f vl=%.1f lat=%.2f dh=%.3f yaw=%.2f slip=%.2f thr=%.1f grounded=%s" % [f, c.vel.length(), c.v_long, c.lat, wrapf(c.h - atan2(tang.x, tang.y), -PI, PI), c.yaw_rate, c.slip, c.throttle, str(not c.airborne)])
			# Now stop dead against the wall and try to drive off.
			c.place_at(s0 + 40.0, side * tr.road_half_width(s0 + 40.0))
			c.vel = Vector2.ZERO
			c.throttle = 1.0
			c.steer = 0.0
			c.h = atan2(tang.x, tang.y) + side * -0.6
			var start := c.s
			for f in 360:
				await get_tree().physics_frame
			line += " | pinned restart: moved %.1f m, speed %.1f" % [c.s - start, c.vel.length()]
			print(line)


## Standing start, full throttle, straight: time to 50 / 80 / 100 km/h, and speed after 5 s (laps of wet grip included).
func _run_rxaccel(list: Array) -> void:
	Game.mode = Game.Mode.TIME_TRIAL
	for si in list:
		Game.stage_index = si
		await _start_race()
		var tr := race.stage.track
		var c: Car = race.player
		race.drivers.erase(c)
		while race.state != Race.State.RACING:
			await get_tree().process_frame
		var s0 := float(_arg_float("--rxaccel_s=", 20.0))
		c.place_at(s0, 0.0)
		c.throttle = 1.0
		c.steer = 0.0
		var t0 := race._race_time_for_bench()
		var t := 0.0
		var marks := {13.9: -1.0, 22.2: -1.0, 27.8: -1.0}
		var line := "RXACCEL %s patch=%s:" % [Catalog.stages()[si].id, c.patch_kind]
		for f in 2400:
			await get_tree().physics_frame
			t = race._race_time_for_bench() - t0
			var v := c.vel.length()
			for m in marks.keys():
				if marks[m] < 0.0 and v >= m:
					marks[m] = t
			if t >= 5.0 and not line.contains("v@5s"):
				line += " v@5s=%.1f s=%.0f lat=%.1f" % [v, c.s, c.lat]
		line += " t50=%.1f t80=%.1f t100=%.1f" % [marks[13.9], marks[22.2], marks[27.8]]
		print(line)


## Drive into every wall from the inside at speed, around the whole circuit, and report any car that ends up beyond it.
func _run_rxwall(list: Array) -> void:
	Game.mode = Game.Mode.TIME_TRIAL
	for si in list:
		Game.stage_index = si
		await _start_race()
		var tr := race.stage.track
		var c: Car = race.player
		race.drivers.erase(c)
		while race.state != Race.State.RACING:
			await get_tree().process_frame
		var tested := 0
		var passed := 0
		var s0 := _arg_float("--rxwall_s=", 30.0)
		var one_only := false
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rxwall_s=") and not OS.get_cmdline_user_args().has("--rxwall_range"):
				one_only = true
		var s_end := _arg_float("--rxwall_end=", tr.length - 30.0)
		while s0 < s_end:
			for side in [-1.0, 1.0]:
				var bars := tr.barriers_at(s0, side)
				if bars.is_empty():
					continue
				var wall := 0.0
				for bar in bars:
					wall = maxf(wall, tr.barrier_wall(bar, s0))
				# Start inside the road on that side, aimed at the wall at 45 degrees.
				var start_lat: float = float(side) * maxf(tr.road_half_width(s0) - 2.0, 1.0)
				c.place_at(s0, start_lat)
				var i := tr.index_at(s0)
				var tang := tr.tang[i]
				var nrm := tr.nrm[i]
				var dir: Vector2 = (tang + nrm * float(side)).normalized()
				c.h = atan2(dir.x, dir.y)
				c.vel = dir * 14.0
				c.throttle = 1.0
				c.steer = 0.0
				var worst := 0.0
				for f in 150:
					await get_tree().physics_frame
					if one_only and f % 5 == 0:
						print("  WTRACE side=%.0f f=%d s=%.0f lat=%.2f v=%.1f y=%.2f air=%s wall=%s" % [side, f, c.s, c.lat, c.vel.length(), c.y, str(c.airborne), str(tr.barriers_at(c.s, signf(c.lat)).map(func(b): return "%s/%s:%.1f" % [b.kind, b.get("ref", ""), tr.barrier_wall(b, c.s)]))])
					var bars2 := tr.barriers_at(c.s, signf(c.lat))
					var w2 := 0.0
					for bar in bars2:
						w2 = maxf(w2, tr.barrier_wall(bar, c.s))
					if w2 > 0.0 and absf(c.lat) > w2 + 0.4 and signf(c.lat) == side:
						worst = maxf(worst, absf(c.lat) - w2)
				# Where it came to rest: is the body overlapping the wall?
				var bars3 := tr.barriers_at(c.s, signf(c.lat))
				var wmax := 0.0
				for bar in bars3:
					if str(bar.kind) != "island":
						wmax = maxf(wmax, tr.barrier_wall(bar, c.s))
				var nn := tr.nrm[c.track_i] * signf(c.lat)
				var ext_end := c.half_wid * absf(c.right_axis().dot(nn)) + c.half_len * absf(c.fwd().dot(nn))
				var overlap := absf(c.lat) + ext_end - wmax
				if wmax > 0.0 and overlap > 0.3 and absf(c.lat) < wmax + 1.0:
					print("RXWALLEND %s s=%.0f side=%.0f overlap=%.2f lat=%.2f wall=%.2f speed=%.1f" % [Catalog.stages()[si].id, s0, side, overlap, c.lat, wmax, c.vel.length()])
				tested += 1
				if worst > 0.0:
					passed += 1
					print("RXWALLPASS %s s=%.0f side=%.0f wall=%.1f beyond=%.1f barriers=%s" % [Catalog.stages()[si].id, s0, side, wall, worst, str(bars.map(func(b): return "%s/%s" % [b.kind, b.get("ref", "")]))])
			if one_only:
				break
			s0 += 25.0
		print("RXWALLSUM %s tested=%d passed_through=%d" % [Catalog.stages()[si].id, tested, passed])
