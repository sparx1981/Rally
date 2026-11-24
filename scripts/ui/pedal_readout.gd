class_name PedalReadout
extends Label
## Shows what Godot reports and what the game uses while the controls tab is open.

var _reader := PlayerInput.new()
var _refresh_in := 0.0


func _process(delta: float) -> void:
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = 0.12
	var pads := PackedInt32Array(Input.get_connected_joypads())
	var throttle := _reader.controller_accelerator(pads)
	var brake := _reader.controller_brake(pads, throttle)
	var lines := PackedStringArray()
	for pad in pads:
		lines.append("%s    LT %.2f    RT %.2f" % [Input.get_joy_name(pad),
			Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT), Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)])
	if pads.is_empty():
		lines.append("Connect a controller to test its pedals.")
	else:
		lines.append("Pedals in game    Brake %.0f%%    Accelerator %.0f%%" % [brake * 100.0, throttle * 100.0])
	text = "\n".join(lines)
