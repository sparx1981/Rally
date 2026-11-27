class_name Rallycross
extends RefCounted
## Twelve original rallycross circuits. Each is a closed polygon of waypoints with a fillet radius at
## every corner (a hairpin is two 90-degree corners), so the corner radii in the design brief are
## exact. The lap starts on the straight after vertex 0. Positions along the lap ("f") are fractions
## of its length, so a circuit keeps its character when its length is tuned.
##
## Fields per circuit
##   verts   [[x, y, radius], ...] metres; scaled uniformly (radii fixed) to reach `length`
##   widths  [[f, metres], ...]    road width, smoothly interpolated around the lap
##   elev    [[f, metres], ...]    road altitude (first and last equal)
##   surf    [[f0, f1, kind], ...] loose-surface sectors; everything else is tarmac
##   bank    [[f0, f1, slope], ...] cross-slope, + banks into the turn, - is adverse
##   joker   {f0, f1, side, surf, w, out, delta, pace}  alternative lane (pace = seconds the AI adds on it)
##   jumps   [{f, kind ("table"|"lip"|"gap"), h, len}]
##   splash  [{f}]  a shallow water crossing on the road
##   tunnel  [f0, f1]   bridge {f, w}   kerbs [[f0, f1]]
##   barrier [[f0, f1, kind]]  edge walls ("tyre", "jersey", "armco", "hay"); default `wall`

const SURFACES := {
	"tarmac": {"grip": 1.35, "drag": 0.0, "color": "#7b7872", "bump": 0.005, "name": "Tarmac"},
	"chalk": {"grip": 0.83, "drag": 0.135, "color": "#ece8dc", "bump": 0.025, "name": "Chalk gravel"},
	"granite": {"grip": 0.89, "drag": 0.16, "color": "#b8a29a", "bump": 0.045, "name": "Granite gravel"},
	"clay": {"grip": 1.0, "drag": 0.09, "color": "#b5573b", "bump": 0.03, "name": "Red bauxite clay"},
	"forest_dirt": {"grip": 0.93, "drag": 0.12, "color": "#7a5a40", "bump": 0.075, "name": "Loose forest dirt"},
	"fine_gravel": {"grip": 0.9, "drag": 0.14, "color": "#d6c49c", "bump": 0.02, "name": "Fine gravel"},
	"sand": {"grip": 0.86, "drag": 0.15, "color": "#e2d09a", "bump": 0.02, "name": "Sand and gravel"},
	"coarse_gravel": {"grip": 0.9, "drag": 0.17, "color": "#b6a68c", "bump": 0.04, "name": "Coarse gravel"},
	"industrial": {"grip": 0.95, "drag": 0.12, "color": "#938878", "bump": 0.03, "name": "Dockyard dirt"},
	"mud": {"grip": 0.62, "drag": 0.3, "color": "#6b4f38", "bump": 0.05, "name": "Watered mud"},
	"ford": {"grip": 0.7, "drag": 0.6, "color": "#6f9db8", "bump": 0.005, "name": "Water ford"},
}

## Kit -> scenery weights, base palette (an existing location), barrier look.
const KITS := {
	"A": {"base": "meadow", "kinds": {"tree": 6, "bush": 3, "tuft": 4, "bale": 4, "flowers": 2, "rock": 1, "barn": 1}, "name": "Countryside"},
	"B": {"base": "pinewood", "kinds": {"pine": 8, "bush": 2, "logs": 3, "rock": 4, "tuft": 2, "cabin": 1}, "name": "Nordic"},
	"C": {"base": "canyon", "kinds": {"rock": 6, "mesa": 3, "cactus": 1, "tuft": 2, "bush": 2, "tent": 1}, "name": "Quarry"},
	"D": {"base": "harbour", "kinds": {"crates": 4, "lamp": 5, "house": 3, "rock": 1, "tuft": 1}, "name": "Urban"},
}


