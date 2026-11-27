class_name GlassCracks
extends Control
## Cracks across the windscreen in the bonnet and cockpit views, growing with the damage the car has taken.

var level := 0
var _seed := 7
var _drawn := -1
var _stars: Array = []   # [origin, [[end points...], ...]]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_level(v: int) -> void:
	if v == level:
		return
	level = v
	queue_redraw()


func _star(origin: Vector2, rng: RandomNumberGenerator) -> Array:
	var rays: Array = []
	var n := rng.randi_range(5, 8)
	for k in n:
		var ang := TAU * float(k) / float(n) + rng.randf_range(-0.3, 0.3)
		var pts := [origin]
		var p := origin
		var length := rng.randf_range(90.0, 280.0)
		var seg := 4
		for q in seg:
			p += Vector2.from_angle(ang + rng.randf_range(-0.35, 0.35)) * (length / seg)
			pts.append(p)
		rays.append(pts)
	return rays


func _draw() -> void:
	if level < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	var count := clampi((level - 1) / 3, 1, 5)
	for i in count:
		var origin := Vector2(rng.randf_range(0.2, 0.8) * w, rng.randf_range(0.15, 0.6) * h)
		for ray: Array in _star(origin, rng):
			var pts := PackedVector2Array(ray)
			draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0, true)
			draw_polyline(pts, Color(0.1, 0.12, 0.16, 0.3), 1.0, true)
		draw_circle(origin, 6.0, Color(1, 1, 1, 0.5))
