class_name Ghost
extends Node3D
## Time Trial ghost: records the player's run (10 samples a second) and replays the best run as a
## pale tracing-paper car. Saved per stage in user://ghosts/.

const RATE := 10.0
const VERSION := 2
const STRIDE := 6                  # t, x, y, z, h, pitch

var _rec := PackedFloat32Array()
var _play := PackedFloat32Array()
var _t := 0.0
var _next := 0.0
var _model: Node3D
var _track: Track
var _sig := ""
var _hint := 0


## Identifies the exact road a ghost was driven on: a ghost from an older layout of the stage is
## thrown away instead of floating about where the road used to be.
static func signature(track: Track) -> String:
	return "%d_%d_%.1f" % [VERSION, track.pts.size(), track.length]


static func path_for(stage_id: String) -> String:
	return "user://ghosts/%s.ghost" % stage_id


func setup(stage_id: String, car: Dictionary, track: Track, show_ghost := true) -> bool:
	_track = track
	_sig = signature(track)
	if show_ghost and FileAccess.file_exists(path_for(stage_id)):
		var f := FileAccess.open(path_for(stage_id), FileAccess.READ)
		if f:
			var data = bytes_to_var(f.get_buffer(f.get_length()))
			if data is Dictionary and data.get("sig", "") == _sig and data.get("data") is PackedFloat32Array:
				_play = data["data"]
	if _play.size() >= STRIDE * 2:
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
	return _play.size() >= STRIDE * 2


func record(t: float, car: Car) -> void:
	if t < _next:
		return
	_next = t + 1.0 / RATE
	_rec.append_array([t, car.position.x, car.position.y, car.position.z, car.h, car.rotation.x])


func save(stage_id: String) -> void:
	if Game.no_save:
		return
	DirAccess.make_dir_recursive_absolute("user://ghosts")
	var f := FileAccess.open(path_for(stage_id), FileAccess.WRITE)
	if f:
		f.store_buffer(var_to_bytes({"sig": _sig, "data": _rec}))


func update(t: float) -> void:
	if _model == null:
		return
	var n := _play.size() / STRIDE
	var i := clampi(int(t * RATE), 0, n - 2)
	while i < n - 2 and _play[(i + 1) * STRIDE] < t:
		i += 1
	var o0 := i * STRIDE
	var o1 := (i + 1) * STRIDE
	var t0 := _play[o0]
	var t1 := _play[o1]
	var k := clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
	var a := Vector3(_play[o0 + 1], _play[o0 + 2], _play[o0 + 3])
	var b := Vector3(_play[o1 + 1], _play[o1 + 2], _play[o1 + 3])
	var p := a.lerp(b, k)
	# Sit on the road: straight-line interpolation between samples cuts across crests and dips, so
	# snap to the surface unless the recorded car was clearly in the air.
	if _track:
		var p2 := Vector2(p.x, p.z)
		var hit: Array = _track.project(p2, _hint, p.y)
		_hint = int(hit[0])
		var g := _track.surface_height(p2, float(hit[1]), float(hit[2]))
		if p.y < g + 0.6:
			p.y = g
	_model.global_position = p
	_model.rotation = Vector3(lerpf(_play[o0 + 5], _play[o1 + 5], k), lerp_angle(_play[o0 + 4], _play[o1 + 4], k), 0.0)
	_model.visible = t <= _play[(n - 1) * STRIDE]