static func circuits() -> Array:
	return [
		{"id": "chalk_valley", "name": "Chalk Valley Bowl", "kit": "A", "racers": 6, "length": 1480.0, "weather": "dry_day",
			"desc": "A figure-eight on a chalk hillside: dive under the overpass, climb back over it.",
			"verts": [[150,150,55],[330,150,42],[150,-150,40],[-150,150,40],[-200,-200,15]],
			"widths": [[0, 16], [0.07, 16], [0.12, 13], [0.45, 12], [0.55, 14], [0.70, 12], [0.85, 14], [0.97, 16], [1, 16]],
			"elev": [[0, 28], [0.08, 14], [0.30, 9], [0.40, 6], [0.50, 8], [0.62, 12], [0.69, 13], [0.85, 22], [0.95, 27], [1, 28]],
			"surf": [[0.079, 0.30, "chalk"], [0.50, 0.72, "chalk"]],
			"bank": [],
			"joker": {"f0": 0.655, "f1": 0.815, "side": "outer", "surf": "chalk", "w": 10.0, "out": 4.0, "delta": 2.0},
			"jumps": [], "barrier": [[0, 1, "tyre"]], "kerbs": [[0.97, 1.0]], "hay": [[0.50, 0.72]]},
		{"id": "timberline", "name": "Timberline Crest", "kit": "B", "racers": 6, "length": 1160.0, "weather": "rain_mist",
			"desc": "A banked timber spiral climbs over the start straight, then a blind forest crest jump.",
			"verts": [[-80,0,25],[200,0,16],[200,160,30],[80,160,30],[80,60,30],[320,60,30],[320,-120,25],[-80,-120,25]],
			"widths": [[0, 16], [0.10, 16], [0.16, 12], [0.25, 18], [0.45, 18], [0.55, 12], [0.9, 12], [0.97, 16], [1, 16]],
			"elev": [[0, 0], [0.16, 2], [0.25, 14], [0.42, 22], [0.50, 24], [0.58, 20], [0.64, 10], [0.78, 4], [1, 0]],
			"surf": [[0.18, 0.64, "forest_dirt"]],
			"bank": [[0.25, 0.41, 0.14]],
			"joker": {"f0": 0.247, "f1": 0.387, "side": "inner", "surf": "forest_dirt", "w": 10.0, "out": 3.0, "delta": 2.2},
			"jumps": [{"f": 0.60, "kind": "table", "h": 1.5, "len": 26.0}], "barrier": [[0, 1, "tyre"]], "kerbs": [[0.95, 1.0]]},
		{"id": "fjord", "name": "Fjord Switchback", "kit": "B", "racers": 5, "length": 1090.0, "weather": "dry_noon",
			"desc": "A steep launch climb, a blind summit and a plunging gravel corkscrew above the fjord.",
			"verts": [[-60,0,24],[150,0,15],[150,-50,15],[60,-50,22],[60,-90,22],[-80,-90,14],[-80,-140,14],[200,-140,28],[200,50,28],[-60,50,24]],
			"widths": [[0, 15], [0.10, 15], [0.18, 11], [0.60, 11], [0.75, 13], [0.95, 13], [1, 15]],
			"elev": [[0, 0], [0.14, 17], [0.22, 30], [0.50, 0], [0.70, 0], [1, 0]],
			"surf": [[0.20, 0.58, "granite"]],
			"bank": [[0.13, 0.19, 0.06], [0.37, 0.42, -0.03]],
			"joker": {"f0": 0.340, "f1": 0.440, "side": "outer", "surf": "granite", "w": 11.0, "out": 6.0, "delta": 1.9},
			"jumps": [], "barrier": [[0, 1, "tyre"]], "kerbs": []},
		{"id": "breton", "name": "Breton Dustbowl", "kit": "A", "racers": 6, "length": 1120.0, "weather": "dry_golden",
			"desc": "Wide fine-gravel sweepers made for three-abreast powerslides.",
			"verts": [[260,0,35],[330,150,40],[160,230,40],[40,150,40],[-60,220,45],[-170,110,45],[-110,-10,40]],
			"widths": [[0, 15], [0.10, 16], [0.15, 18], [0.70, 18], [0.82, 14], [0.90, 12], [1, 15]],
			"elev": [[0, 3], [0.3, 0], [0.6, 4], [0.9, 6], [1, 3]],
			"surf": [[0.14, 0.82, "fine_gravel"]],
			"bank": [],
			"joker": {"f0": 0.376, "f1": 0.644, "side": "outer", "surf": "fine_gravel", "w": 10.0, "out": 3.0, "delta": 1.5},
			"jumps": [{"f": 0.80, "kind": "table", "h": 1.5, "len": 24.0}], "splash": [{"f": 0.31}], "barrier": [[0, 1, "tyre"]], "kerbs": [[0.84, 0.96]]},
		{"id": "sierra", "name": "Sierra Alta Quarry", "kit": "C", "racers": 5, "length": 1510.0, "weather": "dry_noon",
			"desc": "A flat-out straight, a lip jump into a carved rock tunnel, a rutted final hairpin.",
			"verts": [[-130,0,28],[230,0,16],[230,-38,16],[60,-38,35],[60,-170,25],[-130,-170,13]],
			"widths": [[0, 15], [0.15, 15], [0.30, 12], [0.5, 13], [0.8, 11], [0.9, 13], [1, 15]],
			"elev": [[0, 10], [0.3, 10], [0.36, 12], [0.52, 26], [0.64, 34], [0.82, 14], [1, 10]],
			"surf": [[0.40, 0.82, "coarse_gravel"]],
			"bank": [],
			"joker": {"f0": 0.816, "f1": 0.970, "side": "inner", "surf": "coarse_gravel", "w": 10.0, "out": 4.0, "delta": 1.6},
			"jumps": [{"f": 0.675, "kind": "lip", "h": 1.2, "len": 18.0}], "tunnel": [0.70, 0.79], "barrier": [[0, 1, "armco"]], "kerbs": [[0.97, 1.0]]},
		{"id": "bauxite", "name": "Bauxite Cauldron", "kit": "C", "racers": 6, "length": 1240.0, "weather": "dry_golden",
			"desc": "A sunken red quarry with a banked clay Karussell and a rim-hugging Joker shelf.",
			"verts": [[240,0,45],[300,120,28],[240,240,28],[120,260,28],[60,150,40],[-30,200,25],[-110,110,25],[-80,-20,40]],
			"widths": [[0, 15], [0.1, 17], [0.2, 19], [0.45, 19], [0.55, 13], [0.7, 12], [0.9, 14], [1, 15]],
			"elev": [[0, 30], [0.05, 29.5], [0.21, 12], [0.45, 6], [0.56, 9], [0.68, 17], [0.84, 25], [0.94, 29], [1, 30]],
			"surf": [[0.14, 0.62, "clay"]],
			"bank": [[0.28, 0.42, 0.12]],
			"joker": {"f0": 0.209, "f1": 0.451, "side": "outer", "surf": "clay", "w": 10.0, "out": 6.0, "delta": 2.1},
			"jumps": [], "barrier": [[0, 1, "tyre"]], "kerbs": [[0.97, 1.0]]},
		{"id": "funnel", "name": "Funnel Ring", "kit": "A", "racers": 5, "length": 990.0, "weather": "dry_noon",
			"desc": "A start funnel into a tight hairpin, then under and over the same low overpass.",
			"verts": [[-130,150,22],[130,150,14],[130,116,14],[-50,116,25],[-50,40,25],[125,40,16],[125,76,16],[55,76,16],[55,-40,18],[-130,-40,22]],
			"widths": [[0, 16], [0.10, 16], [0.17, 11], [0.5, 12], [0.7, 12], [0.95, 16], [1, 16]],
			"elev": [[0, 12], [0.15, 10], [0.4, 4], [0.48, 2], [0.55, 6], [0.63, 14], [0.8, 18], [1, 12]],
			"surf": [[0.20, 0.62, "sand"]],
			"bank": [[0.50, 0.58, 0.06]],
			"joker": {"f0": 0.750, "f1": 0.950, "side": "inner", "surf": "sand", "w": 10.0, "out": 3.0, "delta": 2.3},
			"jumps": [], "barrier": [[0, 0.69, "tyre"], [0.69, 0.80, "armco"], [0.80, 1, "tyre"]], "kerbs": [[0.93, 1.0]]},
		{"id": "ardennes", "name": "Ardennes Gorge", "kit": "A", "racers": 5, "length": 1110.0, "weather": "dry_golden",
			"desc": "A tabletop jump into the valley and a narrow red covered bridge.",
			"verts": [[160,0,60],[260,25,60],[330,0,60],[420,60,55],[360,200,38],[200,260,28],[60,220,20],[-60,140,35],[-90,40,35]],
			"widths": [[0, 15], [0.1, 15], [0.3, 14], [0.5, 12], [0.58, 10], [0.64, 10], [0.70, 13], [0.9, 15], [1, 15]],
			"elev": [[0, 26], [0.1, 24], [0.3, 20], [0.40, 10], [0.55, 2], [0.62, 2], [0.75, 12], [0.9, 22], [1, 26]],
			"surf": [[0.32, 0.74, "coarse_gravel"]],
			"bank": [],
			"joker": {"f0": 0.475, "f1": 0.745, "side": "outer", "surf": "ford", "w": 10.0, "out": 5.0, "delta": 1.9},
			"jumps": [{"f": 0.36, "kind": "table", "h": 1.4, "len": 22.0}], "bridge": {"f": 0.605, "w": 10.0},
			"barrier": [[0, 1, "tyre"]], "kerbs": []},
		{"id": "baltic", "name": "Baltic Concrete", "kit": "B", "racers": 5, "length": 1280.0, "weather": "rain_overcast",
			"desc": "Zero-runoff concrete corridors, a dipper, then a tabletop into a banked dirt bowl.",
			"verts": [[-60,60,36],[300,0,90],[400,110,60],[250,200,22],[210,150,22],[170,230,22],[40,260,36],[-60,170,45]],
			"widths": [[0, 16], [0.3, 15], [0.5, 12], [0.7, 12], [0.8, 18], [0.95, 18], [1, 16]],
			"elev": [[0, 8], [0.3, 10], [0.45, 20], [0.55, 14], [0.65, 2], [0.7, 6], [0.8, 4], [1, 8]],
			"surf": [[0.62, 1.0, "granite"]],
			"bank": [[0.80, 0.95, 0.12]],
			"joker": {"f0": 0.755, "f1": 0.965, "side": "inner", "surf": "granite", "w": 10.0, "out": 3.0, "delta": 2.0},
			"jumps": [{"f": 0.72, "kind": "table", "h": 1.6, "len": 24.0}], "barrier": [[0, 1, "jersey"]], "kerbs": [[0.50, 0.68]]},
		{"id": "apex", "name": "Apex Ridge", "kit": "C", "racers": 6, "length": 1050.0, "weather": "dry_noon",
			"desc": "A blind 18 percent climb, a 25 m banked Mega-Bowl and a 30 m gap jump.",
			"verts": [[-60,0,60],[250,0,90],[380,60,60],[400,200,48],[250,260,48],[130,170,26],[60,70,30]],
			"widths": [[0, 15], [0.2, 15], [0.3, 12], [0.48, 25], [0.76, 25], [0.85, 14], [1, 15]],
			"elev": [[0, 10], [0.15, 6], [0.25, 3], [0.45, 40], [0.55, 42], [0.78, 36], [0.88, 20], [1, 10]],
			"surf": [[0.55, 1.0, "coarse_gravel"]],
			"bank": [[0.48, 0.76, 0.15]],
			"joker": {"f0": 0.360, "f1": 0.520, "side": "inner", "surf": "coarse_gravel", "w": 10.0, "out": 2.0, "delta": 1.8},
			"jumps": [{"f": 0.86, "kind": "gap", "h": 1.8, "len": 30.0}], "barrier": [[0, 1, "tyre"]], "kerbs": []},
		{"id": "harbor", "name": "Harbor Grid", "kit": "D", "racers": 5, "length": 1360.0, "weather": "dry_noon",
			"desc": "A drag strip through a monument arch, shipping containers and a steel crossover ramp.",
			"verts": [[-60,0,22],[330,0,14],[330,-110,16],[90,-110,16],[90,-180,16],[190,-180,16],[190,-50,20],[-60,-50,22]],
			"widths": [[0, 16], [0.15, 16], [0.2, 12], [0.25, 12], [0.29, 14], [0.7, 14], [0.75, 18], [0.92, 18], [0.97, 16], [1, 16]],
			"elev": [[0, 2], [0.3, 0], [0.45, 0], [0.7, 2], [0.85, 0], [1, 2]],
			"surf": [[0.36, 0.96, "industrial"]],
			"bank": [[0.78, 0.90, 0.06]],
			"joker": {"f0": 0.762, "f1": 0.967, "side": "outer", "surf": "industrial", "w": 10.0, "out": 8.0, "delta": 2.1},
			"jumps": [], "arch": 0.2, "barrier": [[0, 1, "jersey"]], "kerbs": []},
		{"id": "granite", "name": "Granite Apex", "kit": "B", "racers": 5, "length": 1180.0, "weather": "dry_day",
			"desc": "Blasted granite cuts, a drainage-culvert hairpin and an over-under crossover.",
			"verts": [[-140,0,45],[260,0,40],[260,-70,22],[200,-120,20],[270,-170,18],[270,-250,16],[100,-250,20],[100,-310,20],[190,-310,20],[190,-190,20],[-140,-190,30]],
			"widths": [[0, 15], [0.15, 15], [0.22, 12], [0.4, 10], [0.55, 12], [0.8, 14], [0.95, 15], [1, 15]],
			"elev": [[0, 20], [0.15, 12], [0.22, 6], [0.45, 4], [0.6, 10], [0.8, 16], [1, 20]],
			"surf": [[0.20, 0.62, "granite"]],
			"bank": [],
			"joker": {"f0": 0.838, "f1": 0.962, "side": "inner", "surf": "granite", "w": 10.0, "out": 10.0, "delta": 2.2},
			"jumps": [{"f": 0.80, "kind": "table", "h": 1.5, "len": 24.0}], "barrier": [[0, 1, "tyre"]], "kerbs": []},
	]


static func by_id(id: String) -> Dictionary:
	for c in circuits():
		if c.id == id:
			return c
	return {}
