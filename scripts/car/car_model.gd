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
	"mini": {"L": 3.1, "W": 1.6, "low": 0.58, "nose": 0.49, "bon": 0.67, "tail": 0.55, "deck": 0.14, "cab": 0.65, "cab_f": 0.57, "cab_r": -1.27, "rake": 0.18, "back": 0.10, "ride": 0.26, "wr": 0.3, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true, "roof2": true},
	"escort": {"L": 4.0, "W": 1.72, "low": 0.62, "nose": 0.52, "bon": 1.15, "tail": 0.56, "deck": 0.8, "cab": 0.58, "cab_f": 0.55, "cab_r": -1.05, "rake": 0.32, "back": 0.3, "ride": 0.32, "wr": 0.36, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true},
	"stratos": {"L": 3.7, "W": 1.9, "low": 0.47, "nose": 0.22, "bon": 1.34, "tail": 0.54, "deck": 0.76, "cab": 0.48, "cab_f": 0.51, "cab_r": -1.12, "rake": 0.73, "back": 0.29, "ride": 0.28, "wr": 0.4, "wing": "roof", "arches": true, "lamps": "popup"},
	"groupb_rwd": {"L": 4.0, "W": 2.0, "low": 0.52, "nose": 0.28, "bon": 1.3, "tail": 0.48, "deck": 0.9, "cab": 0.44, "cab_f": 0.50, "cab_r": -1.06, "rake": 0.56, "back": 0.5, "ride": 0.3, "wr": 0.4, "wing": "big", "arches": true, "lamps": "rect", "louvres": true},
	"quattro": {"L": 4.15, "W": 1.98, "low": 0.62, "nose": 0.5, "bon": 1.2, "tail": 0.58, "deck": 0.6, "cab": 0.56, "cab_f": 0.55, "cab_r": -1.25, "rake": 0.4, "back": 0.25, "ride": 0.33, "wr": 0.41, "wing": "huge", "arches": true, "lamps": "rect", "pod": true},
	"t16": {"L": 3.7, "W": 1.95, "low": 0.62, "nose": 0.48, "bon": 0.95, "tail": 0.56, "deck": 0.2, "cab": 0.56, "cab_f": 0.5, "cab_r": -1.35, "rake": 0.45, "back": 0.2, "ride": 0.33, "wr": 0.41, "wing": "roof", "arches": true, "lamps": "rect", "pod": true, "louvres": true},
	"groups": {"L": 4.0, "W": 2.0, "low": 0.46, "nose": 0.22, "bon": 1.3, "tail": 0.5, "deck": 0.9, "cab": 0.42, "cab_f": 0.6, "cab_r": -1.05, "rake": 0.66, "back": 0.48, "ride": 0.28, "wr": 0.4, "wing": "big", "arches": true, "lamps": "rect", "louvres": true},
	"gt4": {"L": 4.2, "W": 1.9, "low": 0.56, "nose": 0.36, "bon": 1.25, "tail": 0.5, "deck": 0.35, "cab": 0.48, "cab_f": 0.48, "cab_r": -1.26, "rake": 0.57, "back": 0.68, "ride": 0.31, "wr": 0.4, "wing": "boot", "arches": false, "lamps": "quad", "pod": true},
	"integrale": {"L": 3.9, "W": 1.95, "low": 0.62, "nose": 0.5, "bon": 1.0, "tail": 0.56, "deck": 0.15, "cab": 0.62, "cab_f": 0.55, "cab_r": -1.65, "rake": 0.38, "back": 0.12, "ride": 0.34, "wr": 0.41, "wing": "roof", "arches": true, "lamps": "quad", "pod": true, "louvres": true},
	"impreza": {"L": 4.35, "W": 1.9, "low": 0.62, "nose": 0.48, "bon": 1.2, "tail": 0.48, "deck": 0.92, "cab": 0.54, "cab_f": 0.5, "cab_r": -1.16, "rake": 0.45, "back": 0.52, "ride": 0.34, "wr": 0.41, "wing": "boot_high", "arches": true, "lamps": "rect", "scoop": true, "pod": true},
	"evo": {"L": 4.35, "W": 1.9, "low": 0.62, "nose": 0.46, "bon": 1.15, "tail": 0.67, "deck": 0.48, "cab": 0.60, "cab_f": 0.5, "cab_r": -1.4, "rake": 0.45, "back": 0.30, "ride": 0.33, "wr": 0.41, "wing": "big", "arches": true, "lamps": "rect", "scoop": true},
	"wrc": {"L": 4.15, "W": 1.98, "low": 0.61, "nose": 0.44, "bon": 1.07, "tail": 0.56, "deck": 0.29, "cab": 0.49, "cab_f": 0.52, "cab_r": -1.70, "rake": 0.60, "back": 0.72, "ride": 0.33, "wr": 0.41, "wing": "roof_big", "arches": true, "lamps": "rect", "scoop": true},
	"rally2": {"L": 3.88, "W": 1.9, "low": 0.6, "nose": 0.44, "bon": 1.0, "tail": 0.56, "deck": 0.15, "cab": 0.64, "cab_f": 0.59, "cab_r": -1.58, "rake": 0.55, "back": 0.11, "ride": 0.32, "wr": 0.4, "wing": "roof", "arches": true, "lamps": "rect"},
	"rally1": {"L": 4.24, "W": 2.0, "low": 0.6, "nose": 0.4, "bon": 1.05, "tail": 0.6, "deck": 0.15, "cab": 0.50, "cab_f": 0.53, "cab_r": -1.64, "rake": 0.6, "back": 0.25, "ride": 0.32, "wr": 0.42, "wing": "twin_roof", "arches": true, "lamps": "rect", "louvres": true},
	"estate": {"L": 4.4, "W": 1.85, "low": 0.62, "nose": 0.48, "bon": 1.05, "tail": 0.58, "deck": 0.12, "cab": 0.6, "cab_f": 0.5, "cab_r": -2.0, "rake": 0.45, "back": 0.06, "ride": 0.32, "wr": 0.38, "wing": "none", "arches": false, "lamps": "rect", "pod": true},
	"suv": {"L": 4.1, "W": 2.0, "low": 0.78, "nose": 0.7, "bon": 0.95, "tail": 0.76, "deck": 0.1, "cab": 0.64, "cab_f": 0.6, "cab_r": -1.85, "rake": 0.3, "back": 0.04, "ride": 0.46, "wr": 0.46, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true},
	"truck": {"L": 4.6, "W": 2.15, "low": 0.72, "nose": 0.62, "bon": 1.05, "tail": 0.7, "deck": 1.9, "cab": 0.64, "cab_f": 1.15, "cab_r": -0.35, "rake": 0.4, "back": 0.04, "ride": 0.6, "wr": 0.55, "wing": "none", "arches": true, "lamps": "rect", "pod": true, "bumpers": true},
	# Added from the reference audit (see docs/car-audit.md): silhouettes the first nineteen did not cover.
	"beetle": {"L": 3.75, "W": 1.66, "low": 0.6, "nose": 0.46, "bon": 0.72, "tail": 0.5, "deck": 0.62, "cab": 0.62, "cab_f": 0.2, "cab_r": -0.85, "rake": 0.55, "back": 0.78, "ride": 0.3, "wr": 0.34, "wing": "ducktail", "arches": true, "lamps": "round", "bumpers": true},
	"e36": {"L": 4.2, "W": 1.8, "low": 0.6, "nose": 0.5, "bon": 1.15, "tail": 0.6, "deck": 0.75, "cab": 0.52, "cab_f": 0.5, "cab_r": -1.0, "rake": 0.5, "back": 0.45, "ride": 0.32, "wr": 0.37, "wing": "boot", "arches": false, "lamps": "quad", "bumpers": false},
	"capri": {"L": 4.3, "W": 1.82, "low": 0.55, "nose": 0.4, "bon": 1.55, "tail": 0.5, "deck": 0.55, "cab": 0.46, "cab_f": 0.3, "cab_r": -1.0, "rake": 0.58, "back": 0.7, "ride": 0.3, "wr": 0.38, "wing": "ducktail", "arches": true, "lamps": "rect"},
	"cossie": {"L": 4.4, "W": 1.8, "low": 0.6, "nose": 0.42, "bon": 1.1, "tail": 0.6, "deck": 0.55, "cab": 0.55, "cab_f": 0.55, "cab_r": -1.35, "rake": 0.48, "back": 0.5, "ride": 0.33, "wr": 0.38, "wing": "big", "arches": true, "lamps": "rect", "pod": true},
	"pikes": {"L": 4.5, "W": 2.1, "low": 0.5, "nose": 0.28, "bon": 1.45, "tail": 0.55, "deck": 0.6, "cab": 0.44, "cab_f": 0.45, "cab_r": -1.2, "rake": 0.6, "back": 0.5, "ride": 0.26, "wr": 0.4, "wing": "huge", "arches": true, "lamps": "quad", "scoop": true, "louvres": true},
	"berlinette": {"L": 3.8, "W": 1.7, "low": 0.55, "nose": 0.38, "bon": 0.85, "tail": 0.45, "deck": 0.9, "cab": 0.45, "cab_f": 0.35, "cab_r": -1.0, "rake": 0.6, "back": 0.82, "ride": 0.3, "wr": 0.36, "wing": "none", "arches": true, "lamps": "round", "pod": true},
	"gtv6": {"L": 4.2, "W": 1.76, "low": 0.55, "nose": 0.42, "bon": 1.1, "tail": 0.56, "deck": 0.3, "cab": 0.5, "cab_f": 0.45, "cab_r": -1.3, "rake": 0.5, "back": 0.62, "ride": 0.31, "wr": 0.37, "wing": "small", "arches": true, "lamps": "rect", "pod": true},
	"m1": {"L": 4.35, "W": 1.95, "low": 0.45, "nose": 0.2, "bon": 1.5, "tail": 0.5, "deck": 0.7, "cab": 0.42, "cab_f": 0.4, "cab_r": -1.1, "rake": 0.75, "back": 0.4, "ride": 0.27, "wr": 0.4, "wing": "ducktail", "arches": true, "lamps": "popup", "louvres": true},
	"r5": {"L": 3.6, "W": 1.9, "low": 0.62, "nose": 0.5, "bon": 0.75, "tail": 0.6, "deck": 0.12, "cab": 0.62, "cab_f": 0.45, "cab_r": -1.2, "rake": 0.4, "back": 0.1, "ride": 0.33, "wr": 0.4, "wing": "roof", "arches": true, "lamps": "rect", "pod": true, "louvres": true},
	"sixr4": {"L": 3.4, "W": 1.9, "low": 0.64, "nose": 0.5, "bon": 0.65, "tail": 0.62, "deck": 0.1, "cab": 0.64, "cab_f": 0.4, "cab_r": -1.1, "rake": 0.3, "back": 0.08, "ride": 0.33, "wr": 0.4, "wing": "big", "arches": true, "lamps": "round", "pod": true, "louvres": true},
	"celica": {"L": 4.3, "W": 1.85, "low": 0.55, "nose": 0.4, "bon": 1.2, "tail": 0.55, "deck": 0.35, "cab": 0.5, "cab_f": 0.5, "cab_r": -1.3, "rake": 0.6, "back": 0.6, "ride": 0.32, "wr": 0.39, "wing": "big", "arches": true, "lamps": "rect", "scoop": true},
	"patrol": {"L": 4.5, "W": 1.95, "low": 0.8, "nose": 0.72, "bon": 0.9, "tail": 0.78, "deck": 0.1, "cab": 0.7, "cab_f": 0.55, "cab_r": -2.1, "rake": 0.25, "back": 0.03, "ride": 0.48, "wr": 0.47, "wing": "none", "arches": true, "lamps": "round", "pod": true, "bumpers": true},
	"buggy": {"L": 3.4, "W": 1.8, "low": 0.25, "nose": 0.2, "bon": 0.5, "tail": 0.25, "deck": 0.3, "cab": 0.9, "cab_f": 0.6, "cab_r": -0.9, "rake": 0.3, "back": 0.1, "ride": 0.45, "wr": 0.48, "wing": "none", "arches": false, "lamps": "round", "pod": true},
}

