class_name LeafLitter
extends Node3D
## Roadside drifts use one instanced mesh per clump. Only disturbed leaves are simulated.

const CELL := 24.0
const COLORS := [Color("#b84f30"), Color("#de8538"), Color("#e9b857"), Color("#89492d")]

class Leaf:
	var at := Vector3.ZERO
	var drift := Vector3.ZERO
	var angles := Vector3.ZERO
	var tumble := Vector3.ZERO
	var size := 1.0
	var ground_y := 0.0
	var age := 0.0
	var index := 0

class Drift:
	var station := 0.0
	var origin := Vector2.ZERO
	var tang := Vector2.ZERO
	var mesh: MultiMeshInstance3D
	var leaves: Array[Leaf] = []

var _track: Track
var _rng := RandomNumberGenerator.new()
var _cells := {}
var _moving := {} # Drift -> active leaves
var _moving_count := 0
var _flight_limit := 80
var _draw_distance := 0.0


func build(track: Track, seed_v: int) -> void:
	_track = track
	_rng.seed = seed_v + 472
	var shape := _leaf_mesh()
	var station := _track.start_s + 46.0
	while station < _track.finish_s - 27.0:
		# Most drifts collect near the verge. Some blow well onto the driven line.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		if _rng.randf() < 0.35:
			_add_drift(shape, station, _rng.randf_range(-1.4, 1.4))
		else:
			_add_drift(shape, station, side * (_track.width * 0.5 + _rng.randf_range(-1.6, 0.7)))
		if _rng.randf() < 0.4:
			_add_drift(shape, station + _rng.randf_range(5.0, 11.0), side * _rng.randf_range(1.2, 3.4))
		var progress := track.chapter_progress(station)
		var forest := smoothstep(0.25, 0.40, progress) * (1.0 - smoothstep(0.59, 0.76, progress))
		station += _rng.randf_range(31.0, 68.0) * lerpf(1.1, 0.68, forest)


func configure(quality: float, draw_distance: float) -> void:
	_flight_limit = roundi(lerpf(26.0, 100.0, quality))
	var reach := minf(95.0, draw_distance)
	if reach == _draw_distance:
		return
	_draw_distance = reach
	for drifts: Array in _cells.values():
		for drift: Drift in drifts:
			drift.mesh.visibility_range_end = reach


func _add_drift(shape: Mesh, station: float, lateral: float) -> void:
	var i := _track.index_at(station)
	var center := _track.point_at(station) + _track.nrm[i] * lateral
	if not _track.bridge_at(station, 8.0).is_empty() or _track.tunnel_at(station, 8.0):
		return
	if not _track.feature_at(station, "jump", 9.0).is_empty() or _track.overlaps_water(center, 6.0):
		return
	var drift := Drift.new()
	drift.station = station
	drift.origin = center
	drift.tang = _track.tang[i]
	var base_y := _track.road_h(station)
	var long_spread := _rng.randf_range(0.65, 1.9)
	var width_spread := _rng.randf_range(0.35, 0.85)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = shape
	instances.instance_count = _rng.randi_range(20, 33)
	# Fixed bounds cover flight and settling, including small roadside drops.
	instances.custom_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 11, 20))
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh = instances
	mesh.position = Vector3(center.x, base_y, center.y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	drift.mesh = mesh
	for j in instances.instance_count:
		var along := clampf(_rng.randfn(0.0, 0.52), -1.3, 1.3) * long_spread
		var across := clampf(_rng.randfn(0.0, 0.52), -1.3, 1.3) * width_spread
		var offset := drift.tang * along + _track.nrm[i] * across
		var leaf := Leaf.new()
		leaf.index = j
		leaf.size = _rng.randf_range(0.64, 1.28)
		leaf.angles.y = _rng.randf() * TAU
		leaf.ground_y = _ground(drift, offset)
		leaf.at = Vector3(offset.x, leaf.ground_y + _rng.randf_range(0.0, 0.013), offset.y)
		drift.leaves.append(leaf)
		var ink: Color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
		instances.set_instance_color(j, ink)
		_draw_leaf(drift, leaf)
	var cell := floori(station / CELL)
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(drift)


func disturb(from: Vector2, to: Vector2, station: float, velocity: Vector2, half_width: float) -> void:
	var speed := velocity.length()
	if speed < 0.9 or from.distance_squared_to(to) < 0.00001 or _moving_count >= _flight_limit:
		return
	var flow := velocity / speed
	var side := Vector2(-flow.y, flow.x)
	var wake := half_width + lerpf(0.30, 2.2, smoothstep(3.5, 24.0, speed))
	var strength := clampf(speed / 25.0, 0.0, 1.0)
	var nose_from := from + flow * 0.65
	var nose_to := to + flow * 0.72
	var cell := floori(station / CELL)
	for i in range(cell - 1, cell + 2):
		for drift: Drift in _cells.get(i, []):
			if absf(drift.station - station) > 12.0 or drift.origin.distance_squared_to(to) > 125.0:
				continue
			for leaf: Leaf in drift.leaves:
				if leaf.age > 0.0 or Vector2(leaf.at.x, leaf.at.z).length_squared() > 36.0:
					continue
				var point := drift.origin + Vector2(leaf.at.x, leaf.at.z)
				var nearest := Geometry2D.get_closest_point_to_segment(point, nose_from, nose_to)
				var distance := point.distance_to(nearest)
				# The strongest motion is beside the tyres, feathering out into the wake.
				if distance >= wake * (0.72 + leaf.size * 0.22):
					continue
				var spread := signf(side.dot(point - nearest)) * _rng.randf_range(0.6, 1.7)
				var breeze := flow * _rng.randf_range(0.9, 2.45) + side * spread
				var lift := lerpf(0.32, 1.0, 1.0 - smoothstep(half_width, wake, distance))
				leaf.drift = Vector3(breeze.x, lift * _rng.randf_range(1.1, 2.8), breeze.y) * lerpf(0.26, 1.6, strength)
				leaf.tumble = Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-9.0, 9.0))
				leaf.age = 0.001
				if not _moving.has(drift):
					_moving[drift] = []
				_moving[drift].append(leaf)
				_moving_count += 1
				if _moving_count >= _flight_limit:
					return


