extends Node
## Integration checks for crossings, stage dressing and controller brake release.
var _failures := 0


func _ready() -> void:
	_check_brake()
	_check_lighting()
	_check_engine_audio()
	_check_surface_audio()
	_check_cockpits()
	if ResourceLoader.exists(Race.CO_DRIVER_SCRIPT):
		_check_voice()
	if ResourceLoader.exists(Race.CROSSING_AUDIO_SCRIPT):
		_check_crossing_audio()
	for stage_def: Dictionary in Catalog.stages():
		var stage := Stage.new()
		add_child(stage)
		stage.build(stage_def)
		_check_stage(stage)
		stage.free()
	print("Stage and controller checks: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		_failures += 1


func _check_engine_audio() -> void:
	for style: String in ["mini", "impreza", "quattro", "truck"]:
		var player := Node.new()
		add_child(player)
		var engine := RecordedEngine.new(player, style, true)
		engine.mix(2500.0, 0.5, 0.8)
		var voices := engine._voices.duplicate()
		_expect(voices.size() == 10 and voices.all(func(voice): return voice.playing and voice.playback_type == AudioServer.PLAYBACK_TYPE_STREAM),
			style + " starts all power and overrun loops as direct streams")
		engine.mix(3700.0, 0.0, 0.8)
		_expect(voices[2].volume_db > -20.0 and voices[7].volume_db > voices[2].volume_db,
			style + " plays the overrun bank while keeping the power bank audible")
		engine.mix(6100.0, 1.0, 0.8)
		_expect(engine._voices == voices and voices[4].playing and voices[4].volume_db > -6.0
			and is_equal_approx(voices[4].pitch_scale, 6100.0 / 6400.0) and voices[9].volume_db <= -79.0,
			style + " brings in the high-RPM power recording after throttle reapplication")
		engine.stop()
		_expect(voices.all(func(voice): return not voice.playing), style + " stops every loop when the race ends")
		player.free()
	var car := Car.new()
	car.stats = Catalog.cars()[0]
	car.frozen = false
	var top := float(car.stats.top)
	for i in 32:
		car._update_gear(7.95 * top, 1.0)
	var before := car.acoustic_rpm
	for i in 32:
		car._update_gear(8.05 * top, 1.0)
	_expect(car.gear == 2 and car.acoustic_rpm > 3500.0 and car.acoustic_rpm < before - 1800.0,
		"An upshift drops the exhaust pitch into the next gear's working RPM range")
	car.free()


func _check_surface_audio() -> void:
	Sfx.engine_start("impreza")
	Sfx.set_surface("dry", 19.0, 1.0, 0.52)
	Sfx.set_skid(0.68, "dry")
	for i in 12:
		Sfx._process(1.0 / 60.0)
	_expect(Sfx._gravel_roll.playing and Sfx._gravel_roll.volume_db > -8.0
		and Sfx._gravel_scrub.playing and Sfx._gravel_scrub.volume_db > -8.0,
		"Gravel tyres have separate audible rolling and sliding recordings")
	Sfx.set_skid(0.75, "rain")
	Sfx.set_surface("rain", 19.0, 0.0, 0.36)
	for i in 12:
		Sfx._process(1.0 / 60.0)
	_expect(Sfx._skid.volume_db > -8.0 and Sfx._gravel_scrub.volume_db <= -78.0,
		"Wet road slides use tyre scrub instead of gravel")
	Sfx.set_skid(0.0)
	Sfx.set_surface("dry", 0.0, 0.0, 0.0)
	for i in 12:
		Sfx._process(1.0 / 60.0)
	_expect(Sfx._skid.volume_db <= -78.0 and Sfx._gravel_roll.volume_db <= -78.0,
		"Tyre loops fade at the end of a slide and when ground speed falls to zero")
	Sfx.set_engine(5100.0, 0.90)
	Sfx._process(1.0 / 60.0)
	Sfx.engine_shift(false)
	_expect(is_zero_approx(Sfx._shift_time), "A downshift leaves the engine mix up")
	for pressure: float in [0.72, 0.57, 0.44, 0.30, 0.18]:
		Sfx.set_engine(4500.0, pressure)
		Sfx._process(1.0 / 60.0)
	_expect(Sfx._pop_cd > 0.0, "An analog high-RPM lift triggers a recorded exhaust pop")
	Sfx.engine_stop()


func _check_cockpits() -> void:
	var material := StandardMaterial3D.new()
	for stats: Dictionary in Catalog.cars():
		var model := CarModel.build(stats, 7, material)
		var cockpit := CarModel.build_cockpit(stats, model, material)
		var nose := cockpit.nose as MeshInstance3D
		if stats.style == "buggy":
			_expect(nose == null, "The open buggy uses its full exterior mesh")
		else:
			var shell := (model.body as Node3D).get_child(0) as MeshInstance3D
			var bounds := nose.mesh.get_aabb()
			_expect(bounds.position.z >= float(cockpit.nose_clip) - 0.001
				and is_equal_approx(bounds.end.z, shell.mesh.get_aabb().end.z)
				and nose.material_override == shell.material_override,
				"%s cockpit bonnet matches the forward exterior" % stats.style)
		cockpit.root.free()
		model.root.free()


func _axis(device: int, pressure: float, axis := JOY_AXIS_TRIGGER_LEFT) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = pressure
	event.device = device
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_brake() -> void:
	var original_mode: int = Settings.g("controller_trigger_mode")
	Settings.data["controller_trigger_mode"] = PlayerInput.TriggerMode.AUTO
	var reader := PlayerInput.new()
	var pad := PackedInt32Array([4])
	_axis(4, 0.65)
	_expect(reader.controller_brake(pad) > 0.5, "Trigger applies braking")
	_axis(4, 0.11)
	_expect(reader.controller_brake(pad) == 0.0, "Trigger releases with residual pressure")
	_axis(4, 0.9)
	_expect(reader.controller_brake(pad) > 0.98, "Full brake after first release")
	_axis(4, 0.0)
	_expect(reader.controller_brake(pad) == 0.0, "Trigger returns to zero")
	_axis(4, 1.0)
	reader.controller_brake(pad)
	_axis(4, -1.0)
	_expect(reader.controller_brake(pad) == 0.0, "Signed resting value releases the brake")
	_axis(4, 0.74)
	_expect(reader.controller_brake(pad) > 0.7, "Braking before switching pedals")
	_axis(4, 0.91)
	_expect(reader.controller_brake(pad, 1.0) == 0.0, "RT overrides a stale LT reading")
	_expect(reader.controller_brake(pad, 1.0) == 0.0, "Stale braking stays suppressed")
	_axis(4, 0.0)
	reader.controller_brake(pad, 1.0)
	_axis(4, 0.78)
	_expect(reader.controller_brake(pad, 1.0) == 0.0, "LT cannot reassert itself during throttle")
	_expect(reader.controller_brake(pad) == 0.0, "LT must first return to rest after acceleration")
	_axis(4, 0.02)
	reader.controller_brake(pad)
	_axis(4, 0.78)
	_expect(reader.controller_brake(pad) > 0.8, "LT works after returning to rest")
	_axis(4, 0.0)
	reader.controller_brake(pad)
	_axis(7, 0.95)
	_expect(reader.controller_brake(PackedInt32Array([4, 7])) == 1.0, "Second controller can brake")
	_expect(reader.controller_brake(pad) == 0.0, "Disconnected controller clears its pressure")
	_axis(7, 0.0)
	var button := InputEventJoypadButton.new()
	button.device = 4
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	_expect(reader.controller_brake(pad, 1.0) == 1.0, "X deliberately applies the brake during throttle")
	var released := button.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	_expect(reader.controller_brake(pad) == 0.0, "X releases the brake")

	reader = PlayerInput.new()
	reader.detect_android_range = true
	_axis(4, 0.90)
	_expect(reader.controller_brake(pad) > 0.5, "First LT movement before range is known")
	_axis(4, 0.50)
	_expect(reader.controller_brake(pad) == 0.0, "Android half-range LT rests at 0.50")
	_axis(4, 0.75)
	_expect(absf(reader.trigger_value(4, JOY_AXIS_TRIGGER_LEFT) - 0.5) < 0.002, "Half-range LT retains proportional travel")
	_axis(4, 0.50, JOY_AXIS_TRIGGER_RIGHT)
	_expect(reader.controller_accelerator(pad) == 0.0, "Half-range RT is idle at 0.50")
	_axis(4, 0.93, JOY_AXIS_TRIGGER_RIGHT)
	_expect(reader.controller_accelerator(pad) > 0.9, "Half-range RT accelerates")
	_axis(7, 0.29)
	_expect(reader.controller_brake(PackedInt32Array([7])) > 0.1, "Ordinary trigger identifies sub-midpoint travel")
	_axis(7, 0.50)
	_expect(reader.controller_brake(PackedInt32Array([7])) > 0.4, "Ordinary trigger at 50% still brakes")
	Settings.data["controller_trigger_mode"] = PlayerInput.TriggerMode.BUTTON_BRAKE
	_expect(reader.controller_brake(PackedInt32Array([7])) == 0.0, "X-only option ignores LT")
	Settings.data["controller_trigger_mode"] = original_mode


func _check_lighting() -> void:
	for mode: int in [Catalog.SUNSET, Catalog.SUNRISE]:
		var stage := Stage.new()
		add_child(stage)
		stage.build(Catalog.stages()[0], mode)
		var starts_dark := mode == Catalog.SUNRISE
		var track := stage.track
		var start := stage.headlight_level
		_expect(is_equal_approx(start, float(starts_dark)), "Light level matches the start of the transition")
		stage.advance_lighting(lerpf(track.start_s, track.finish_s, 0.475))
		var midway := stage.headlight_level
		_expect(midway > 0.2 and midway < 0.8, "Dusk or dawn blends the endpoints")
		_expect(not stage.advance_lighting(track.start_s) and stage.headlight_level == midway, "Reversing does not rewind sunset")
		stage.advance_lighting(lerpf(track.start_s, track.finish_s, 0.96))
		_expect(is_equal_approx(stage.headlight_level, float(not starts_dark)), "Transition completes before the finish")
		stage.free()


func _check_voice() -> void:
	var notes := Track.new()
	notes.notes = [
		{"s0": 65.0, "s1": 79.0, "kind": "corner", "dir": -1, "sev": 3, "hairpin": false},
		{"s0": 85.0, "s1": 97.0, "kind": "tunnel"}
	]
	var voice_script := load(Race.CO_DRIVER_SCRIPT)
	var voice = voice_script.new()
	add_child(voice)
	voice.setup(notes)
	var timing = Settings.g("codriver_timing")
	var volume = Settings.g("codriver_volume")
	var selection = Settings.g("codriver_voice")
	Settings.data.codriver_volume = 0.66
	Settings.data.codriver_timing = 1
	voice.call_ahead(20.0, 18.0)
	_expect(not voice.playing, "Late mode waits for the closer approach")
	Settings.data.codriver_timing = 3
	var voices: Array[String] = voice_script.available_voices()
	if voices.is_empty():
		voices.append("george")
	for id: String in voices:
		Settings.data.codriver_voice = id
		voice.seek_course(0.0)
		voice.call_ahead(20.0, 18.0)
		_expect(voice.playing and voice.stream.resource_path == voice_script.clip_path(id, "left3_into_tunnel"),
			id + " calls a complete turn into a hazard using the selected voice")
		voice.seek_course(90.0)
		_expect(not voice.playing and voice._cursor == 2, "Recovery stops stale voice audio")
	Settings.data.codriver_timing = timing
	Settings.data.codriver_volume = volume
	Settings.data.codriver_voice = selection
	voice.free()


func _check_crossing_audio() -> void:
	var crossing = load(Race.CROSSING_AUDIO_SCRIPT).new()
	var notes := Track.new()
	notes.bridges = [{"s": 80.0, "half": 10.0, "kind": "truss"}]
	add_child(crossing)
	crossing.setup(notes, 1.3)
	crossing.seek_course(66.5)
	crossing.feed(69.0, 12.0, false)
	_expect(not crossing._players[0].playing, "Airborne axle does not play a joint")
	var audio_setting = Settings.g("crossing_audio")
	Settings.data.crossing_audio = true
	crossing.feed(72.0, 12.0, true)
	_expect(crossing._players[0].playing, "Grounded rear axle plays the steel joint")
	crossing.seek_course(94.0)
	_expect(not crossing._players[0].playing, "Crossing audio stops when seeking")
	Settings.data.crossing_audio = audio_setting
	crossing.free()


func _check_stage(stage: Stage) -> void:
	var id: String = stage.def.id
	var track := stage.track
	_expect(stage.has_node("Birds"), id + " has no birds")
	_check_chapters(stage)
	if stage.def.loc_id == "autumn":
		_check_leaves(stage)
	else:
		_expect(stage.leaf_litter == null, id + " has autumn leaf litter")
	if stage.def.get("stacked", false):
		var center: Vector2 = track.stacked_crossing.center
		var lower: float = track.stacked_crossing.lower
		var upper: float = track.stacked_crossing.upper
		var low_y := track.road_h(lower)
		var high_y := track.road_h(upper)
		_expect(track.point_at(lower).distance_to(track.point_at(upper)) < 2.5 and high_y-low_y > 7.0,
			"Stacked road occupies one footprint at two drivable heights")
		_expect(absf(track.project(center, track.index_at(upper), low_y)[1] - lower) < 3.0, "Wrong hint still finds lower deck")
		_expect(absf(track.project(center, track.index_at(lower), high_y)[1] - upper) < 3.0, "Wrong hint still finds upper deck")
		_expect(stage.has_node("StackedBridge") and stage._stacked_road != null, "Stacked road has an actual deck and cutaway mesh")
		_expect(absf(track.terrain.height(center)-low_y) < 0.5, "Terrain underneath the bridge agrees with the lower deck")

	for tunnel in track.tunnels:
		_expect(stage.has_node("TunnelRoof"), id + " tunnel has no roof")
		var centre: float = (tunnel.s0 + tunnel.s1) * 0.5
		for side: float in [-1, 1]:
			_expect(track.barrier_at(centre, side).get("kind") == "tunnel", id + " lacks a tunnel wall")
		var car := Car.new()
		stage.add_child(car)
		car.is_player = true
		car.setup(Catalog.cars()[0], 1, stage, stage.paper_mat)
		for station: float in [tunnel.s0 - 5.0, centre, tunnel.s1 + 5.0]:
			car.place_at(station, 0.0)
			_expect(car._contact.visible and car._contact.mesh.get_surface_count() == 1, id + " car shadow missing")
			_expect(track.road_h(station) + 4.6 - car.y > 4.5, id + " tunnel clearance is too low")
		car.free()
	for bridge in track.bridges:
		if Stage.SWITCHBACK_BRIDGES.get(id, -1.0) == bridge.s:
			var middle := track.point_at(bridge.s)
			_expect(track.terrain.height(middle) < track.road_h(bridge.s) - 4.0, id + " missing the dry bridge cutting")
	print(id, " • ", track.tunnels.size(), " tunnels")


func _check_chapters(stage: Stage) -> void:
	var track := stage.track
	var site: String = stage.def.loc_id
	if site not in ["gorge", "alpine", "harbour", "autumn"]:
		_expect(track.chapters.is_empty(), stage.def.id + " has unexpected chapters")
		return
	_expect(track.chapters.size() == 3 and track.terrain._route_progress.size() == track.terrain.h.size(),
		stage.def.id + " has three chapters and a terrain progress map")
	if site == "gorge":
		return
	var kind: String = {"alpine": "pine_snow", "harbour": "house", "autumn": "tree"}[site]
	var count := [0, 0, 0]
	var total := [0, 0, 0]
	for prop: Dictionary in stage.scenery.placements:
		if prop.s > track.finish_s:
			continue
		var chapter := mini(2, int(track.chapter_progress(prop.s) * 3.0))
		total[chapter] += 1
		if prop.kind == kind:
			count[chapter] += 1
	var dense := 0 if site == "alpine" else 1
	_expect(count[dense] > 2 * count[2] and count[dense] * total[2] > 1.7 * count[2] * total[dense],
		stage.def.id + " scenery distinguishes the dense and exposed chapters")


func _check_leaves(stage: Stage) -> void:
	var litter := stage.leaf_litter
	_expect(litter != null and litter._cells.size() > 40, stage.def.id + " has leaf drifts along the route")
	if litter == null or litter._cells.is_empty():
		return
	var drift: LeafLitter.Drift = litter._cells.values()[0][0]
	var leaf := drift.leaves[0]
	var original := leaf.at
	var point := drift.origin + Vector2(original.x, original.z)
	var direction := drift.tang
	var side := Vector2(-direction.y, direction.x)
	var lateral_min := INF
	var lateral_max := -INF
	for resting: LeafLitter.Leaf in drift.leaves:
		var lateral := Vector2(resting.at.x, resting.at.z).dot(side)
		lateral_min = minf(lateral_min, lateral)
		lateral_max = maxf(lateral_max, lateral)
	_expect(drift.leaves.size() >= 59 and lateral_max - lateral_min > 2.6,
		stage.def.id + " has broad, visibly populated leaf drifts")
	var from := point - direction * 1.5
	var to := point - direction * 0.2
	litter.disturb(to, to, drift.station, Vector2.ZERO, 0.95)
	litter.disturb(from + side * 12.0, to + side * 12.0, drift.station, direction * 25.0, 0.95)
	_expect(litter._moving_count == 0, stage.def.id + " leaves ignore parked and distant cars")
	litter.disturb(from + side * 1.8, to + side * 1.8, drift.station, direction * 25.0, 0.95)
	_expect(leaf.age > 0.0 and leaf.at == original and litter._moving_count <= litter._flight_limit,
		stage.def.id + " a fast pass can lift the existing leaves from the side")
	litter.advance(0.04)
	_expect(leaf.at.y > original.y and not is_zero_approx(leaf.at.distance_to(original)),
		stage.def.id + " disturbed leaves lift and drift")
	for i in 150:
		litter.advance(1.0 / 60.0)
	_expect(litter._moving_count == 0 and leaf.age == 0.0 and is_equal_approx(leaf.at.y, leaf.ground_y) and leaf.at != original,
		stage.def.id + " leaves settle where they land")
