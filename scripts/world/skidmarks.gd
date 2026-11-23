class_name SkidMarks
extends MultiMeshInstance3D
## Tyre marks: short dark strips laid behind the rear wheels on hard cornering, sliding and heavy
## braking. A fixed ring of instances, so old marks are recycled and the cost never grows.

const MAX_MARKS := 900
const SEG := 0.7

var _next := 0
var _last := {}   # key (car id + wheel) -> Vector3 last point


func setup(col: Color) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = pm
	multimesh.instance_count = MAX_MARKS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Call each frame per car. marking = whether the tyres are scrubbing hard right now.
func feed(car: Car, marking: bool) -> void:
	var f := Vector3(sin(car.h), 0, cos(car.h))
	var r := Vector3(cos(car.h), 0, -sin(car.h))
	for side in [-1.0, 1.0]:
		var key := "%d_%d" % [car.get_instance_id(), int(side)]
		if not marking:
			_last.erase(key)
			continue
		var p = car.position - f * (car.half_len - 0.8) + r * side * (car.half_wid - 0.25)
		p.y = car.track.surface_height(Vector2(p.x, p.z), car.s, car.lat) + (Stage.ROAD_Y if car.on_road else 0.0) + 0.02
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
		multimesh.set_instance_transform(_next, Transform3D(basis, mid))
		_next = (_next + 1) % MAX_MARKS
		multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, _next if _next > 0 else MAX_MARKS)
		_last[key] = p
