extends Node
## Integration checks for authored crossings, birds and controller brake release.
var _failures := 0


func _ready() -> void:
	_check_brake()
	_check_lighting()
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


func _check_stage(stage: Stage) -> void:
	var id: String = stage.def.id
	var track := stage.track
	_expect(stage.has_node("Birds"), id + " has no birds")
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
