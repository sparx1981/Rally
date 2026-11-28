class_name Race
extends Node3D
## Runs one stage: countdown, fixed-step physics for all cars, collisions, timing, positions,
## haptics, engine audio, HUD and the pop-up scenery driven by the player's progress.
## In attract mode (title screen) an AI drives and the stage loops.

signal lighting_changed
signal finished(result: Dictionary)
signal pause_requested

enum State { COUNTDOWN, RACING, DONE }

const FIXED := 1.0 / 120.0
const CO_DRIVER_SCRIPT := "res://scripts/race/co_driver_voice.gd"
const CROSSING_AUDIO_SCRIPT := "res://scripts/race/crossing_audio.gd"
const RECOVERY_WARNING := 10.0
const RECOVERY_LIMIT := 15.0

var stage_index := 0
var mode := 0
var attract := false
var stage: Stage
var cars: Array[Car] = []
var drivers := {}          # Car -> AIDriver
var player: Car
var camera: ChaseCamera
var hud: Hud
var touch: TouchControls
var input := PlayerInput.new()
var _voice
var _crossing_audio
var state := State.COUNTDOWN
var race_time := 0.0
var medals := [0.0, 0.0, 0.0]   # gold, silver, bronze
var _acc := 0.0
var _count := 3.5
var _intro_t := -1.0          # intro flyover clock (seconds); -1 = none
const INTRO_LEN := 10.0
var _orbit_t := 0.0
var _rain_lens: RainLens
var _cracks: GlassCracks
var _last_count := 4
var _done_t := 0.0
var _reset_cd := 0.0
var _off_track_time := 0.0
var _laps := 0
var _circuit_progress := {}
var _lap_log := {}       # car -> race time at each completed lap
var _joker_state := {}   # car -> {run, prev}
var _joker_hint_t := 0.0
const JOKER_PENALTY := 15.0   # seconds added for finishing without taking the Joker (the lane itself costs about 2-10 s)
var _hud_layer: CanvasLayer
var _clock := 0.0
var _entrants: Array = []
var sim_dt := 0.0        # test mode: fixed simulated frame time
var autopilot := false   # test/screenshot mode: the AI drives the player's car


func setup(stage_i: int, mode_v: int, entrants: Array, attract_v := false, tod := -1, moves := false) -> void:
	stage_index = stage_i
	mode = mode_v
	attract = attract_v
	_entrants = entrants
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(Catalog.stages()[stage_i], tod, moves and not attract_v)
	var tr := stage.track
	_laps = clampi(Game.circuit_laps, 3, 12) if tr.circuit else 0
	var n := entrants.size()
	var player_slot := n - 1 if mode != Game.Mode.TIME_TRIAL else 0
	var order: Array = []
	for e in entrants:
		if not e["player"]:
			order.append(e)
	if not attract:
		order.insert(player_slot, entrants[0])
	for i in order.size():
		var e: Dictionary = order[i]
		var car := Car.new()
		car.driver_name = e["name"]
		car.is_player = bool(e["player"]) and not attract
		add_child(car)
		var cdef: Dictionary = Catalog.cars()[int(e["car"])]
		if bool(e["player"]) and not attract:
			cdef = Catalog.livery(cdef, Game.livery)
		elif e.has("livery") and not attract:
			cdef = Catalog.livery(cdef, int(e["livery"]))
		car.setup(cdef, i + 1, stage, stage.car_material())
		var row := i / 2
		var gap := 12.5 if tr.circuit else 8.0
		var lane := 2.7 if tr.circuit else 2.2
		var lat := 0.0 if n == 1 else (-lane if i % 2 == 0 else lane)
		# Circuit grids are staggered: the left column sits half a row behind the right one.
		var stagger := (gap * 0.5 if (tr.circuit and i % 2 == 0) else 0.0)
		car.place_at(tr.start_s - 5.0 - row * gap - stagger, lat)
		cars.append(car)
		if _laps > 0:
			_circuit_progress[car] = {"completed": 0, "gate": 0, "previous": car.s, "started": false}
			_lap_log[car] = []
			_joker_state[car] = {"run": 0.0, "prev": car.s}
			car.laps_total = _laps
		car.landed.connect(func(v): _on_landed(car, v))
		if car.is_player and not attract:
			car.compressed.connect(Sfx.suspension)
		car.splashed.connect(func(v): _on_splashed(car, v))
		if car.is_player:
			player = car
			car.gear_changed.connect(_on_gear)
		else:
			drivers[car] = AIDriver.new(car, float(e["skill"]) * (1.0 if attract else Game.difficulty_factor()))
	if attract:
		player = cars[0]
	elif autopilot:
		drivers[player] = AIDriver.new(player, 0.95)
	skids = SkidMarks.new()
	add_child(skids)
	var kind := stage.kind()
	skids.setup(Color("#3a2c22") if kind == "dry" else (Color("#2a2420") if kind == "rain" else Color("#7d86a0")))
	camera = ChaseCamera.new()
	add_child(camera)
	camera.target = player
	camera.current = true
	if attract:
		camera.force_view = 0
	if mode == Game.Mode.TIME_TRIAL and not attract and _laps == 0:
		ghost = Ghost.new()
		add_child(ghost)
		ghost.setup(Catalog.record_id(Catalog.stages()[stage_i]), player.stats, stage.track, Game.show_ghost)
	if stage.changing_light() or stage.wx.get("headlights", false):
		# Rival lenses use the stage emissive material. Reserve the mobile
		# renderer's per-object spotlight slots for the driver's lamp array.
		player.enable_lights(int(Settings.g("shadows")) > 0, stage.changing_light() or stage.tod == 2)
		if stage.changing_light():
			player.set_headlight_level(stage.headlight_level)
	camera.follow(0.016)
	var st: Dictionary = player.stats
	var mu := Car.BASE_MU * float(st["grip"]) * stage.grip()
	var ideal := tr.ideal_time(mu * 0.95, player.profile_braking() * 0.85, player.profile_acceleration() * 0.75, player.top_speed())
	medals = [ideal * 1.06, ideal * 1.3, ideal * 1.48]
	if attract:
		for c in cars:
			c.frozen = false
		state = State.RACING
	else:
		_make_hud()
		if ResourceLoader.exists(CO_DRIVER_SCRIPT):
			_voice = load(CO_DRIVER_SCRIPT).new()
			add_child(_voice)
			_voice.setup(tr)
		if ResourceLoader.exists(CROSSING_AUDIO_SCRIPT):
			_crossing_audio = load(CROSSING_AUDIO_SCRIPT).new()
			add_child(_crossing_audio)
			_crossing_audio.setup(tr, player.half_len - 0.78)
		Sfx.engine_start(player.stats["style"])
		# Intro flyover (after the HUD exists): any touch skips it.
		if not Game.no_save and not autopilot and DisplayServer.get_name() != "headless":
			_intro_t = 0.0
			set_overlay_visible(false)
			hud.show_hint_timed("Tap to skip", INTRO_LEN)