# Instrument pack position (metres from the driver), auxiliary dial count, face colour and trim.
const DASHBOARDS := {
	"classic": [-0.10, 2, "#ede1be", "#744f34"], "mini": [-0.31, 1, "#f0ead4", "#526454"],
	"escort": [-0.055, 3, "#e6dbc0", "#51504a"], "stratos": [-0.08, 2, "#e4c879", "#383d40"],
	"groupb_rwd": [-0.02, 3, "#eebc69", "#494039"], "quattro": [-0.12, 3, "#d8cfaf", "#674c40"],
	"t16": [0.01, 2, "#dedad1", "#494a58"], "groups": [-0.03, 1, "#acc9ae", "#353d48"],
	"gt4": [-0.04, 2, "#d3e1d9", "#4d5359"], "integrale": [-0.11, 3, "#ecbc8a", "#4e4945"],
	"impreza": [0.02, 2, "#ebe8d6", "#39495c"], "evo": [-0.07, 3, "#d6dae2", "#554649"],
	"wrc": [-0.10, 1, "#c4dfcb", "#414a50"], "rally2": [-0.04, 1, "#d1deae", "#383c42"],
	"rally1": [0.0, 0, "#b9dddf", "#323d43"], "estate": [-0.14, 2, "#e2d6ac", "#695442"],
	"suv": [-0.08, 3, "#d6d8c2", "#536055"], "truck": [-0.15, 3, "#eee0c2", "#505661"],
	"buggy": [0.0, 0, "#f2d088", "#594b3e"],
	"beetle": [-0.2, 1, "#e8dfc6", "#3f5a52"], "e36": [-0.05, 2, "#d9dde0", "#2f3438"],
	"capri": [-0.06, 2, "#e4d8b8", "#4a4036"], "cossie": [-0.04, 2, "#d9dee4", "#34393f"],
	"pikes": [-0.02, 2, "#e8c9c0", "#3a2f30"], "berlinette": [-0.1, 2, "#e0dcc4", "#2c4568"],
	"gtv6": [-0.05, 2, "#d9dcd2", "#3b4048"], "m1": [-0.05, 2, "#e8cf80", "#38342c"],
	"r5": [-0.04, 3, "#e6d9c0", "#3a2d2d"], "sixr4": [-0.05, 3, "#e6dcc4", "#3a3030"],
	"celica": [-0.03, 2, "#d8e2dc", "#3c4a40"], "patrol": [-0.12, 3, "#d8d6c0", "#4a4a44"]

}


const SPONSOR_COLS := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#2b2b2b")]


