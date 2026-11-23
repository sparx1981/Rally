class_name CarModel
extends RefCounted
## Builds small folded-paper rally cars in many era styles: a folded body box, a cabin with printed
## windows, box arches, wings, light pods, sponsor patches, a door roundel, mud flaps and octagonal
## card wheels. The dune buggy is a tube frame and the trophy truck has an open bed.

const WHEEL_R := 0.4

## Shape table: L length, W width, low body height, cab height/length/offset, ride height, wheel
## radius, wing, arches, lamps pod, round headlights, chrome bumpers, nose drop (wedge).
const STYLES := {
	"classic": {"L": 3.9, "W": 1.7, "low": 0.55, "cab_h": 0.5, "cab_l": 1.6, "cab_z": -0.35, "ride": 0.3, "wr": 0.36, "wing": "none", "arches": false, "pod": false, "round": true, "bumpers": true, "nose": 0.12},
	"hatch": {"L": 3.6, "W": 1.8, "low": 0.62, "cab_h": 0.6, "cab_l": 1.8, "cab_z": -0.45, "ride": 0.32, "wr": 0.38, "wing": "small", "arches": false, "pod": true, "round": true, "bumpers": false, "nose": 0.0},
	"saloon70": {"L": 4.2, "W": 1.8, "low": 0.62, "cab_h": 0.6, "cab_l": 2.0, "cab_z": -0.2, "ride": 0.34, "wr": 0.38, "wing": "none", "arches": false, "pod": true, "round": true, "bumpers": true, "nose": 0.0},
	"groupb_rwd": {"L": 4.0, "W": 2.0, "low": 0.5, "cab_h": 0.42, "cab_l": 1.5, "cab_z": 0.1, "ride": 0.3, "wr": 0.4, "wing": "big", "arches": true, "pod": false, "round": false, "bumpers": false, "nose": 0.2},
	"groupb": {"L": 3.9, "W": 2.05, "low": 0.6, "cab_h": 0.55, "cab_l": 1.8, "cab_z": -0.35, "ride": 0.33, "wr": 0.41, "wing": "huge", "arches": true, "pod": true, "round": false, "bumpers": false, "nose": 0.05},
	"groups": {"L": 4.0, "W": 2.0, "low": 0.45, "cab_h": 0.4, "cab_l": 1.4, "cab_z": 0.0, "ride": 0.28, "wr": 0.4, "wing": "big", "arches": true, "pod": false, "round": false, "bumpers": false, "nose": 0.25},
	"saloon": {"L": 4.0, "W": 1.9, "low": 0.62, "cab_h": 0.55, "cab_l": 1.9, "cab_z": -0.25, "ride": 0.32, "wr": 0.4, "wing": "small", "arches": false, "pod": true, "round": false, "bumpers": false, "nose": 0.0},
	"coupe": {"L": 4.1, "W": 1.9, "low": 0.55, "cab_h": 0.45, "cab_l": 1.7, "cab_z": -0.35, "ride": 0.3, "wr": 0.4, "wing": "small", "arches": false, "pod": false, "round": false, "bumpers": false, "nose": 0.05},
	"turbo": {"L": 4.0, "W": 1.95, "low": 0.58, "cab_h": 0.5, "cab_l": 1.75, "cab_z": -0.3, "ride": 0.32, "wr": 0.4, "wing": "big", "arches": true, "pod": false, "round": false, "bumpers": false, "nose": 0.0},
	"rally2": {"L": 3.9, "W": 1.9, "low": 0.6, "cab_h": 0.55, "cab_l": 1.8, "cab_z": -0.35, "ride": 0.32, "wr": 0.4, "wing": "small", "arches": true, "pod": false, "round": false, "bumpers": false, "nose": 0.0},
	"rally1": {"L": 4.1, "W": 2.0, "low": 0.6, "cab_h": 0.52, "cab_l": 1.8, "cab_z": -0.3, "ride": 0.32, "wr": 0.42, "wing": "huge", "arches": true, "pod": false, "round": false, "bumpers": false, "nose": 0.0},
	"estate": {"L": 4.3, "W": 1.85, "low": 0.62, "cab_h": 0.58, "cab_l": 2.6, "cab_z": -0.6, "ride": 0.32, "wr": 0.38, "wing": "none", "arches": false, "pod": true, "round": false, "bumpers": false, "nose": 0.0},
	"suv": {"L": 4.1, "W": 2.0, "low": 0.75, "cab_h": 0.62, "cab_l": 2.3, "cab_z": -0.35, "ride": 0.45, "wr": 0.46, "wing": "none", "arches": true, "pod": true, "round": true, "bumpers": true, "nose": 0.0},
	"truck": {"L": 4.6, "W": 2.15, "low": 0.7, "cab_h": 0.62, "cab_l": 1.6, "cab_z": 0.45, "ride": 0.6, "wr": 0.55, "wing": "none", "arches": true, "pod": true, "round": false, "bumpers": true, "nose": 0.0},
	"buggy": {"L": 3.4, "W": 1.8, "low": 0.25, "cab_h": 0.9, "cab_l": 1.5, "cab_z": -0.1, "ride": 0.45, "wr": 0.48, "wing": "none", "arches": false, "pod": true, "round": true, "bumpers": false, "nose": 0.0},
}

