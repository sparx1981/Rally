class_name StageRouteMap
extends Control

var _road := PackedVector2Array()


func show_route(stage_def: Dictionary) -> void:
	var route := Track.new()
	route.generate(int(stage_def.seed), float(stage_def.length) + Track.POST_FINISH, float(stage_def.twist), float(stage_def.width))
	_road.clear()
	var first := route.index_at(route.start_s)
	var last := route.index_at(route.finish_s)
	for index in range(first, last, 3):
		_road.append(route.pts[index])
	_road.append(route.pts[last])
	queue_redraw()


func _draw() -> void:
	if _road.size() < 2:
		return
	var bounds := Rect2(_road[0], Vector2.ZERO)
	for point in _road:
		bounds = bounds.expand(point)
	var space := size - Vector2(30, 26)
	var scale_factor := minf(space.x / maxf(1.0, bounds.size.x), space.y / maxf(1.0, bounds.size.y))
	var route := PackedVector2Array()
	for point in _road:
		route.append((point - bounds.get_center()) * scale_factor + size * 0.5)
	draw_polyline(route, Color("#ad987b"), 6.0, true)
	draw_polyline(route, PaperTheme.INK, 2.0, true)
	draw_circle(route[0], 5.0, Color("#568067"), true, -1.0, true)
	draw_circle(route[-1], 5.0, PaperTheme.ACCENT, true, -1.0, true)
