class_name CarModel
extends RefCounted
## Builds small folded-paper rally cars in many era styles: a folded body box, a cabin with printed
## windows, box arches, wings, light pods, sponsor patches, a door roundel, mud flaps and octagonal
## card wheels. The dune buggy is a tube frame and the trophy truck has an open bed.

const WHEEL_R := 0.4

## Shape table. Profiles are side views (z forward, y up) built from: L length, W width, low body
## height, nose (height at the front tip), bon (bonnet length), tail (height at the rear tip), deck
## (boot length), cab (cabin height), cab_f / cab_r (cabin base front / rear z), rake (windscreen
## lean), back (rear window lean; big = fastback), ride height, wr wheel radius. Detail flags: wing
## (none, small, boot, roof, big, huge, ducktail), arches (box flares), lamps (round, quad, rect,
## popup), scoop (bonnet scoop), louvres, pod (lamp pod), bumpers (chrome), roof2 (contrast roof).
const STYLES := {
	"classic": {"L": 3.9, "W": 1.7, "low": 0.55, "nose": 0.32, "bon": 1.2, "tail": 0.38, "deck": 0.7, "cab": 0.5, "cab_f": 0.35, "cab_r": -1.05, "rake": 0.42, "back": 0.6, "ride": 0.3, "wr": 0.36, "wing": "none", "arches": false, "lamps": "round", "bumpers": true},
	"mini": {"L": 3.1, "W": 1.6, "low": 0.62, "nose": 0.5, "bon": 0.55, "tail": 0.55, "deck": 0.18, "cab": 0.62, "cab_f": 0.55, "cab_r": -1.25, "rake": 0.22, "back": 0.08, "ride": 0.26, "wr": 0.3, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true, "roof2": true},
	"escort": {"L": 4.0, "W": 1.72, "low": 0.62, "nose": 0.52, "bon": 1.15, "tail": 0.56, "deck": 0.8, "cab": 0.58, "cab_f": 0.55, "cab_r": -1.05, "rake": 0.32, "back": 0.3, "ride": 0.32, "wr": 0.36, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true},
	"stratos": {"L": 3.7, "W": 1.9, "low": 0.5, "nose": 0.22, "bon": 1.2, "tail": 0.55, "deck": 0.7, "cab": 0.5, "cab_f": 0.5, "cab_r": -0.85, "rake": 0.85, "back": 0.3, "ride": 0.28, "wr": 0.4, "wing": "roof", "arches": true, "lamps": "popup", "louvres": true},
	"groupb_rwd": {"L": 4.0, "W": 2.0, "low": 0.52, "nose": 0.28, "bon": 1.3, "tail": 0.48, "deck": 0.9, "cab": 0.44, "cab_f": 0.45, "cab_r": -0.9, "rake": 0.6, "back": 0.5, "ride": 0.3, "wr": 0.4, "wing": "big", "arches": true, "lamps": "rect", "louvres": true},
	"quattro": {"L": 4.15, "W": 1.98, "low": 0.62, "nose": 0.5, "bon": 1.2, "tail": 0.58, "deck": 0.6, "cab": 0.56, "cab_f": 0.55, "cab_r": -1.25, "rake": 0.4, "back": 0.25, "ride": 0.33, "wr": 0.41, "wing": "huge", "arches": true, "lamps": "rect", "pod": true},
	"t16": {"L": 3.7, "W": 1.95, "low": 0.62, "nose": 0.48, "bon": 0.95, "tail": 0.56, "deck": 0.2, "cab": 0.56, "cab_f": 0.5, "cab_r": -1.35, "rake": 0.45, "back": 0.2, "ride": 0.33, "wr": 0.41, "wing": "roof", "arches": true, "lamps": "rect", "pod": true, "louvres": true},
	"groups": {"L": 4.0, "W": 2.0, "low": 0.46, "nose": 0.22, "bon": 1.3, "tail": 0.5, "deck": 0.9, "cab": 0.42, "cab_f": 0.4, "cab_r": -0.8, "rake": 0.75, "back": 0.55, "ride": 0.28, "wr": 0.4, "wing": "big", "arches": true, "lamps": "rect", "louvres": true},
	"gt4": {"L": 4.2, "W": 1.9, "low": 0.56, "nose": 0.36, "bon": 1.25, "tail": 0.5, "deck": 0.35, "cab": 0.48, "cab_f": 0.45, "cab_r": -1.15, "rake": 0.6, "back": 0.85, "ride": 0.31, "wr": 0.4, "wing": "boot", "arches": false, "lamps": "quad", "pod": true},
	"integrale": {"L": 3.9, "W": 1.95, "low": 0.62, "nose": 0.5, "bon": 1.0, "tail": 0.56, "deck": 0.15, "cab": 0.62, "cab_f": 0.55, "cab_r": -1.65, "rake": 0.38, "back": 0.12, "ride": 0.34, "wr": 0.41, "wing": "roof", "arches": true, "lamps": "quad", "pod": true, "louvres": true},
	"impreza": {"L": 4.35, "W": 1.9, "low": 0.62, "nose": 0.48, "bon": 1.2, "tail": 0.58, "deck": 0.7, "cab": 0.56, "cab_f": 0.5, "cab_r": -1.2, "rake": 0.45, "back": 0.4, "ride": 0.34, "wr": 0.41, "wing": "boot_high", "arches": true, "lamps": "rect", "scoop": true, "pod": true},
	"evo": {"L": 4.35, "W": 1.9, "low": 0.62, "nose": 0.46, "bon": 1.15, "tail": 0.6, "deck": 0.7, "cab": 0.56, "cab_f": 0.5, "cab_r": -1.25, "rake": 0.45, "back": 0.42, "ride": 0.33, "wr": 0.41, "wing": "big", "arches": true, "lamps": "rect", "scoop": true},
	"wrc": {"L": 4.15, "W": 1.98, "low": 0.62, "nose": 0.46, "bon": 1.05, "tail": 0.58, "deck": 0.15, "cab": 0.58, "cab_f": 0.5, "cab_r": -1.6, "rake": 0.55, "back": 0.22, "ride": 0.33, "wr": 0.41, "wing": "roof_big", "arches": true, "lamps": "rect", "scoop": true},
	"rally2": {"L": 4.0, "W": 1.9, "low": 0.6, "nose": 0.44, "bon": 1.0, "tail": 0.56, "deck": 0.15, "cab": 0.56, "cab_f": 0.5, "cab_r": -1.55, "rake": 0.55, "back": 0.25, "ride": 0.32, "wr": 0.4, "wing": "roof", "arches": true, "lamps": "rect"},
	"rally1": {"L": 4.15, "W": 2.0, "low": 0.6, "nose": 0.4, "bon": 1.05, "tail": 0.6, "deck": 0.15, "cab": 0.55, "cab_f": 0.5, "cab_r": -1.6, "rake": 0.6, "back": 0.25, "ride": 0.32, "wr": 0.42, "wing": "huge", "arches": true, "lamps": "rect", "louvres": true},
	"estate": {"L": 4.4, "W": 1.85, "low": 0.62, "nose": 0.48, "bon": 1.05, "tail": 0.58, "deck": 0.12, "cab": 0.6, "cab_f": 0.5, "cab_r": -2.0, "rake": 0.45, "back": 0.06, "ride": 0.32, "wr": 0.38, "wing": "none", "arches": false, "lamps": "rect", "pod": true},
	"suv": {"L": 4.1, "W": 2.0, "low": 0.78, "nose": 0.7, "bon": 0.95, "tail": 0.76, "deck": 0.1, "cab": 0.64, "cab_f": 0.6, "cab_r": -1.85, "rake": 0.3, "back": 0.04, "ride": 0.46, "wr": 0.46, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true},
	"truck": {"L": 4.6, "W": 2.15, "low": 0.72, "nose": 0.62, "bon": 1.05, "tail": 0.7, "deck": 1.9, "cab": 0.64, "cab_f": 1.15, "cab_r": -0.35, "rake": 0.4, "back": 0.04, "ride": 0.6, "wr": 0.55, "wing": "none", "arches": true, "lamps": "rect", "pod": true, "bumpers": true},
	"buggy": {"L": 3.4, "W": 1.8, "low": 0.25, "nose": 0.2, "bon": 0.5, "tail": 0.25, "deck": 0.3, "cab": 0.9, "cab_f": 0.6, "cab_r": -0.9, "rake": 0.3, "back": 0.1, "ride": 0.45, "wr": 0.48, "wing": "none", "arches": false, "lamps": "round", "pod": true},
}

