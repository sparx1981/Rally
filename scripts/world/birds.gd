class_name Birds
extends Node3D
## Paper birds that live in the world, not around the camera. Flocks perch at fixed spots along the
## stage, pecking and hopping. When a car comes close they burst up, fleeing away from it with hard
## wingbeats, climb, circle their home with flap-and-glide bursts while banking into the turns, then
## glide back down and land with a flare once the road is quiet again.

enum S { PERCH, FLEE, CIRCLE, LAND }

const SCARE_DIST := 20.0
const ACTIVE_DIST := 150.0

var _flocks: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(track: Track, mat: Material, seed_v: int, rain: bool, region: String) -> void:
	_rng.seed = seed_v * 17 + 9
	var coastal := region in ["harbour", "cliffs"]
	var body := _body_mesh(coastal)
	var wing_l := _wing_mesh(1.0, coastal)
	var wing_r := _wing_mesh(-1.0, coastal)
	var s := 90.0
	while s < track.length - 60.0:
		var i := track.index_at(s)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var home2 := track.pts[i] + track.nrm[i] * side * _rng.randf_range(track.width * 0.5 + 6.0, track.width * 0.5 + 26.0)
		if not track.overlaps_water(home2, 5.5) and track.clearance(home2) > track.width * 0.5 + 4.0:
			var gy = track.terrain.height(home2) if track.terrain else 0.0
			var flock := {"home": Vector3(home2.x, gy, home2.y), "birds": [], "fled": false, "quiet": 0.0}
			var n := _rng.randi_range(3, 6) if not rain else _rng.randi_range(2, 3)
			for k in n:
				var perch: Vector3 = flock["home"] + Vector3(_rng.randf_range(-3.5, 3.5), 0.0, _rng.randf_range(-3.5, 3.5))
				if track.terrain:
					if track.terrain.is_sea(Vector2(perch.x, perch.z)):
						continue
					perch.y = track.terrain.height(Vector2(perch.x, perch.z))
				flock["birds"].append(_make_bird(body, wing_l, wing_r, mat, perch))
			if not flock["birds"].is_empty():
				_flocks.append(flock)
		s += _rng.randf_range(110.0, 220.0)


func _make_bird(body: Mesh, wl: Mesh, wr: Mesh, mat: Material, perch: Vector3) -> Dictionary:
	var node := Node3D.new()
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = mat
	node.add_child(bmi)
	var wings: Array = []
	for m in [wl, wr]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, 0.12, 0.05)
		var fold := Node3D.new()
		pivot.add_child(fold)
		var wmi := MeshInstance3D.new()
		wmi.mesh = m
		wmi.material_override = mat
		fold.add_child(wmi)
		node.add_child(pivot)
		wings.append(pivot)
	node.position = perch
	node.rotation.y = _rng.randf() * TAU
	node.visible = false
	add_child(node)
	return {"node": node, "wings": wings, "state": S.PERCH, "pos": perch, "perch": perch, "vel": Vector3.ZERO,
		"t": _rng.randf() * 3.0, "phase": _rng.randf() * TAU, "flap": 0.0, "bank": 0.0, "orbit": _rng.randf_range(9.0, 15.0),
		"alt": _rng.randf_range(7.0, 11.0), "dir": -1.0 if _rng.randf() < 0.5 else 1.0, "glide": 0.0}


## threats: positions of the cars. focus: where the camera looks (birds far from it are idle).
func update(dt: float, threats: Array, focus: Vector3) -> void:
	_time += dt
	for fl in _flocks:
		var home: Vector3 = fl["home"]
		var far := home.distance_to(focus) > ACTIVE_DIST
		var nearest := INF
		var threat := Vector3.ZERO
		for t in threats:
			var d := Vector2(t.x - home.x, t.z - home.z).length()
			if d < nearest:
				nearest = d
				threat = t
		if far and not fl["fled"]:
			for b in fl["birds"]:
				b["node"].visible = false
			continue
		if nearest < SCARE_DIST and not fl["fled"]:
			fl["fled"] = true
			fl["quiet"] = 0.0
			if home.distance_to(focus) < 60.0:
				Sfx.flutter(-10.0)
			for b in fl["birds"]:
				var away := Vector3(b["pos"].x - threat.x, 0.0, b["pos"].z - threat.z).normalized()
				b["vel"] = away * _rng.randf_range(6.0, 9.0) + Vector3.UP * _rng.randf_range(5.0, 7.5)
				b["state"] = S.FLEE
				b["t"] = _rng.randf_range(1.6, 2.4)
		if fl["fled"]:
			fl["quiet"] = float(fl["quiet"]) + dt if nearest > SCARE_DIST * 1.8 else 0.0
		var all_down := true
		for b in fl["birds"]:
			b["node"].visible = true
			_step_bird(b, fl, dt)
			if b["state"] != S.PERCH:
				all_down = false
		if fl["fled"] and all_down:
			fl["fled"] = false


