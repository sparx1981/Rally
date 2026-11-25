class_name StageRouteMap
extends Control

var _road := PackedVector2Array()
var _height := PackedFloat32Array()
var _ascent := 0.0
var route_length := 0.0


func show_route(stage_def: Dictionary) -> void:
	var route := Track.new()
	route.build_stage_route(stage_def, Catalog.weather(stage_def.weather).kind)
	route_length = route.finish_s - route.start_s
	_road.clear()
	_height.clear()
	_ascent = 0.0
	var first := route.index_at(route.start_s)
	var last := route.index_at(route.finish_s)
	for index in range(first, last + 1):
		if index % 3 == 0 or index in [first, last]:
			_road.append(route.pts[index])
			_height.append(route.road_h_i(index))
		if index > first:
			_ascent += maxf(0.0, route.road_h_i(index) - route.road_h_i(index - 1))
	queue_redraw()


func _draw() -> void:
	if _road.size() < 2 or size.y < 100:
		return
	var bounds := Rect2(_road[0], Vector2.ZERO)
	for point in _road:
		bounds = bounds.expand(point)
	var map_height := size.y - 76.0
	var space := Vector2(size.x - 30.0, map_height - 14.0)
	var scale_factor := minf(space.x / maxf(1.0, bounds.size.x), space.y / maxf(1.0, bounds.size.y))
	var route := PackedVector2Array()
	for point in _road:
		route.append((point - bounds.get_center()) * scale_factor + Vector2(size.x, map_height) * 0.5)
	draw_polyline(route, Color("#ad987b"), 6.0, true)
	draw_polyline(route, PaperTheme.INK, 2.0, true)
	draw_circle(route[0], 5.0, Color("#568067"), true, -1.0, true)
	draw_rect(Rect2(route[-1] - Vector2(4, 4), Vector2(8, 8)), PaperTheme.ACCENT)
	_draw_elevation(map_height + 10.0)


func _draw_elevation(top: float) -> void:
	var low := _height[0]
	var high := low
	for point in _height:
		low = minf(low, point)
		high = maxf(high, point)
	var profile := PackedVector2Array()
	var baseline := size.y - 4.0
	for i in _height.size():
		profile.append(Vector2(5.0 + float(i) / (_height.size() - 1) * (size.x - 10.0),
			baseline - (_height[i] - low) / maxf(high - low, 1.0) * 36.0))
	var fill := profile.duplicate()
	fill.append(Vector2(size.x - 5.0, baseline + 1.0))
	fill.append(Vector2(5.0, baseline + 1.0))
	# Keep the fill polygon non-degenerate at the low points.
	draw_colored_polygon(fill, Color("#d9c6a3"))
	draw_polyline(profile, PaperTheme.ACCENT, 2.0, true)
	draw_string(get_theme_default_font(), Vector2(6, top + 13), "Elevation  ·  +%d m climb" % roundi(_ascent),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, PaperTheme.INK)