const SPONSOR_COLS := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#2b2b2b")]


## Style table with the derived values other code uses (cab_h, cab_l, cab_z).
static func shape(style: String) -> Dictionary:
	var P: Dictionary = STYLES.get(style, STYLES["evo"]).duplicate()
	P["cab_h"] = P["cab"]
	P["cab_l"] = float(P["cab_f"]) - float(P["cab_r"])
	P["cab_z"] = (float(P["cab_f"]) + float(P["cab_r"])) * 0.5
	return P


## Returns {"root", "body", "wheels" [fl, fr, rl, rr], "length", "width", "wheel_r", "head" (driver eye),
## "lamp" (headlight position, local)}
static func build(car: Dictionary, number: int, mat: Material) -> Dictionary:
	var style: String = car.get("style", "evo")
	var P := shape(style)
	var body_c: Color = car["body"]
	var acc: Color = car["accent"]
	var stripe: Color = car["stripe"]
	var L: float = P["L"]
	var W: float = P["W"]
	var low: float = P["low"]
	var ride: float = P["ride"]
	var wr: float = P["wr"]
	var cab_h: float = P["cab"]
	var cab_f: float = P["cab_f"]
	var cab_r: float = P["cab_r"]
	var b := PaperKit.Builder.new(number * 13 + 1)
	var I := Transform3D()
	var y0 := ride
	var ink := Color("#2e2a28")
	var glass := Color("#5a6f80")
	var top_y := y0 + low
	var nose_y := y0 + float(P["nose"])
	var tail_y := y0 + float(P["tail"])
	if style == "buggy":
		_buggy(b, P, body_c, acc, stripe)
	else:
		# Body: a folded side profile with a sloped nose and tail.
		var bon_end := L * 0.5 - float(P["bon"])
		# Wheel arches cut into the profile, so the wheels sit in real openings and never pass
		# through the bodywork (with room for steering and suspension travel).
		var wzf := L * 0.5 - 0.8
		var arch_r := minf(wr + 0.12, top_y - 0.08 - wr)
		var yb := y0 + 0.05
		var prof := PackedVector2Array([Vector2(-L * 0.5, yb)])
		for wz in [-wzf, wzf]:
			prof.append(Vector2(wz - arch_r, yb))
			prof.append(Vector2(wz - arch_r, maxf(wr, yb)))
			for k in range(1, 8):
				var ang := PI - PI * k / 8.0
				prof.append(Vector2(wz + cos(ang) * arch_r, wr + sin(ang) * arch_r))
			prof.append(Vector2(wz + arch_r, maxf(wr, yb)))
			prof.append(Vector2(wz + arch_r, yb))
		prof.append_array(PackedVector2Array([Vector2(L * 0.5, yb), Vector2(L * 0.5, nose_y),
			Vector2(L * 0.5 - 0.25, top_y - 0.04), Vector2(bon_end, top_y), Vector2(-L * 0.5 + float(P["deck"]), top_y),
			Vector2(-L * 0.5 + 0.12, tail_y + 0.04), Vector2(-L * 0.5, tail_y)]))
		b.prism(prof, -W * 0.5, W * 0.5, I, body_c, {}, 1.05)
		if style == "truck":
			_truck_bed(b, P, body_c, acc)
		# Cabin: raked windscreen and rear window printed as glass strips.
		var cw := W * 0.84
		var cab := PackedVector2Array([Vector2(cab_r, top_y - 0.01), Vector2(cab_f, top_y - 0.01),
			Vector2(cab_f - float(P["rake"]), top_y + cab_h), Vector2(cab_r + float(P["back"]), top_y + cab_h)])
		var cab_col := body_c
		if P.get("roof2", false):
			cab_col = PaperKit.CREAM if body_c.v < 0.8 else Color("#2b2b2b")
		b.prism(cab, -cw * 0.5, cw * 0.5, I, cab_col, {1: glass, 3: glass}, 1.0)
		# Side windows: the cabin side outline inset, printed as glass.
		var inset := PackedVector2Array()
		var cc := Vector2((cab_r + cab_f) * 0.5, top_y + cab_h * 0.5)
		for q in cab:
			var d := (q - cc)
			inset.append(cc + Vector2(d.x * 0.86, d.y * 0.7) + Vector2(0, 0.02))
		for xs in [1.0, -1.0]:
			var side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (cw * 0.5 + 0.012), 0, 0))
			var win2 := PackedVector2Array()
			for q in inset:
				win2.append(Vector2(-q.x * xs, q.y))
			b.card(win2, side, glass, {"thick": 0.015, "edge": 0.025, "lip": 0.02})
			# B-pillar for four-door shapes.
			if float(P["cab_f"]) - float(P["cab_r"]) > 1.55:
				var bz := (cab_r + cab_f) * 0.5 - 0.05
				b.card(PaperKit.rect(0.09, cab_h * 0.75, -bz * xs, top_y + 0.04), side * Transform3D(Basis(), Vector3(0, 0, 0.02)), cab_col, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
			var body_side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.012), 0, 0))
			# Livery stripe, door line, roundel with the number, sponsor patches.
			b.card(PaperKit.rrect(L * 0.9, low * 0.16, 0.04, 0, y0 + low * 0.38), body_side, stripe, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
			var dz := (cab_r + cab_f) * 0.5
			b.card(PaperKit.rect(0.025, low * 0.7, -dz * xs + 0.6, y0 + 0.12), body_side * Transform3D(Basis(), Vector3(0, 0, 0.015)), body_c.darkened(0.35), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
			b.card(PaperKit.circle(low * 0.25, -dz * xs, y0 + low * 0.62, 14), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
			for d in mini(number, 4):
				var dot := PaperKit.circle(0.045, -dz * xs - 0.1 + d * 0.07, y0 + low * 0.62, 6)
				b.card(dot, body_side * Transform3D(Basis(), Vector3(0, 0, 0.032)), ink, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
			for k in 2:
				var pz = (L * 0.33 - k * L * 0.66) * xs
				var sc: Color = SPONSOR_COLS[(number + k) % SPONSOR_COLS.size()]
				b.card(PaperKit.rrect(0.6, 0.18, 0.04, pz, y0 + low * 0.74), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.015, "lip": 0.0})
				b.card(PaperKit.rect(0.44, 0.06, pz, y0 + low * 0.74 + 0.06), body_side * Transform3D(Basis(), Vector3(0, 0, 0.03)), sc, {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
			# Mirror.
			b.box(Vector3(xs * (cw * 0.5 + 0.12), top_y + 0.12, cab_f - 0.12), Vector3(0.14, 0.09, 0.07), I, body_c)
		var front := Transform3D(Basis(), Vector3(0, 0, L * 0.5 + 0.012))
		var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -L * 0.5 - 0.012))
		var lamp_y := y0 + (float(P["nose"]) - 0.05) * 0.72
		var lamps: String = P["lamps"]
		for xs in [1.0, -1.0]:
			match lamps:
				"round":
					b.card(PaperKit.circle(0.12, xs * W * 0.3, lamp_y, 12), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
				"quad":
					for k in 2:
						b.card(PaperKit.circle(0.085, xs * (W * 0.2 + k * 0.2), lamp_y, 10), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
				"popup":
					b.card(PaperKit.rrect(0.38, 0.09, 0.03, xs * W * 0.3, lamp_y - 0.02), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
				_:
					b.card(PaperKit.rrect(W * 0.24, 0.13, 0.04, xs * W * 0.3, lamp_y - 0.04), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
			b.card(PaperKit.rrect(W * 0.18, 0.12, 0.04, xs * W * 0.33, y0 + float(P["tail"]) * 0.7), back, Color("#d84a32"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
		b.card(PaperKit.rrect(W * 0.3, 0.12, 0.04, 0, y0 + float(P["nose"]) * 0.42), front, Color("#3a3430"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
		if P.get("bumpers", false):
			b.box(Vector3(0, y0 + 0.08, L * 0.5 + 0.07), Vector3(W * 0.96, 0.12, 0.12), I, Color("#d8d4cc"))
			b.box(Vector3(0, y0 + 0.08, -L * 0.5 - 0.07), Vector3(W * 0.96, 0.12, 0.12), I, Color("#d8d4cc"))
		else:
			b.slab(Vector3(-W * 0.5, y0 + 0.04, L * 0.5 + 0.16), Vector3(W * 0.5, y0 + 0.04, L * 0.5 + 0.16), Vector3(W * 0.5, y0 + 0.04, L * 0.5 - 0.1), Vector3(-W * 0.5, y0 + 0.04, L * 0.5 - 0.1), 0.04, ink)
		# Bonnet details: a centre stripe, a scoop, louvres.
		var bon_mid := (L * 0.5 + bon_end) * 0.5
		var lay := Basis(Vector3.RIGHT, -PI * 0.5)
		if float(P["bon"]) > 0.6:
			b.card(PaperKit.rect(W * 0.2, float(P["bon"]) * 0.8, 0, -bon_mid - float(P["bon"]) * 0.4), Transform3D(lay, Vector3(0, top_y + 0.012, 0)), acc, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
		if P.get("scoop", false):
			b.slab(Vector3(-0.28, top_y + 0.02, bon_mid + 0.25), Vector3(0.28, top_y + 0.02, bon_mid + 0.25), Vector3(0.24, top_y + 0.13, bon_mid - 0.2), Vector3(-0.24, top_y + 0.13, bon_mid - 0.2), 0.05, body_c.darkened(0.08))
			b.card(PaperKit.rrect(0.4, 0.08, 0.03, 0, 0), Transform3D(Basis(), Vector3(0, top_y + 0.03, bon_mid + 0.26)), ink, {"thick": 0.01, "edge": 0.0, "lip": 0.0})
		if P.get("louvres", false):
			for k in 4:
				b.card(PaperKit.rect(W * 0.34, 0.035, 0, 0), Transform3D(lay, Vector3(0, top_y + 0.018, bon_mid + 0.25 - k * 0.12)), ink, {"thick": 0.006, "edge": 0.0, "lip": 0.0, "sides": false})
		b.card(PaperKit.rect(cw * 0.22, (cab_f - cab_r) * 0.6, 0, 0), Transform3D(lay, Vector3(0, top_y + cab_h + 0.012, (cab_f + cab_r) * 0.5 + (cab_f - cab_r) * 0.3)), acc, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
		# Box arches over the wheels.
		# Arch trim: a flared ring round each opening (wider on the box-arch cars).
		var flare := 0.16 if P.get("arches", false) else 0.07
		for xs in [1.0, -1.0]:
			var side_t := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.02), 0, 0))
			for zs in [1.0, -1.0]:
				var az: float = zs * wzf
				var ring := PackedVector2Array()
				for k in 9:
					var ang := PI - PI * k / 8.0
					ring.append(Vector2(-(az + cos(ang) * (arch_r + flare)) * xs, wr + sin(ang) * (arch_r + flare)))
				ring.append(Vector2(-(az + arch_r + flare) * xs, wr - 0.08))
				ring.append(Vector2(-(az + arch_r) * xs, wr - 0.08))
				for k in range(8, -1, -1):
					var ang := PI - PI * k / 8.0
					ring.append(Vector2(-(az + cos(ang) * arch_r) * xs, wr + sin(ang) * arch_r))
				ring.append(Vector2(-(az - arch_r) * xs, wr - 0.08))
				ring.append(Vector2(-(az - arch_r - flare) * xs, wr - 0.08))
				b.card(ring, side_t, body_c.darkened(0.08), {"thick": 0.1 if flare > 0.1 else 0.05, "edge": 0.02, "lip": 0.0})
		# Wings and spoilers.
		_wing(b, P, L, W, top_y, cab_h, cab_r, acc, ink)
		# Rally lamp pod.
		if P.get("pod", false):
			var pod_z := L * 0.5 - 0.42
			var pod_y := nose_y + 0.16
			if style == "truck":
				pod_z = cab_f - float(P["rake"]) - 0.1
				pod_y = top_y + cab_h + 0.12
			b.box(Vector3(0, pod_y, pod_z), Vector3(W * 0.66, 0.14, 0.14), I, ink)
			for k in 4:
				var lx := -W * 0.25 + k * W * 0.167
				b.card(PaperKit.circle(0.09, lx, pod_y + 0.02, 10), Transform3D(Basis(), Vector3(0, 0, pod_z + 0.08)), Color("#fff4d6"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
		# Mud flaps.
		for xs in [1.0, -1.0]:
			for zs in [1.0, -1.0]:
				var fz = zs * (L * 0.5 - 0.8) - wr - 0.12
				b.card(PaperKit.rrect(0.4, ride + 0.08, 0.04, 0, 0), Transform3D(Basis(), Vector3(xs * (W * 0.5 - 0.22), 0.05, fz)), ink if zs > 0 else acc, {"thick": 0.03, "edge": 0.02, "lip": 0.0})

	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	body.add_child(mi)
	var gold: bool = car.get("gold_wheels", false)
	var wheel_mesh := _wheel_mesh(Color("#d9b24a") if gold else acc, wr, 0.42 if style in ["buggy", "truck", "suv"] else 0.3)
	var wheels: Array = []
	var wx := W * 0.5 - 0.1 + (0.2 if style == "buggy" else 0.0)
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
	# Driver's eyes: left seat, just behind the windscreen base, below the roof line.
	var head := Vector3(0.36, top_y + cab_h * 0.55, cab_f - float(P["rake"]) - 0.45)
	if style == "buggy":
		head = Vector3(0.0, y0 + 1.0, 0.0)
	return {"root": root, "body": body, "wheels": wheels, "length": L, "width": W, "wheel_r": wr, "head": head,
		"lamp": Vector3(0, y0 + float(P["nose"]) * 0.7, L * 0.5 + 0.1), "style": style}


static func _wing(b: PaperKit.Builder, P: Dictionary, L: float, W: float, top_y: float, cab_h: float, cab_r: float, acc: Color, ink: Color) -> void:
	var wing: String = P["wing"]
	var y0: float = P["ride"]
	var tail_top := y0 + float(P["tail"])
	match wing:
		"none":
			return
		"roof", "roof_big":
			# Spoiler off the back of the roof (hatchbacks).
			var rz := cab_r + float(P["back"])
			var ry := top_y + cab_h
			var ext := 0.45 if wing == "roof" else 0.6
			b.slab(Vector3(-W * 0.4, ry, rz + 0.05), Vector3(W * 0.4, ry, rz + 0.05), Vector3(W * 0.4, ry - 0.08, rz - ext), Vector3(-W * 0.4, ry - 0.08, rz - ext), 0.05, acc)
			if wing == "roof_big":
				for xs in [-1.0, 1.0]:
					b.card(PaperKit.rrect(ext + 0.1, 0.3, 0.04, 0, 0), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xs * W * 0.4, ry - 0.25, rz - ext * 0.5)), acc.darkened(0.2), {"thick": 0.03, "edge": 0.02, "lip": 0.0})
			return
		"boot":
			var bz := -L * 0.5 + 0.25
			b.slab(Vector3(-W * 0.42, tail_top + 0.12, bz - 0.15), Vector3(W * 0.42, tail_top + 0.12, bz - 0.15), Vector3(W * 0.42, tail_top + 0.16, bz + 0.2), Vector3(-W * 0.42, tail_top + 0.16, bz + 0.2), 0.05, acc)
			return
	var wy: float = top_y + {"small": 0.25, "big": 0.42, "huge": 0.58, "boot_high": 0.42}.get(wing, 0.4)
	var wz := -L * 0.5 + 0.28
	var span: float = W * (0.9 if wing == "small" else 1.02)
	for xs in [-0.45, 0.45]:
		var pb := Vector3(xs * span, y0 + float(P["tail"]) - 0.05, wz)
		b.box(Vector3(pb.x, (pb.y + wy) * 0.5, wz), Vector3(0.07, wy - pb.y, 0.18), Transform3D(), ink)
	var chord: float = {"small": 0.38, "big": 0.5, "huge": 0.66, "boot_high": 0.45}.get(wing, 0.45)
	b.slab(Vector3(-span * 0.5, wy, wz - chord * 0.5), Vector3(span * 0.5, wy, wz - chord * 0.5), Vector3(span * 0.5, wy + 0.08, wz + chord * 0.5), Vector3(-span * 0.5, wy + 0.08, wz + chord * 0.5), 0.05, acc)
	if wing == "huge" or wing == "big":
		for xs in [-0.5, 0.5]:
			b.card(PaperKit.rrect(chord * 1.15, 0.34, 0.05, 0, wy - 0.12), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xs * span, 0, wz)), acc.darkened(0.2), {"thick": 0.03, "edge": 0.02, "lip": 0.0})


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



## In-car view: dashboard, A-pillars, roof edge, steering wheel and a rev dial whose needle moves.
## Returns {"root", "wheel" (rotates with steering), "needle" (rotates with rpm)}.
static func build_cockpit(car: Dictionary, model: Dictionary, mat: Material) -> Dictionary:
	var style: String = car.get("style", "saloon")
	var P := shape(style)
	var head: Vector3 = model["head"]
	var W: float = P["W"]
	var L: float = P["L"]
	var top_y: float = float(P["ride"]) + float(P["low"])
	var cab_h: float = P["cab_h"]
	var cab_z: float = P["cab_z"]
	var cab_l: float = P["cab_l"]
	var body_c: Color = car["body"]
	var dark := Color("#3a3430")
	var b := PaperKit.Builder.new(21)
	var I := Transform3D()
	var dash_z := head.z + 0.55
	var gb := PaperKit.Builder.new(24)   # glass panes (drawn with a tinted see-through material)
	if style != "buggy":
		# A closed cabin shell that follows the car's own cabin profile: the only openings are glass.
		var cab_r: float = P["cab_r"]
		var cab_f: float = P["cab_f"]
		var rake: float = P["rake"]
		var back: float = P["back"]
		var cw: float = W * 0.84
		var hx: float = cw * 0.5 - 0.015
		var roof_y: float = top_y + cab_h
		var floor_y: float = top_y - 0.5
		var trim := Color(body_c).darkened(0.35)
		var lining := Color("#8f877c")
		var Lt := func(c: Color) -> Color: return PaperKit.lin(c, 1.0)
		var outline := [Vector2(cab_r, top_y), Vector2(cab_f, top_y), Vector2(cab_f - rake, roof_y), Vector2(cab_r + back, roof_y)]
		var cc := Vector2((cab_r + cab_f) * 0.5, top_y + cab_h * 0.5)
		var inset: Array = []
		for q in outline:
			var d: Vector2 = q - cc
			inset.append(cc + Vector2(d.x * 0.86, d.y * 0.7) + Vector2(0, 0.02))
		for xs in [-1.0, 1.0]:
			var x: float = xs * hx
			var inward := Vector3(-xs, 0, 0)
			# Window frame: a ring of panels between the cabin outline and the window opening.
			for i in 4:
				var j := (i + 1) % 4
				var o0: Vector2 = outline[i]
				var o1: Vector2 = outline[j]
				var i0: Vector2 = inset[i]
				var i1: Vector2 = inset[j]
				b.quad(Vector3(x, o0.y, o0.x), Vector3(x, o1.y, o1.x), Vector3(x, i1.y, i1.x), Vector3(x, i0.y, i0.x), inward, Lt.call(trim))
			# Side glass.
			var g0: Vector2 = inset[0]
			var g1: Vector2 = inset[1]
			var g2: Vector2 = inset[2]
			var g3: Vector2 = inset[3]
			gb.quad(Vector3(x, g0.y, g0.x), Vector3(x, g1.y, g1.x), Vector3(x, g2.y, g2.x), Vector3(x, g3.y, g3.x), inward, Color.WHITE)
			# B-pillar on longer cabins.
			if cab_f - cab_r > 1.55:
				b.box(Vector3(x * 0.99, top_y + cab_h * 0.5, cc.x - 0.05), Vector3(0.05, cab_h, 0.12), I, trim)
			# Door panel below the window line, down to the floor.
			var dz0 := cab_r - 0.1
			var dz1 := cab_f + 0.35
			var dx: float = xs * (W * 0.47)
			b.quad(Vector3(dx, floor_y, dz0), Vector3(dx, floor_y, dz1), Vector3(dx, top_y + 0.02, dz1), Vector3(dx, top_y + 0.02, dz0), inward, Lt.call(trim.darkened(0.15)))
			# Sill between door top and window frame.
			b.quad(Vector3(dx, top_y + 0.02, dz0), Vector3(dx, top_y + 0.02, dz1), Vector3(x, top_y, dz1), Vector3(x, top_y, dz0), Vector3(-xs, 1, 0).normalized(), Lt.call(trim))
		# Headliner.
		var r0: Vector2 = outline[3]
		var r1: Vector2 = outline[2]
		b.quad(Vector3(-hx, roof_y, r0.x), Vector3(hx, roof_y, r0.x), Vector3(hx, roof_y, r1.x), Vector3(-hx, roof_y, r1.x), Vector3.DOWN, Lt.call(lining))
		# Windscreen and rear window glass.
		gb.quad(Vector3(-hx, top_y, cab_f), Vector3(hx, top_y, cab_f), Vector3(hx, roof_y, cab_f - rake), Vector3(-hx, roof_y, cab_f - rake), Vector3(0, -rake, -cab_h).normalized(), Color.WHITE)
		gb.quad(Vector3(-hx, top_y + 0.12, cab_r + back * 0.12), Vector3(hx, top_y + 0.12, cab_r + back * 0.12), Vector3(hx, roof_y, cab_r + back), Vector3(-hx, roof_y, cab_r + back), Vector3(0, -back, cab_h).normalized(), Color.WHITE)
		# Rear bulkhead below the rear window, floor, and the footwell under the dash.
		b.quad(Vector3(-W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, top_y + 0.12, cab_r - 0.1), Vector3(-W * 0.47, top_y + 0.12, cab_r - 0.1), Vector3.BACK, Lt.call(trim.darkened(0.2)))
		b.quad(Vector3(-hx, top_y + 0.12, cab_r - 0.1), Vector3(hx, top_y + 0.12, cab_r - 0.1), Vector3(hx, top_y + 0.12, cab_r + back * 0.12), Vector3(-hx, top_y + 0.12, cab_r + back * 0.12), Vector3.UP, Lt.call(dark))
		b.quad(Vector3(-W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_f + 0.35), Vector3(-W * 0.47, floor_y, cab_f + 0.35), Vector3.UP, Lt.call(Color("#3a3430")))
		b.quad(Vector3(-W * 0.47, floor_y, cab_f + 0.35), Vector3(W * 0.47, floor_y, cab_f + 0.35), Vector3(W * 0.47, top_y + 0.02, cab_f + 0.35), Vector3(-W * 0.47, top_y + 0.02, cab_f + 0.35), Vector3.FORWARD, Lt.call(dark))
		# Bonnet seen through the screen, then the dashboard and cowl.
		b.box(Vector3(0, top_y - 0.05, (cab_f + L * 0.5) * 0.5), Vector3(W, 0.1, L * 0.5 - cab_f), I, body_c, body_c.lightened(0.05))
		b.box(Vector3(0, top_y - 0.05, cab_f - 0.05), Vector3(W * 0.9, 0.18, 0.5), I, Color("#4e4640"), Color("#6a6058"))
		b.box(Vector3(0, top_y + 0.03, dash_z + 0.05), Vector3(W * 0.86, 0.12, 0.36), I, Color("#4e4640"), Color("#5e564e"))
		# Rear-view mirror, seats, centre console and a roll cage.
		b.box(Vector3(0.0, roof_y - 0.045, cab_f - rake + 0.04), Vector3(0.12, 0.035, 0.015), I, Color("#7d8a94"))
		for sx in [head.x, -head.x]:
			b.box(Vector3(sx, top_y - 0.1, head.z - 0.3), Vector3(0.5, 0.75, 0.12), I, Color("#2e2a28"))
			b.box(Vector3(sx, floor_y + 0.2, head.z + 0.05), Vector3(0.5, 0.12, 0.6), I, Color("#2e2a28"))
		b.box(Vector3(0, floor_y + 0.2, head.z + 0.25), Vector3(0.22, 0.3, 0.8), I, Color("#3a3430"))
		var cage := Color("#b8b2a8")
		for xs in [-1.0, 1.0]:
			var a2 := Vector3(xs * (hx - 0.08), top_y + 0.05, cab_f - 0.05)
			var c2 := Vector3(xs * (hx - 0.08), roof_y - 0.06, cab_f - rake - 0.05)
			b.box(Vector3.ZERO, Vector3(0.045, 0.045, (c2 - a2).length()), Transform3D(Basis.looking_at((c2 - a2).normalized(), Vector3.UP), (a2 + c2) * 0.5), cage)
			b.box(Vector3(xs * (hx - 0.08), (top_y + roof_y) * 0.5, head.z - 0.45), Vector3(0.045, cab_h, 0.045), I, cage)
		b.box(Vector3(0, roof_y - 0.06, head.z - 0.45), Vector3(hx * 2.0 - 0.16, 0.045, 0.045), I, cage)
	else:
		b.box(Vector3(0, float(P["ride"]) + 0.55, dash_z), Vector3(W * 0.5, 0.12, 0.25), I, dark)
	# Rev dial on the dash.
	var dial_pos := Vector3(head.x, top_y + 0.03, dash_z - 0.05)
	b.card(PaperKit.circle(0.09, 0, 0, 14), Transform3D(Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, PI), dial_pos), PaperKit.CREAM, {"thick": 0.01, "edge": 0.015, "lip": 0.0})
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if gb.v.size() > 0:
		var gm := StandardMaterial3D.new()
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_color = Color(0.62, 0.74, 0.82, 0.16)
		gm.roughness = 1.0
		gm.metallic_specular = 0.0
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var gmi := MeshInstance3D.new()
		gmi.mesh = gb.mesh()
		gmi.material_override = gm
		gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gmi)
	# Steering wheel (its own node so it turns).
	var wheel := Node3D.new()
	wheel.position = Vector3(head.x, head.y - 0.36, head.z + 0.5)
	wheel.rotation.x = -0.5
	var wb := PaperKit.Builder.new(22)
	var ring := PackedVector2Array()
	for i in 14:
		var ang := TAU * i / 14.0
		ring.append(Vector2(cos(ang), sin(ang)) * 0.17)
	var face := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	# Rim as 14 short segments (an open ring, not a filled disc), plus spokes and a centre mark.
	for i in 14:
		var a0 := ring[i]
		var a1 := ring[(i + 1) % 14]
		var mid := (a0 + a1) * 0.5
		var seg := PaperKit.rect((a1 - a0).length() + 0.02, 0.035, 0, -0.0175)
		wb.card(seg, face * Transform3D(Basis(Vector3.BACK, (a1 - a0).angle()), Vector3(mid.x, mid.y, 0)), dark, {"thick": 0.03, "edge": 0.0, "lip": 0.0})
	wb.card(PaperKit.circle(0.04, 0, 0, 10), face, Color("#5a524c"), {"thick": 0.035, "edge": 0.0, "lip": 0.0})
	wb.card(PaperKit.rect(0.36, 0.05, 0, -0.025), face * Transform3D(Basis(), Vector3(0, 0, -0.02)), dark, {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	wb.card(PaperKit.rect(0.04, 0.05, 0, 0.15), face * Transform3D(Basis(), Vector3(0, 0, -0.02)), car["accent"], {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	var wmi := MeshInstance3D.new()
	wmi.mesh = wb.mesh()
	wmi.material_override = mat
	wheel.add_child(wmi)
	root.add_child(wheel)
	var needle := Node3D.new()
	needle.position = dial_pos + Vector3(0, 0, -0.012)
	needle.rotation.x = -0.5
	var nb := PaperKit.Builder.new(23)
	nb.card(PaperKit.rect(0.012, 0.08, 0, 0), Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), Color("#c8553d"), {"thick": 0.004, "edge": 0.0, "lip": 0.0})
	var nmi := MeshInstance3D.new()
	nmi.mesh = nb.mesh()
	nmi.material_override = mat
	var npiv := Node3D.new()
	npiv.add_child(nmi)
	needle.add_child(npiv)
	root.add_child(needle)
	return {"root": root, "wheel": wheel, "needle": npiv}
