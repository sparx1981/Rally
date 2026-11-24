class_name SkidMarks
extends MultiMeshInstance3D
## Tyre marks: short dark strips laid behind the rear wheels on hard cornering, sliding and heavy
## braking. A fixed ring of instances, so old marks are recycled and the cost never grows.

const MAX_MARKS := 900
const SEG := 0.7

const WET_RUN := 16.0
var _wet_left := {} # metres of water carried by each rear tyre
var _previous := {}
var _clock := 0.0
var _ink := ShaderMaterial.new()
var _next := 0
var _last := {}   # key (car id + wheel) -> Vector3 last point


func setup(col: Color) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_ink.shader = preload("res://shaders/tyre_marks.gdshader")
	_ink.set_shader_parameter("rubber", col)
	pm.material = _ink
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = pm
	multimesh.instance_count = MAX_MARKS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func advance(seconds: float) -> void:
	_clock += seconds
	_ink.set_shader_parameter("clock_s", _clock)


## Call each frame per car. marking = whether the tyres are scrubbing hard right now.
func feed(car: Car, marking: bool) -> void:
	var f := Vector3(sin(car.h), 0, cos(car.h))
	var r := Vector3(cos(car.h), 0, -sin(car.h))
	for side: float in [-1.0, 1.0]:
		var key := "%d_%d" % [car.get_instance_id(), int(side)]
		var wheel := Vector3(car.pos.x, car.y, car.pos.y) - f * (car.half_len - 0.8) + r * side * (car.half_wid - 0.25)
		var xz := Vector2(wheel.x, wheel.z)
		var previous: Vector2 = _previous.get(key, xz)
		var travel := previous.distance_to(xz)
		_previous[key] = xz
		if travel > 4.0 or car.airborne:
			_last.erase(key)
			_wet_left.erase(key)
			continue
		if not marking and not car.in_water and not _wet_left.has(key):
			_last.erase(key)
			continue
		var hit := car.track.project(xz, car.track_i)
		if car.track.inside_ford(xz, hit[1]):
			_wet_left[key] = WET_RUN
			_last.erase(key)
			continue
		var wet := maxf(0.0, float(_wet_left.get(key, 0.0)) - travel)
		if wet > 0.0:
			_wet_left[key] = wet
		elif _wet_left.has(key):
			_wet_left.erase(key)
		if not marking and wet <= 0.0:
			_last.erase(key)
			continue
		var p := wheel
		p.y = car.track.surface_height(xz, hit[1], hit[2]) + (Stage.ROAD_Y if absf(hit[2]) <= car.track.width * 0.5 else 0.0) + 0.025
		if not _last.has(key):
			_last[key] = p
			continue
		var a: Vector3 = _last[key]
		var d = p - a
		if d.length() < SEG:
			continue
		var mid = (a + p) * 0.5
		var dir = d.normalized()
		var basis := Basis(Vector3(dir.z, 0, -dir.x).normalized() * 0.3, Vector3.UP, dir * d.length())
		multimesh.set_instance_custom_data(_next, Color(wet / WET_RUN, _clock, 1.0 if wet > 0.0 else 0.0, 0.0))
		multimesh.set_instance_transform(_next, Transform3D(basis, mid))
		_next = (_next + 1) % MAX_MARKS
		multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, _next if _next > 0 else MAX_MARKS)
		_last[key] = p
