class_name RainLens
extends Control
## Raindrops running down the lens in the bonnet and cockpit views (drawn as a few dozen refractive-looking beads).

var _drops: Array = []   # [pos, radius, speed, life, delay]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 26:
		_drops.append(_new_drop(true))


func _new_drop(first := false) -> Array:
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	return [Vector2(randf() * w, randf() * h if first else -20.0), randf_range(3.0, 9.0), randf_range(18.0, 90.0), randf_range(3.0, 9.0), randf() * 2.0]


func _process(delta: float) -> void:
	if not visible:
		return
	for i in _drops.size():
		var d: Array = _drops[i]
		d[4] -= delta
		if d[4] > 0.0:
			continue
		# Beads cling, then slide: speed grows with size and a little wobble.
		d[0] += Vector2(sin(d[3] * 3.0) * 6.0 * delta, d[2] * delta)
		d[3] -= delta
		if d[0].y > size.y + 30.0 or d[3] <= 0.0:
			_drops[i] = _new_drop()
	queue_redraw()


func _draw() -> void:
	for d: Array in _drops:
		if d[4] > 0.0:
			continue
		var p: Vector2 = d[0]
		var r: float = d[1]
		# Trail, dark rim, bright highlight.
		draw_line(p - Vector2(0, r * 3.0), p, Color(1, 1, 1, 0.12), r * 0.6)
		draw_circle(p, r, Color(0.8, 0.88, 0.95, 0.16))
		draw_arc(p, r, 0.0, TAU, 12, Color(0.1, 0.12, 0.16, 0.35), 1.5)
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.55))
