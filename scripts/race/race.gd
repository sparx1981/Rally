class_name Race
extends Node3D
## Runs one stage: countdown, fixed-step physics for all cars, collisions, timing, positions,
## haptics, engine audio, HUD and the pop-up scenery driven by the player's progress.
## In attract mode (title screen) an AI drives and the stage loops.

signal finished(result: Dictionary)
signal pause_requested

enum State { COUNTDOWN, RACING, DONE }

const FIXED := 1.0 / 120.0

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
var state := State.COUNTDOWN
var race_time := 0.0
var medals := [0.0, 0.0, 0.0]   # gold, silver, bronze
var _acc := 0.0
var _count := 3.5
var _last_count := 4
var _done_t := 0.0
var _reset_cd := 0.0
var _hud_layer: CanvasLayer
var _clock := 0.0
var _entrants: Array = []
var sim_dt := 0.0        # test mode: fixed simulated frame time
var autopilot := false   # test/screenshot mode: the AI drives the player's car


func setup(stage_i: int, mode_v: int, entrants: Array, attract_v := false) -> void:
	stage_index = stage_i
	mode = mode_v
	attract = attract_v
	_entrants = entrants
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(Catalog.stages()[stage_i])
	var tr := stage.track
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
		car.setup(Catalog.cars()[int(e["car"])], i + 1, stage, stage.paper_mat)
		var row := i / 2
		var lat := 0.0 if n == 1 else (-2.2 if i % 2 == 0 else 2.2)
		car.place_at(tr.start_s - 5.0 - row * 8.0, lat)
		cars.append(car)
		if car.is_player:
			player = car
			car.gear_changed.connect(_on_gear)
		else:
			drivers[car] = AIDriver.new(car, float(e["skill"]) * (1.0 if attract else Game.difficulty_factor()))
	if attract:
		player = cars[0]
	elif autopilot:
		drivers[player] = AIDriver.new(player, 0.95)
	camera = ChaseCamera.new()
	add_child(camera)
	camera.target = player
	camera.current = true
	camera.follow(0.016)
	var st: Dictionary = player.stats
	var mu := Car.BASE_MU * float(st["grip"]) * stage.grip()
	var ideal := tr.ideal_time(mu * 0.95, Car.BRAKE * stage.grip() * 0.85, Car.BASE_ACC * float(st["accel"]) * 0.75, player.top_speed())
	medals = [ideal * 1.12, ideal * 1.24, ideal * 1.38]
	if attract:
		for c in cars:
			c.frozen = false
		state = State.RACING
		stage.scenery.raise_all()
	else:
		_make_hud()
		Sfx.engine_start()


func _make_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 1
	add_child(_hud_layer)
	hud = Hud.new()
	_hud_layer.add_child(hud)
	touch = TouchControls.new()
	_hud_layer.add_child(touch)
	touch.visible = touch.should_show()
	touch.pause_pressed.connect(func(): pause_requested.emit())
	input.touch = touch
	hud.pos_tag.visible = mode != Game.Mode.TIME_TRIAL
	if mode == Game.Mode.TIME_TRIAL:
		var best := Game.best_time(stage_index)
		hud.set_sub("Best %s   Gold %s" % [Game.fmt_time(best), Game.fmt_time(medals[0])])
	else:
		hud.set_sub(Catalog.stages()[stage_index]["name"])


func _exit_tree() -> void:
	if not attract:
		Sfx.engine_stop()
		Sfx.set_skid(0.0)
		Haptics.stop()


func _unhandled_input(event: InputEvent) -> void:
	if attract:
		return
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera"):
		camera.view = 1 - camera.view
	elif event.is_action_pressed("reset_car") and state == State.RACING and _reset_cd <= 0.0:
		player.reset_to_track()
		_reset_cd = 1.5
		camera.snap()


func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if sim_dt > 0.0:
		dt = sim_dt
	_clock += dt
	if touch:
		touch.visible = touch.should_show()
	if not attract and state != State.DONE and not autopilot:
		input.apply(player, dt)
	_update_state(dt)
	_acc += dt
	var steps := 0
	while _acc >= FIXED and steps < 8:
		_acc -= FIXED
		steps += 1
		for c in cars:
			if drivers.has(c):
				drivers[c].update(FIXED, cars, _clock)
			c.step(FIXED)
		_collide()
		if state == State.RACING:
			race_time += FIXED
	_check_finish()
	camera.follow(dt)
	stage.update(dt, player.position + Vector3(sin(player.h), 0, cos(player.h)) * 10.0, player.s, camera)
	if not attract:
		_feedback(dt)
		_update_hud()
	_reset_cd -= dt


func _update_state(dt: float) -> void:
	if state == State.COUNTDOWN:
		_count -= dt
		var c := int(ceil(_count))
		if c != _last_count and c <= 3:
			_last_count = c
			if c > 0:
				hud.show_center(str(c), 0.9, 96)
				Sfx.play("tock", -4.0)
				Haptics.impulse(0.3, 0.06)
		if _count <= 0.0:
			state = State.RACING
			for car in cars:
				car.frozen = false
			hud.show_center("GO!", 0.8, 96)
			Sfx.play("go", -2.0)
			Haptics.impulse(0.7, 0.18)
	elif state == State.DONE:
		_done_t += dt
		if _done_t > 2.8 and _done_t - dt <= 2.8:
			finished.emit(_results())


