extends Node
## Integration checks for authored crossings, wildlife and controller brake release.
var _failures := 0


func _ready() -> void:
	_check_brake()
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


func _axis(device: int, pressure: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = pressure
	event.device = device
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_brake() -> void:
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
	_expect(reader.controller_brake(pad) == 1.0, "X applies the brake")
	var released := button.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	_expect(reader.controller_brake(pad) == 0.0, "X releases the brake")


func _check_stage(stage: Stage) -> void:
	var id: String = stage.def.id
	var track := stage.track
	_expect(not stage.wildlife._groups.is_empty(), id + " has no wildlife")
	if not stage.wildlife._groups.is_empty():
		var group: Dictionary = stage.wildlife._groups.front()
		var actor := stage.wildlife._actor
		var start := Vector3(group.a.x, track.terrain.height(group.a), group.a.y)
		stage.wildlife.update(0.0, start, group.s)
		var before := actor.position
		stage.wildlife.update(0.6, start, group.s)
		_expect(actor.visible and actor.position.distance_to(before) > 0.01, id + " wildlife did not animate")
		stage.wildlife.update(0.1, start + Vector3(250, 0, 0), group.s + 250.0)
		_expect(not actor.visible, id + " wildlife still active at long range")

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
	print(id, " • ", stage.wildlife._groups.size(), " wildlife routes • ", track.tunnels.size(), " tunnels")