func advance(dt: float) -> void:
	for drift: Drift in _moving.keys():
		var moving: Array = _moving[drift]
		for i in range(moving.size() - 1, -1, -1):
			var leaf: Leaf = moving[i]
			leaf.age += dt
			leaf.drift *= exp(-2.2 * dt)
			leaf.drift.y -= 4.7 * dt
			leaf.at += leaf.drift * dt
			leaf.angles += leaf.tumble * dt
			leaf.tumble *= exp(-1.8 * dt)
			if leaf.drift.y < 0.0:
				var offset := Vector2(leaf.at.x, leaf.at.z)
				leaf.ground_y = _ground(drift, offset)
				if leaf.at.y <= leaf.ground_y and leaf.age > 0.12:
					leaf.at.y = leaf.ground_y
					leaf.angles.x = 0.0
					leaf.angles.z = 0.0
					leaf.age = 0.0
					moving.remove_at(i)
					_moving_count -= 1
			_draw_leaf(drift, leaf)
		if moving.is_empty():
			_moving.erase(drift)


func _ground(drift: Drift, offset: Vector2) -> float:
	var p := drift.origin + offset
	var station := drift.station + offset.dot(drift.tang)
	var i := _track.index_at(station)
	var lateral := (p - _track.point_at(station)).dot(_track.nrm[i])
	var floor_y := _track.terrain.height(p)
	if absf(lateral) < _track.road_half_width(station) + 0.06:
		var print_height := 0.027 if not _track.patch_at(station, lateral).is_empty() else 0.0
		floor_y = maxf(floor_y, _track.road_h(station) + Stage.ROAD_Y + print_height)
	return floor_y - drift.mesh.position.y + 0.022


func _draw_leaf(drift: Drift, leaf: Leaf) -> void:
	var basis := Basis.from_euler(leaf.angles)
	drift.mesh.multimesh.set_instance_transform(leaf.index, Transform3D(basis.scaled(Vector3.ONE * leaf.size), leaf.at))


func _leaf_mesh() -> Mesh:
	var outline := PackedVector2Array([
		Vector2(0.0, -0.115), Vector2(0.055, -0.065), Vector2(0.078, -0.007),
		Vector2(0.050, 0.061), Vector2(0.0, 0.103), Vector2(-0.045, 0.067),
		Vector2(-0.069, 0.012), Vector2(-0.049, -0.058)
	])
	var builder := PaperKit.Builder.new()
	var fold := Vector3(0, 0.017, 0.006)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var p := Vector3(a.x, 0, a.y)
		var q := Vector3(b.x, 0, b.y)
		var normal := (p - fold).cross(q - fold).normalized()
		var crease := Color.WHITE if i < 4 else Color(0.79, 0.76, 0.69)
		builder.tri3(fold, p, q, normal if normal.y > 0.0 else -normal, crease, crease.darkened(0.12), crease)
	var surface := builder.mesh()
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	surface.surface_set_material(0, mat)
	return surface