func _step_bird(b: Dictionary, fl: Dictionary, dt: float) -> void:
	var home: Vector3 = fl["home"]
	var pos: Vector3 = b["pos"]
	var vel: Vector3 = b["vel"]
	var node: Node3D = b["node"]
	b["t"] = float(b["t"]) - dt
	var flap_amp := 0.0
	var flap_hz := 0.0
	var fold := 0.0
	match b["state"]:
		S.PERCH:
			fold = 1.0
			vel = Vector3.ZERO
			pos.y = float(b["perch"].y) + 0.02
			# Pecking: dip the whole body forward now and then; small hops to turn.
			var peck := maxf(0.0, sin(_time * 5.0 + float(b["phase"])))
			node.rotation.x = 0.35 * pow(peck, 6.0)
			if float(b["t"]) < 0.0:
				b["t"] = _rng.randf_range(1.5, 4.0)
				node.rotation.y += _rng.randf_range(-1.2, 1.2)
				pos += Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
		S.FLEE:
			flap_amp = 1.0
			flap_hz = 9.0
			vel += Vector3.UP * 4.0 * dt
			vel.y = minf(vel.y, 6.0)
			if pos.y > home.y + float(b["alt"]) or float(b["t"]) < 0.0:
				b["state"] = S.CIRCLE
				b["t"] = _rng.randf_range(6.0, 10.0)
		S.CIRCLE:
			var r: float = b["orbit"]
			var to_c := Vector3(pos.x - home.x, 0.0, pos.z - home.z)
			var ang := atan2(to_c.z, to_c.x) + float(b["dir"]) * 0.9
			var target := home + Vector3(cos(ang) * r, float(b["alt"]), sin(ang) * r)
			var desired := (target - pos).normalized() * 7.5
			vel = vel.lerp(desired, clampf(dt * 1.4, 0.0, 1.0))
			# Flap-and-glide: bursts of wingbeats, then a glide on held wings.
			b["glide"] = float(b["glide"]) - dt
			if float(b["glide"]) < -1.2:
				b["glide"] = _rng.randf_range(0.8, 1.8)
			if float(b["glide"]) < 0.0:
				flap_amp = 0.75
				flap_hz = 6.0
			if float(b["t"]) < 0.0 and float(fl["quiet"]) > 3.0:
				b["state"] = S.LAND
		S.LAND:
			var perch: Vector3 = b["perch"]
			var to_p := perch - pos
			var dist := to_p.length()
			var spd := clampf(dist * 0.8, 2.0, 7.0)
			vel = vel.lerp(to_p.normalized() * spd, clampf(dt * 2.0, 0.0, 1.0))
			flap_amp = 0.35 if dist > 4.0 else 0.6
			flap_hz = 4.0 if dist > 4.0 else 8.0
			if dist < 0.5 or pos.y <= perch.y + 0.05:
				b["state"] = S.PERCH
				b["t"] = _rng.randf_range(1.0, 3.0)
				pos = Vector3(perch.x, perch.y + 0.02, perch.z)
				node.rotation.y = atan2(vel.x, vel.z)
				vel = Vector3.ZERO
	pos += vel * dt
	if b["state"] != S.PERCH:
		pos.y = maxf(pos.y, float(b["perch"].y) + 0.05)
		var hv := Vector2(vel.x, vel.z)
		if hv.length() > 0.3:
			var new_yaw := atan2(vel.x, vel.z)
			var turn := wrapf(new_yaw - node.rotation.y, -PI, PI)
			node.rotation.y = lerp_angle(node.rotation.y, new_yaw, clampf(dt * 6.0, 0.0, 1.0))
			b["bank"] = lerpf(float(b["bank"]), clampf(-turn * 4.0, -0.6, 0.6), clampf(dt * 4.0, 0.0, 1.0))
		node.rotation.z = b["bank"]
		node.rotation.x = clampf(-vel.y * 0.06, -0.4, 0.4)
	b["pos"] = pos
	b["vel"] = vel
	node.position = pos
	# Wings: flap about the shoulder hinge, held in a slight V while gliding, folded back on the ground.
	b["flap"] = float(b["flap"]) + dt * flap_hz * TAU
	var beat := sin(float(b["flap"])) * flap_amp
	var dihedral := 0.22 if flap_amp == 0.0 else 0.1
	var fold_ang := 1.35 * fold
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var pivot: Node3D = b["wings"][k]
		pivot.rotation.z = side * (dihedral + beat * 0.9) if fold == 0.0 else side * 0.15
		pivot.get_child(0).rotation.y = side * fold_ang