func _check_finish() -> void:
	var tr := stage.track
	for c in cars:
		if c.finished or c.frozen:
			continue
		if c.s >= tr.finish_s:
			if attract:
				c.place_at(tr.start_s, 0.0)
				camera.snap()
				continue
			c.finished = true
			c.finish_time = race_time
			if c == player:
				state = State.DONE
				_done_t = 0.0
				drivers[player] = AIDriver.new(player, 0.7)   # coast it through the finish
				Haptics.pattern_finish()
				hud.show_center("FINISH", 2.6, 84)
				Sfx.play("go", -2.0, 0.8)


func _collide() -> void:
	for c in cars:
		for o in stage.scenery.solids_near(c.pos):
			var op := Vector2(o[0], o[1])
			var d := c.pos - op
			var min_d := Car.RADIUS + float(o[2])
			var dl := d.length()
			if dl < min_d and dl > 0.001:
				var nrm := d / dl
				c.pos = op + nrm * min_d
				var vn := c.vel.dot(nrm)
				if vn < 0.0:
					c.vel -= nrm * vn * 1.35
					c.vel *= 0.82
					_on_impact(c, -vn)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a := cars[i]
			var b := cars[j]
			var d := a.pos - b.pos
			var dl := d.length()
			var min_d := Car.RADIUS * 1.7
			if dl < min_d and dl > 0.001:
				var nrm := d / dl
				var push := (min_d - dl) * 0.5
				a.pos += nrm * push
				b.pos -= nrm * push
				var rel := (a.vel - b.vel).dot(nrm)
				if rel < 0.0:
					var imp := nrm * rel * 0.6
					a.vel -= imp
					b.vel += imp
					_on_impact(a, -rel * 0.6)
					_on_impact(b, -rel * 0.6)


func _on_impact(c: Car, strength: float) -> void:
	if c != player or attract or strength < 1.5:
		return
	var k := clampf(strength / 14.0, 0.15, 1.0)
	Haptics.impulse(k, 0.08 + k * 0.12)
	Sfx.play("thump", linear_to_db(clampf(k, 0.2, 1.0)) - 2.0, randf_range(0.9, 1.1))
	camera.kick(k)


func _on_gear(_g: int) -> void:
	Haptics.impulse(0.18, 0.035)
	Sfx.play("gear", -12.0)


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
	Sfx.set_engine(p.rpm, p.throttle if not p.frozen or state == State.COUNTDOWN else 0.0)
	Sfx.set_skid(clampf((p.slip - 0.1) * 2.0, 0.0, 1.0) * sf if p.on_road else 0.0)
	# Puddles: a splash, a jolt and a little drag.
	var in_p := false
	for pd in stage.scenery.puddles:
		if p.pos.distance_to(pd[0]) < float(pd[1]):
			in_p = true
			break
	if in_p and not p.in_puddle and sp > 4.0:
		Sfx.play("splash", -3.0, randf_range(0.9, 1.1))
		Haptics.impulse(0.35 + sf * 0.3, 0.12)
	p.in_puddle = in_p


func _positions() -> Array:
	var arr := cars.duplicate()
	arr.sort_custom(func(a, b):
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return a.s > b.s)
	return arr


func _update_hud() -> void:
	hud.set_time(race_time if state != State.DONE else player.finish_time)
	hud.set_speed(player.speed(), player.gear)
	hud.pace.set_note(stage.track.next_corner(player.s, 70.0), player.s)
	var tr := stage.track
	var marks: Array = []
	for c in cars:
		var col: Color = c.stats["body"]
		marks.append([(c.s - tr.start_s) / (tr.finish_s - tr.start_s), col, c == player])
	hud.strip.marks = marks
	hud.strip.queue_redraw()
	if mode != Game.Mode.TIME_TRIAL:
		var pos := _positions().find(player) + 1
		hud.set_position_text("P%d/%d" % [pos, cars.size()])
	var wrong := player.vel.length() > 3.0 and player.vel.normalized().dot(tr.tang[player.track_i]) < -0.4
	if wrong:
		hud.show_hint("WRONG WAY")
	elif absf(player.lat) > tr.width * 1.6 and state == State.RACING:
		hud.show_hint("Lost? Press RESET (Y / R)")
	else:
		hud.show_hint("")


func _results() -> Dictionary:
	var tr := stage.track
	var rows: Array = []
	for c in _positions():
		var t: float = c.finish_time
		if not c.finished:
			# Estimate the remaining time from the car's average pace so far.
			var avg := maxf((c.s - tr.start_s) / maxf(race_time, 1.0), 8.0)
			t = race_time + (tr.finish_s - c.s) / avg
		rows.append({"name": c.driver_name, "time": t, "car": Catalog.cars().find(c.stats), "player": c == player})
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