## Test helper: start the cars just before the first hazard of a type, countdown skipped.
func skip_to_hazard(type: String) -> void:
	var f: Dictionary = {}
	for bar in stage.track.barriers:
		if bar["kind"] == type:
			skip_to_s(float(bar["s0"]) - 20.0)
			return
	if type == "bridge" and not stage.track.bridges.is_empty():
		skip_to_s(float(stage.track.bridges[0]["s"]) - 70.0)
		return
	for x in stage.track.features:
		if x["type"] == type:
			f = x
			break
	if f.is_empty():
		return
	skip_to_s(float(f["s0"]) - 70.0)


func skip_to_s(s0: float) -> void:
	for i in cars.size():
		cars[i].place_at(s0 - 9.0 * (i / 2) + (0.0 if cars[i] == player else 4.0), (-2.0 if i % 2 == 0 else 2.0) if cars.size() > 1 else 0.0)
		cars[i].vel = cars[i].fwd() * 22.0
		cars[i].frozen = false
	_count = 0.0
	state = State.RACING
	_seek_stage_audio(true)
	camera.snap()


## Show or hide the whole in-race overlay (HUD, touch buttons, camera / pause icons).
func set_overlay_visible(v: bool) -> void:
	if _hud_layer:
		_hud_layer.visible = v
	if touch and not v:
		touch.release_all()
	if not v:
		_stop_stage_audio()


func cycle_camera() -> void:
	var v := (ChaseCamera.VIEWS.size() + camera.view_index() + 1) % ChaseCamera.VIEWS.size()
	Settings.set_value("camera", v)
	Sfx.toggle()
	if hud:
		hud.show_hint_timed(ChaseCamera.view_name(v), 1.2)


func _make_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 1
	add_child(_hud_layer)
	hud = Hud.new()
	_hud_layer.add_child(hud)
	_rain_lens = RainLens.new()
	_rain_lens.visible = false
	_hud_layer.add_child(_rain_lens)
	touch = TouchControls.new()
	_hud_layer.add_child(touch)
	touch.visible = touch.should_show()
	touch.pause_pressed.connect(func(): pause_requested.emit())
	hud.camera_pressed.connect(cycle_camera)
	hud.reset_requested.connect(_reset_player)
	input.touch = touch
	hud.pos_tag.visible = mode != Game.Mode.TIME_TRIAL
	if mode == Game.Mode.TIME_TRIAL:
		var best := Game.best_time(stage_index)
		hud.set_sub("Best %s   Gold %s" % [Game.fmt_time(best), Game.fmt_time(medals[0])])
	else:
		hud.set_sub(Catalog.stage_title(stage_index))
	Sfx.popped.connect(_on_popped)


func _on_popped() -> void:
	if player:
		player.exhaust_puff(0.45)
		player.backfire(1.0)


func _exit_tree() -> void:
	if Sfx.popped.is_connected(_on_popped):
		Sfx.popped.disconnect(_on_popped)
	if not attract:
		Sfx.engine_stop()
		Sfx.set_skid(0.0)
		Haptics.stop()


