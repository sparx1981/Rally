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
		await _start_attract(randi() % Catalog.stages().size(), true)
		_title()
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


## The native splash and the first interactive frame share the same original rally print.
func _loading_stage(sdef: Dictionary, startup := false) -> void:
	_clear_menu()
	var poster := TextureRect.new()
	poster.texture = preload("res://ui/boot.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(poster)
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", PaperTheme.box(PaperTheme.CREAM, PaperTheme.EDGE, 1, 0, 0))
	poster.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var rows := VBoxContainer.new()
	footer.add_child(rows)
	var stage_name := Label.new()
	stage_name.text = "Folding %s…" % sdef["name"] if startup else "%s  ·  %s" % [sdef["name"], sdef["variant_name"]]
	stage_name.add_theme_font_size_override("font_size", 25)
	stage_name.add_theme_color_override("font_color", PaperTheme.INK)
	rows.add_child(stage_name)
	if not startup:
		var tod_i := Game.race_tod()
		if tod_i < 0:
			tod_i = int(sdef.get("tod", 0))
		var info := Label.new()
		var distance := "%d laps" % Game.circuit_laps if sdef.get("circuit", false) else "%.1f km" % (float(sdef["length"]) / 1000.0)
		info.text = "%s  ·  %s  ·  %s     |     %s" % [distance, Catalog.weather(sdef["weather"])["label"], Catalog.TOD_NAMES[clampi(tod_i, 0, Catalog.TOD_NAMES.size() - 1)], TIPS.pick_random()]
		info.add_theme_font_size_override("font_size", 17)
		info.add_theme_color_override("font_color", PaperTheme.EDGE)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(info)
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
			list.add_child(_choice("Frame rate cap", ["30 fps", "60 fps"], 1 if int(Settings.g("fps")) == 60 else 0, func(i): Settings.set_value("fps", 60 if i == 1 else 30)))
			list.add_child(_choice("Show FPS counter", ["Off", "On"], 1 if Settings.g("show_fps") else 0, func(i): Settings.set_value("show_fps", i == 1)))
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
		elif a.begins_with("--at="):
			_shot["at"] = float(a.substr(5))
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
	if OS.get_cmdline_user_args().has("--rxcheck"):
		await _run_rxcheck(list)
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
			var jokers := {}
			var sec := {}       # lap -> [time at section start, time at section end]
			var prev_s := race.player.s
			while res.is_empty() and frames < 30 * 1500:
				await get_tree().process_frame
				frames += 1
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
			"series": _series_select()
			"details": _stage_details(int(_shot.get("stage", 0)))
			"settings": _settings()
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


func _arg_float(prefix: String, fallback: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return fallback


## Geometry audit: where the road surface sits against the landscape, across the road and Joker lane.
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
		print("RXOBJ %s solid_on_road=%d %s kinds=%s" % [Catalog.stages()[si].id, on_road, first_bad, str(kinds)])
		print("RXCROSS %s %s" % [Catalog.stages()[si].id, str(tr.stacked_crossing)])
		print("RXCHECK %s samples=%d buried=%d worst=%.2f@%s perched=%d worst=%.2f@%s" % [Catalog.stages()[si].id, total, buried, worst_b, wb, perched, worst_p, wp])