## Front grille shape per style (default "slats"), plus roof racks and bull bars on utility bodies.
const GRILLES := {
	"classic": "oval", "capri": "oval", "cossie": "oval", "escort": "slim", "groupb_rwd": "slim",
	"quattro": "shield", "integrale": "shield", "t16": "shield", "celica": "shield", "groups": "shield",
	"e36": "kidney", "m1": "kidney", "gtv6": "kidney", "berlinette": "slim", "pikes": "oval",
	"gt4": "mesh", "impreza": "mesh", "evo": "mesh", "wrc": "mesh", "rally2": "mesh", "rally1": "mesh", "r5": "mesh", "sixr4": "mesh",
	"suv": "bars", "patrol": "bars", "truck": "bars", "estate": "slats", "beetle": "none", "stratos": "none",
}
const RACKS := {"patrol": "full", "suv": "full", "estate": "rails", "beetle": "light"}
const BULLS := {"patrol": "hoop", "suv": "hoop", "truck": "hoop"}

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
	var paint: String = car.get("paint", "sweep")
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
	# Parts that can be torn off in a crash are separate meshes: front and rear bumper, left and right mirror.
	var det := {"bf": PaperKit.Builder.new(61), "br": PaperKit.Builder.new(62), "ml": PaperKit.Builder.new(63), "mr": PaperKit.Builder.new(64)}
	var I := Transform3D()
	var y0 := ride
	var ink := Color("#2e2a28")
	var glass := Color("#5a6f80")
	var top_y := y0 + low
	var nose_y := y0 + float(P["nose"])
	var tail_y := y0 + float(P["tail"])
	var beams := PackedVector3Array()
	var rear_lenses: Array[Rect2] = []
	if style == "buggy":
		for side: float in [-1,1]:
			beams.append(Vector3(side*W*0.22,y0+0.42,L*0.48+0.065))
		_buggy(b, P, body_c, acc, stripe)
	else:
		# Body: a folded side profile with a sloped nose and tail.
		var bon_end := L * 0.5 - float(P["bon"])
		# Wheel arches cut into the profile, so the wheels sit in real openings and never pass
		# through the bodywork (with room for steering and suspension travel).
		var wzf := L * 0.5 - 0.8
		var arch_r := wr + 0.075
		var yb := y0 + 0.05
		var prof := PackedVector2Array([Vector2(-L * 0.5, yb)])
		for wz in [-wzf, wzf]:
			prof.append(Vector2(wz - arch_r, yb))
			if wr > yb:
				prof.append(Vector2(wz - arch_r, wr))
			for k in range(1, 8):
				var ang := PI - PI * k / 8.0
				prof.append(Vector2(wz + cos(ang) * arch_r, wr + sin(ang) * arch_r))
			if wr > yb:
				prof.append(Vector2(wz + arch_r, wr))
			prof.append(Vector2(wz + arch_r, yb))
		prof.append(Vector2(L*0.5,yb))
		var deck := PackedVector2Array([Vector2(L*0.5,nose_y),Vector2(L*0.5-0.25,top_y-0.04),
			Vector2(bon_end,top_y),Vector2(-L*0.5+float(P.deck),top_y),Vector2(-L*0.5+0.12,tail_y+0.04),Vector2(-L*0.5,tail_y)])
		# Keep the low bonnet between the wheels. Each outer wing has its own
		# shoulder over the tyre, including room for lock and bump travel.
		var shoulder := PackedVector2Array()
		var raised := false
		for j in deck.size()-1:
			var a := deck[j]
			var z := deck[j+1]
			var samples: Array[float] = [a.x]
			for axle: float in [wzf,-wzf]:
				for k in 9:
					var sample := axle+arch_r*cos(k*PI/8)
					if sample < a.x-0.001 and sample > z.x+0.001:
						samples.append(sample)
			samples.sort()
			samples.reverse()
			for sample in samples:
				var roof := remap(sample,a.x,z.x,a.y,z.y)
				var gap := absf(absf(sample)-wzf)
				var wing := wr+sqrt(maxf(0.0,arch_r*arch_r-gap*gap))+0.055
				if gap<=arch_r and wing>roof:
					raised = true
					roof = wing
				shoulder.append(Vector2(sample,roof))
		shoulder.append(deck[-1])
		if raised:
			var center := PackedVector2Array([prof[0],prof[-1]])
			center.append_array(deck)
			b.prism(center,-W*0.31,W*0.31,I,body_c)
			prof.append_array(shoulder)
			b.prism(prof,-W*0.5,-W*0.31,I,body_c)
			b.prism(prof,W*0.31,W*0.5,I,body_c)
		else:
			prof.append_array(deck)
			b.prism(prof,-W*0.5,W*0.5,I,body_c)
		if style == "truck":
			_truck_bed(b, P, body_c, acc)
		# Cabin: raked windscreen and rear window printed as glass strips.
		var cw := W * 0.84
		var cab := _cabin_outline(P, top_y)
		var cab_col := body_c
		if P.get("roof2", false):
			cab_col = PaperKit.CREAM if body_c.v < 0.8 else Color("#2b2b2b")
		b.prism(cab, -cw * 0.5, cw * 0.5, I, cab_col, {1: glass, 3: glass if style == "truck" else cab_col}, 1.0)
		# Rear glazing sits inside the rubber surround on period cars. Bonded
		# glass has a finer printed border flush with the outer surface.
		if style != "truck":
			var bonded := style in ["wrc","rally1","rally2","evo","impreza","gt4"]
			var rise := Vector3(0,cab_h+0.01,float(P.back))
			var frame := Transform3D(Basis(Vector3.LEFT,rise.normalized(),Vector3.LEFT.cross(rise).normalized()),Vector3(0,top_y-0.01,cab_r))
			var seal := 0.026 if bonded else 0.052
			var outer := PaperKit.rrect(cw*0.96,rise.length()*0.94,0.06,0,rise.length()*0.03)
			var inner := PaperKit.rrect(cw*0.96-2*seal,rise.length()*0.94-2*seal,0.04,0,rise.length()*0.03+seal)
			b.card(inner,frame.translated_local(Vector3.BACK*0.008),glass,{"thick":0.004,"lip":0.0})
			for edge in outer.size():
				var next := (edge+1)%outer.size()
				var surround := PackedVector3Array()
				for uv: Vector2 in [outer[edge],outer[next],inner[next],inner[edge]]:
					surround.append(frame*Vector3(uv.x,uv.y,0.013 if bonded else 0.025))
				b.quad(surround[0],surround[1],surround[2],surround[3],frame.basis.z,PaperKit.lin(ink.lightened(0.07)))
				if not bonded:
					b.quad(surround[2],surround[3],surround[3]-frame.basis.z*0.017,surround[2]-frame.basis.z*0.017,frame.basis.z,PaperKit.lin(ink))
		# Two laid-down wipers follow the rake of this particular screen.
		_windscreen_wipers(b, cab, cw, ink)
		# Side windows: the cabin side outline inset, printed as glass.
		var inset := _side_window(cab)
		for xs in [1.0, -1.0]:
			var side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (cw * 0.5 + 0.012), 0, 0))
			var win2 := PackedVector2Array()
			for q in inset:
				win2.append(Vector2(-q.x * xs, q.y))
			b.card(win2, side, glass, {"thick": 0.015, "edge": 0.025, "lip": 0.02})
			if style in ["impreza","evo"]:
				var bottom := inset[0].lerp(inset[1], 0.18 if style == "evo" else 0.23)
				var upper := inset[3].lerp(inset[2], 0.14 if style == "evo" else 0.04)
				var pillar := PackedVector2Array()
				for pt: Vector2 in [bottom, bottom+Vector2(0.05,0), upper+Vector2(0.05,0), upper]:
					pillar.append(Vector2(-pt.x*xs,pt.y))
				b.card(pillar,side.translated_local(Vector3.BACK*0.025),cab_col,{"edge":0.0,"lip":0.0,"thick":0.01})
			# B-pillar for four-door shapes.
			if float(P["cab_f"]) - float(P["cab_r"]) > 1.55:
				var bz := (cab_r + cab_f) * 0.5 - 0.05
				b.card(PaperKit.rect(0.09, cab_h * 0.75, -bz * xs, top_y + 0.04), side * Transform3D(Basis(), Vector3(0, 0, 0.02)), cab_col, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
			var body_side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.012), 0, 0))
			# Livery stripe, door line, roundel with the number, sponsor patches.
			var span := wzf - arch_r
			var rise := low * 0.30 if paint == "sweep" else 0.0
			var flank := PackedVector2Array([Vector2(-span * xs, y0 + low * 0.28), Vector2(span * xs, y0 + low * 0.28 + rise),
				Vector2(span * xs, y0 + low * 0.48 + rise), Vector2(-span * xs, y0 + low * 0.43)])
			b.card(flank, body_side, stripe, {"thick": 0.008, "edge": 0.0, "lip": 0.0})
			if paint == "sweep":
				var upper := PackedVector2Array([flank[3], flank[2], flank[2] + Vector2(0, low * 0.05), flank[3] + Vector2(0, low * 0.05)])
				b.card(upper, body_side.translated_local(Vector3(0, 0, 0.006)), acc, {"thick": 0.005, "edge": 0.0, "lip": 0.0})
			var dz := (cab_r + cab_f) * 0.5
			b.card(PaperKit.rect(0.025, low * 0.7, -dz * xs + 0.6, y0 + 0.12), body_side * Transform3D(Basis(), Vector3(0, 0, 0.015)), body_c.darkened(0.35), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
			b.card(PaperKit.circle(low * 0.25, -dz * xs, y0 + low * 0.62, 14), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
			var roundel := body_side.translated_local(Vector3(-dz * xs, y0 + low * 0.62, 0.030))
			_print_number(b, number, roundel, low * 0.24, ink)
			for k in 2:
				var pz = (L * 0.33 - k * L * 0.66) * xs
				var sc: Color = SPONSOR_COLS[(number + k) % SPONSOR_COLS.size()]
				b.card(PaperKit.rrect(0.6, 0.18, 0.04, pz, y0 + low * 0.74), body_side * Transform3D(Basis(), Vector3(0, 0, 0.02)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.015, "lip": 0.0})
				b.card(PaperKit.rect(0.44, 0.06, pz, y0 + low * 0.74 + 0.06), body_side * Transform3D(Basis(), Vector3(0, 0, 0.03)), sc, {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
			# A recessed door pull, mirror stalk and a rear-facing mirror insert.
			b.box(Vector3(xs * (W * 0.5 + 0.018), top_y - 0.08, dz - 0.22), Vector3(0.027, 0.035, 0.16), I, ink)
			var mb: PaperKit.Builder = det["mr"] if xs > 0.0 else det["ml"]
			mb.box(Vector3(xs * (cw * 0.5 + 0.056), top_y + 0.10, cab_f - 0.12), Vector3(0.14, 0.035, 0.046), I, ink)
			mb.box(Vector3(xs * (cw * 0.5 + 0.12), top_y + 0.12, cab_f - 0.160), Vector3(0.11, 0.057, 0.013), I, glass.lightened(0.3))
			mb.box(Vector3(xs * (cw * 0.5 + 0.12), top_y + 0.12, cab_f - 0.12), Vector3(0.14, 0.09, 0.07), I, body_c)
		var front := Transform3D(Basis(), Vector3(0, 0, L * 0.5 + 0.012))
		var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -L * 0.5 - 0.012))
		var lamp_y := y0 + (float(P["nose"]) - 0.05) * 0.72
		var lamps: String = {"wrc": "split", "rally1": "blade", "rally2": "taper", "evo": "taper"}.get(style, P["lamps"])
		for xs in [1.0, -1.0]:
			var emitter_x := W * (0.32 if lamps in ["blade","taper"] else 0.30)
			if lamps not in ["quad", "split", "popup"]:
				beams.append(Vector3(xs*emitter_x,lamp_y,front.origin.z+0.038))
			match lamps:
				"blade", "taper":
					var lamp_x: float = xs * W * 0.32
					var height := 0.065 if lamps == "blade" else 0.14
					var lens := PackedVector2Array([Vector2(lamp_x-xs*0.22,lamp_y-height*0.34),Vector2(lamp_x+xs*0.19,lamp_y-height*0.62),
						Vector2(lamp_x+xs*0.23,lamp_y+height*0.70),Vector2(lamp_x-xs*0.16,lamp_y+height*0.26)])
					b.card(lens,front,Color("#fff4d4"),{"thick":0.025,"edge":0.025,"glow":true})
				"split":
					for segment in 2:
						beams.append(Vector3(xs*(W*0.25+segment*0.18),lamp_y+0.02,front.origin.z+0.038))
						b.card(PaperKit.rrect(0.16,0.105,0.028,xs*(W*0.25+segment*0.18),lamp_y-0.032),front,Color("#fff3cc"),{"thick":0.025,"glow":true})
				"round":
					var mount := front
					if style == "mini":
						b.card(PaperKit.circle(0.148, xs * W * 0.3, lamp_y, 12), front, Color("#c6c0b5"),
							{"thick": 0.034, "edge": 0.017, "lip": 0.008})
						mount = front.translated_local(Vector3.BACK * 0.020)
					b.card(PaperKit.circle(0.12, xs * W * 0.3, lamp_y, 12), mount, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
				"quad":
					for k in 2:
						beams.append(Vector3(xs*(W*0.2+k*0.2),lamp_y,front.origin.z+0.038))
						b.card(PaperKit.circle(0.085, xs * (W * 0.2 + k * 0.2), lamp_y, 10), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
				"popup":
					var pod_x: float = xs * W * 0.30
					var pod_y := nose_y + 0.25
					var pod_z := L * 0.5 - 0.07
					var shell := PackedVector2Array([Vector2(-0.34, -0.07), Vector2(-0.29, 0.015),
						Vector2(-0.10, 0.13), Vector2(0.0, 0.11), Vector2(0.0, -0.19)])
					b.prism(shell, pod_x - 0.16, pod_x + 0.16, Transform3D(Basis(), Vector3(0, pod_y, pod_z)), body_c)
					var lens_face := Transform3D(Basis(), Vector3(pod_x, pod_y - 0.02, pod_z + 0.014))
					b.card(PaperKit.rrect(0.28, 0.23, 0.052), lens_face, ink, {"thick": 0.024})
					b.card(PaperKit.circle(0.103, 0, 0, 12), lens_face.translated_local(Vector3.BACK * 0.015),
						Color("#fff1c9"), {"thick": 0.012, "edge": 0.014, "glow": true})
					beams.append(lens_face.origin + Vector3.BACK * 0.035)
				_:
					b.card(PaperKit.rrect(W * 0.24, 0.13, 0.04, xs * W * 0.3, lamp_y - 0.04), front, Color("#fff0c8"), {"thick": 0.02, "edge": 0.025, "lip": 0.0, "glow": true})
			var lens_size := Vector2(W*0.18,0.12)
			if style == "evo":
				lens_size = Vector2(0.21,0.24)
			elif style == "impreza":
				lens_size = Vector2(0.41,0.105)
			var lamp_height := y0+float(P.tail)*0.73
			if style == "mini":
				lens_size = Vector2(0.11, 0.19)
				lamp_height -= 0.035
			elif style == "stratos":
				lens_size = Vector2(0.23, 0.21)
				lamp_height += 0.035
			elif style == "rally2":
				lens_size = Vector2(0.15,0.26)
				lamp_height += 0.10
			elif style == "wrc":
				lens_size = Vector2(0.46,0.085)
			var lens := Rect2(Vector2(xs*W*0.33,lamp_height), lens_size)
			b.card(PaperKit.rrect(lens.size.x, lens.size.y, 0.07 if style == "stratos" else 0.032,
				lens.position.x, lens.position.y - lens.size.y * 0.5), back, Color("#c84738"),
				{"thick": 0.02, "edge": 0.018, "lip": 0.0, "glow": true})
			rear_lenses.append(lens)

		var grille := Transform3D(Basis(), Vector3(0, y0 + float(P["nose"]) * 0.38, L * 0.5 + 0.022))
		if style == "mini":
			b.card(PaperKit.rrect(W * 0.61, 0.20, 0.072, 0, -0.105), grille, Color("#c6c0b5"), {"thick": 0.026})
			b.card(PaperKit.rrect(W * 0.54, 0.15, 0.056, 0, -0.08), grille.translated_local(Vector3.BACK * 0.017),
				ink, {"thick": 0.009, "edge": 0.0, "lip": 0.0})
			for slat in 5:
				b.box(Vector3(0, -0.065 + slat * 0.029, 0.025), Vector3(W * (0.43 + 0.025 * mini(slat, 4 - slat)), 0.008, 0.012),
					grille, Color("#c0bbb0"))
		else:
			_grille(b, String(GRILLES.get(style, "slats")), grille, W, ink)
		for sx: float in [-0.18, 0.18]:
			b.card(PaperKit.circle(0.024, W * sx, 0, 6), grille, Color("#a8a298"), {"thick": 0.025, "edge": 0.0, "lip": 0.0})
		if style == "rally1":
			for side: float in [-1, 1]:
				var cheek := Transform3D(Basis(),Vector3(side*W*0.40,y0+0.08,L*0.5+0.054))
				b.box(Vector3.ZERO,Vector3(0.27,0.14,0.13),cheek,ink)
				b.box(Vector3(0,0.012,0.072),Vector3(0.21,0.015,0.018),cheek,acc)
				for vane in 2:
					b.box(Vector3(side*(0.26+0.22*vane),y0+0.03,-L*0.5),Vector3(0.034,0.16,0.33),I,ink)
		elif style == "wrc":
			for side: float in [-1, 1]:
				b.prism(PackedVector2Array([Vector2(-0.43,top_y-0.04),Vector2(-0.26,top_y+0.09),Vector2(0.23,top_y+0.09),Vector2(0.42,top_y-0.04)]),
					side*W*0.50-0.085,side*W*0.50+0.085,Transform3D(Basis(),Vector3(0,0,-L*0.5+0.8)),body_c)
		# A pressed tail panel and cream rally plate sit between the rear lamps.
		var plate_y := y0 + float(P["tail"]) * 0.60
		if style == "wrc":
			b.box(Vector3(0,plate_y+0.13,0.025),Vector3(W*0.69,0.045,0.04),back,ink)
		elif style == "rally2":
			for side: float in [-1,1]:
				b.box(Vector3(side*W*0.22,plate_y,0.014),Vector3(0.045,0.30,0.035),back,body_c.darkened(0.25))
		var plate := Transform3D(back.basis, Vector3(0, plate_y, back.origin.z))
		b.box(Vector3.ZERO, Vector3(W * 0.28, 0.145, 0.028), plate, ink)
		b.box(Vector3(0, 0, 0.019), Vector3(W * 0.24, 0.106, 0.012), plate, PaperKit.CREAM)
		_print_number(b, number, plate.translated_local(Vector3(0, 0, 0.028)), 0.080, ink)
		for pin: float in [-1.0, 1.0]:
			b.box(Vector3(pin * W * 0.096, 0.025, 0.028), Vector3(0.025, 0.018, 0.008), plate, ink)
		if style != "mini":
			for k in 3:
				b.box(Vector3(0, y0 + float(P["nose"]) * 0.42 + 0.025 + k * 0.035, front.origin.z + 0.018), Vector3(W * 0.25, 0.012, 0.012), I, ink.lightened(0.32))
		if P.get("bumpers", false):
			var bumper := Vector3(W * 0.96, 0.055 if style == "mini" else 0.12, 0.12)
			det["bf"].box(Vector3(0, y0 + 0.08, L * 0.5 + 0.07), bumper, I, Color("#d8d4cc"))
			det["br"].box(Vector3(0, y0 + 0.08, -L * 0.5 - 0.07), bumper, I, Color("#d8d4cc"))
		else:
			b.slab(Vector3(-W * 0.5, y0 + 0.04, L * 0.5 + 0.16), Vector3(W * 0.5, y0 + 0.04, L * 0.5 + 0.16), Vector3(W * 0.5, y0 + 0.04, L * 0.5 - 0.1), Vector3(-W * 0.5, y0 + 0.04, L * 0.5 - 0.1), 0.04, ink)
		if BULLS.has(style):
			_bull_bar(b, W, y0, L, float(P["nose"]), ink)
		if RACKS.has(style):
			_roof_rack(b, String(RACKS[style]), P, top_y + cab_h, cw)
		# Bonnet details: a centre stripe, a scoop, louvres.
		var bon_mid := (L * 0.5 + bon_end) * 0.5
		var lay := Basis(Vector3.RIGHT, -PI * 0.5)
		# Lay the print against the folded bonnet, including the short Mini bonnet.
		var rear_z := maxf(bon_end, cab_f)
		var tip_z := L * 0.5 - 0.25
		var rear_y := lerpf(top_y, top_y - 0.04, (rear_z - bon_end) / (tip_z - bon_end)) + 0.006
		_bonnet_print(b, paint, acc, W, rear_z, tip_z, rear_y, top_y - 0.034)
		if P.get("scoop", false):
			b.slab(Vector3(-0.28, top_y + 0.02, bon_mid + 0.25), Vector3(0.28, top_y + 0.02, bon_mid + 0.25), Vector3(0.24, top_y + 0.13, bon_mid - 0.2), Vector3(-0.24, top_y + 0.13, bon_mid - 0.2), 0.05, body_c.darkened(0.08))
			b.card(PaperKit.rrect(0.4, 0.08, 0.03, 0, 0), Transform3D(Basis(), Vector3(0, top_y + 0.03, bon_mid + 0.26)), ink, {"thick": 0.01, "edge": 0.0, "lip": 0.0})
		if P.get("louvres", false):
			for k in 4:
				b.card(PaperKit.rect(W * 0.34, 0.035, 0, 0), Transform3D(lay, Vector3(0, top_y + 0.018, bon_mid + 0.25 - k * 0.12)), ink, {"thick": 0.006, "edge": 0.0, "lip": 0.0, "sides": false})
		var roof_front := cab_f - float(P["rake"])
		var roof_rear := cab_r + float(P["back"])
		var roof_print := (roof_front - roof_rear) * 0.84
		b.card(PaperKit.rect(cw * 0.22, roof_print, 0, -roof_print * 0.5), Transform3D(lay, Vector3(0, top_y + cab_h + 0.012, (roof_rear + roof_front) * 0.5)), acc, {"thick": 0.012, "edge": 0.02, "lip": 0.0})
		if style == "stratos":
			# Stand-off louvres over the rear screen and the short engine deck.
			for slat in 5:
				var t := (slat + 1.0) / 6.0
				var slat_z := lerpf(cab_r, roof_rear, t) - 0.105
				var slat_y := top_y + cab_h * t + 0.018
				b.box(Vector3(0, slat_y, slat_z), Vector3(cw * lerpf(0.74, 0.64, t), 0.034, 0.21),
					I, ink.lightened(t * 0.15))
			b.card(PaperKit.rrect(cw * 0.65, 0.12, 0.03, 0, y0 + 0.105), back, ink, {"thick": 0.027})
		# Box arches over the wheels.
		# Arch trim: a flared ring round each opening (wider on the box-arch cars).
		var boxed := style in ["quattro","groupb_rwd","t16","groups"]
		var vented := style in ["rally1","rally2","wrc"]
		var flare := 0.065 if style in ["classic","mini","escort"] else (0.16 if P.get("arches", false) else 0.07)
		for xs in [1.0, -1.0]:
			var side_t := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (W * 0.5 + 0.02), 0, 0))
			for zs in [1.0, -1.0]:
				var az: float = zs * wzf
				var ring := PackedVector2Array()
				for k in 9:
					var ang := PI - PI * k / 8.0
					var crown := minf(sin(ang)*1.25, 1.0) if boxed else sin(ang)
					ring.append(Vector2(-(az + cos(ang) * (arch_r + flare)) * xs, wr + crown * (arch_r + flare)))
				ring.append(Vector2(-(az + arch_r + flare) * xs, wr - 0.08))
				ring.append(Vector2(-(az + arch_r) * xs, wr - 0.08))
				for k in range(8, -1, -1):
					var ang := PI - PI * k / 8.0
					ring.append(Vector2(-(az + cos(ang) * arch_r) * xs, wr + sin(ang) * arch_r))
				ring.append(Vector2(-(az - arch_r) * xs, wr - 0.08))
				ring.append(Vector2(-(az - arch_r - flare) * xs, wr - 0.08))
				b.card(ring, side_t, body_c.darkened(0.08), {"thick": 0.1 if flare > 0.1 else 0.05, "edge": 0.02, "lip": 0.0})
				if boxed:
					for k in 5:
						var ang := (k+0.5)*PI/5
						var uv := Vector2(-(az+cos(ang)*(arch_r+flare*0.52))*xs,wr+sin(ang)*(arch_r+flare*0.55))
						b.card(PaperKit.circle(0.020,uv.x,uv.y,6),side_t.translated_local(Vector3.BACK*0.057),Color("#b5afa0"),{"thick":0.008,"lip":0.0})
				elif vented:
					for k in 3:
						var uv := Vector2((arch_r+0.11-az)*xs,wr+0.035+k*0.055)
						b.card(PaperKit.rect(0.15,0.028,uv.x,uv.y),side_t.translated_local(Vector3.BACK*0.059),ink,{"thick":0.01,"lip":0.0})
		var hardware_y := tail_y-0.055
		if style in ["classic","mini","escort","estate","suv"]:
			for sx: float in [-1,1]:
				b.box(Vector3(sx*W*0.22,hardware_y,0.023),Vector3(0.13,0.074,0.040),back,Color("#aaa499"))
				b.box(Vector3(sx*W*0.22,hardware_y,0.047),Vector3(0.15,0.023,0.019),back,ink)
		elif boxed or style == "stratos":
			for sx: float in [-1,1]:
				b.box(Vector3(sx*W*0.24,hardware_y-0.035,0.035),Vector3(0.055,0.15,0.03),back,ink)
				b.box(Vector3(sx*W*0.24,hardware_y,0.054),Vector3(0.071,0.035,0.014),back,PaperKit.CREAM)
		else:
			b.box(Vector3(0,hardware_y,0.019),Vector3(W*0.19,0.07,0.025),back,ink)
			b.box(Vector3(0,hardware_y+0.021,0.036),Vector3(W*0.16,0.026,0.021),back,body_c)
		# Riveted roof intake on the newer competition shells, open toward the nose.
		if style in ["rally1", "rally2", "wrc", "impreza", "evo"]:
			var vent_z := roof_front - roof_print * 0.28
			var vent_y := top_y + cab_h + 0.065
			b.prism(PackedVector2Array([Vector2(-0.17, -0.045), Vector2(0.15, -0.045), Vector2(0.15, 0.055), Vector2(-0.09, 0.035)]),
				-0.19, 0.19, Transform3D(Basis(), Vector3(0, vent_y, vent_z)), body_c)
			b.box(Vector3(0, vent_y, vent_z + 0.152), Vector3(0.31, 0.058, 0.008), I, ink)
		var exhaust := Transform3D(Basis(Vector3.UP, PI), Vector3(-W * 0.29, y0 + 0.015, -L * 0.5 - 0.07))
		b.card(PaperKit.circle(0.077, 0, 0, 10), exhaust, Color("#8e8980"), {"thick": 0.20, "lip": 0.0})
		b.card(PaperKit.circle(0.052, 0, 0, 10), exhaust.translated_local(Vector3(0, 0, 0.102)), ink, {"thick": 0.004, "edge": 0.0, "lip": 0.0})
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
				beams.append(Vector3(lx,pod_y+0.02,pod_z+0.11))
				b.card(PaperKit.circle(0.09, lx, pod_y + 0.02, 10), Transform3D(Basis(), Vector3(0, 0, pod_z + 0.08)), Color("#fff4d6"), {"thick": 0.02, "edge": 0.02, "lip": 0.0, "glow": true})
		# Bonnet retaining pins follow the sloped leading panel on each side.
		var nose_run := L * 0.5 - float(P["bon"])
		var pin_z := lerpf(nose_run, L * 0.5 - 0.25, 0.72)
		for flank: float in [-1.0, 1.0]:
			var pin := Transform3D(lay, Vector3(flank * W * 0.33, top_y - 0.04 * 0.72 + 0.009, pin_z))
			b.card(PaperKit.circle(0.050, 0, 0, 8), pin, Color("#99988f"), {"thick": 0.012, "lip": 0.0})
			b.box(Vector3(0.009, 0, 0.012), Vector3(0.067, 0.012, 0.010), pin, ink)
			var flap_z := -L * 0.5 + 0.12
			b.box(Vector3(flank * W * 0.38, tail_y - 0.10, flap_z - 0.145), Vector3(0.082, 0.035, 0.018), I, Color("#da9143"))
		# Mud flaps.
		for xs in [1.0, -1.0]:
			for zs in [1.0, -1.0]:
				var fz = zs * (L * 0.5 - 0.8) - wr - 0.12
				b.card(PaperKit.rrect(0.4, ride + 0.08, 0.04, 0, 0), Transform3D(Basis(), Vector3(xs * (W * 0.5 - 0.22), 0.05, fz)), ink if zs > 0 else acc, {"thick": 0.03, "edge": 0.02, "lip": 0.0})

	# Fold the front and rear overhangs inward beyond the tyres. The design table
	# sets the narrowing on each side; paint, lamp lenses and trim follow the same fold.
	var taper: Vector2 = {
		"classic":Vector2(0.22,0.18), "stratos":Vector2(0.36,0.21), "groups":Vector2(0.31,0.10),
		"groupb_rwd":Vector2(0.23,0.08), "gt4":Vector2(0.24,0.15), "impreza":Vector2(0.18,0.10),
		"evo":Vector2(0.07,0.04), "rally1":Vector2(0.23,0.06), "rally2":Vector2(0.16,0.18),
		"wrc":Vector2(0.14,0.11), "mini":Vector2(0.15,0.11)
	}.get(style,Vector2.ZERO)
	if taper != Vector2.ZERO:
		for i in b.v.size():
			var point: Vector3 = b.v[i]
			var tip := taper.x if point.z > 0 else taper.y
			var t := clampf((absf(point.z) - L*0.5 + 0.42) / 0.42, 0.0, 1.0)
			if t == 0:
				continue
			var width_scale := 1.0 - smoothstep(0.0, 1.0, t) * tip
			var slope := signf(point.z) * tip * 6.0 * t * (1.0-t) / 0.42
			var n: Vector3 = b.n[i]
			n.x /= width_scale
			n.z += n.x * point.x * slope
			b.n[i] = n.normalized()
			point.x *= width_scale
			b.v[i] = point

	for i in beams.size():
		var t := clampf((absf(beams[i].z)-L*0.5+0.42)/0.42,0.0,1.0)
		beams[i].x *= 1.0-taper.x*smoothstep(0,1,t)
	for i in rear_lenses.size():
		rear_lenses[i].position.x *= 1.0-taper.y
		rear_lenses[i].size.x *= 1.0-taper.y
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	body.add_child(mi)
	var detach := {}
	for key in det.keys():
		var dmesh: ArrayMesh = (det[key] as PaperKit.Builder).mesh()
		if dmesh.get_surface_count() == 0:
			continue
		var dn := MeshInstance3D.new()
		dn.mesh = dmesh
		dn.material_override = mat
		body.add_child(dn)
		detach[key] = dn
	var gold: bool = car.get("gold_wheels", false)
	var wheel_mesh := _wheel_mesh(Color("#d9b24a") if gold else acc, wr, 0.42 if style in ["buggy", "truck", "suv"] else 0.3, style)
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
		"lamp": Vector3(0, y0 + float(P["nose"]) * 0.7, L * 0.5 + 0.1), "exhaust": Vector3(-W * 0.29, y0 + 0.03, -L * 0.5 - 0.12), "style": style, "beam_mounts": beams, "rear_lenses": rear_lenses, "detach": detach}


static func _grille(b: PaperKit.Builder, kind: String, g: Transform3D, W: float, ink: Color) -> void:
	var chrome := Color("#c9c4b9")
	var dim := Color("#78746d")
	match kind:
		"oval":
			b.card(PaperKit.circle(0.13, 0, 0, 14), g, chrome, {"thick": 0.024})
			b.card(PaperKit.circle(0.10, 0, 0, 14), g.translated_local(Vector3.BACK * 0.014), ink, {"thick": 0.008, "edge": 0.0, "lip": 0.0})
			for k in 5:
				b.box(Vector3(0, (k - 2) * 0.034, 0.024), Vector3(0.17, 0.008, 0.008), g, dim)
		"kidney":
			for sx: float in [-1.0, 1.0]:
				var kc := g.translated_local(Vector3(sx * 0.075, 0, 0))
				b.card(PaperKit.rrect(0.12, 0.17, 0.05, 0, 0), kc, chrome, {"thick": 0.024})
				b.card(PaperKit.rrect(0.095, 0.145, 0.04, 0, 0), kc.translated_local(Vector3.BACK * 0.014), ink, {"thick": 0.008, "edge": 0.0, "lip": 0.0})
				for k in 3:
					b.box(Vector3((k - 1) * 0.03, 0, 0.022), Vector3(0.007, 0.13, 0.007), kc, dim)
		"shield":
			var shield := PackedVector2Array([Vector2(-0.19, 0.07), Vector2(0.19, 0.07), Vector2(0.15, -0.09), Vector2(-0.15, -0.09)])
			b.card(shield, g, chrome, {"thick": 0.024})
			var inner := PackedVector2Array([Vector2(-0.165, 0.055), Vector2(0.165, 0.055), Vector2(0.13, -0.075), Vector2(-0.13, -0.075)])
			b.card(inner, g.translated_local(Vector3.BACK * 0.014), ink, {"thick": 0.008, "edge": 0.0, "lip": 0.0})
			for k in 4:
				b.box(Vector3(0, 0.035 - k * 0.032, 0.022), Vector3(0.27 - k * 0.02, 0.008, 0.008), g, dim)
		"mesh":
			b.card(PaperKit.rrect(W * 0.46, 0.15, 0.03, 0, -0.02), g, ink, {"thick": 0.02})
			for k in 4:
				b.box(Vector3(0, -0.07 + k * 0.034, 0.016), Vector3(W * 0.42, 0.006, 0.006), g, dim)
			for k in 7:
				b.box(Vector3((k - 3) * W * 0.062, -0.02, 0.016), Vector3(0.006, 0.12, 0.006), g, dim)
		"bars":
			b.card(PaperKit.rrect(W * 0.46, 0.20, 0.025, 0, 0), g, chrome, {"thick": 0.03})
			b.card(PaperKit.rrect(W * 0.42, 0.16, 0.02, 0, 0), g.translated_local(Vector3.BACK * 0.018), ink, {"thick": 0.008, "edge": 0.0, "lip": 0.0})
			for k in 5:
				b.box(Vector3(0, (k - 2) * 0.034, 0.026), Vector3(W * 0.42, 0.012, 0.01), g, chrome)
		"slim":
			b.box(Vector3.ZERO, Vector3(W * 0.40, 0.06, 0.02), g, ink)
			b.box(Vector3(0, 0, 0.014), Vector3(W * 0.38, 0.012, 0.008), g, chrome)
		"none":
			b.box(Vector3(0, -0.05, 0), Vector3(W * 0.16, 0.035, 0.016), g, ink)
		_:
			b.box(Vector3.ZERO, Vector3(W * 0.30, 0.105, 0.022), g, ink)
			for slat in 3:
				b.box(Vector3(0, (slat - 1) * 0.030, 0.015), Vector3(W * 0.28, 0.009, 0.009), g, dim)


static func _bull_bar(b: PaperKit.Builder, W: float, y0: float, L: float, nose: float, _ink: Color) -> void:
	var tube := Color("#2a2a2c")
	var I := Transform3D()
	var z := L * 0.5 + 0.20
	var top := y0 + nose + 0.20
	var low := y0 + 0.10
	var hw := W * 0.30
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * hw, (low + top) * 0.5, z), Vector3(0.05, top - low, 0.05), I, tube)
		b.box(Vector3(sx * hw, top, z - 0.075), Vector3(0.05, 0.05, 0.16), I, tube)
		b.box(Vector3(sx * hw, low, z - 0.06), Vector3(0.05, 0.05, 0.14), I, tube)
	b.box(Vector3(0, top, z), Vector3(hw * 2.0 + 0.05, 0.05, 0.05), I, tube)
	b.box(Vector3(0, low, z), Vector3(hw * 2.0 + 0.05, 0.05, 0.05), I, tube)
	b.box(Vector3(0, (top + low) * 0.5, z), Vector3(0.04, top - low, 0.04), I, tube)
	b.box(Vector3(0, y0 + 0.04, z - 0.04), Vector3(W * 0.62, 0.05, 0.10), I, Color("#8c877d"))