# --- meshes: flat paper cards seen well from above ------------------------------------------------

static func _lay() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)


static func _body_mesh(coastal: bool) -> ArrayMesh:
	var b := PaperKit.Builder.new(3)
	var ink := Color("#ded7c9") if coastal else Color("#3a3430")
	var lay := _lay()
	# Body: a chunky teardrop along +Z (card Y maps to -Z, so mirror).
	var body := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		var rx := 0.16 * (1.0 + 0.25 * sin(a))
		body.append(Vector2(cos(a) * rx, -sin(a) * 0.42))
	b.card(body, Transform3D(Basis(), Vector3(0, 0.1, 0)) * lay, ink, {"thick": 0.05, "edge": 0.02, "lip": 0.0})
	b.card(PaperKit.circle(0.13, 0.0, -0.48, 10), Transform3D(Basis(), Vector3(0, 0.16, 0)) * lay, ink, {"thick": 0.05, "edge": 0.02, "lip": 0.0})
	b.card(PackedVector2Array([Vector2(-0.04, -0.6), Vector2(0.04, -0.6), Vector2(0.0, -0.72)]), Transform3D(Basis(), Vector3(0, 0.16, 0)) * lay, Color("#e8b04a"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	b.card(PackedVector2Array([Vector2(-0.16, 0.6), Vector2(0.16, 0.6), Vector2(0.05, 0.32), Vector2(-0.05, 0.32)]), Transform3D(Basis(), Vector3(0, 0.1, 0)) * lay, ink, {"thick": 0.03, "edge": 0.02, "lip": 0.0})
	return b.mesh()


static func _wing_mesh(side: float, coastal: bool) -> ArrayMesh:
	var b := PaperKit.Builder.new(5 if side > 0 else 6)
	var lay := _lay()
	var pts := PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.5, -0.28), Vector2(0.95, -0.12), Vector2(1.1, 0.06), Vector2(0.85, 0.2), Vector2(0.45, 0.3), Vector2(0.0, 0.3)])
	var tip := PackedVector2Array([Vector2(0.66, -0.18), Vector2(0.95, -0.12), Vector2(1.1, 0.06), Vector2(0.85, 0.2), Vector2(0.66, 0.22)])
	if coastal:
		for polygon in [pts, tip]:
			for i in polygon.size():
				polygon[i] = Vector2(polygon[i].x * 1.25, polygon[i].y + pow(polygon[i].x, 2.0) * 0.24)
	if side < 0:
		for i in pts.size():
			pts[i].x = -pts[i].x
		for i in tip.size():
			tip[i].x = -tip[i].x
	b.card(pts, lay, Color("#efe3c8") if coastal else Color("#645b53"), {"thick": 0.02, "edge": 0.025, "lip": 0.03})
	b.card(tip, lay * Transform3D(Basis(), Vector3(0, 0, 0.015)), Color("#5a4a3e"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return b.mesh()
