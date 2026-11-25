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
var _last_count := 4
var _done_t := 0.0
var _reset_cd := 0.0
var _hud_layer: CanvasLayer
var _clock := 0.0
var _entrants: Array = []
var sim_dt := 0.0        # test mode: fixed simulated frame time
var autopilot := false   # test/screenshot mode: the AI drives the player's car


func setup(stage_i: int, mode_v: int, entrants: Array, attract_v := false, tod := -1) -> void:
	stage_index = stage_i
	mode = mode_v
	attract = attract_v
	_entrants = entrants
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.build(Catalog.stages()[stage_i], tod)
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
		var cdef: Dictionary = Catalog.cars()[int(e["car"])]
		if bool(e["player"]) and not attract:
			cdef = Catalog.livery(cdef, Game.livery)
		car.setup(cdef, i + 1, stage, stage.paper_mat)
		var row := i / 2
		var lat := 0.0 if n == 1 else (-2.2 if i % 2 == 0 else 2.2)
		car.place_at(tr.start_s - 5.0 - row * 8.0, lat)
		cars.append(car)
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
	if mode == Game.Mode.TIME_TRIAL and not attract:
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
	_seek_stage_audio()
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


func _exit_tree() -> void:
	if Sfx.popped.is_connected(_on_popped):
		Sfx.popped.disconnect(_on_popped)
	if not attract:
		Sfx.engine_stop()
		Sfx.set_skid(0.0)
		Haptics.stop()


func _unhandled_input(event: InputEvent) -> void:
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
				if c == player:
					_seek_stage_audio()
					Haptics.impulse(0.8, 0.25)
			elif leaves and not c.airborne and not c.in_water and not c.frozen:
				leaves.disturb(previous, c.pos, c.s, c.vel, c.half_wid)
		_collide()
		if state == State.RACING:
			race_time += FIXED
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
	_check_finish()
	if state == State.RACING:
		if _voice:
			_voice.call_ahead(player.s, maxf(player.v_long, 0.0))
		if _crossing_audio:
			_crossing_audio.feed(player.s, player.speed(), player.on_road and not player.airborne)
	player.sync_now()
	camera.follow(dt)
	var vi := camera.view_index()
	stage.set_bonnet(ChaseCamera.is_ground_level(vi))
	if vi != _last_view:
		_last_view = vi
		player.cockpit(vi == ChaseCamera.COCKPIT)
		player.set_low_view(vi == ChaseCamera.LOW)
	var vf: Array = camera.view_focus()
	if stage.advance_lighting(player.s):
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
		if _done_t > 5.0 and _done_t - dt <= 5.0:
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
			# Every finisher coasts on into the parc fermé and parks in its own bay.
			if not drivers.has(c) or c == player:
				drivers[c] = AIDriver.new(c, 0.7)
			var bay := _bays_used
			_bays_used += 1
			var slot: Array = Stage.parc_bay(tr.length, bay)
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
	var j := minf(-(1.0 + RESTITUTION) * vn / denom, MAX_IMPULSE)
	var pre_a := c.vel.length()
	var pre_b := other.vel.length() if other else 0.0
	c.vel += n * j
	c.yaw_rate = clampf(c.yaw_rate + clampf(j * ca / INERTIA * 0.6, -MAX_YAW_KICK, MAX_YAW_KICK), -2.5, 2.5)
	# Tangential scrub at the contact.
	var t := Vector2(-n.y, n.x)
	c.vel -= t * (c.vel - vb).dot(t) * 0.12
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
		var bar := stage.track.barrier_at(c.s, side)
		if bar.is_empty():
			continue
		var wn: Vector2 = stage.track.nrm[c.track_i] * side          # points out of the road
		var ext := c.half_wid * absf(c.right_axis().dot(wn)) + c.half_len * absf(c.fwd().dot(wn))
		var wall: float = bar.get("wall", stage.track.width * 0.5 + Stage.BARRIER_LAT)
		var offset := absf(c.lat) - wall
		var pen := ext - absf(offset)
		if offset > 0.0:
			wn = -wn
		if pen > 0.0:
			c.pos -= wn * pen
			var cp := _corner_support(c, wn)
			var hit := _apply_contact(c, -wn, cp, Vector2.ZERO, null)
			c.vel *= 0.995
			_on_impact(c, hit, cp)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a := cars[i]
			var b := cars[j]
			if absf(a.y-b.y) > 2.0 or (mode == Game.Mode.RACE and not Game.ai_contact and not attract and (a == player or b == player)):
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
	Sfx.set_skid((clampf((p.slip - 0.1) * 2.0, 0.0, 1.0) * sf if p.on_road else 0.0) * (0.0 if p.airborne else 1.0), kind)
	var surf := kind
	if p.patch_kind != "":
		surf = p.patch_kind
	elif not p.on_road:
		surf = "snow" if kind == "snow" else "gravel"
	elif stage.def["id"] == "harbour":
		surf = "cobble"
	Sfx.set_surface(surf, 0.0 if p.airborne else sp)
	# The crowd cheers as you fly past them at jumps and splashes.
	for f in stage.track.features:
		if f["type"] in ["jump", "splash"] and absf(p.s - float(f["s"]) - 6.0) < 1.5 and sp > 8.0 and not _cheered.has(f["s"]):
			_cheered[f["s"]] = true
			Sfx.cheer()
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
		return a.s > b.s)
	return arr


func _update_hud() -> void:
	hud.set_time(race_time if state != State.DONE else player.finish_time)
	hud.set_speed(player.speed(), player.gear)
	hud.pace.set_note(stage.track.next_note(player.s, 70.0), player.s)
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
	var lost := absf(player.lat) > tr.width * 1.6 and state == State.RACING
	hud.show_reset(lost and touch.visible)
	if lost and touch.visible:
		hud.show_hint("")
	elif wrong:
		hud.show_hint("WRONG WAY")
	elif lost:
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


func _seek_stage_audio() -> void:
	if _voice:
		_voice.seek_course(player.s)
	if _crossing_audio:
		_crossing_audio.seek_course(player.s)


func _stop_stage_audio() -> void:
	if _voice:
		_voice.stop()
	if _crossing_audio:
		_crossing_audio.stop()