static func _roof_rack(b: PaperKit.Builder, kind: String, P: Dictionary, roof_y: float, cw: float) -> void:
	var tube := Color("#2a2a2c")
	var I := Transform3D()
	var z1: float = float(P["cab_f"]) - float(P["rake"]) - 0.12
	var z0: float = float(P["cab_r"]) + float(P["back"]) + 0.12
	var hw := cw * (0.40 if kind != "light" else 0.34)
	var h := 0.075 if kind == "full" else 0.05
	var zc := (z0 + z1) * 0.5
	var zl := z1 - z0
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * hw, roof_y + h, zc), Vector3(0.035, 0.035, zl), I, tube)
		for pz: float in [z0 + 0.05, zc, z1 - 0.05]:
			b.box(Vector3(sx * hw, roof_y + h * 0.5, pz), Vector3(0.03, h, 0.03), I, tube)
	var bars := 4 if kind == "full" else 3
	for k in bars:
		var bz := lerpf(z0 + 0.05, z1 - 0.05, float(k) / float(bars - 1))
		b.box(Vector3(0, roof_y + h, bz), Vector3(hw * 2.0, 0.03, 0.03), I, tube)
	if kind == "full":
		for k in 5:
			b.box(Vector3((k - 2) * hw * 0.4, roof_y + h, zc), Vector3(0.02, 0.02, zl), I, tube)
		var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, roof_y + h + 0.03, z0 + zl * 0.28))
		b.card(PaperKit.circle(0.30, 0, 0, 14), lay, Color("#262424"), {"thick": 0.20, "lip": 0.0})
		b.card(PaperKit.circle(0.17, 0, 0, 12), lay.translated_local(Vector3(0, 0, 0.102)), Color("#9a948a"), {"thick": 0.004, "edge": 0.0, "lip": 0.0})
		b.box(Vector3(0, roof_y + h + 0.08, z1 - 0.28), Vector3(hw * 1.2, 0.15, 0.28), I, Color("#7a6c52"))


