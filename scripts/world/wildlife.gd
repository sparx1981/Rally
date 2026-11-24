class_name Wildlife
extends Node3D
## Small scenic animals stay on a tested verge. Only nearby groups animate.

const REGIONAL_SPECIES := {
	"meadow": "hare", "canyon": "lizard", "autumn": "squirrel",
	"moor": "hare", "pinewood": "fox", "harbour": "crab",
	"alpine": "chamois", "lakes": "snow_hare", "taiga": "fox",
	"cliffs": "hare", "gorge": "lizard"
}

var _track: Track
var _species: String
var _groups: Array[Dictionary] = []
var _phase := 0.0
var _actor: Node3D
var _body: MeshInstance3D
var _legs: MeshInstance3D
var _alternate: MeshInstance3D


func setup(track: Track, scenery: Scenery, material: Material, stage_def: Dictionary) -> void:
	_track = track
	_species = REGIONAL_SPECIES[stage_def.loc_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stage_def.seed) * 23 + 39
	var meshes := _model()
	for station in range(130, int(track.finish_s) - 80, 290):
		for attempt in 12:
			var s := station + rng.randf_range(-25.0, 42.0)
			var i := track.index_at(s)
			var side := 1.0 if rng.randf() > 0.5 else -1.0
			var at := track.pts[i] + track.nrm[i] * side * (track.width * 0.5 + rng.randf_range(4.5, 10.0))
			if _species == "crab" and absf(track.terrain.height(at) - track.terrain.sea_y) > 7.0 and attempt < 8:
				continue
			var end := at + (track.tang[i] * 2.8 + track.nrm[i] * side * 1.3)
			if not _safe_route(at, end, scenery):
				continue
			_groups.append({"s": s, "a": at, "b": end, "phase": rng.randf() * TAU})
			break
	# Neighbouring groups are more than 190 m apart, so only one actor can
	# ever be within an active stretch of road.
	_actor = Node3D.new()
	_actor.name = _species.capitalize()
	_actor.visible = false
	add_child(_actor)
	_body = _piece(_actor, meshes[0], material)
	_legs = _piece(_actor, meshes[1], material)
	_alternate = _piece(_actor, meshes[2], material)


func _safe_route(a: Vector2, b: Vector2, scenery: Scenery) -> bool:
	for f: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var p := a.lerp(b, f)
		if _track.clearance(p) < _track.width * 0.5 + 3.5 or not _track.terrain.supports_prop(p, 1.05) or _track.overlaps_water(p, 1.2):
			return false
		for o in scenery.solids_near(p):
			if p.distance_to(Vector2(o[0], o[1])) < float(o[2]) + 0.9:
				return false
	return true


func _piece(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func update(delta: float, focus: Vector3, station: float) -> void:
	_phase += delta
	_actor.visible = false
	for group in _groups:
		if absf(group.s - station) >= 95.0 or Vector2(focus.x, focus.z).distance_squared_to(group.a) >= 78.0 * 78.0:
			continue
		var cycle := _phase * (0.87 if _species == "chamois" else 1.35) + float(group.phase)
		var amount := 0.5 - 0.50 * cos(cycle)
		var dir: Vector2 = group.a.direction_to(group.b) * signf(sin(cycle))
		var p: Vector2 = group.a.lerp(group.b, amount)
		var gait := cycle * 6.0
		var hop := absf(sin(gait)) * (0.13 if _species in ["hare", "snow_hare", "squirrel"] else 0.025)
		_actor.position = Vector3(p.x, _track.terrain.height(p) + hop, p.y)
		_actor.rotation.y = atan2(dir.x, dir.y) + (PI * 0.5 if _species == "crab" else 0.0)
		_body.rotation.x = sin(gait) * 0.10
		_legs.rotation.x = sin(gait) * 0.38
		_alternate.rotation.x = -_legs.rotation.x
		_actor.visible = true
		break


func _model() -> Array[Mesh]:
	var shell := PaperKit.Builder.new(42)
	var legs := PaperKit.Builder.new(43)
	var alternate := PaperKit.Builder.new(44)
	var ink: Color = {"hare": Color("#a17d59"), "snow_hare": Color("#ddd8ce"),
		"lizard": Color("#88906b"), "squirrel": Color("#b36f47"), "fox": Color("#b5734c"),
		"crab": Color("#ab6858"), "chamois": Color("#a89277") }[_species]
	var z := 0.38
	var height := 0.32
	var width := 0.31
	if _species == "chamois":
		z = 0.70
		height = 0.77
		width = 0.35
	elif _species == "fox":
		z = 0.57
		height = 0.46
	elif _species in ["lizard", "crab"]:
		height = 0.15
		width = 0.58 if _species == "crab" else 0.28
	shell.box(Vector3(0, height, 0), Vector3(width, height * 0.58, z), Transform3D.IDENTITY, ink)
	var head := Vector3(0, height * 1.30, z * 0.44)
	shell.box(head, Vector3(width * 0.72, height * 0.43, 0.25), Transform3D.IDENTITY, ink.lightened(0.16))
	shell.box(head + Vector3(0, -0.035, 0.13), Vector3(width * 0.48, 0.08, 0.12), Transform3D.IDENTITY, ink.lightened(0.29))
	for side: float in [-1, 1]:
		var face := head + Vector3(side * width * 0.365, 0.02, 0.055)
		shell.box(face, Vector3(0.024, 0.044, 0.05), Transform3D.IDENTITY, Color("#3a3230"))
		var ear := 0.25 if _species in ["hare", "snow_hare", "chamois"] else 0.12
		if _species not in ["lizard", "crab"]:
			shell.box(Vector3.ZERO, Vector3(0.065, ear, 0.064),
				Transform3D(Basis(Vector3.BACK, -side * 0.22), face + Vector3(0, ear * 0.52, -0.08)), ink.darkened(0.18))
		for fore: float in [-1, 1]:
			var builder := legs if side * fore > 0.0 else alternate
			var leg_pos := Vector3(side * width * 0.42, height * 0.42, fore * z * 0.30)
			builder.box(leg_pos, Vector3(0.09, height * 0.78, 0.11), Transform3D.IDENTITY, ink.darkened(0.19))
		if _species == "crab":
			shell.box(Vector3(side * 0.38, 0.18, 0.19), Vector3(0.29, 0.11, 0.16), Transform3D.IDENTITY, ink.lightened(0.13))
	if _species in ["fox","squirrel","lizard"]:
		var tail_y := height + (0.16 if _species == "squirrel" else -0.015)
		shell.box(Vector3.ZERO, Vector3(width * 0.55, 0.095, z * 0.94),
			Transform3D(Basis(Vector3.RIGHT, 0.35 if _species == "squirrel" else -0.12), Vector3(0, tail_y, -z * 0.82)), ink.darkened(0.09))
	elif _species in ["hare", "snow_hare"]:
		shell.box(Vector3(0, height, -z * 0.58), Vector3(0.12, 0.11, 0.12), Transform3D.IDENTITY, ink.lightened(0.36))
	return [shell.mesh(), legs.mesh(), alternate.mesh()]