func _unhandled_input(event: InputEvent) -> void:
	if _intro_t >= 0.0 and (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_end_intro()
		get_viewport().set_input_as_handled()
		return
	if attract or state == State.DONE:
		return
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera"):
		cycle_camera()
	elif event.is_action_pressed("reset_car"):
		_reset_player()


func _reset_player() -> void:
	if state != State.RACING or _reset_cd > 0.0 or get_tree().paused:
		return
	player.reset_to_track()
	_off_track_time = 0.0
	_sync_circuit_station(player)
	_seek_stage_audio()
	_reset_cd = 1.5
	camera.snap()
	hud.show_reset(false)


func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if sim_dt > 0.0:
		dt = sim_dt
	_clock += dt
	if touch:
		touch.visible = touch.should_show() and state != State.DONE
	if hud:
		hud.set_controls_visible(state != State.DONE)
	if not attract and state != State.DONE and not autopilot:
		input.apply(player, dt)
	_update_state(dt)
	_acc += dt
	var steps := 0
	var leaves := stage.leaf_litter
	while _acc >= FIXED and steps < 8:
		_acc -= FIXED
		steps += 1
		for c in cars:
			if drivers.has(c):
				drivers[c].update(FIXED, cars, _clock)
			var previous: Vector2 = c.pos
			c.step(FIXED)
			if c.y < stage.track.terrain.min_h - 10.0 and not c.frozen:
				c.reset_to_track()   # over the cliff or into the river: back on the road
				_sync_circuit_station(c)
				if c == player:
					_off_track_time = 0.0
					_seek_stage_audio()
					Haptics.impulse(0.8, 0.25)
			elif leaves and not c.airborne and not c.in_water and not c.frozen:
				leaves.disturb(previous, c.pos, c.s, c.vel, c.half_wid)
			if _laps > 0 and not c.frozen and not c.finished:
				_update_circuit(c)
				_update_joker(c)
		_collide()
		if state == State.RACING:
			race_time += FIXED
			if not attract:
				_update_recovery(FIXED)
		if _laps > 0:
			_check_finish()
	for c: Car in cars:
		c.render_fraction = clampf(_acc / FIXED, 0.0, 1.0)
	if sim_dt > 0.0 and OS.get_cmdline_user_args().has("--trace") and Engine.get_process_frames() % 10 == 0:
		print("TRACE s=%.1f lat=%.2f v=%.1f y=%.2f air=%s steer=%.2f slip=%.2f h=%.2f" % [player.s, player.lat, player.v_long, player.y, player.airborne, player.steer, player.slip, player.h])
	if skids:
		skids.advance(dt)
		for c in cars:
			var hard: bool = not c.in_water and not c.airborne and absf(c.v_long) > 7.0 and (c.slip > 0.18 or c.handbrake > 0.5 or (c.service_brake > 0.5 and c.v_long > 10.0))
			skids.feed(c, hard)
	if ghost and state == State.RACING:
		ghost.record(race_time, player)
		ghost.update(race_time)
	if not attract and player:
		stage.scenery.scare(player.pos)
		stage.scenery.shake(player.pos, absf(player.v_long), player.global_position.y, stage.wx["kind"] == "snow" or str(stage.def.get("id", "")).begins_with("alpine"), Color(stage.def.get("leaf", "#6f9a4a")))
	if _laps == 0:
		_check_finish()
	if state == State.RACING:
		if _laps > 0:
			_joker_prompt(dt)
		if _voice:
			_voice.call_ahead(player.s, maxf(player.v_long, 0.0))
		if _crossing_audio:
			_crossing_audio.feed(player.s, player.speed(), player.on_road and not player.airborne)
	player.sync_now()
	if _intro_t >= 0.0:
		_intro_camera(dt)
	elif state == State.DONE and not attract and not autopilot and DisplayServer.get_name() != "headless":
		_finish_camera(dt)
	elif hero_s >= 0.0:
		_hero_camera(dt)
	else:
		camera.follow(dt)
	var vi := camera.view_index()
	stage.set_bonnet(ChaseCamera.is_ground_level(vi))
	if _cracks:
		_cracks.visible = ChaseCamera.is_mounted(vi) and _intro_t < 0.0 and player.damage_level() >= 3
		_cracks.set_level(player.damage_level())
	if _rain_lens:
		_rain_lens.visible = stage.kind() == "rain" and ChaseCamera.is_mounted(vi) and _intro_t < 0.0
	if vi != _last_view:
		_last_view = vi
		player.cockpit(vi == ChaseCamera.COCKPIT)
		player.set_low_view(vi == ChaseCamera.LOW)
	var vf: Array = camera.view_focus()
	var lighting_station := clampf(_race_distance(player) / _laps, 0.0, stage.track.length) if _laps > 0 else player.s
	if stage.advance_lighting(lighting_station):
		player.set_headlight_level(stage.headlight_level)
		lighting_changed.emit()
	stage.update(dt, vf[0], float(vf[1]), player.s, camera)
	var threats: Array = []
	for c in cars:
		threats.append(c.position)
	stage.birds.update(dt, threats, vf[0])
	if not attract:
		_feedback(dt)
		_update_hud()
	_reset_cd -= dt


func _end_intro() -> void:
	if _intro_t < 0.0:
		return
	_intro_t = -1.0
	set_overlay_visible(true)
	hud.show_hint("")
	camera.snap()


## Intro flyover: a slow sweep round the start line from high above down to the chase position. Any touch,
## key or button skips it.
func _intro_camera(dt: float) -> void:
	_intro_t += dt
	var k := clampf(_intro_t / INTRO_LEN, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var base := player.global_position
	var heading := player.h
	var ang := heading + PI + lerpf(1.9, 0.0, e)
	var radius := lerpf(26.0, 9.0, e)
	var height := lerpf(16.0, 3.4, e)
	var pos := base + Vector3(sin(ang) * radius, height, cos(ang) * radius)
	camera.global_position = pos
	camera.look_at(base + Vector3(0, 1.0, 0) + Vector3(sin(heading), 0, cos(heading)) * lerpf(12.0, 3.0, e), Vector3.UP)
	camera.fov = lerpf(46.0, 62.0, e)
	if _intro_t >= INTRO_LEN:
		_end_intro()


## --- Cinematic hero mode (confirmation screens): an AI car drives the stage's signature section on a loop while the
## camera cuts between a low pass-by, a high three-quarter view and a swinging chase.
var hero_s := -1.0
var hero_kind := ""
var _hero_t := 0.0
var _hero_loop := 0
var _hero_look := Vector3.ZERO


## The most photogenic spot of a track: a bridge, then a jump, the Joker lane, a splash, a hairpin, else the tightest bend.
static func hero_spot(tr: Track) -> Dictionary:
	var lo := 130.0
	var hi := tr.length - 130.0
	for br: Dictionary in tr.bridges:
		var bs := float(br.get("s", -1.0))
		if bs > lo and bs < hi:
			return {"s": bs, "kind": "bridge"}
	for f: Dictionary in tr.features:
		if str(f.get("type", "")) == "jump":
			var js := float(f.get("s", -1.0))
			if js > lo and js < hi:
				return {"s": js, "kind": "jump"}
	if not tr.joker.is_empty():
		return {"s": (float(tr.joker.s0) + float(tr.joker.s1)) * 0.5, "kind": "joker"}
	for f: Dictionary in tr.features:
		if str(f.get("type", "")) == "splash":
			var ws := float(f.get("s", -1.0))
			if ws > lo and ws < hi:
				return {"s": ws, "kind": "splash"}
	for n: Dictionary in tr.notes:
		if bool(n.get("hairpin", false)) or (str(n.get("kind", "")) == "corner" and int(n.get("sev", 9)) <= 1):
			var ns := (float(n["s0"]) + float(n["s1"])) * 0.5
			if ns > lo and ns < hi:
				return {"s": ns, "kind": "hairpin"}
	var best := lo
	var best_k := -1.0
	var q := lo
	while q < hi:
		var k := float(tr.curv_abs[tr.index_at(q)])
		if k > best_k:
			best_k = k
			best = q
		q += 6.0
	return {"s": best, "kind": "bend"}


func start_hero() -> void:
	var spot := Race.hero_spot(stage.track)
	hero_s = float(spot["s"])
	hero_kind = str(spot["kind"])
	_hero_t = 0.0
	_hero_loop = 0
	_hero_restart()


var _hero_side := 1.0
var _hero_off := 4.2


## True when no solid prop (tree, rock, house) stands within r metres of p.
func _hero_free(p: Vector2, r: float) -> bool:
	if stage.scenery == null:
		return true
	for o in stage.scenery.props_near(p):
		if float(o[2]) > 0.0 and Vector2(float(o[0]), float(o[1])).distance_to(p) < float(o[2]) + r:
			return false
	return true


## Pick the verge side and distance for this loop's low camera so no tree or rock stands in the way.
func _hero_pick_side(_shot: int) -> void:
	_hero_side = 1.0 if (_hero_loop / 3) % 2 == 0 else -1.0


func _hero_restart() -> void:
	_hero_pick_side(_hero_loop % 3)
	var car := player
	car.place_at(hero_s - 105.0, 0.0)
	car.vel = car.fwd() * 17.0
	_hero_t = 0.0
	_hero_look = Vector3(car.pos.x, car.y + 0.8, car.pos.y)


func _hero_camera(dt: float) -> void:
	var tr := stage.track
	var car := player
	_hero_t += dt
	if car.s > hero_s + 60.0 or _hero_t > 16.0 or car.s < hero_s - 140.0:
		_hero_loop += 1
		_hero_restart()
	var hi := tr.index_at(hero_s)
	var hp: Vector2 = tr.point_at(hero_s)
	var nrm: Vector2 = tr.nrm[hi]
	var hw := tr.road_half_width(hero_s)
	var side := _hero_side
	var car_pos := Vector3(car.pos.x, car.y + 0.7, car.pos.y)
	var cam_pos := Vector3.ZERO
	var aim := car_pos
	var fov := 42.0
	# Every shot keeps the camera over the road itself (never beside it), so it cannot end up inside scenery,
	# barrier walls or a bridge's trusses.
	var lane := side * hw * 0.5
	match _hero_loop % 3:
		0:   # Low pass-by: the camera crouches in the lane edge and the car sweeps past.
			var sc := hero_s - 16.0 + _hero_t * 1.4
			var lp := tr.point_at(sc) + tr.nrm[tr.index_at(sc)] * lane
			cam_pos = Vector3(lp.x, tr.surface_height(lp, sc, lane) + 0.95, lp.y)
			fov = 40.0
		1:   # High chase: above and behind, looking along the road at the feature ahead.
			cam_pos = car_pos - car.fwd3() * 12.0 + car.right_axis3() * lane * 0.5 + Vector3(0, 6.5, 0)
			var hero_pt := Vector3(hp.x, tr.surface_height(hp, hero_s, 0.0) + 1.0, hp.y)
			aim = hero_pt if car.s < hero_s - 45.0 else car_pos.lerp(hero_pt, 0.25)
			fov = 52.0
		_:   # Swinging low chase from behind to the side, kept inside the road width.
			var ang := lerpf(0.3, 1.1, clampf(_hero_t / 7.0, 0.0, 1.0)) * side
			var swing := minf(10.0, hw * 0.9 / maxf(absf(sin(ang)), 0.2))
			var back := -car.fwd3() * cos(ang) * swing + car.right_axis3() * sin(ang) * swing
			cam_pos = car_pos + back + Vector3(0, 1.8, 0)
			fov = 52.0
	# Aim a little to the left of the subject so it sits right of centre, clear of the menu on the left.
	var to_aim := aim - cam_pos
	aim -= to_aim.cross(Vector3.UP).normalized() * to_aim.length() * 0.2
	_hero_look = _hero_look.lerp(aim, clampf(dt * 7.0, 0.0, 1.0))
	camera.global_position = cam_pos
	camera.look_at(_hero_look, Vector3.UP)
	camera.fov = lerpf(camera.fov, fov, clampf(dt * 3.0, 0.0, 1.0))


## After the finish the camera swings slowly round the car while the results build.
func _finish_camera(dt: float) -> void:
	_orbit_t += dt
	var base := player.global_position
	var shot := int(_orbit_t / 4.0) % 3
	var u := fposmod(_orbit_t, 4.0) / 4.0
	var fwd := Vector3(sin(player.h), 0.0, cos(player.h))
	var pos: Vector3
	var aim := base + Vector3(0, 0.9, 0)
	match shot:
		0:   # slow orbit
			var ang := player.h + PI + 0.5 + _orbit_t * 0.45
			pos = base + Vector3(sin(ang) * 8.5, 3.2 + sin(_orbit_t * 0.6) * 0.5, cos(ang) * 8.5)
			camera.fov = 52.0
		1:   # low front three-quarter, creeping in
			var right := Vector3(fwd.z, 0.0, -fwd.x)
			pos = base + fwd * lerpf(9.0, 6.0, u) + right * 3.0 + Vector3(0, 0.9, 0)
			camera.fov = 40.0
		_:   # high behind, drifting up
			pos = base - fwd * 12.0 + Vector3(0, lerpf(5.0, 11.0, u), 0)
			camera.fov = 58.0
	camera.global_position = pos
	camera.look_at(aim, Vector3.UP)


func _update_state(dt: float) -> void:
	if _intro_t >= 0.0:
		return
	if state == State.COUNTDOWN:
		_count -= dt
		var c := int(ceil(_count))
		if c != _last_count and c <= 3:
			_last_count = c
			if c > 0:
				hud.show_center(str(c), 0.9, 96)
				Sfx.play("tock", -4.0)
				Haptics.impulse(0.3, 0.06)
		if stage.rx_props:
			stage.rx_props.set_start_lights(clampi(ceili((3.0 - _count) / 3.0 * 5.0), 0, 5))
		if _count <= 0.0:
			if stage.rx_props:
				stage.rx_props.set_start_lights(0)
			state = State.RACING
			for car in cars:
				car.frozen = false
			hud.show_center("GO!", 0.8, 96)
			Sfx.play("go", -2.0)
			Haptics.impulse(0.7, 0.18)
	elif state == State.DONE:
		_done_t += dt
		if _done_t > 5.0 and _done_t - dt <= 5.0:
			finished.emit(_results())


func _check_finish() -> void:
	var tr := stage.track
	if attract and tr.circuit:
		return
	for c in cars:
		if c.finished or c.frozen:
			continue
		var lap_finish: bool = _laps > 0 and _circuit_progress[c].completed >= _laps
		if lap_finish or (_laps == 0 and c.s >= tr.finish_s):
			if attract:
				c.place_at(tr.start_s, 0.0)
				camera.snap()
				continue
			c.finished = true
			c.finish_time = race_time
			if _laps > 0 and stage.rx_props and (c == player or not _celebrated):
				_celebrated = true
				stage.rx_props.celebrate()
			if _laps > 0 and not stage.track.joker.is_empty() and not c.joker_taken:
				c.joker_penalty = JOKER_PENALTY
				c.finish_time += JOKER_PENALTY
				if c == player:
					hud.show_hint_timed("+%d s: Joker lane not taken" % int(JOKER_PENALTY), 3.0)
			if not drivers.has(c) or c == player:
				drivers[c] = AIDriver.new(c, 0.7)
			if _laps == 0:
				var slot: Array = Stage.parc_bay(tr.length, _bays_used)
				_bays_used += 1
				drivers[c].stop_at_s = slot[0]
				drivers[c].park_lat = slot[1]
			if c == player:
				state = State.DONE
				_stop_stage_audio()
				_done_t = 0.0
				Haptics.pattern_finish()
				if ghost:
					var best := Game.best_time(stage_index)
					if best < 0.0 or race_time < best:
						ghost.save(Catalog.record_id(Catalog.stages()[stage_index]))
				hud.show_center("FINISH", 2.6, 84)
				Sfx.play("finish", -6.0)


func _sync_circuit_station(car: Car) -> void:
	if _laps > 0:
		_circuit_progress[car].previous = car.s


func _update_recovery(delta: float) -> void:
	_off_track_time = 0.0 if player.on_road else _off_track_time + delta
	if _off_track_time >= RECOVERY_LIMIT:
		_reset_player()


func _update_circuit(car: Car) -> void:
	var tr := stage.track
	var progress: Dictionary = _circuit_progress[car]
	var previous: float = progress.previous
	progress.previous = car.s
	var advance := fposmod(car.s - previous, tr.length)
	# Count a gate when the car is on, or just beside, the road (a bridge deck or kerb must not hide the crossing).
	var beside := absf(car.lat) <= tr.road_extent(car.s) + 5.0
	if not (car.on_road or beside) or advance <= 0.0 or advance > 8.0 or car.vel.dot(tr.tang[car.track_i]) <= 0.0:
		return
	var checkpoint := float(progress.gate) * tr.length * 0.25
	var to_gate := fposmod(checkpoint - fposmod(previous, tr.length), tr.length)
	if to_gate > advance:
		return
	if car == player and progress.started:
		_split_delta(int(progress.gate))
	if progress.gate == 0:
		if progress.started:
			progress.completed += 1
			car.lap = int(progress.completed)
			_lap_log[car].append(race_time)
		progress.started = true
		if car == player:
			_lap_start = race_time
		if car == player:
			_seek_stage_audio(true)
	progress.gate = (int(progress.gate) + 1) % 4


var _lap_start := 0.0
var _splits_best := [0.0, 0.0, 0.0, 0.0]
var _splits_now := [0.0, 0.0, 0.0, 0.0]
var _best_lap := INF


## A quarter-lap checkpoint was crossed: show how far ahead or behind the best lap so far we are.
func _split_delta(gate: int) -> void:
	var t := race_time - _lap_start
	var idx := (gate + 3) % 4          # gate 1 closes quarter 1 ... gate 0 closes the lap
	_splits_now[idx] = t
	var best: float = _splits_best[idx]
	if best > 0.0 and hud:
		var d := t - best
		hud.show_hint_timed("%s%.2f s  vs best lap" % ["+" if d >= 0.0 else "-", absf(d)], 2.4)
	if idx == 3:
		if t < _best_lap:
			_best_lap = t
			_splits_best = _splits_now.duplicate()


## Joker lane: counts the distance driven inside the lane; half of it counts as taken.
func _update_joker(c: Car) -> void:
	var tr := stage.track
	if tr.joker.is_empty() or c.joker_taken:
		return
	var st: Dictionary = _joker_state[c]
	var advance := fposmod(c.s - float(st.prev), tr.length)
	st.prev = c.s
	# Credit the distance the car actually drives, not the change in its projected station: on the inside of a tight
	# bend (Funnel Ring, Harbor Grid, Bauxite) the station crawls forward and the lane was never counted as taken.
	var travelled: float = c.pos.distance_to(st.get("pp", c.pos))
	st["pp"] = c.pos
	var band := tr.joker_band(c.s)
	if OS.get_cmdline_user_args().has("--jokerdbg") and c == player and c.s > float(tr.joker.s0) - 20.0 and c.s < float(tr.joker.s1) + 20.0 and Engine.get_process_frames() % 20 == 0:
		print("JD lap=%d s=%.1f lat=%.2f band=[%.2f,%.2f] adv=%.2f run=%.1f need=%.1f" % [c.lap, c.s, c.lat, band.x, band.y, advance, float(st.run), 0.5 * (float(tr.joker.s1) - float(tr.joker.s0))])
	if not is_nan(band.x) and c.lat >= band.x and c.lat <= band.y and advance < 8.0 and travelled < 8.0:
		st.run += maxf(advance, travelled)
	elif c.s < tr.joker.s0 or c.s > tr.joker.s1:
		st.run = 0.0
	if float(st.run) >= 0.5 * (float(tr.joker.s1) - float(tr.joker.s0)):
		c.joker_taken = true
		if c == player and not attract:
			hud.show_hint_timed("JOKER LAP TAKEN", 2.2)


## Prompt the player to use the Joker lane while they still owe it.
func _joker_prompt(dt: float) -> void:
	var tr := stage.track
	if attract or tr.joker.is_empty() or player.joker_taken or state != State.RACING:
		return
	_joker_hint_t -= dt
	var ahead := fposmod(float(tr.joker.s0) - player.s, tr.length)
	if _joker_hint_t <= 0.0 and ahead < 130.0 and ahead > 20.0:
		_joker_hint_t = 6.0
		hud.show_hint_timed("JOKER LANE REQUIRED - LAST CHANCE" if player.lap + 1 >= _laps else "JOKER LANE AHEAD", 2.6)


func _race_time_for_bench() -> float:
	return race_time


func _race_distance(car: Car) -> float:
	var tr := stage.track
	if _laps == 0:
		return car.s - tr.start_s
	var progress: Dictionary = _circuit_progress[car]
	if not progress.started:
		return wrapf(car.s, -tr.length * 0.5, tr.length * 0.5)
	var gate: int = progress.gate
	var sector_limit := tr.length * (1.0 if gate == 0 else gate * 0.25)
	var station := car.s
	if gate == 1 and station > tr.length * 0.9:
		station -= tr.length
	return float(progress.completed) * tr.length + minf(station, sector_limit)


## Collisions use each car's oriented box (its real paper body), not a circle: props are circles,
## car-vs-car uses the separating-axis test, and impulses act at the contact point so a clipped
## corner also nudges the car's yaw.
const INERTIA := 1.6
const RESTITUTION := 0.15
const MAX_IMPULSE := 9.0        # m/s of speed change per contact
const MAX_YAW_KICK := 1.2       # rad/s of spin added per contact


func _corner_support(c: Car, n: Vector2) -> Vector2:
	var f := c.fwd()
	var r := c.right_axis()
	return c.pos + r * (c.half_wid * signf(r.dot(n))) + f * (c.half_len * signf(f.dot(n)))


func _apply_contact(c: Car, n: Vector2, cp: Vector2, other_vel: Vector2, other: Car) -> float:
	var rc := cp - c.pos
	var perp_a := Vector2(rc.y, -rc.x)
	var va := c.vel + perp_a * c.yaw_rate
	var vb := other_vel
	var cb := 0.0
	var perp_b := Vector2.ZERO
	if other:
		var rb := cp - other.pos
		perp_b = Vector2(rb.y, -rb.x)
		vb = other.vel + perp_b * other.yaw_rate
		cb = perp_b.dot(n)
	var vn := (va - vb).dot(n)
	if vn >= 0.0:
		return 0.0
	var ca := perp_a.dot(n)
	var denom := 1.0 + ca * ca / INERTIA
	if other:
		denom += 1.0 + cb * cb / INERTIA
	# Leaning on something must not bounce: restitution and spin only for real hits.
	var bounce := RESTITUTION if -vn > 2.5 else 0.0
	var j := minf(-(1.0 + bounce) * vn / denom, MAX_IMPULSE)
	var pre_a := c.vel.length()
	var pre_b := other.vel.length() if other else 0.0
	c.vel += n * j
	c.yaw_rate = clampf(c.yaw_rate + clampf(j * ca / INERTIA * 0.6, -MAX_YAW_KICK, MAX_YAW_KICK) * clampf(-vn / 2.0, 0.0, 1.0), -2.5, 2.5)
	# Tangential scrub at the contact.
	var t := Vector2(-n.y, n.x)
	# Gentle contact (leaning on a wall) must not stall the car: scrub scales with how hard the hit was.
	c.vel -= t * (c.vel - vb).dot(t) * 0.12 * clampf((-vn - 0.6) / 3.0, 0.0, 1.0)
	# A hit never leaves a car faster than it was going (or than the other car was going).
	c.vel = c.vel.limit_length(maxf(pre_a, pre_b * 0.6))
	if other:
		other.vel -= n * j
		other.yaw_rate = clampf(other.yaw_rate - clampf(j * cb / INERTIA * 0.6, -MAX_YAW_KICK, MAX_YAW_KICK), -2.5, 2.5)
		other.vel = other.vel.limit_length(maxf(pre_b, pre_a * 0.6))
	return -vn


## Speed kept after smashing through a breakable prop.
const BREAK_KEEP := {"bale": 0.58, "snowbank": 0.72, "crates": 0.82, "tent": 0.85, "cactus": 0.9, "logs": 0.7}


func _collide() -> void:
	for tc in _tyre_cool.keys():
		_tyre_cool[tc] = float(_tyre_cool[tc]) - FIXED
	if stage.rx_props:
		for c in cars:
			var knocked: int = stage.rx_props.knock_cones(c)
			if knocked > 0:
				c.vel *= pow(0.985, knocked)
				if c == player:
					Sfx.impact(0.2, true)
					Haptics.impulse(0.15, 0.05)
	for c in cars:
		if stage.track.on_stacked_span(c.s) and c.y > stage.track.terrain.height(c.pos) + 2.0:
			continue
		var f := c.fwd()
		var r := c.right_axis()
		for o in stage.scenery.props_near(c.pos):
			var op := Vector2(o[0], o[1])
			var rad := absf(float(o[2]))
			if o[4]:
				# Small props break instead of stopping the car.
				var dd := op - c.pos
				if absf(dd.dot(r)) < c.half_wid + rad and absf(dd.dot(f)) < c.half_len + rad and not c.airborne:
					stage.scenery.break_piece(int(o[3]), c.vel)
					# Heavy props (a tight hay bale weighs a few hundred kilos) cost real speed.
					var keep: float = BREAK_KEEP.get(o[5] if o.size() > 5 else "", 0.97)
					c.vel *= keep
					c.yaw_rate += randf_range(-0.4, 0.4) * (1.0 - keep)
					if keep < 0.8 and c == player:
						camera.kick(0.35)
					_debris(Vector3(op.x, c.y + 0.5, op.y), 8.0)
					if c == player:
						Haptics.impulse(0.25 + (1.0 - keep) * 1.2, 0.06 + (1.0 - keep) * 0.2)
						Sfx.impact(0.25 + (1.0 - keep), true)
				continue
			var d := op - c.pos
			var lx := clampf(d.dot(r), -c.half_wid, c.half_wid)
			var lz := clampf(d.dot(f), -c.half_len, c.half_len)
			var closest := c.pos + r * lx + f * lz
			var sep := op - closest
			var dl := sep.length()
			var n: Vector2
			var pen: float
			if dl > 0.0001:
				if dl >= rad:
					continue
				n = -sep / dl
				pen = rad - dl
			else:
				# Prop centre inside the body: push out along the shallower axis.
				var px := c.half_wid - absf(d.dot(r))
				var pz := c.half_len - absf(d.dot(f))
				n = -r * signf(d.dot(r)) if px < pz else -f * signf(d.dot(f))
				pen = minf(px, pz) + rad
			c.pos += n * pen
			var hit := _apply_contact(c, n, closest, Vector2.ZERO, null)
			_on_impact(c, hit, closest, true)
	# Armco and fences are walls along the road edge.
	for c in cars:
		var side := signf(c.lat)
		if side == 0.0:
			continue
		for bar in stage.track.barriers_at(c.s, side):
			var wn: Vector2 = stage.track.nrm[c.track_i] * side          # points out of the road
			var ext := c.half_wid * absf(c.right_axis().dot(wn)) + c.half_len * absf(c.fwd().dot(wn))
			var wall: float = stage.track.barrier_wall(bar, c.s)
			var offset := absf(c.lat) - wall
			var pen := ext - absf(offset)
			var pull_in := false
			if offset > 0.0:
				wn = -wn
				# Past an outer wall by more than the car's half-size: it has slipped through (a fast hit, or a
				# wall sweeping inward at a lane exit). Outer walls have nothing legitimate behind them, so
				# bring the car back inside. (The island's walls do have a lane behind them, so they are exempt.)
				var ref := str(bar.get("ref", ""))
				if offset < 14.0 and (ref == "lane_out" or (ref == "road" and str(bar.kind) != "island")):
					pen = ext + offset
					pull_in = true
			if pen > 4.0 and OS.get_cmdline_user_args().has("--rxwall"):
				print("  BIGPEN pen=%.1f ext=%.2f offset=%.2f lat=%.2f wall=%.2f ref=%s s=%.1f" % [pen, ext, offset, c.lat, wall, str(bar.get("ref", "")), c.s])
			if pen > 0.0:
				# wn points inward when the car is beyond the wall: an outer wall pulls it back in, an island wall
				# keeps whichever side it is on.
				var push := wn if pull_in else -wn
				c.pos += push * pen
				var cp := _corner_support(c, -push)
				var v_before := c.vel.length()
				var hit := _apply_contact(c, push, cp, Vector2.ZERO, null)
				if OS.get_cmdline_user_args().has("--rxgrind") and v_before - c.vel.length() > 0.4:
					print("  WALLHIT v %.1f -> %.1f vn=%.2f pen=%.2f ext=%.2f wall=%.2f lat=%.2f" % [v_before, c.vel.length(), hit, pen, ext, wall, c.lat])
				c.vel *= 1.0 - 0.012 * clampf(hit / 6.0, 0.0, 1.0)   # only real impacts cost speed; scraping along does not
				_on_impact(c, hit, cp)
				if hit > 1.5 and str(bar.kind) in ["armco", "jersey", "fence"]:
					c.spark(Vector3(cp.x, c.y + 0.35, cp.y), Vector3(-push.x, 0.0, -push.y))
				if str(bar.kind) == "tyre" and stage.rx_props and hit > 4.0 and float(_tyre_cool.get(c, 0.0)) <= 0.0:
					_tyre_cool[c] = 0.5
					stage.rx_props.knock_tyres(cp, push, hit, c.y)
				# A car pinned against the wall at low speed is eased away from it, so it can always drive off.
				if c.vel.length() < 3.0:
					_wall_time[c] = float(_wall_time.get(c, 0.0)) + FIXED
					if float(_wall_time[c]) > 0.35:
						c.vel += push * 3.0 * FIXED
						c.yaw_rate *= 0.9
				else:
					_wall_time[c] = 0.0
			elif _wall_time.has(c):
				_wall_time[c] = maxf(0.0, float(_wall_time[c]) - FIXED * 2.0)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a := cars[i]
			var b := cars[j]
			if absf(a.y-b.y) > 2.0 or (_laps > 0 and (a.finished or b.finished)):
				continue
			if mode == Game.Mode.RACE and not Game.ai_contact and not attract and (a == player or b == player):
				continue
			var d := a.pos - b.pos
			if d.length_squared() > 30.0:
				continue
			var axes := [a.fwd(), a.right_axis(), b.fwd(), b.right_axis()]
			var best := INF
			var bn := Vector2.ZERO
			var sep_found := false
			for ax in axes:
				var ra := a.half_wid * absf(a.right_axis().dot(ax)) + a.half_len * absf(a.fwd().dot(ax))
				var rb := b.half_wid * absf(b.right_axis().dot(ax)) + b.half_len * absf(b.fwd().dot(ax))
				var ov: float = ra + rb - absf(d.dot(ax))
				if ov <= 0.0:
					sep_found = true
					break
				if ov < best:
					best = ov
					bn = ax if d.dot(ax) >= 0.0 else -ax
			if sep_found:
				continue
			a.pos += bn * best * 0.5
			b.pos -= bn * best * 0.5
			# Contact point: midway between the two bodies' deepest corners along the normal.
			var cp := (_corner_support(a, -bn) + _corner_support(b, bn)) * 0.5
			var hit := _apply_contact(a, bn, cp, Vector2.ZERO, b)
			_on_impact(a, hit, cp)
			_on_impact(b, hit, cp)


func _on_impact(c: Car, strength: float, at: Vector2 = Vector2.INF, paper := false) -> void:
	if strength < 1.5:
		return
	if OS.get_cmdline_user_args().has("--rxdebug") and c == player:
		var near := ""
		for o in stage.scenery.props_near(c.pos):
			near += " %s@%.1f,%.1f r=%.1f" % [str(o[5]) if o.size() > 5 else "?", Vector2(o[0], o[1]).distance_to(c.pos), o[2], float(o[2])]
		print("IMPACT s=%.0f lat=%.1f str=%.1f paper=%s props:%s" % [c.s, c.lat, strength, paper, near])
	if at != Vector2.INF and strength > 2.5:
		_debris(Vector3(at.x, c.y + 0.6, at.y), strength)
	if at != Vector2.INF and strength > 4.0:
		c.add_damage(at, strength)
	if c != player or attract:
		return
	var k := clampf(strength / 14.0, 0.15, 1.0)
	Haptics.impulse(k, 0.08 + k * 0.12)
	Sfx.impact(k, paper)
	camera.kick(k)


var _cheered := {}
var _celebrated := false
var _tyre_cool := {}   # car -> seconds before it can knock more tyres off a wall
var _wall_time := {}   # car -> seconds pinned against a wall at low speed
var ghost: Ghost
var skids: SkidMarks
var _last_view := -1
var _bays_used := 0
var _debris_pool: Array[CPUParticles3D] = []
var _debris_i := 0


## Paper scraps burst from the exact point where bodywork touches.
func _debris(p: Vector3, strength: float) -> void:
	if _debris_pool.is_empty():
		for k in 4:
			var cp := CPUParticles3D.new()
			cp.one_shot = true
			cp.emitting = false
			cp.amount = 14
			cp.lifetime = 0.8
			cp.explosiveness = 0.95
			cp.direction = Vector3.UP
			cp.spread = 70.0
			cp.initial_velocity_min = 2.5
			cp.initial_velocity_max = 6.0
			cp.gravity = Vector3(0, -14, 0)
			cp.angular_velocity_min = -400.0
			cp.angular_velocity_max = 400.0
			var qm := QuadMesh.new()
			qm.size = Vector2(0.22, 0.16)
			var m := StandardMaterial3D.new()
			m.albedo_color = PaperKit.CREAM
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 1.0
			qm.material = m
			cp.mesh = qm
			cp.local_coords = false
			add_child(cp)
			_debris_pool.append(cp)
	var e := _debris_pool[_debris_i]
	_debris_i = (_debris_i + 1) % _debris_pool.size()
	e.global_position = p
	e.amount = clampi(int(strength * 1.5), 6, 24)
	e.restart()


func _on_landed(c: Car, v: float) -> void:
	if sim_dt > 0.0 and c == player:
		print("TEST landed v=%.1f air=%.2fs speed=%.1f flight~%.0fm" % [v, c.air_time, c.speed(), c.speed() * c.air_time])
	if c != player or attract:
		return
	var k := clampf(v / 12.0, 0.2, 1.0)
	Haptics.impulse(k, 0.1 + k * 0.15)
	Sfx.land(k)
	camera.kick(k * 0.8)


func _on_splashed(c: Car, v: float) -> void:
	c.spray(v)
	if c != player or attract:
		return
	Sfx.splash(true, clampf(v / 25.0, 0.3, 1.0))
	Haptics.impulse(clampf(v / 25.0, 0.3, 0.9), 0.25)
	camera.kick(0.4)


func _on_gear(gear: int, previous: int) -> void:
	if camera:
		camera.gear_kick()
	Haptics.impulse(0.18, 0.035)
	Sfx.engine_shift(gear > previous and previous > 0)


func _feedback(dt: float) -> void:
	var p := player
	var sp := absf(p.v_long)
	var sf := clampf(sp / 25.0, 0.0, 1.0)
	var weak := 0.0
	var strong := 0.0
	var kind := stage.kind()
	if p.on_road:
		weak = sf * (0.12 if kind == "dry" else (0.08 if kind == "rain" else 0.05))
	else:
		weak = 0.2 + sf * 0.25
		strong = sf * 0.45
	strong = maxf(strong, p.slip * sf * 0.6)
	if p.handbrake > 0.0 and sp > 5.0:
		strong = maxf(strong, 0.3)
	Haptics.rumble(weak, strong)
	Sfx.set_engine(p.acoustic_rpm, p.throttle if not p.frozen or state == State.COUNTDOWN else 0.0,
		_last_view == ChaseCamera.COCKPIT, _voice != null and _voice.playing)
	var surf := "cobble" if stage.def.loc_id == "harbour" else kind
	var loose := 0.0
	var supported := 0.0
	for i in p.wheel_surface.size():
		var contact := float(p.wheel_load[i])
		var surface := p.wheel_surface[i]
		supported += contact
		if surface == "gravel" or (surface == "verge" and kind != "snow") or (surface == "road" and surf == "dry"):
			loose += contact
		elif surface == "mud":
			loose += contact * 0.42
	var loose_fraction := loose / maxf(supported, 0.001)
	var grounded_speed := 0.0 if p.airborne or p.in_water else p.speed()
	var sideways := smoothstep(0.06, 0.44, p.slip)
	var locked := maxf(p.handbrake * 0.74, smoothstep(0.72, 1.0, p.service_brake) * 0.50)
	var scrub := maxf(sideways, locked) * smoothstep(2.0, 13.0, grounded_speed)
	Sfx.set_skid(scrub, surf)
	Sfx.set_surface(surf, grounded_speed, loose_fraction, p.slip)
	# The crowd cheers as you fly past them at jumps and splashes.
	for f in stage.track.features:
		if f["type"] in ["jump", "splash"] and absf(p.s - float(f["s"]) - 6.0) < 1.5 and sp > 8.0 and not _cheered.has(f["s"]):
			_cheered[f["s"]] = true
			Sfx.cheer()
			stage.cheer_crowd()
	# Puddles: a splash, a jolt and a little drag.
	var in_p := false
	for pd in stage.scenery.puddles:
		if p.pos.distance_to(pd[0]) < float(pd[1]):
			in_p = true
			break
	if in_p and not p.in_puddle and sp > 4.0:
		Sfx.splash(false, clampf(sp / 20.0, 0.3, 1.0))
		Haptics.impulse(0.35 + sf * 0.3, 0.12)
	p.in_puddle = in_p


func _positions() -> Array:
	var arr := cars.duplicate()
	arr.sort_custom(func(a, b):
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return _race_distance(a) > _race_distance(b))
	return arr


## Bug-report panel (Settings > Graphics > Debug panel): everything needed to place a screenshot.
func _debug_text() -> String:
	var tr := stage.track
	var st: Dictionary = Catalog.stages()[stage_index]
	var span := tr.length if tr.rx else (tr.finish_s - tr.start_s)
	var along := fposmod(player.s - tr.start_s, tr.length) if tr.rx else clampf(player.s - tr.start_s, 0.0, span)
	var frac := clampf(along / maxf(span, 1.0), 0.0, 0.9999)
	var sector := int(frac * 3.0) + 1
	var sector_m := along - (sector - 1) * span / 3.0
	var chapter := ""
	if not tr.chapters.is_empty():
		chapter = "  chapter %d" % (mini(int(frac * tr.chapters.size()), tr.chapters.size() - 1) + 1)
	var lat_state := "on road"
	if not player.on_road:
		lat_state = "OFF ROAD"
	var lane := ""
	if tr.rx and not tr.joker.is_empty():
		lane = "  joker %s" % ("DONE" if player.joker_taken else "todo")
	var weather := "%s / %s" % [kind_label(), ["Day", "Dusk", "Night"][clampi(stage.tod, 0, 2)]]
	var lines := PackedStringArray([
		"CAR   %s (#%d) %s  %s" % [player.stats.get("name", "?"), player.number, player.stats.get("style", "?"), player.stats.get("class", "")],
		"TRACK %s  [%s, stage %d, seed %d]" % [Catalog.stage_title(stage_index), st.get("loc_id", "?"), stage_index, int(st.get("seed", 0))],
		"SECT  %d/3  (%.0f m into sector)  %.0f / %.0f m  %.0f%%%s%s" % [sector, sector_m, along, span, frac * 100.0, chapter, lane],
		"LAP   %d  station s=%.1f  idx=%d  lat=%.2f" % [player.lap + 1, player.s, player.track_i, player.lat],
		"SURF  %s  grip=%.2f  %s%s%s" % [player.patch_kind if player.patch_kind != "" else "base", player.surface, lat_state, "  PUDDLE" if player.in_puddle else "", "  WATER" if player.in_water else ""],
		"POS   x=%.1f z=%.1f  y=%.2f  vy=%.1f  %s" % [player.pos.x, player.pos.y, player.y, player.vy, "AIR %.1fs" % player.air_time if player.airborne else "grounded"],
		"MOVE  %.0f km/h  gear %d  rpm %d  slip %.2f  thr %.2f brk %.2f st %.2f" % [player.speed() * 3.6, player.gear, int(player.rpm), player.slip, player.throttle, player.brake, player.steer],
		"WORLD %s  mode %d  state %d  t=%.1fs  %d fps" % [weather, int(mode), int(state), race_time, Engine.get_frames_per_second()],
	])
	return "\n".join(lines)


func kind_label() -> String:
	return String(stage.kind()).capitalize()


func _update_hud() -> void:
	hud.set_debug(_debug_text() if bool(Settings.g("debug_hud")) else "")
	hud.set_time(race_time if state != State.DONE else player.finish_time)
	hud.set_speed(player.speed(), player.gear)
	hud.pace.set_note(stage.track.next_note(player.s, 70.0), player.s)
	var tr := stage.track
	var marks: Array = []
	for c in cars:
		var col: Color = c.stats["body"]
		var total := tr.length * _laps if _laps > 0 else tr.finish_s - tr.start_s
		marks.append([1.0 if c.finished else clampf(_race_distance(c) / total, 0.0, 1.0), col, c == player])
	hud.strip.marks = marks
	hud.strip.queue_redraw()
	if mode != Game.Mode.TIME_TRIAL:
		var pos := _positions().find(player) + 1
		var lap := mini(int(_circuit_progress[player].completed) + 1, _laps) if _laps > 0 else 0
		var lap_text := "  ·  Lap %d/%d" % [lap, _laps] if _laps > 0 else ""
		hud.set_position_text("P%d/%d%s" % [pos, cars.size(), lap_text])
	hud.set_joker(not tr.joker.is_empty() and not attract, player.joker_taken, player.lap + 1 >= _laps)
	stage.set_lap_wear(player.lap + 1)
	var wrong := player.vel.length() > 3.0 and player.vel.normalized().dot(tr.tang[player.track_i]) < -0.4
	var lost := _off_track_time >= RECOVERY_WARNING and state == State.RACING
	var seconds := maxi(1, ceili(RECOVERY_LIMIT - _off_track_time))
	hud.show_reset(lost and touch.visible, seconds)
	if lost and touch.visible:
		hud.show_hint("")
	elif lost:
		hud.show_hint("Return to track in %ds  ·  Y / R to reset now" % seconds)
	elif wrong:
		hud.show_hint("WRONG WAY")
	else:
		hud.show_hint("")


func _results() -> Dictionary:
	var tr := stage.track
	var rows: Array = []
	for c in _positions():
		var t: float = c.finish_time
		if not c.finished:
			# Estimate the remaining time from the car's average pace so far.
			var distance := _race_distance(c)
			var total := tr.length * _laps if _laps > 0 else tr.finish_s - tr.start_s
			var avg := maxf(distance / maxf(race_time, 1.0), 8.0)
			t = race_time + (total - distance) / avg
		rows.append({"name": c.driver_name, "time": t, "car": Catalog.cars().map(func(x): return x["id"]).find(c.stats["id"]), "player": c == player})
	rows.sort_custom(func(a, b): return a["time"] < b["time"])
	var medal := 3
	for i in 3:
		if player.finish_time <= medals[i]:
			medal = i
			break
	return {"rows": rows, "player_time": player.finish_time, "medal": medal, "medals": medals, "stage": stage_index}


func resume_input() -> void:
	if touch:
		touch.release_all()


## Re-aim the stage audio after the car moves. A respawn never interrupts or repeats a call; only
## crossing the line on a new lap makes every note speakable again.
func _seek_stage_audio(new_lap := false) -> void:
	if _voice:
		_voice.seek_course(player.s, new_lap)
	if _crossing_audio:
		_crossing_audio.seek_course(player.s)


func _stop_stage_audio() -> void:
	if _voice:
		_voice.stop_calls()
	if _crossing_audio:
		_crossing_audio.stop()