static func _cabin_outline(profile: Dictionary, sill: float) -> PackedVector2Array:
	var front: float = profile["cab_f"]
	var rear: float = profile["cab_r"]
	var roof := sill + float(profile["cab_h"])
	return PackedVector2Array([
		Vector2(rear, sill - 0.01), Vector2(front, sill - 0.01),
		Vector2(front - float(profile["rake"]), roof),
		Vector2(rear + float(profile["back"]), roof)
	])


static func _side_window(cabin: PackedVector2Array) -> PackedVector2Array:
	var center := Vector2((cabin[0].x + cabin[1].x) * 0.5, (cabin[0].y + cabin[2].y + 0.01) * 0.5)
	var outline := PackedVector2Array()
	for corner in cabin:
		outline.append(center + (corner - center) * Vector2(0.86, 0.70) + Vector2(0, 0.02))
	return outline


static func _windscreen_wipers(b: PaperKit.Builder, cabin: PackedVector2Array, width: float, color: Color) -> void:
	var up := Vector3(0, cabin[2].y - cabin[1].y, cabin[2].x - cabin[1].x)
	var axis := up.normalized()
	var frame := Transform3D(Basis(Vector3.RIGHT, axis, Vector3.RIGHT.cross(axis)), Vector3(0, cabin[1].y, cabin[1].x))
	for side: float in [-0.24, 0.24]:
		var blade := frame * Transform3D(Basis(Vector3.BACK, 0.12), Vector3(width * side, up.length() * 0.13, 0.014))
		b.box(Vector3.ZERO, Vector3(width * 0.39, 0.024, 0.018), blade, color)


static func _bonnet_print(b: PaperKit.Builder, paint: String, acc: Color, width: float, rear_z: float, tip_z: float, rear_y: float, tip_y: float) -> void:
	var bands := [Vector2(-0.42, 0.42)] if paint == "safari" else [Vector2(-0.10, 0.10)]
	if paint == "twins":
		bands = [Vector2(0.13, 0.20), Vector2(0.225, 0.265)]
	for band: Vector2 in bands:
		b.quad(Vector3(width * band.x, rear_y, rear_z), Vector3(width * band.y, rear_y, rear_z),
			Vector3(width * band.y, tip_y, tip_z), Vector3(width * band.x, tip_y, tip_z), Vector3.UP, PaperKit.lin(acc))


