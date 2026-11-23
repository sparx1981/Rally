class_name Ghost
extends Node3D
## Time Trial ghost: records the player's run (10 samples a second) and replays the best run as a
## pale tracing-paper car. Saved per stage in user://ghosts/.

const RATE := 10.0

var _rec := PackedFloat32Array()   # t, x, y, z, h
var _play := PackedFloat32Array()
var _t := 0.0
var _next := 0.0
var _model: Node3D


static func path_for(stage_id: String) -> String:
	return "user://ghosts/%s.ghost" % stage_id


func setup(stage_id: String, car: Dictionary) -> bool:
	if FileAccess.file_exists(path_for(stage_id)):
		var f := FileAccess.open(path_for(stage_id), FileAccess.READ)
		if f:
			var data = bytes_to_var(f.get_buffer(f.get_length()))
			if data is PackedFloat32Array:
				_play = data
	if _play.size() >= 10:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.86, 0.9, 0.98, 0.38)
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		var m := CarModel.build(car, 0, mat)
		_model = m["root"]
		add_child(_model)
		for n in _model.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _play.size() >= 10


func record(t: float, car: Car) -> void:
	if t < _next:
		return
	_next = t + 1.0 / RATE
	_rec.append_array([t, car.position.x, car.position.y, car.position.z, car.h])


func save(stage_id: String) -> void:
	if Game.no_save:
		return
	DirAccess.make_dir_recursive_absolute("user://ghosts")
	var f := FileAccess.open(path_for(stage_id), FileAccess.WRITE)
	if f:
		f.store_buffer(var_to_bytes(_rec))


func update(t: float) -> void:
	if _model == null:
		return
	var n := _play.size() / 5
	var i := clampi(int(t * RATE), 0, n - 2)
	while i < n - 2 and _play[(i + 1) * 5] < t:
		i += 1
	var t0 := _play[i * 5]
	var t1 := _play[(i + 1) * 5]
	var k := clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
	var a := Vector3(_play[i * 5 + 1], _play[i * 5 + 2], _play[i * 5 + 3])
	var b := Vector3(_play[(i + 1) * 5 + 1], _play[(i + 1) * 5 + 2], _play[(i + 1) * 5 + 3])
	_model.global_position = a.lerp(b, k)
	_model.rotation.y = lerp_angle(_play[i * 5 + 4], _play[(i + 1) * 5 + 4], k)
	_model.visible = t <= _play[(n - 1) * 5]
