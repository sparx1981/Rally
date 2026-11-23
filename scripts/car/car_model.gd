class_name CarModel
extends RefCounted
## Builds a small folded-paper rally car (~20 cards): a folded body box, a cabin with printed windows,
## livery stripes, a door roundel, a light pod, mud flaps, a rear wing and octagonal card wheels.

const WHEEL_R := 0.4


## Returns {"root": Node3D, "body": Node3D, "wheels": [fl, fr, rl, rr]}
static func build(car: Dictionary, number: int, mat: Material) -> Dictionary:
	var style: String = car["style"]
	var body_c: Color = car["body"]
	var acc: Color = car["accent"]
	var stripe: Color = car["stripe"]
	var L := 4.0
	var W := 1.9
	var low_h := 0.62
	var cab_h := 0.55
	var cab_l := 1.9
	var cab_z := -0.25
	var ride := 0.32
	match style:
		"hatch":
			L = 3.6; cab_l = 1.8; cab_z = -0.45; cab_h = 0.6
		"coupe":
			L = 4.1; low_h = 0.55; cab_h = 0.45; cab_l = 1.7; cab_z = -0.35
		"suv":
			L = 4.1; W = 2.0; low_h = 0.75; cab_h = 0.62; cab_l = 2.3; cab_z = -0.35; ride = 0.45
		"turbo":
			L = 4.0; low_h = 0.58; cab_h = 0.5; cab_l = 1.75; cab_z = -0.3
		"estate":
			L = 4.3; cab_l = 2.6; cab_z = -0.6; cab_h = 0.58
	var b := PaperKit.Builder.new(number * 13 + 1)
	var I := Transform3D()
	var y0 := ride
	# Lower body (a folded box) with a slightly darker sill.
	b.box(Vector3(0, y0 + low_h * 0.5, 0), Vector3(W, low_h, L), I, body_c, body_c.lightened(0.06))
	# Cabin, slightly narrower; windows printed as cards with dark cut edges.
	var cy := y0 + low_h + cab_h * 0.5
	var cw := W * 0.86
	b.box(Vector3(0, cy, cab_z), Vector3(cw, cab_h, cab_l), I, body_c, body_c.lightened(0.1))
	var glass := Color("#5a6f80")
	for xs in [1.0, -1.0]:
		var side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (cw * 0.5 + 0.015), 0, 0))
		var win := PaperKit.rrect(cab_l * 0.82, cab_h * 0.62, 0.08, -cab_z * xs, cy - cab_h * 0.28)
		b.card(win, side, glass, {"thick": 0.02, "edge": 0.03, "lip": 0.03})
		# Door roundel with the car number dots, and a livery stripe along the body.
		var body_side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.015), 0, 0))
		b.card(PaperKit.rrect(L * 0.92, low_h * 0.22, 0.05, 0, y0 + low_h * 0.42), body_side, stripe, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
		b.card(PaperKit.circle(low_h * 0.3, -cab_z * xs * 0.3, y0 + low_h * 0.55, 14), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
		for d in mini(number, 4):
			var dot := PaperKit.circle(0.045, -cab_z * xs * 0.3 - 0.1 + d * 0.07, y0 + low_h * 0.55, 6)
			b.card(dot, body_side * Transform3D(Basis(), Vector3(0, 0, 0.035)), Color("#2e2a28"), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
	var front := Transform3D(Basis(), Vector3(0, 0, L * 0.5 + 0.015))
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -L * 0.5 - 0.015))
	var cab_front := Transform3D(Basis(), Vector3(0, 0, cab_z + cab_l * 0.5 + 0.015))
	var cab_back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, cab_z - cab_l * 0.5 - 0.015))
	b.card(PaperKit.rrect(cw * 0.86, cab_h * 0.66, 0.08, 0, cy - cab_h * 0.3), cab_front, glass, {"thick": 0.02, "edge": 0.03})
	b.card(PaperKit.rrect(cw * 0.8, cab_h * 0.55, 0.08, 0, cy - cab_h * 0.25), cab_back, glass, {"thick": 0.02, "edge": 0.03})
	# Lights: cream headlamps, red tail lamps, a grille.
	for xs in [1.0, -1.0]:
		b.card(PaperKit.rrect(W * 0.22, low_h * 0.28, 0.06, xs * W * 0.32, y0 + low_h * 0.55), front, Color("#f6ecd0"), {"thick": 0.02, "edge": 0.025, "lip": 0.0})
		b.card(PaperKit.rrect(W * 0.2, low_h * 0.22, 0.05, xs * W * 0.33, y0 + low_h * 0.58), back, Color("#b8402e"), {"thick": 0.02, "edge": 0.025, "lip": 0.0})
	b.card(PaperKit.rrect(W * 0.32, low_h * 0.26, 0.05, 0, y0 + low_h * 0.5), front, Color("#3a3430"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	# Bonnet stripe + roof stripe (accent).
	var top_y := y0 + low_h + 0.012
	var bonnet := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top_y, 0))
	var bon_len := L * 0.5 - (cab_z + cab_l * 0.5)
	b.card(PaperKit.rect(W * 0.24, bon_len * 0.9, 0, -(L * 0.5) + 0.05), bonnet, acc, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
	var roof := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, y0 + low_h + cab_h + 0.012, 0))
	b.card(PaperKit.rect(cw * 0.24, cab_l * 0.9, 0, -cab_z - cab_l * 0.45), roof, acc, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
	# Rally light pod on the bonnet front.
	var pod_z := L * 0.5 - 0.35
	b.box(Vector3(0, top_y + 0.1, pod_z), Vector3(W * 0.7, 0.16, 0.16), I, Color("#3a3430"))
	for k in 4:
		var lx := -W * 0.27 + k * W * 0.18
		b.card(PaperKit.circle(0.1, lx, top_y + 0.12, 10), Transform3D(Basis(), Vector3(0, 0, pod_z + 0.09)), Color("#fff4d6"), {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	# Rear wing (not on the estate).
	if style != "estate":
		var wy := y0 + low_h + (0.42 if style != "hatch" else 0.3)
		var wz := -L * 0.5 + 0.25
		for xs in [-0.55, 0.55]:
			b.card(PaperKit.rect(0.08, wy - (y0 + low_h), 0, 0), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xs, y0 + low_h, wz)), Color("#3a3430"), {"thick": 0.04, "edge": 0.0, "lip": 0.0})
		b.slab(Vector3(-W * 0.5, wy, wz - 0.25), Vector3(W * 0.5, wy, wz - 0.25), Vector3(W * 0.5, wy + 0.06, wz + 0.2), Vector3(-W * 0.5, wy + 0.06, wz + 0.2), 0.05, acc)
	# Mud flaps.
	for xs in [1.0, -1.0]:
		for zs in [1.0, -1.0]:
			var fz = zs * (L * 0.5 - 0.8) - 0.52
			var flap := Transform3D(Basis(), Vector3(xs * (W * 0.5 - 0.22), 0.05, fz))
			b.card(PaperKit.rrect(0.42, ride + 0.1, 0.04, 0, 0), flap, Color("#2e2a28") if zs > 0 else acc, {"thick": 0.03, "edge": 0.02, "lip": 0.0})

	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	body.add_child(mi)
	var wheel_mesh := _wheel_mesh(acc)
	var wheels: Array = []
	var wx := W * 0.5 - 0.12
	var wz := L * 0.5 - 0.8
	for pos in [Vector3(wx, WHEEL_R, wz), Vector3(-wx, WHEEL_R, wz), Vector3(wx, WHEEL_R, -wz), Vector3(-wx, WHEEL_R, -wz)]:
		var steer := Node3D.new()
		steer.position = pos
		var spin := Node3D.new()
		steer.add_child(spin)
		var wmi := MeshInstance3D.new()
		wmi.mesh = wheel_mesh
		wmi.material_override = mat
		if pos.x < 0.0:
			wmi.rotation.y = PI
		spin.add_child(wmi)
		root.add_child(steer)
		wheels.append(steer)
	return {"root": root, "body": body, "wheels": wheels, "length": L, "width": W}


static func _wheel_mesh(hub: Color) -> ArrayMesh:
	var b := PaperKit.Builder.new(5)
	var oct := PackedVector2Array()
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		oct.append(Vector2(cos(a), sin(a)) * WHEEL_R)
	var side := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	b.card(oct, side, Color("#2b2420"), {"thick": 0.3, "edge": 0.03, "lip": 0.0})
	var hub_p := PaperKit.circle(WHEEL_R * 0.5, 0, 0, 10)
	b.card(hub_p, side * Transform3D(Basis(), Vector3(0, 0, 0.16)), hub, {"thick": 0.02, "edge": 0.025, "lip": 0.03})
	b.card(PaperKit.circle(WHEEL_R * 0.18, 0, 0, 8), side * Transform3D(Basis(), Vector3(0, 0, 0.18)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return b.mesh()