## Cut-stencil numerals printed directly into the body mesh.
static func _print_number(b: PaperKit.Builder, number: int, face: Transform3D, height: float, ink: Color) -> void:
	var digits := str(absi(number))
	var masks := [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
	# Clockwise from the top, with the crossbar last.
	var centres := [Vector2(0, 0.45), Vector2(0.23, 0.23), Vector2(0.23, -0.23), Vector2(0, -0.45), Vector2(-0.23, -0.23), Vector2(-0.23, 0.23), Vector2.ZERO]
	for i in digits.length():
		var mask: int = masks[int(digits[i])]
		for k in centres.size():
			if (mask & (1 << k)) == 0:
				continue
			var h := Vector2(0.21, 0.055) if k in [0, 3, 6] else Vector2(0.055, 0.19)
			var c: Vector2 = centres[k] + Vector2((i - (digits.length() - 1) * 0.5) * 0.75, 0)
			var quad := PackedVector3Array()
			for sign_xy: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var pt := (c + sign_xy * h) * height
				quad.append(face * Vector3(pt.x, pt.y, 0))
			b.quad(quad[0], quad[1], quad[2], quad[3], face.basis.z, PaperKit.lin(ink))


static func _wing(b: PaperKit.Builder, P: Dictionary, L: float, W: float, top_y: float, cab_h: float, cab_r: float, acc: Color, ink: Color) -> void:
	var wing: String = P["wing"]
	var y0: float = P["ride"]
	var tail_top := y0 + float(P["tail"])
	match wing:
		"none":
			return
		"twin_roof":
			var rz := cab_r + float(P["back"])
			var ry := top_y + cab_h
			for flank: float in [-1, 1]:
				b.prism(PackedVector2Array([Vector2(-0.65,-0.12),Vector2(-0.68,0.19),Vector2(-0.48,0.22),Vector2(0.10,0.02),Vector2(0.08,-0.09)]),
					flank*W*0.42-0.025,flank*W*0.42+0.025,Transform3D(Basis(),Vector3(0,ry,rz)),ink)
			for layer in 2:
				var wy := ry - 0.055 + layer * 0.185
				var aft := rz - 0.47 - layer * 0.16
				b.slab(Vector3(-W*0.45,wy,aft),Vector3(W*0.45,wy,aft),Vector3(W*0.43,wy+0.045,aft+0.29),Vector3(-W*0.43,wy+0.045,aft+0.29),0.035,acc if layer else ink)
			return
		"roof_big":
			var rz := cab_r + float(P["back"])
			var ry := top_y + cab_h
			for side: float in [-1.0, 1.0]:
				b.prism(PackedVector2Array([Vector2(-0.53, -0.14), Vector2(-0.60, 0.16),
					Vector2(-0.20, 0.18), Vector2(-0.10, -0.03)]),
					side * W * 0.35 - 0.024, side * W * 0.35 + 0.024, Transform3D(Basis(), Vector3(0, ry, rz)), ink)
			b.slab(Vector3(-W * 0.46, ry + 0.15, rz - 0.63), Vector3(W * 0.46, ry + 0.15, rz - 0.63),
				Vector3(W * 0.42, ry + 0.21, rz - 0.20), Vector3(-W * 0.42, ry + 0.21, rz - 0.20), 0.05, acc)
			return
		"roof":
			# Spoiler off the back of the roof (hatchbacks).
			var rz := cab_r + float(P["back"])
			var ry := top_y + cab_h
			b.slab(Vector3(-W * 0.4, ry, rz + 0.05), Vector3(W * 0.4, ry, rz + 0.05),
				Vector3(W * 0.4, ry - 0.08, rz - 0.45), Vector3(-W * 0.4, ry - 0.08, rz - 0.45), 0.05, acc)
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
	var spare := Transform3D(Basis(Vector3.UP, PI), Vector3(0, y0 + 0.72, -1.49))
	_spare_wheel(b, spare, float(P["wr"]) * 0.88, acc)
	# Webbing over the open seat and cooling fins on the exposed engine.
	for sx: float in [-0.14, 0.14]:
		b.box(Vector3(sx, y0 + 0.45, 0.06), Vector3(0.07, 0.46, 0.025), I, stripe)
	for k in 4:
		b.box(Vector3(0, y0 + 0.66, -0.94 - k * 0.14), Vector3(0.68, 0.05, 0.05), I, ink)
	# Braced rear shock towers on the exposed frame.
	for flank: float in [-1.0, 1.0]:
		tube.call(Vector3(flank * 0.33, y0 + 0.61, -0.86), Vector3(flank * 0.69, y0 + 0.06, -1.02))
		b.box(Vector3(flank * 0.34, y0 + 0.60, -0.86), Vector3(0.14, 0.10, 0.15), I, acc)
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
	var spare := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top_y + 0.15, bed_front - bed_len * 0.5))
	_spare_wheel(b, spare, float(P["wr"]), acc)


static func _spare_wheel(b: PaperKit.Builder, mount: Transform3D, radius: float, hub: Color) -> void:
	b.card(PaperKit.circle(radius, 0, 0, 12), mount, Color("#302b28"), {"thick": 0.24, "edge": 0.04, "lip": 0.02})
	b.card(PaperKit.circle(radius * 0.51, 0, 0, 10), mount.translated_local(Vector3(0, 0, 0.13)), hub, {"thick": 0.015, "edge": 0.02, "lip": 0.02})
	for tilt: float in [-0.56, 0.56]:
		var strap := mount * Transform3D(Basis(Vector3.BACK, tilt), Vector3(0, 0, 0.145))
		b.box(Vector3.ZERO, Vector3(0.05, radius * 1.94, 0.016), strap, PaperKit.KRAFT)


static func _wheel_mesh(hub: Color, r: float, width: float, style: String) -> ArrayMesh:
	var b := PaperKit.Builder.new(5)
	# Fold a rounded shoulder into each sidewall. The centre tread and the
	# two shoulder facets shade separately as the wheel turns.
	var side := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	var tyre := Color("#302d2b")
	for i in 16:
		var start := TAU * i / 16.0
		var end := TAU * (i + 1) / 16.0
		var u := Vector3(0, sin(start), cos(start))
		var v := Vector3(0, sin(end), cos(end))
		var radial := (u + v).normalized()
		var shoulder := Vector3.RIGHT * width * 0.32
		b.quad(u*r - shoulder, v*r - shoulder, v*r + shoulder, u*r + shoulder, radial, PaperKit.lin(tyre.lightened(0.04)))
		for sign_x: float in [-1.0, 1.0]:
			var face := Vector3.RIGHT * sign_x * width * 0.5
			b.quad(u*r*0.88+face,v*r*0.88+face,v*r*0.62+face,u*r*0.62+face,Vector3.RIGHT*sign_x,PaperKit.lin(tyre))
			b.quad(u*r*0.62+face,v*r*0.62+face,v*r*0.62,u*r*0.62,-radial,PaperKit.lin(tyre.lightened(0.13)))
			b.quad(u*r + shoulder*sign_x, v*r + shoulder*sign_x, v*r*0.88 + face, u*r*0.88 + face,
				(radial + Vector3.RIGHT * sign_x).normalized(), PaperKit.lin(tyre))
	var steel := style in ["classic","mini","escort","estate","suv","truck"]
	var open := style in ["stratos","groups","gt4","evo","rally1","wrc","buggy"]
	var face := side.translated_local(Vector3.BACK*(width*0.5+0.008))
	var rim_color := Color("#b0aba3") if steel else hub.lerp(Color("#a3a3a0"),0.3)
	var spoke_count := 6 if open else 10
	var depth := 0.032 if steel else 0.016
	var backplate := face.translated_local(Vector3.FORWARD*0.061 if open else Vector3.BACK*0.003)
	# Behind the wheel face: a brake disc with a coloured caliper, seen through the openings in the wheel.
	var disc_face := face.translated_local(Vector3.FORWARD * 0.075)
	b.card(PaperKit.circle(r * 0.52, 0, 0, 18), disc_face, Color("#8d9298"), {"thick": 0.012, "lip": 0.0})
	b.card(PaperKit.circle(r * 0.40, 0, 0, 16), disc_face.translated_local(Vector3.BACK * 0.014), Color("#5a5d62"), {"thick": 0.006, "edge": 0.0, "lip": 0.0})
	b.card(PaperKit.rrect(r * 0.2, r * 0.46, 0.02, r * 0.4, r * 0.12), face.translated_local(Vector3.FORWARD * 0.045), Color("#c8553d"), {"thick": 0.03, "edge": 0.0, "lip": 0.0})
	if open:
		b.card(PaperKit.circle(r*0.43,0,0,16),backplate,Color("#716f69"),{"thick":0.014,"lip":0.0})
	else:
		# Steel and plain wheels: an outer ring and five broad spokes, with open gaps between them.
		for k in 16:
			var u0 := Vector2.from_angle(k*TAU/16)
			var v0 := Vector2.from_angle((k+1)*TAU/16)
			b.quad(face*Vector3(u0.x*r*0.64,u0.y*r*0.64,0.004), face*Vector3(v0.x*r*0.64,v0.y*r*0.64,0.004),
				face*Vector3(v0.x*r*0.46,v0.y*r*0.46,0.004), face*Vector3(u0.x*r*0.46,u0.y*r*0.46,0.004), Vector3.RIGHT, PaperKit.lin(rim_color.darkened(0.18)))
		for k in 5:
			var dir5 := Vector2.from_angle(k*TAU/5 + 0.3)
			var tan5 := dir5.orthogonal()
			var sp5 := PackedVector2Array([dir5*r*0.1 - tan5*r*0.07, dir5*r*0.52 - tan5*r*0.055, dir5*r*0.52 + tan5*r*0.055, dir5*r*0.1 + tan5*r*0.07])
			b.card(sp5, face.translated_local(Vector3.BACK*0.006), rim_color.darkened(0.1), {"thick": 0.012, "edge": 0.0, "lip": 0.0})
	for k in 16:
		var u := Vector2.from_angle(k*TAU/16)
		var v := Vector2.from_angle((k+1)*TAU/16)
		var a := face*Vector3(u.x*r*0.64,u.y*r*0.64,depth)
		var c := face*Vector3(v.x*r*0.64,v.y*r*0.64,depth)
		var d := face*Vector3(v.x*r*0.54,v.y*r*0.54,0.009)
		var e := face*Vector3(u.x*r*0.54,u.y*r*0.54,0.009)
		b.quad(a,c,d,e,Vector3.RIGHT,PaperKit.lin(rim_color.lightened(0.15)))
	for k in spoke_count:
		var dir := Vector2.from_angle(k*TAU/spoke_count)
		var tip := dir*r*0.55
		if open:
			var tangent := dir.orthogonal()*r
			var spoke := PackedVector2Array([dir*r*0.14-tangent*0.08,tip-tangent*0.04,tip+tangent*0.08,dir*r*0.14+tangent*0.08])
			b.card(spoke,face.translated_local(Vector3.BACK*0.014),rim_color,{"thick":0.014,"edge":0.0,"lip":0.0})
		else:
			pass
	b.card(PaperKit.circle(r*0.22,0,0,10),face.translated_local(Vector3.BACK*0.020),rim_color.lightened(0.12),{"thick":0.014,"lip":0.0})
	for k in 5:
		var lug := Vector2.from_angle(k*TAU/5)*r*0.15
		b.card(PaperKit.circle(r*0.034,lug.x,lug.y,6),face.translated_local(Vector3.BACK*0.033),tyre,{"thick":0.009,"lip":0.0})
	return b.mesh()



## In-car view: dashboard, A-pillars, roof edge, steering wheel and a rev dial whose needle moves.
## Returns {"root", "wheel" (rotates with steering), "needle" (rotates with rpm)}.
## Retain the real bodywork forward of the windscreen, including paint, vents and dents.
static func cockpit_nose(shell: Mesh, scuttle: float) -> ArrayMesh:
	var source := shell.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
	var result := PaperKit.Builder.new()
	for first in range(0, vertices.size(), 3):
		var front_count := int(vertices[first].z >= scuttle) + int(vertices[first + 1].z >= scuttle) + int(vertices[first + 2].z >= scuttle)
		if front_count == 0:
			continue
		if front_count == 3:
			for point in range(first, first + 3):
				result.v.append(vertices[point])
				result.n.append(normals[point])
				result.c.append(colors[point])
			continue
		var cut_vertices := PackedVector3Array()
		var cut_normals := PackedVector3Array()
		var cut_colors := PackedColorArray()
		for corner in 3:
			var a := first + corner
			var next := first + (corner + 1) % 3
			var inside := vertices[a].z >= scuttle
			if inside:
				cut_vertices.append(vertices[a])
				cut_normals.append(normals[a])
				cut_colors.append(colors[a])
			if inside != (vertices[next].z >= scuttle):
				var fraction := inverse_lerp(vertices[a].z, vertices[next].z, scuttle)
				cut_vertices.append(vertices[a].lerp(vertices[next], fraction))
				cut_normals.append(normals[a].lerp(normals[next], fraction).normalized())
				cut_colors.append(colors[a].lerp(colors[next], fraction))
		for corner in range(1, cut_vertices.size() - 1):
			for point: int in [0, corner, corner + 1]:
				result.v.append(cut_vertices[point])
				result.n.append(cut_normals[point])
				result.c.append(cut_colors[point])
	return result.mesh()