const SPONSOR_COLS := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#2b2b2b")]


## Returns {"root", "body", "wheels" [fl, fr, rl, rr], "length", "width", "wheel_r", "head" (driver eye),
## "lamp" (headlight position, local)}
static func build(car: Dictionary, number: int, mat: Material) -> Dictionary:
	var style: String = car.get("style", "saloon")
	var P: Dictionary = STYLES.get(style, STYLES["saloon"])
	var body_c: Color = car["body"]
	var acc: Color = car["accent"]
	var stripe: Color = car["stripe"]
	var L: float = P["L"]
	var W: float = P["W"]
	var low_h: float = P["low"]
	var cab_h: float = P["cab_h"]
	var cab_l: float = P["cab_l"]
	var cab_z: float = P["cab_z"]
	var ride: float = P["ride"]
	var wr: float = P["wr"]
	var b := PaperKit.Builder.new(number * 13 + 1)
	var I := Transform3D()
	var y0 := ride
	var ink := Color("#2e2a28")
	var glass := Color("#5a6f80")
	var top_y := y0 + low_h
	if style == "buggy":
		_buggy(b, P, body_c, acc, stripe)
	else:
		# Lower body: a folded box (a wedge for the mid-engined cars via a sloping bonnet slab).
		b.box(Vector3(0, y0 + low_h * 0.5, 0), Vector3(W, low_h, L), I, body_c, body_c.lightened(0.06))
		var nose: float = P["nose"]
		if nose > 0.0:
			b.slab(Vector3(-W * 0.5, top_y + 0.01, L * 0.5 - 0.05), Vector3(W * 0.5, top_y + 0.01, L * 0.5 - 0.05),
				Vector3(W * 0.5, top_y + nose, cab_z + cab_l * 0.5), Vector3(-W * 0.5, top_y + nose, cab_z + cab_l * 0.5), 0.05, body_c)
		# Cabin and printed windows.
		var cw := W * 0.86
		var cy := top_y + cab_h * 0.5
		if style == "truck":
			_truck_bed(b, P, body_c, acc)
		b.box(Vector3(0, cy, cab_z), Vector3(cw, cab_h, cab_l), I, body_c, body_c.lightened(0.1))
		for xs in [1.0, -1.0]:
			var side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (cw * 0.5 + 0.015), 0, 0))
			var win := PaperKit.rrect(cab_l * 0.82, cab_h * 0.62, 0.08 if not P["round"] else 0.16, -cab_z * xs, cy - cab_h * 0.28)
			b.card(win, side, glass, {"thick": 0.02, "edge": 0.03, "lip": 0.03})
			var body_side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.015), 0, 0))
			# Livery stripe, sponsor patches and the door roundel.
			b.card(PaperKit.rrect(L * 0.92, low_h * 0.2, 0.05, 0, y0 + low_h * 0.42), body_side, stripe, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
			b.card(PaperKit.circle(low_h * 0.28, -cab_z * xs * 0.3, y0 + low_h * 0.58, 14), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
			for d in mini(number, 4):
				var dot := PaperKit.circle(0.045, -cab_z * xs * 0.3 - 0.1 + d * 0.07, y0 + low_h * 0.58, 6)
				b.card(dot, body_side * Transform3D(Basis(), Vector3(0, 0, 0.035)), ink, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
			for k in 2:
				var px = (L * 0.32 - k * L * 0.64) * xs
				var sc: Color = SPONSOR_COLS[(number + k) % SPONSOR_COLS.size()]
				b.card(PaperKit.rrect(0.62, 0.2, 0.04, px, y0 + low_h * 0.72), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.015, "lip": 0.0})
				b.card(PaperKit.rect(0.46, 0.07, px, y0 + low_h * 0.72 + 0.065), body_side * Transform3D(Basis(), Vector3(0, 0, 0.03)), sc, {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
		var front := Transform3D(Basis(), Vector3(0, 0, L * 0.5 + 0.015))
		var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -L * 0.5 - 0.015))
		var cab_front := Transform3D(Basis(), Vector3(0, 0, cab_z + cab_l * 0.5 + 0.015))
		var cab_back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, cab_z - cab_l * 0.5 - 0.015))
		b.card(PaperKit.rrect(cw * 0.86, cab_h * 0.66, 0.08, 0, cy - cab_h * 0.3), cab_front, glass, {"thick": 0.02, "edge": 0.03})
		if style != "truck":
			b.card(PaperKit.rrect(cw * 0.8, cab_h * 0.55, 0.08, 0, cy - cab_h * 0.25), cab_back, glass, {"thick": 0.02, "edge": 0.03})
		# Lamps: cream headlamps (round on the older cars), red tail lamps, a grille.
		for xs in [1.0, -1.0]:
			if P["round"]:
				b.card(PaperKit.circle(low_h * 0.17, xs * W * 0.32, y0 + low_h * 0.6, 12), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
			else:
				b.card(PaperKit.rrect(W * 0.24, low_h * 0.22, 0.05, xs * W * 0.31, y0 + low_h * 0.6), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
			b.card(PaperKit.rrect(W * 0.2, low_h * 0.2, 0.05, xs * W * 0.33, y0 + low_h * 0.6), back, Color("#d84a32"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
		b.card(PaperKit.rrect(W * 0.32, low_h * 0.26, 0.05, 0, y0 + low_h * 0.42), front, Color("#3a3430"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
		if P["bumpers"]:
			b.box(Vector3(0, y0 + 0.08, L * 0.5 + 0.08), Vector3(W * 0.96, 0.14, 0.14), I, Color("#d8d4cc"))
			b.box(Vector3(0, y0 + 0.08, -L * 0.5 - 0.08), Vector3(W * 0.96, 0.14, 0.14), I, Color("#d8d4cc"))
		else:
			# Splitter.
			b.slab(Vector3(-W * 0.5, y0 + 0.02, L * 0.5 + 0.18), Vector3(W * 0.5, y0 + 0.02, L * 0.5 + 0.18), Vector3(W * 0.5, y0 + 0.02, L * 0.5 - 0.1), Vector3(-W * 0.5, y0 + 0.02, L * 0.5 - 0.1), 0.04, ink)
		# Bonnet and roof stripes.
		var bonnet := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top_y + 0.012 + P["nose"] * 0.5, 0))
		var bon_len := L * 0.5 - (cab_z + cab_l * 0.5)
		if bon_len > 0.3:
			b.card(PaperKit.rect(W * 0.24, bon_len * 0.9, 0, -(L * 0.5) + 0.05), bonnet, acc, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
		var roof := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top_y + cab_h + 0.012, 0))
		b.card(PaperKit.rect(cw * 0.24, cab_l * 0.9, 0, -cab_z - cab_l * 0.45), roof, acc, {"thick": 0.015, "edge": 0.02, "lip": 0.0})
		# Box arches over the wheels.
		if P["arches"]:
			for xs in [1.0, -1.0]:
				for zs in [1.0, -1.0]:
					var az = zs * (L * 0.5 - 0.8)
					b.box(Vector3(xs * (W * 0.5 + 0.06), y0 + low_h * 0.55, az), Vector3(0.16, low_h * 0.7, wr * 2.6), I, body_c.darkened(0.06), body_c)
		# Wings.
		var wing: String = P["wing"]
		if wing != "none":
			var wy: float = top_y + {"small": 0.28, "big": 0.45, "huge": 0.62}[wing]
			var wz := -L * 0.5 + 0.25
			var span: float = W * (0.9 if wing == "small" else 1.05)
			for xs in [-0.5, 0.5]:
				b.card(PaperKit.rect(0.08, wy - top_y, 0, 0), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xs * span * 0.9, top_y, wz)), ink, {"thick": 0.04, "edge": 0.0, "lip": 0.0})
			var chord: float = {"small": 0.4, "big": 0.5, "huge": 0.65}[wing]
			b.slab(Vector3(-span * 0.5, wy, wz - chord * 0.5), Vector3(span * 0.5, wy, wz - chord * 0.5), Vector3(span * 0.5, wy + 0.08, wz + chord * 0.5), Vector3(-span * 0.5, wy + 0.08, wz + chord * 0.5), 0.05, acc)
			if wing == "huge":
				for xs in [-0.5, 0.5]:
					b.card(PaperKit.rrect(chord * 1.2, 0.36, 0.05, 0, wy - 0.12), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xs * span, 0, wz)), acc.darkened(0.2), {"thick": 0.03, "edge": 0.02, "lip": 0.0})
		# Rally lamp pod.
		if P["pod"]:
			var pod_z := L * 0.5 - 0.35
			var pod_y = top_y + 0.1 + P["nose"]
			if style == "truck":
				pod_z = cab_z + cab_l * 0.5 - 0.1
				pod_y = top_y + cab_h + 0.12
			b.box(Vector3(0, pod_y, pod_z), Vector3(W * 0.7, 0.16, 0.16), I, ink)
			for k in 4:
				var lx := -W * 0.27 + k * W * 0.18
				b.card(PaperKit.circle(0.1, lx, pod_y + 0.02, 10), Transform3D(Basis(), Vector3(0, 0, pod_z + 0.09)), Color("#fff4d6"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
		# Mud flaps.
		for xs in [1.0, -1.0]:
			for zs in [1.0, -1.0]:
				var fz = zs * (L * 0.5 - 0.8) - wr - 0.12
				b.card(PaperKit.rrect(0.42, ride + 0.1, 0.04, 0, 0), Transform3D(Basis(), Vector3(xs * (W * 0.5 - 0.22), 0.05, fz)), ink if zs > 0 else acc, {"thick": 0.03, "edge": 0.02, "lip": 0.0})

	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	body.add_child(mi)
	var wheel_mesh := _wheel_mesh(acc, wr, 0.42 if style in ["buggy", "truck", "suv"] else 0.3)
	var wheels: Array = []
	var wx := W * 0.5 - 0.12 + (0.2 if style == "buggy" else 0.0)
	var wz := L * 0.5 - 0.8
	for p in [Vector3(wx, wr, wz), Vector3(-wx, wr, wz), Vector3(wx, wr, -wz), Vector3(-wx, wr, -wz)]:
		var steer := Node3D.new()
		steer.position = p
		var spin := Node3D.new()
		steer.add_child(spin)
		var wmi := MeshInstance3D.new()
		wmi.mesh = wheel_mesh
		wmi.material_override = mat
		if p.x < 0.0:
			wmi.rotation.y = PI
		spin.add_child(wmi)
		root.add_child(steer)
		wheels.append(steer)
	var head := Vector3(0.35, top_y + cab_h * 0.55, cab_z + cab_l * 0.12)
	if style == "buggy":
		head = Vector3(0.0, y0 + 1.0, 0.0)
	return {"root": root, "body": body, "wheels": wheels, "length": L, "width": W, "wheel_r": wr, "head": head,
		"lamp": Vector3(0, y0 + low_h * 0.6, L * 0.5 + 0.1), "style": style}


## Dune buggy: floor pan, tube roll cage, seat, rear engine, nose panel, spare wheel and a whip flag.
static func _buggy(b: PaperKit.Builder, P: Dictionary, body_c: Color, acc: Color, stripe: Color) -> void:
	var L: float = P["L"]
	var W: float = P["W"]
	var y0: float = P["ride"]
	var ink := Color("#2e2a28")
	var I := Transform3D()
	b.box(Vector3(0, y0 + 0.08, 0), Vector3(W * 0.7, 0.16, L * 0.9), I, ink)
	var tube := func(a: Vector3, c: Vector3) -> void:
		var mid := (a + c) * 0.5
		var d := c - a
		var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
		b.box(Vector3.ZERO, Vector3(0.09, 0.09, d.length()), Transform3D(basis, mid), body_c)
	var top := y0 + 1.25
	for xs in [-1.0, 1.0]:
		var x = xs * W * 0.33
		tube.call(Vector3(x, y0 + 0.15, 0.55), Vector3(x * 0.85, top, 0.15))
		tube.call(Vector3(x * 0.85, top, 0.15), Vector3(x * 0.85, top, -0.55))
		tube.call(Vector3(x * 0.85, top, -0.55), Vector3(x, y0 + 0.15, -0.9))
		tube.call(Vector3(x, y0 + 0.15, 0.55), Vector3(x, y0 + 0.15, L * 0.45))
	tube.call(Vector3(-W * 0.28, top, 0.15), Vector3(W * 0.28, top, 0.15))
	tube.call(Vector3(-W * 0.28, top, -0.55), Vector3(W * 0.28, top, -0.55))
	# Nose panel, seat, engine, roof panel.
	b.slab(Vector3(-W * 0.32, y0 + 0.2, L * 0.48), Vector3(W * 0.32, y0 + 0.2, L * 0.48), Vector3(W * 0.3, y0 + 0.5, 0.6), Vector3(-W * 0.3, y0 + 0.5, 0.6), 0.05, acc)
	b.box(Vector3(0, y0 + 0.45, -0.2), Vector3(0.6, 0.5, 0.5), I, ink)
	b.box(Vector3(0, y0 + 0.4, -1.15), Vector3(0.8, 0.5, 0.7), I, Color("#8a8a8a"), Color("#6a6a6a"))
	b.slab(Vector3(-W * 0.3, top + 0.04, 0.2), Vector3(W * 0.3, top + 0.04, 0.2), Vector3(W * 0.3, top + 0.04, -0.6), Vector3(-W * 0.3, top + 0.04, -0.6), 0.04, stripe)
	b.box(Vector3(0, y0 + 0.7, -1.55), Vector3(0.7, 0.7, 0.18), I, ink)
	# Whip flag.
	b.box(Vector3(W * 0.3, top + 0.8, -0.6), Vector3(0.03, 1.6, 0.03), I, ink)
	b.card(PackedVector2Array([Vector2(0, 0), Vector2(0.45, 0.12), Vector2(0, 0.26)]), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(W * 0.3, top + 1.35, -0.6)), Color("#e8b04a"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	for xs in [1.0, -1.0]:
		b.card(PaperKit.circle(0.1, xs * W * 0.22, y0 + 0.42, 10), Transform3D(Basis(), Vector3(0, 0, L * 0.48 + 0.04)), Color("#fff0c8"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})


## Trophy truck: an open bed with sides behind the cab and a spare wheel.
static func _truck_bed(b: PaperKit.Builder, P: Dictionary, body_c: Color, acc: Color) -> void:
	var L: float = P["L"]
	var W: float = P["W"]
	var top_y: float = float(P["ride"]) + float(P["low"])
	var cab_z: float = P["cab_z"]
	var cab_l: float = P["cab_l"]
	var bed_front := cab_z - cab_l * 0.5
	var bed_len := bed_front + L * 0.5
	for xs in [1.0, -1.0]:
		b.box(Vector3(xs * W * 0.45, top_y + 0.2, bed_front - bed_len * 0.5), Vector3(0.1, 0.4, bed_len), Transform3D(), body_c.darkened(0.08))
	b.box(Vector3(0, top_y + 0.2, -L * 0.5 + 0.05), Vector3(W * 0.9, 0.4, 0.1), Transform3D(), body_c.darkened(0.08))
	b.box(Vector3(0, top_y + 0.32, bed_front - bed_len * 0.5), Vector3(1.1, 0.4, 1.1), Transform3D(), Color("#2b2420"))
	b.card(PaperKit.circle(0.28, 0, 0, 10), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top_y + 0.53, bed_front - bed_len * 0.5)), acc, {"thick": 0.02, "edge": 0.02, "lip": 0.0})


static func _wheel_mesh(hub: Color, r: float, width: float) -> ArrayMesh:
	var b := PaperKit.Builder.new(5)
	var oct := PackedVector2Array()
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		oct.append(Vector2(cos(a), sin(a)) * r)
	var side := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	b.card(oct, side, Color("#2b2420"), {"thick": width, "edge": 0.03, "lip": 0.0})
	var hub_p := PaperKit.circle(r * 0.5, 0, 0, 10)
	b.card(hub_p, side * Transform3D(Basis(), Vector3(0, 0, width * 0.5 + 0.01)), hub, {"thick": 0.02, "edge": 0.025, "lip": 0.03})
	b.card(PaperKit.circle(r * 0.18, 0, 0, 8), side * Transform3D(Basis(), Vector3(0, 0, width * 0.5 + 0.03)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return b.mesh()