static func build_cockpit(car: Dictionary, model: Dictionary, mat: Material) -> Dictionary:
	var style: String = car.get("style", "saloon")
	var P := shape(style)
	var head: Vector3 = model["head"]
	var W: float = P["W"]
	var top_y: float = float(P["ride"]) + float(P["low"])
	var cab_h: float = P["cab_h"]
	var cab_z: float = P["cab_z"]
	var cab_l: float = P["cab_l"]
	var body_c: Color = car["body"]
	var dark := Color("#3a3430")
	var b := PaperKit.Builder.new(21)
	var I := Transform3D()
	var dash_z := minf(head.z + 0.55, float(P["cab_f"]) - 0.20)
	var trip_display: Label3D
	var dash: Array = DASHBOARDS.get(style, DASHBOARDS["evo"])
	var cluster_x := head.x + float(dash[0])
	var face_color := Color(dash[2])
	var panel := Color(dash[3])
	var digital := style in ["groups", "wrc", "rally1", "rally2"]
	var gear_readout: Label3D
	var speed_readout: Label3D
	# Low roof prototypes need a smaller instrument pack to clear the sightline at 58°.
	var dial_scale := clampf((cab_h - 0.42) * 1.8 + 0.66, 0.66, 1.0)
	var dial_y := top_y + 0.15 - (1.0 - dial_scale) * 0.14
	var speed_pivot: Node3D
	var speed_mesh: MeshInstance3D
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
		var outline := _cabin_outline(P, top_y)
		var cc := Vector2((cab_r + cab_f) * 0.5, top_y + cab_h * 0.5)
		var inset := _side_window(outline)
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
		var screen_base := outline[1]
		var screen_top := outline[2]
		gb.quad(Vector3(-hx, screen_base.y, screen_base.x), Vector3(hx, screen_base.y, screen_base.x), Vector3(hx, screen_top.y, screen_top.x), Vector3(-hx, screen_top.y, screen_top.x), Vector3(0, -rake, -cab_h).normalized(), Color.WHITE)
		_windscreen_wipers(b, outline, cw, Color("#2b2725"))
		gb.quad(Vector3(-hx, top_y + 0.12, cab_r + back * 0.12), Vector3(hx, top_y + 0.12, cab_r + back * 0.12), Vector3(hx, roof_y, cab_r + back), Vector3(-hx, roof_y, cab_r + back), Vector3(0, -back, cab_h).normalized(), Color.WHITE)
		# Rear bulkhead below the rear window, floor, and the footwell under the dash.
		b.quad(Vector3(-W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, top_y + 0.12, cab_r - 0.1), Vector3(-W * 0.47, top_y + 0.12, cab_r - 0.1), Vector3.BACK, Lt.call(trim.darkened(0.2)))
		b.quad(Vector3(-hx, top_y + 0.12, cab_r - 0.1), Vector3(hx, top_y + 0.12, cab_r - 0.1), Vector3(hx, top_y + 0.12, cab_r + back * 0.12), Vector3(-hx, top_y + 0.12, cab_r + back * 0.12), Vector3.UP, Lt.call(dark))
		b.quad(Vector3(-W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_r - 0.1), Vector3(W * 0.47, floor_y, cab_f + 0.35), Vector3(-W * 0.47, floor_y, cab_f + 0.35), Vector3.UP, Lt.call(Color("#3a3430")))
		b.quad(Vector3(-W * 0.47, floor_y, cab_f + 0.35), Vector3(W * 0.47, floor_y, cab_f + 0.35), Vector3(W * 0.47, top_y + 0.02, cab_f + 0.35), Vector3(-W * 0.47, top_y + 0.02, cab_f + 0.35), Vector3.FORWARD, Lt.call(dark))
		# Dashboard and scuttle sit behind the original bodywork.
		b.box(Vector3(0, top_y - 0.05, cab_f - 0.12), Vector3(W * 0.83, 0.18, 0.24), I, Color("#4e4640"), Color("#6a6058"))
		b.box(Vector3(0, top_y + 0.03, dash_z + 0.05), Vector3(W * 0.86, 0.12, 0.36), I, panel, panel.lightened(0.10))
		# Recessed demister slots across the scuttle, with raised folded lips.
		for section in 3:
			var slot_x := W * 0.23 * (section - 1)
			for row in 2:
				b.box(Vector3(slot_x, top_y + 0.047, cab_f - 0.14 + row * 0.028), Vector3(W * 0.16, 0.008, 0.013), I, dark)
		# Rear-view mirror, seats, centre console and a roll cage.
		var mirror := Vector3(0, roof_y - 0.063, cab_f - rake + 0.04)
		b.box(mirror + Vector3.UP * 0.035, Vector3(0.022, 0.075, 0.026), I, dark)
		b.box(mirror, Vector3(0.21, 0.056, 0.03), I, dark)
		b.box(mirror + Vector3.FORWARD * 0.018, Vector3(0.19, 0.042, 0.007), I, Color("#8498a1"))
		for vside: float in [-0.36, 0.36]:
			var vent := Vector3(W * vside, top_y + 0.035, dash_z - 0.136)
			b.box(vent, Vector3(0.115, 0.065, 0.018), I, dark.darkened(0.4))
			for slat in 3:
				b.box(vent + Vector3(0, (slat - 1) * 0.017, -0.011), Vector3(0.10, 0.006, 0.008), I, Color("#81796c"))
		for sx in [head.x, -head.x]:
			b.box(Vector3(sx, top_y - 0.1, head.z - 0.3), Vector3(0.5, 0.75, 0.12), I, Color("#2e2a28"))
			for side_x: float in [-0.215, 0.215]:
				b.box(Vector3(sx + side_x, top_y - 0.11, head.z - 0.20), Vector3(0.085, 0.51, 0.19), I, dark.darkened(0.25))
			b.box(Vector3(sx, top_y + 0.25, head.z - 0.3), Vector3(0.30, 0.18, 0.14), I, dark)
			b.box(Vector3(sx, floor_y + 0.2, head.z + 0.05), Vector3(0.5, 0.12, 0.6), I, Color("#2e2a28"))
		b.box(Vector3(0, floor_y + 0.2, head.z + 0.25), Vector3(0.22, 0.3, 0.8), I, Color("#3a3430"))
		var cage := Color("#b8b2a8")
		for xs in [-1.0, 1.0]:
			var a2 := Vector3(xs * (hx - 0.08), top_y + 0.05, cab_f - 0.05)
			var c2 := Vector3(xs * (hx - 0.08), roof_y - 0.06, cab_f - rake - 0.05)
			b.box(Vector3.ZERO, Vector3(0.045, 0.045, (c2 - a2).length()), Transform3D(Basis.looking_at((c2 - a2).normalized(), Vector3.UP), (a2 + c2) * 0.5), cage)
			b.box(Vector3(xs * (hx - 0.08), (top_y + roof_y) * 0.5, head.z - 0.45), Vector3(0.045, cab_h, 0.045), I, cage)
		b.box(Vector3(0, roof_y - 0.06, head.z - 0.45), Vector3(hx * 2.0 - 0.16, 0.045, 0.045), I, cage)
		# --- rally-car detail ---------------------------------------------------------------
		var ink := Color("#2a2624")
		var dx: float = cluster_x
		var cx: float = -head.x
		# Instrument binnacle over the driver's dials, with a speedo and three small gauges.
		var tilt := (Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, PI)).scaled(Vector3.ONE * dial_scale)
		var speed_face := Transform3D(tilt, Vector3(dx + 0.10 * dial_scale, dial_y, dash_z - 0.035))
		if digital:
			var lcd := Vector3(dx + 0.10 * dial_scale, dial_y, dash_z - 0.052)
			b.box(lcd, Vector3(0.19, 0.10, 0.022) * dial_scale, I, dark)
			b.box(lcd + Vector3.FORWARD * 0.013, Vector3(0.17, 0.082, 0.008) * dial_scale, I, face_color)
			speed_readout = Label3D.new()
			speed_readout.position = lcd + Vector3.FORWARD * 0.021
			speed_readout.rotation.y = PI
			speed_readout.font_size = 54
			speed_readout.pixel_size = 0.0012 * dial_scale
			speed_readout.modulate = Color("#1e3329")
			speed_readout.outline_size = 0
		else:
			b.card(PaperKit.circle(0.07, 0, 0, 14), speed_face, face_color, {"thick": 0.01, "edge": 0.012, "lip": 0.0})
			speed_pivot = Node3D.new()
			speed_pivot.transform = speed_face.translated_local(Vector3(0, 0, 0.010))
			var speed_hand := PaperKit.Builder.new(26)
			speed_hand.box(Vector3(0, 0.020, 0), Vector3(0.007, 0.054, 0.004), I, ink)
			speed_mesh = MeshInstance3D.new()
			speed_mesh.mesh = speed_hand.mesh()
			speed_mesh.material_override = mat
			speed_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			speed_pivot.add_child(speed_mesh)
			for k in 7:
				var angle := lerpf(2.2, -1.8, k / 6.0)
				var tick := speed_face * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
				b.box(Vector3(0, 0.05, 0.007), Vector3(0.006, 0.012, 0.003), tick, ink)
		for k in int(dash[1]):
			var gauge := Transform3D(tilt, Vector3(dx - (0.21 + k * 0.065) * dial_scale, dial_y - 0.02 * dial_scale, dash_z - 0.03))
			b.card(PaperKit.circle(0.03, 0, 0, 10), gauge, Color("#e8dcc0"), {"thick": 0.008, "edge": 0.008, "lip": 0.0})
			var pointer := gauge * Transform3D(Basis(Vector3.BACK, -0.65 + k * 0.58), Vector3.ZERO)
			b.box(Vector3(0, 0.009, 0.006), Vector3(0.005, 0.024, 0.003), pointer, ink)
		# Gauge pod standing on the dash behind the dials.
		b.box(Vector3.ZERO, Vector3(0.56, 0.16, 0.05), Transform3D(tilt, Vector3(dx - 0.05 * dial_scale, dial_y - 0.01 * dial_scale, dash_z + 0.04)), Color("#2e2a28"))
		if digital:
			var screen := Vector3(dx - 0.255 * dial_scale, dial_y + 0.040 * dial_scale, dash_z - 0.062)
			b.box(screen, Vector3(0.080, 0.055, 0.014) * dial_scale, I, face_color)
			gear_readout = Label3D.new()
			gear_readout.position = screen + Vector3.FORWARD * 0.011
			gear_readout.rotation.y = PI
			gear_readout.font_size = 54
			gear_readout.pixel_size = 0.0008 * dial_scale
			gear_readout.modulate = Color("#223329")
			gear_readout.outline_size = 0
		elif style in ["classic", "mini", "estate", "escort"]:
			# A rolled trim strip and glovebox latch on the passenger side.
			b.box(Vector3(-W * 0.23, top_y + 0.02, dash_z - 0.14), Vector3(W * 0.38, 0.016, 0.016), I, face_color)
			b.box(Vector3(-W * 0.23, top_y - 0.012, dash_z - 0.15), Vector3(0.085, 0.027, 0.018), I, dark)
		# Co-driver: tripmaster with a lit display, intercom box and the pace-note book on the dash.
		b.box(Vector3(cx, top_y + 0.1, dash_z - 0.02), Vector3(0.24, 0.1, 0.08), I, Color("#26282c"))
		b.box(Vector3(cx, top_y + 0.11, dash_z - 0.065), Vector3(0.18, 0.045, 0.01), I, Color("#b8e0a0"), Color(-1, 0, 0), true)
		b.box(Vector3(cx - 0.17, top_y + 0.08, dash_z - 0.01), Vector3(0.08, 0.06, 0.06), I, Color("#3a3c40"))
		trip_display = Label3D.new()
		trip_display.position = Vector3(cx, top_y + 0.11, dash_z - 0.073)
		trip_display.rotation.y = PI
		trip_display.font_size = 44
		trip_display.pixel_size = 0.00065
		trip_display.modulate = Color("#223329")
		trip_display.outline_size = 0
		# Recessed radio speaker and four mounting screws on the co-driver fascia.
		var grille := Vector3(cx, top_y - 0.038, dash_z - 0.15)
		b.box(grille, Vector3(0.22, 0.083, 0.012), I, dark)
		for k in 7:
			b.box(grille + Vector3((k - 3) * 0.021, 0, -0.009), Vector3(0.009, 0.054, 0.007), I, Color("#80776d"))
		for xsign: float in [-1.0, 1.0]:
			for ysign: float in [-1.0, 1.0]:
				b.box(grille + Vector3(xsign * 0.096, ysign * 0.03, -0.009), Vector3(0.009, 0.009, 0.005), I, PaperKit.CREAM)
		var notebook := Transform3D(Basis(Vector3.UP, 0.18), Vector3(cx + 0.05, top_y + 0.107, dash_z + 0.16))
		b.box(Vector3.ZERO, Vector3(0.26, 0.024, 0.19), notebook, car["accent"])
		b.box(Vector3(0, 0.016, 0), Vector3(0.245, 0.012, 0.178), notebook, PaperKit.CREAM)
		for k in 3:
			b.box(Vector3(-0.014 + 0.012 * k, 0.024, -0.05 + 0.046 * k), Vector3(0.14 - 0.02 * k, 0.003, 0.009), notebook, ink)
			b.box(Vector3(-0.09 + k * 0.085, 0.022, 0.08), Vector3(0.018, 0.014, 0.038), notebook, dark)
		# Switch panel on the centre console: a row of coloured toggles and a big red kill switch.
		b.box(Vector3(0, top_y - 0.08, dash_z - 0.14), Vector3(0.3, 0.14, 0.02), I, Color("#3a3430"))
		for k in 6:
			b.box(Vector3(-0.11 + k * 0.044, top_y - 0.06, dash_z - 0.155), Vector3(0.016, 0.03, 0.02), I, [Color("#d8d4cc"), Color("#e8b04a"), Color("#3f6fa8")][k % 3])
		b.box(Vector3(0.0, top_y - 0.12, dash_z - 0.156), Vector3(0.05, 0.05, 0.02), I, Color("#c8553d"))
		# Gear stick and the tall hydraulic handbrake beside it.
		var gbase := Vector3(0.06, floor_y + 0.36, head.z + 0.42)
		b.box(Vector3.ZERO, Vector3(0.03, 0.03, 0.34), Transform3D(Basis(Vector3.RIGHT, -1.15), gbase + Vector3(0, 0.15, -0.06)), ink)
		b.box(gbase + Vector3(0, 0.31, -0.12), Vector3(0.06, 0.06, 0.06), I, Color("#1a1816"))
		var hbase := Vector3(0.13, floor_y + 0.36, head.z + 0.18)
		b.box(Vector3.ZERO, Vector3(0.03, 0.03, 0.42), Transform3D(Basis(Vector3.RIGHT, -1.0), hbase + Vector3(0, 0.18, -0.1)), Color("#9a9690"))
		b.box(hbase + Vector3(0, 0.38, -0.21), Vector3(0.045, 0.1, 0.045), I, Color("#c8553d"))
		# Racing harnesses on both seat backs.
		for sx in [dx, cx]:
			for k in [-1.0, 1.0]:
				b.box(Vector3(sx + k * 0.1, top_y + 0.05, head.z - 0.235), Vector3(0.05, 0.62, 0.012), I, Color("#c8553d"))
			b.box(Vector3(sx, top_y - 0.2, head.z - 0.232), Vector3(0.24, 0.05, 0.012), I, Color("#c8553d"))
		# Door cards: a pull strap and a map pocket each side.
		for xs in [-1.0, 1.0]:
			var dxp: float = xs * (hx - 0.04)
			b.box(Vector3(dxp, top_y - 0.05, head.z + 0.15), Vector3(0.02, 0.04, 0.22), I, Color("#c8553d"))
			b.box(Vector3(dxp, floor_y + 0.32, head.z + 0.3), Vector3(0.03, 0.16, 0.4), I, Color("#3a3430"))
		# Fire extinguisher strapped to the floor between the seats.
		b.box(Vector3(0, floor_y + 0.12, head.z - 0.15), Vector3(0.09, 0.09, 0.36), I, Color("#c8553d"))
		b.box(Vector3(0, floor_y + 0.12, head.z + 0.05), Vector3(0.05, 0.05, 0.06), I, ink)
	else:
		b.box(Vector3(0, head.y - 0.32, head.z + 0.73), Vector3(W * 0.48, 0.14, 0.13), I, panel)
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(side * W * 0.19, head.y - 0.46, head.z + 0.74), Vector3(0.045, 0.26, 0.05), I, dark)
	# Rev dial on the dash.
	var dial_pos := Vector3(cluster_x - 0.08 * dial_scale, dial_y, dash_z - 0.035)
	if style == "buggy":
		dial_pos = Vector3(head.x, head.y - 0.20, head.z + 0.66)
	var dial_face := Transform3D((Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, PI)).scaled(Vector3.ONE * dial_scale), dial_pos)
	b.card(PaperKit.circle(0.09, 0, 0, 16), dial_face, face_color, {"thick": 0.01, "edge": 0.012, "lip": 0.0})
	for k in 9:
		var angle := lerpf(2.2, -1.8, k / 8.0)
		var tick := dial_face * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
		b.box(Vector3(0, 0.065, 0.007), Vector3(0.008, 0.018, 0.003), tick, Color("#c8553d") if k >= 7 else dark)
	var root := Node3D.new()
	if gear_readout:
		root.add_child(gear_readout)
		root.add_child(speed_readout)
	# Light lenses sit on a dark backing strip. All lit lenses share a single draw call.
	var strip := dial_pos + Vector3(0.08, 0.077, -0.037) * dial_scale
	var leds := MultiMesh.new()
	leds.transform_format = MultiMesh.TRANSFORM_3D
	leds.use_colors = true
	var lens := BoxMesh.new()
	lens.size = Vector3(0.025, 0.016, 0.010) * dial_scale
	var luminous := StandardMaterial3D.new()
	luminous.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luminous.vertex_color_use_as_albedo = true
	lens.material = luminous
	leds.mesh = lens
	leds.instance_count = 5
	b.box(strip + Vector3.BACK * 0.008, Vector3(0.19, 0.025, 0.014) * dial_scale, I, dark)
	for i in 5:
		var at := strip + Vector3((2 - i) * 0.035 * dial_scale, 0, -0.005)
		leds.set_instance_transform(i, Transform3D(Basis(), at))
		leds.set_instance_color(i, [Color("#61cc68"), Color("#83dc70"), Color("#ffc24d"), Color("#ff9944"), Color("#ff5141")][i])
	leds.visible_instance_count = 0
	var bar := MultiMeshInstance3D.new()
	bar.multimesh = leds
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var nose: MeshInstance3D
	var nose_clip := float(P["cab_f"]) + 0.004
	if style != "buggy":
		var shell := (model["body"] as Node3D).get_child(0) as MeshInstance3D
		nose = MeshInstance3D.new()
		nose.mesh = cockpit_nose(shell.mesh, nose_clip)
		nose.material_override = shell.material_override
		nose.layers = shell.layers
		root.add_child(nose)
	# Soft cabin fill so the dash, dials and switches read instead of sitting in black shadow.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, head.y + 0.1, head.z + 0.15)
	fill.omni_range = 1.4
	fill.omni_attenuation = 1.2
	fill.light_energy = 1.8
	fill.light_color = Color("#ffe8c8")
	fill.shadow_enabled = false
	root.add_child(fill)
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
	wheel.position = Vector3(head.x, head.y - 0.3, head.z + 0.47)
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
	for angle: float in [-1.33, 1.33, PI]:
		var spoke := face * Transform3D(Basis(Vector3.BACK, angle), Vector3(0, 0, 0.004))
		wb.card(PackedVector2Array([Vector2(-0.026, 0.02), Vector2(0.026, 0.02), Vector2(0.014, 0.155), Vector2(-0.014, 0.155)]), spoke, Color("#686057"), {"thick": 0.012, "edge": 0.0, "lip": 0.0})
	wb.box(Vector3(0, 0.168, 0.018), Vector3(0.029, 0.036, 0.024), face, car["accent"])
	# Gloved hands at nine and three o'clock, turning with the wheel: a fist over the rim, a thumb and a sleeve cuff trailing back.
	var glove := Color("#2d2f36")
	var skin := Color("#e0b48f")
	for hs: float in [-1.0, 1.0]:
		var hx := hs * 0.105
		var hy := 0.134
		wb.box(Vector3(hx, hy, -0.01), Vector3(0.062, 0.085, 0.07), I, glove)
		wb.box(Vector3(hx - hs * 0.012, hy + 0.052, -0.02), Vector3(0.03, 0.045, 0.04), I, glove)
		wb.box(Vector3(hx + hs * 0.002, hy - 0.07, -0.085), Vector3(0.05, 0.05, 0.12), I, Color(car["accent"]).darkened(0.35))
		wb.box(Vector3(hx + hs * 0.002, hy - 0.085, -0.15), Vector3(0.045, 0.045, 0.045), I, skin)
	var wmi := MeshInstance3D.new()
	wmi.mesh = wb.mesh()
	wmi.material_override = mat
	wheel.add_child(wmi)
	root.add_child(wheel)
	var needle := Node3D.new()
	needle.position = dial_pos + Vector3(0, 0, -0.012)
	needle.rotation.x = -0.5
	needle.scale = Vector3.ONE * dial_scale
	var nb := PaperKit.Builder.new(23)
	nb.card(PaperKit.rect(0.012, 0.08, 0, 0), Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), Color("#c8553d"), {"thick": 0.004, "edge": 0.0, "lip": 0.0})
	var nmi := MeshInstance3D.new()
	nmi.mesh = nb.mesh()
	nmi.material_override = mat
	var npiv := Node3D.new()
	npiv.add_child(nmi)
	needle.add_child(npiv)
	root.add_child(needle)
	if trip_display:
		root.add_child(trip_display)
	if speed_pivot:
		root.add_child(speed_pivot)
	return {"root": root, "nose": nose, "nose_clip": nose_clip, "wheel": wheel, "needle": npiv, "speed_hand": speed_mesh, "trip_display": trip_display, "shift_leds": leds, "gear_readout": gear_readout, "speed_readout": speed_readout}
