class_name Catalog
extends RefCounted
## Static game data: cars, light/weather sets, stages and championship series.
## All names and designs are original to this project.

static var _cars: Array = []
static var _stages: Array = []
static var _locations: Array = []
static var _weather: Dictionary = {}
static var _series: Array = []


## Original cars in the classes found across rally games (historic RWD, Group 2, Group B, Group A,
## WRC, Rally1/Rally2, Group S prototypes, off-road buggies and trucks). No real makes or liveries.
## drive: rwd (throttle oversteer), fwd (understeer), awd (neutral). offroad: 0..1 rough-ground ability.
static func cars() -> Array:
	if _cars.is_empty():
		var C := func(id, name, cls, style, drive, body, acc, stripe, top, accel, grip, steer, offroad, desc):
			return {"id": id, "name": name, "class": cls, "style": style, "drive": drive, "body": Color(body), "accent": Color(acc),
				"front_split": {"quattro":0.50,"t16":0.40,"rally1":0.46}.get(style,0.48),
				"differential_bias": 1.0 if style in ["classic","mini","estate"] else (2.6 if drive=="awd" else 1.8),
				"stripe": Color(stripe), "top": top, "accel": accel, "grip": grip, "steer": steer, "offroad": offroad, "desc": desc}
		_cars = [
			C.call("ventura", "Ventura 60", "1960s Classic", "classic", "rwd", "#6f9bb0", "#efe3c8", "#c8553d", 0.8, 0.78, 0.9, 1.05, 0.2, "A rounded sixties sports coupe. Light, lively and tail-happy."),
			C.call("pip", "Pip 1300", "1960s Mini", "mini", "fwd", "#c8553d", "#efe3c8", "#efe3c8", 0.82, 0.86, 1.02, 1.22, 0.2, "A tiny front-drive box with a contrast roof and four spot lamps. Darts through hairpins."),
			C.call("comet", "Comet 1600", "1970s Group 2", "escort", "rwd", "#efe3c8", "#3f6fa8", "#c8553d", 0.88, 0.88, 0.95, 1.06, 0.3, "Boxy two-door rear-drive saloon on flared arches. Slides for days."),
			C.call("stiletto", "Stiletto HF", "1970s Group 4", "stratos", "rwd", "#2f8a8a", "#e8c05a", "#efe3c8", 0.96, 1.0, 0.95, 1.12, 0.2, "Short mid-engined wedge with a wraparound screen. Twitchy and thrilling."),
			C.call("strega", "Strega B", "1980s Group B", "groupb_rwd", "rwd", "#efe3c8", "#3f6fa8", "#c8553d", 1.04, 1.06, 0.92, 1.0, 0.25, "Long, low mid-engined Group B. Brutal power to the rear wheels."),
			C.call("tempest", "Tempest S1", "1980s Group B", "quattro", "awd", "#efe3c8", "#c8553d", "#e8b04a", 1.08, 1.15, 0.97, 0.94, 0.3, "Boxy four-wheel-drive turbo coupe with a towering wing. The sound of the eighties."),
			C.call("lince", "Lince T16", "1980s Group B", "t16", "awd", "#efe3c8", "#3f6fa8", "#c8553d", 1.04, 1.12, 1.0, 1.08, 0.3, "Stubby mid-engined hatch with bulging arches. Agile and explosive."),
			C.call("wraith", "Wraith S", "Group S Prototype", "groups", "awd", "#2f3a4a", "#e2763a", "#efe3c8", 1.12, 1.12, 1.0, 1.0, 0.2, "The prototype class that never raced. Low, light and savage."),
			C.call("quadra", "Quadra Evo", "1990s Group A", "integrale", "awd", "#c8553d", "#efe3c8", "#3f6fa8", 1.0, 1.04, 1.02, 1.0, 0.35, "Square five-door hatch with box arches and a roof spoiler. A legend of the era."),
			C.call("halcyon", "Halcyon GT4", "1990s Group A", "gt4", "awd", "#efe3c8", "#c8553d", "#2b2b2b", 1.04, 1.0, 0.98, 0.98, 0.3, "Sleek four-wheel-drive turbo coupe with a fastback and boot spoiler."),
			C.call("nimbus", "Nimbus Turbo", "1990s WRC", "impreza", "awd", "#2f4f9a", "#e8c05a", "#e8c05a", 1.06, 1.06, 1.04, 1.02, 0.35, "Compact four-door with a bonnet scoop, tall wing and gold wheels. Boxer burble included."),
			C.call("marten", "Marten RS", "2000s Group N", "evo", "awd", "#ece4d2", "#2f8a8a", "#c8553d", 1.02, 1.04, 1.02, 1.0, 0.35, "Turbo saloon with a scoop and a big wing. Balanced on every surface."),
			C.call("lynx", "Lynx Turbo", "2000s WRC", "wrc", "awd", "#35302c", "#e2763a", "#e8c05a", 1.08, 1.08, 1.04, 1.0, 0.35, "A noughties world rally hatch. Huge grip, fierce turbo."),
			C.call("fennec", "Fennec R2", "Modern Rally2", "rally2", "awd", "#f0f0ea", "#d9a441", "#2f8a8a", 1.02, 1.02, 1.05, 1.08, 0.35, "A modern privateer's weapon. Precise and easy to trust."),
			C.call("vortex", "Vortex R1", "Modern Rally1", "rally1", "awd", "#c8553d", "#2b2b2b", "#efe3c8", 1.14, 1.15, 1.08, 1.03, 0.35, "Top-class hybrid hatch with wild aero. The fastest car here."),
			C.call("otter", "Otter Estate", "Fun / Estate", "estate", "fwd", "#d9a441", "#7a3b3b", "#efe3c8", 0.92, 0.92, 1.04, 1.02, 0.4, "A family estate with a rally heart. Very stable."),
			C.call("badger", "Badger 4x4", "Off-road 4x4", "suv", "awd", "#5f7f4a", "#e08a3a", "#2f3a2a", 0.9, 0.86, 1.1, 0.9, 0.9, "Heavy cross-country 4x4. Ignores rough ground."),
			C.call("mule", "Mule Trophy", "Off-road Truck", "truck", "awd", "#e8b04a", "#2b2b2b", "#c8553d", 0.96, 0.9, 1.0, 0.88, 1.0, "Long-travel desert trophy truck. Flies over anything."),
			C.call("sandhopper", "Sandhopper", "Dune Buggy", "buggy", "rwd", "#e2763a", "#2b2b2b", "#e8c05a", 0.9, 1.1, 1.0, 1.15, 0.95, "Open tube-frame dune buggy. Tiny, twitchy and unstoppable off-road."),
			# Added from the reference audit: look-alikes with made-up names and liveries.
			C.call("scarab", "Scarab 1300", "1960s Rear-engine", "beetle", "rwd", "#3a9a86", "#efe3c8", "#c8553d", 0.8, 0.8, 0.94, 1.1, 0.3, "A round little rear-engined bug with a ducktail lid. Light at the front, so steer with the throttle."),
			C.call("alder", "Alder 328", "1990s Touring", "e36", "rwd", "#e8a33a", "#efe3c8", "#2b2b2b", 0.98, 1.0, 1.0, 1.04, 0.25, "A crisp touring coupe with quad lamps. Neutral until you ask too much of the rear."),
			C.call("gazelle", "Gazelle GT", "1970s Touring", "capri", "rwd", "#d6e03a", "#2b2b2b", "#efe3c8", 0.94, 0.96, 0.95, 1.02, 0.25, "A long-nosed fastback with flared arches and a ducktail. Loud, quick and a handful."),
			C.call("cormorant", "Cormorant RS", "1980s Group A", "cossie", "rwd", "#efe3c8", "#3f6fa8", "#c8553d", 1.0, 1.02, 0.98, 1.0, 0.3, "A big-winged hatch-saloon with a wide stance. Rear-drive, boosted and enthusiastic."),
			C.call("summit", "Summit Special", "Hill-climb Special", "pikes", "awd", "#c8302d", "#efe3c8", "#e8b04a", 1.12, 1.16, 1.06, 0.98, 0.15, "A low, wide silhouette racer with a splitter and a wing the size of a door. Built for one fast run."),
			C.call("verbena", "Verbena A100", "1970s Group 4", "berlinette", "rwd", "#2d5fc8", "#efe3c8", "#e8b04a", 0.92, 0.96, 0.98, 1.14, 0.3, "A rear-engined berlinette with a swooping fastback. Tiny, light and made for twisty gravel."),
			C.call("gallo", "Gallo V6", "1980s Group A", "gtv6", "rwd", "#efe3c8", "#2b4a8a", "#e8b04a", 0.98, 1.0, 0.98, 1.02, 0.25, "A hatchback coupe with a gruff V6 and a notchy gearbox."),
			C.call("mirage", "Mirage M", "1970s Group 5", "m1", "rwd", "#e8c040", "#c8302d", "#2b2b2b", 1.04, 1.04, 0.96, 1.0, 0.2, "A low wedge with pop-up lamps and a ducktail. Mid-engined and utterly committed."),
			C.call("rook", "Rook Turbo", "1980s Group B", "r5", "rwd", "#c8302d", "#efe3c8", "#2b2b2b", 1.06, 1.08, 0.95, 1.1, 0.25, "A boxy little hatch with the engine behind the seats and arches like a bodybuilder."),
			C.call("marmot", "Marmot 6R", "1980s Group B", "sixr4", "awd", "#e83a2d", "#efe3c8", "#2b3a8a", 1.04, 1.1, 1.0, 1.1, 0.3, "A stubby four-wheel-drive brick with a big rear wing and a thumping V6."),
			C.call("celeste", "Celeste GT-4", "1990s Group A", "celica", "awd", "#efe3c8", "#2f8a3a", "#c8302d", 1.02, 1.04, 1.02, 1.0, 0.35, "A sleek four-wheel-drive coupe-hatch with a bonnet scoop and a tall wing."),
			C.call("drover", "Drover 60", "Off-road 4x4", "patrol", "awd", "#3a3a3d", "#d9a441", "#c8553d", 0.88, 0.84, 1.1, 0.88, 0.9, "A tall expedition wagon on big tyres. Slow to turn, impossible to stop."),
		]
		for c in _cars:
			c["gold_wheels"] = c["id"] == "nimbus"
	return _cars


const LIVERY_NAMES := ["Works", "Privateer", "Heritage"]


## Heritage paint takes its palette and panel placement from period event programmes.
## The fictional cars keep their own race numbers and sponsor marks.
static func livery(car: Dictionary, i: int) -> Dictionary:
	var c := car.duplicate()
	var style: String = car["style"]
	c["paint"] = "sweep"
	match i % 3:
		1:
			c["body"] = car["accent"]
			c["accent"] = car["body"]
			c["stripe"] = Color("#f3e8cf") if Color(c["body"]).v < 0.7 else Color("#353330")
			c["paint"] = "twins"
		2:
			if style in ["mini", "classic", "escort"]:
				# Monte Carlo: red and ivory, narrow offset bonnet stripes.
				c.merge({"body": Color("#b63c32"), "accent": Color("#f5e8cf"), "stripe": Color("#e6d3ab"), "paint": "twins"}, true)
			elif style in ["stratos", "integrale", "groupb_rwd", "t16"]:
				# Sanremo: cream stock, a green flank and a red pinstripe.
				c.merge({"body": Color("#ece4ce"), "accent": Color("#bb4137"), "stripe": Color("#387650")}, true)
			elif style in ["impreza", "wrc", "rally1", "rally2"]:
				# British forest stages: blue and gold, rising over the rear quarter.
				c.merge({"body": Color("#31509a"), "accent": Color("#f4d16b"), "stripe": Color("#dda93f")}, true)
			else:
				# Safari: a low-glare bonnet over warm red bodywork.
				c.merge({"body": Color("#b44834"), "accent": Color("#393735"), "stripe": Color("#eee2c4"), "paint": "safari"}, true)
	return c


## Light sets follow the papercraft skill: one warm low key, a frontal fill, shadows that leak the
## world's colour (never grey), and weather that changes the light and grip, not the prints.
static func weather(id: String) -> Dictionary:
	if _weather.is_empty():
		_weather = {
			"dry_day": {"label": "Dry", "kind": "dry", "key": Color("#ffdcb2"), "key_e": 0.78, "elev": 48.0, "azim": 35.0,
				"fill": Color("#f2dcc2"), "fill_e": 0.2, "amb": Color("#fff0da"), "amb_e": 0.24, "leak": Color("#a0602c"),
				"wrap": 0.3, "grip": 1.0, "exposure": 0.95, "contrast": 1.06, "sat": 0.94, "tint": Vector3(1.01, 0.99, 0.975),
				"vig": 0.08, "vig_col": Color("#3a200c"), "green_pull": 0.3, "glow": 0.0, "particles": ""},
			"dry_noon": {"label": "Dry", "kind": "dry", "key": Color("#fff0d2"), "key_e": 0.8, "elev": 58.0, "azim": 50.0,
				"fill": Color("#d8b0b4"), "fill_e": 0.2, "amb": Color("#fff0da"), "amb_e": 0.22, "leak": Color("#9a5a34"),
				"wrap": 0.3, "grip": 0.94, "exposure": 0.93, "contrast": 1.06, "sat": 0.92, "tint": Vector3(1.0, 0.99, 0.98),
				"vig": 0.08, "vig_col": Color("#3a200c"), "green_pull": 0.2, "glow": 0.0, "particles": ""},
			"dry_golden": {"label": "Dry", "kind": "dry", "key": Color("#ffc890"), "key_e": 0.85, "elev": 32.0, "azim": 40.0,
				"fill": Color("#b9bcd8"), "fill_e": 0.22, "amb": Color("#ffe6c8"), "amb_e": 0.22, "leak": Color("#8f5034"),
				"wrap": 0.3, "grip": 1.0, "exposure": 0.94, "contrast": 1.06, "sat": 0.93, "tint": Vector3(1.0, 0.99, 0.985),
				"vig": 0.09, "vig_col": Color("#3a200c"), "green_pull": 0.25, "glow": 0.0, "particles": ""},
			"rain_mist": {"label": "Rain", "kind": "rain", "key": Color("#f8e2b6"), "key_e": 0.6, "elev": 52.0, "azim": 30.0,
				"fill": Color("#62857f"), "fill_e": 0.24, "amb": Color("#c9d0c8"), "amb_e": 0.34, "leak": Color("#44685c"),
				"wrap": 0.34, "grip": 0.72, "exposure": 1.0, "contrast": 1.08, "sat": 0.92, "tint": Vector3(0.99, 1.0, 1.01),
				"vig": 0.12, "vig_col": Color("#1e2a28"), "green_pull": 0.15, "glow": 0.25, "particles": "rain"},
			"rain_overcast": {"label": "Rain", "kind": "rain", "key": Color("#f3e6cf"), "key_e": 0.62, "elev": 50.0, "azim": 45.0,
				"fill": Color("#9fb3c4"), "fill_e": 0.24, "amb": Color("#d0d6dc"), "amb_e": 0.34, "leak": Color("#4f6070"),
				"wrap": 0.34, "grip": 0.74, "exposure": 1.0, "contrast": 1.08, "sat": 0.93, "tint": Vector3(0.99, 1.0, 1.02),
				"vig": 0.12, "vig_col": Color("#1c2430"), "green_pull": 0.15, "glow": 0.35, "particles": "rain"},
			"snow_bright": {"label": "Snow", "kind": "snow", "key": Color("#fbf0e0"), "key_e": 0.72, "elev": 46.0, "azim": 40.0,
				"fill": Color("#a4bbe0"), "fill_e": 0.22, "amb": Color("#dfe6f2"), "amb_e": 0.28, "leak": Color("#6c84b0"),
				"wrap": 0.3, "grip": 0.53, "exposure": 0.86, "contrast": 1.08, "sat": 1.0, "tint": Vector3(1.0, 1.0, 1.02),
				"vig": 0.08, "vig_col": Color("#283048"), "green_pull": 0.1, "glow": 0.0, "particles": "snow"},
			"snow_ice": {"label": "Snow", "kind": "snow", "key": Color("#fbf0e0"), "key_e": 0.72, "elev": 44.0, "azim": 30.0,
				"fill": Color("#a4bbe0"), "fill_e": 0.22, "amb": Color("#dfe6f2"), "amb_e": 0.28, "leak": Color("#6c84b0"),
				"wrap": 0.3, "grip": 0.46, "exposure": 0.86, "contrast": 1.08, "sat": 1.0, "tint": Vector3(1.0, 1.0, 1.02),
				"vig": 0.08, "vig_col": Color("#283048"), "green_pull": 0.1, "glow": 0.0, "particles": "snow"},
			"snow_dusk": {"label": "Snow", "kind": "snow", "key": Color("#ffb38a"), "key_e": 0.7, "elev": 28.0, "azim": 45.0,
				"fill": Color("#6f63a8"), "fill_e": 0.3, "amb": Color("#c6bfd9"), "amb_e": 0.34, "leak": Color("#5e5c98"),
				"wrap": 0.36, "grip": 0.52, "exposure": 0.95, "contrast": 1.06, "sat": 0.98, "tint": Vector3(1.01, 0.98, 1.01),
				"vig": 0.14, "vig_col": Color("#1a1430"), "green_pull": 0.1, "glow": 1.1, "particles": "snow"},
		}
	return _weather[id]


static func _pal(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		out[k] = Color(d[k])
	return out


static func locations() -> Array:
	if _locations.is_empty():
		_locations = [
			{"id": "meadow", "bridges": ["stone"], "barriers": ["fence", "wall", "wall"], "region": "British farmland lanes (Rally GB style): narrow, rolling, hedged.", "elev": {"climb": 0.0, "amp": 6.0, "wave": 190.0, "grade": 0.08, "hills": 9.0}, "name": "Meadow Run", "weather": "dry_day", "seed": 1101, "length": 1700.0, "twist": 0.35, "width": 8.5,
				"desc": "Rolling farmland lanes between hay fields and red barns.",
				"pal": _pal({"ground": "#d9d7bc", "ground2": "#cbcfa9", "ground3": "#e3dcc6", "road": "#c9ab7e", "rut": "#a88a62",
					"f_dark": "#5f7f4a", "f_mid": "#7d9a5a", "f_light": "#a3b56e", "trunk": "#7a5235", "accent": "#c8553d",
					"accent2": "#e8b04a", "wall": "#efe3c8", "roof": "#b5523b", "wood": "#8a5a3b", "stone": "#a99d8a", "flower": "#e8d06a"}),
				"kinds": {"tree": 5, "bush": 4, "tuft": 5, "flowers": 3, "house": 1, "barn": 1, "bale": 3, "rock": 1, "logs": 1, "spectators": 0}},
			{"id": "canyon", "barriers": ["armco"], "region": "High desert mountain roads (Mexico / Acropolis style): rocky climbs and switchbacks.", "elev": {"climb": 32.0, "amp": 9.0, "wave": 260.0, "grade": 0.11, "hills": 26.0}, "name": "Sandstone Canyon", "weather": "dry_noon", "seed": 2207, "length": 1900.0, "twist": 0.5, "width": 8.5,
				"desc": "Sun-baked switchbacks through red mesas and cactus flats.",
				"pal": _pal({"ground": "#ead8b2", "ground2": "#e0c79c", "ground3": "#f0e2c4", "road": "#c99c6c", "rut": "#a87a50",
					"f_dark": "#5f7a50", "f_mid": "#7d9264", "f_light": "#a4b07a", "trunk": "#7a5235", "accent": "#2f8a8a",
					"accent2": "#e8c05a", "wall": "#e9cfa6", "roof": "#b5623b", "wood": "#8a5a3b", "stone": "#c9774a", "flower": "#e2763a"}),
				"kinds": {"cactus": 5, "mesa": 3, "rock": 5, "bush": 2, "tuft": 3, "tent": 1, "logs": 1}},
			{"id": "autumn", "leaves": true, "forest": {"trees": {"tree": 3, "pine": 1}}, "bridges": ["stone", "covered"], "barriers": ["fence", "armco"], "region": "Vineyard and forest ridges (Germany / Ardennes style): twisty, up and down.", "elev": {"climb": 14.0, "amp": 9.0, "wave": 150.0, "grade": 0.1, "hills": 15.0}, "name": "Autumn Ridge", "weather": "dry_golden", "seed": 3313, "length": 2000.0, "twist": 0.6, "width": 8.0,
				"desc": "Twisting forest gravel under copper and gold leaves.",
				"pal": _pal({"ground": "#e6d2a8", "ground2": "#dcc394", "ground3": "#ecdcbc", "road": "#b8946a", "rut": "#94704c",
					"f_dark": "#a8452e", "f_mid": "#d0682e", "f_light": "#e8a040", "trunk": "#6e4a32", "accent": "#e8c05a",
					"accent2": "#7a8a4a", "wall": "#efe3c8", "roof": "#8a4a32", "wood": "#7a5235", "stone": "#a89c8a", "flower": "#e8c05a"}),
				"kinds": {"fern": 2, "vine_row": 3, "tree": 7, "pine": 3, "bush": 3, "tuft": 3, "logs": 2, "rock": 2, "cabin": 1}},
			{"id": "moor", "bridges": ["stone"], "barriers": ["wall", "wall", "fence"], "region": "Open moorland (Welsh forests and moors style): rolling crests, wet and rough.", "elev": {"climb": 0.0, "amp": 10.0, "wave": 210.0, "grade": 0.09, "hills": 16.0}, "name": "Moorland Mire", "weather": "rain_mist", "seed": 4421, "length": 1800.0, "twist": 0.45, "width": 8.5,
				"desc": "Wet peat tracks across heather moors. Puddles everywhere.",
				"pal": _pal({"ground": "#c2c6ad", "ground2": "#b2b99c", "ground3": "#cdcdb6", "road": "#8f7a62", "rut": "#6f5c48",
					"f_dark": "#5d7556", "f_mid": "#7b9068", "f_light": "#9aa87a", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#c9a447", "wall": "#e2dccb", "roof": "#5d6b7a", "wood": "#6e5038", "stone": "#9c9a90", "flower": "#a77ba0"}),
				"kinds": {"bulrush": 2, "heather": 6, "rock": 4, "bush": 3, "tuft": 4, "pine": 1, "house": 1, "tent": 1}},
			{"id": "pinewood", "forest": {"trees": {"pine": 1}, "thick": 1.2}, "bridges": ["covered"], "barriers": [], "region": "Fast forest gravel (Finland style): short sharp crests and yumps between the trees.", "elev": {"climb": 0.0, "amp": 4.0, "wave": 75.0, "grade": 0.1, "hills": 8.0}, "name": "Pinewood Deluge", "weather": "rain_mist", "seed": 5531, "length": 2000.0, "twist": 0.62, "width": 8.0,
				"desc": "Dark, dripping pine forest with tight muddy hairpins.",
				"pal": _pal({"ground": "#bcc2a8", "ground2": "#aab396", "ground3": "#c8c9b0", "road": "#7e6a55", "rut": "#5e4c3c",
					"f_dark": "#3f5e4a", "f_mid": "#557560", "f_light": "#6d8a6c", "trunk": "#6a4a36", "accent": "#d9a441",
					"accent2": "#c8553d", "wall": "#e2dccb", "roof": "#5d6b7a", "wood": "#6e5038", "stone": "#9a9a90", "flower": "#d9a441"}),
				"kinds": {"fern": 3, "wood_store": 1, "pine": 9, "bush": 3, "tuft": 3, "logs": 2, "rock": 2, "tent": 1, "cabin": 1}},
			{"id": "harbour", "coast": {"sea": -3.0, "edge": 30.0, "beach": true, "harbour": true}, "barriers": ["armco", "wall", "wall"], "region": "Coastal mountain roads (Corsica / Sardinia style): climbing away from the sea.", "elev": {"climb": 26.0, "amp": 6.0, "wave": 160.0, "grade": 0.11, "hills": 22.0}, "name": "Harbour Lanes", "weather": "rain_overcast", "seed": 6619, "length": 1750.0, "twist": 0.55, "width": 8.0,
				"desc": "Slippery cobbles through a painted fishing village.",
				"pal": _pal({"ground": "#c9c5b3", "ground2": "#b9b7a6", "ground3": "#d6d1bd", "road": "#8a8278", "rut": "#6c665e",
					"f_dark": "#5d7556", "f_mid": "#7b9068", "f_light": "#9aa87a", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#2f8a8a", "wall": "#d98c6a", "roof": "#5d6b7a", "wood": "#7a5a40", "stone": "#9c988c", "flower": "#e2c26a"}),
				"kinds": {"bulrush": 2, "net_shed": 2, "house": 6, "crates": 3, "lamp": 2, "bush": 2, "tuft": 2, "rock": 1, "spectators": 0}},
			{"id": "alpine", "barriers": ["armco"], "region": "Alpine col (Monte Carlo, Col de Turini style): a long hairpin climb to the summit.", "elev": {"climb": 55.0, "amp": 5.0, "wave": 220.0, "grade": 0.12, "hills": 42.0}, "name": "Alpine Pass", "weather": "snow_bright", "seed": 7717, "length": 1900.0, "twist": 0.6, "width": 8.0,
				"desc": "High mountain hairpins on packed snow. Brake early.",
				"pal": _pal({"ground": "#e4e8ef", "ground2": "#d8dee8", "ground3": "#eef0f5", "road": "#cdd2dc", "rut": "#a7aec0",
					"f_dark": "#4a6b5e", "f_mid": "#628374", "f_light": "#7d9a88", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#3f6fa8", "wall": "#e8dcc8", "roof": "#8a4a3a", "wood": "#7a5235", "stone": "#9a9fae", "flower": "#f3f4f7"}),
				"kinds": {"pine_snow": 8, "rock": 3, "snowbank": 5, "cabin": 1, "logs": 1}},
			{"id": "lakes", "barriers": [], "region": "Frozen lakes and snowbanks (Rally Sweden style): fast and nearly flat.", "elev": {"climb": 0.0, "amp": 3.0, "wave": 240.0, "grade": 0.06, "hills": 6.0}, "name": "Frozen Lakes", "weather": "snow_ice", "seed": 8803, "length": 1800.0, "twist": 0.4, "width": 9.0,
				"desc": "Fast, icy straights between birch woods. Almost no grip.",
				"pal": _pal({"ground": "#e2e7ee", "ground2": "#cddbe8", "ground3": "#edf0f5", "road": "#c9cfda", "rut": "#a3abbd",
					"f_dark": "#5a7a6a", "f_mid": "#7a9a7a", "f_light": "#a4b88a", "trunk": "#efeae0", "accent": "#d98c3a",
					"accent2": "#a84a3a", "wall": "#a84a3a", "roof": "#3f4a5a", "wood": "#7a5235", "stone": "#9aa0ae", "flower": "#f3f4f7"}),
				"kinds": {"birch": 6, "pine_snow": 3, "snowbank": 5, "cabin": 1, "rock": 2}},
			{"id": "taiga", "forest": {"trees": {"pine_snow": 1}}, "barriers": ["fence"], "tod": 1, "region": "Arctic forest (Arctic Rally / Norway style): rolling snow roads under a low sun.", "elev": {"climb": 10.0, "amp": 7.0, "wave": 170.0, "grade": 0.09, "hills": 12.0}, "name": "Twilight Taiga", "weather": "snow_bright", "seed": 9901, "length": 2000.0, "twist": 0.55, "width": 8.0,
				"desc": "Snowy forest at dusk, lit by cabin windows and lamps.",
				"pal": _pal({"ground": "#dcdbe6", "ground2": "#cfcfdd", "ground3": "#e6e5ee", "road": "#c2c1d0", "rut": "#9e9cb4",
					"f_dark": "#3e5a5a", "f_mid": "#53706a", "f_light": "#6d8a80", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#e8c05a", "wall": "#a85a3a", "roof": "#4a4a5a", "wood": "#7a5235", "stone": "#9a9aae", "flower": "#f3f4f7"}),
				"kinds": {"pine_snow": 8, "snowbank": 4, "cabin": 2, "lamp": 2, "rock": 1, "logs": 1}},
			{"id": "cliffs", "barriers": ["wall", "fence"], "coast": {"sea": -26.0, "edge": 20.0, "beach": false, "lighthouse": true}, "region": "Clifftop coast roads (Wales / Cornwall / Madeira style): the sea a sheer drop away.", "elev": {"climb": 16.0, "amp": 7.0, "wave": 180.0, "grade": 0.1, "hills": 8.0}, "name": "Coastal Cliffs", "weather": "dry_day", "seed": 10111, "length": 1900.0, "twist": 0.5, "width": 8.0,
				"desc": "Windy clifftop lanes with the sea far below. Don't run wide.",
				"pal": _pal({"ground": "#c9d3a6", "ground2": "#b8c595", "ground3": "#d6ddb4", "road": "#b8ab90", "rut": "#958870",
					"f_dark": "#5a7650", "f_mid": "#78935f", "f_light": "#9db27a", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#3f6fa8", "wall": "#ece6d8", "roof": "#4a5a6a", "wood": "#7a5a40", "stone": "#a8a496", "flower": "#e8c05a"}),
				"kinds": {"tuft": 6, "bush": 4, "rock": 3, "flowers": 2, "house": 1, "spectators": 1}},
			{"id": "gorge", "bridges": ["girder", "truss"], "barriers": ["armco"], "region": "High desert mountain roads (Mexico / Acropolis style): rocky climbs and switchbacks.", "elev": {"climb": 32.0, "amp": 9.0, "wave": 260.0, "grade": 0.11, "hills": 26.0}, "name": "Slate Gorge", "weather": "dry_noon", "seed": 11939, "length": 1900.0, "twist": 0.5, "width": 8.5,
				"desc": "Exposed slate cuttings, a rail underpass and long spans over ravines.",
				"pal": _pal({"ground": "#b8aaa0", "ground2": "#a09388", "ground3": "#cec0ad", "road": "#c99c6c", "rut": "#a87a50",
					"f_dark": "#5f7a50", "f_mid": "#7d9264", "f_light": "#a4b07a", "trunk": "#7a5235", "accent": "#2f8a8a",
					"accent2": "#e8c05a", "wall": "#e9cfa6", "roof": "#b5623b", "wood": "#8a5a3b", "stone": "#706971", "flower": "#e2763a"}),
				"kinds": {"mesa": 4, "rock": 22, "bush": 1, "tuft": 1}},
		]
	return _locations


const VARIANTS := [["Sprint", 4000.0], ["Classic", 8000.0], ["Long", 10000.0], ["Marathon", 15000.0]]
const SUNSET := 3
const SUNRISE := 4
const TOD_NAMES := ["Day", "Dusk", "Night", "Sunset", "Sunrise"]

# Names, terrain ink multipliers and regional scenery weights in route order.
const CHAPTERS := {
	"gorge": [
		{"name": "Scree slopes"}, {"name": "Split slate"}, {"name": "Pale shelves"}
	],
	"alpine": [
		{"name": "Wooded slopes", "ink": Vector3(0.83, 0.92, 0.96),
			"weights": {"pine_snow": 3.6, "logs": 2.4, "snowbank": 0.65, "rock": 0.55}},
		{"name": "Ski lift slopes", "ink": Vector3(1.0, 1.02, 1.04),
			"weights": {"cabin": 3.3, "snowbank": 2.3, "pine_snow": 0.9}},
		{"name": "Exposed snowfields", "ink": Vector3(1.12, 1.14, 1.19),
			"weights": {"pine_snow": 0.12, "logs": 0.15, "cabin": 0.25, "rock": 2.9, "snowbank": 2.5}}
	],
	"harbour": [
		{"name": "Working waterfront", "ink": Vector3(0.91, 0.96, 1.03),
			"weights": {"net_shed": 3.0, "crates": 2.7, "bulrush": 2.0, "house": 0.6}},
		{"name": "Fishing village", "ink": Vector3(1.10, 1.04, 0.94),
			"weights": {"house": 3.6, "lamp": 3.0, "net_shed": 0.4, "rock": 0.6}},
		{"name": "Open headland", "ink": Vector3(0.85, 1.02, 0.85),
			"weights": {"house": 0.14, "net_shed": 0.1, "crates": 0.15, "lamp": 0.35,
				"tuft": 4.0, "bush": 3.0, "rock": 2.9}}
	],
	"autumn": [
		{"name": "Vineyard lanes", "ink": Vector3(1.01, 1.08, 0.84), "forest": 0.18,
			"weights": {"vine_row": 4.0, "cabin": 2.3, "tree": 0.24, "pine": 0.35}},
		{"name": "Copper woods", "ink": Vector3(1.04, 0.78, 0.66), "forest": 1.0,
			"weights": {"tree": 3.2, "fern": 2.4, "logs": 2.0, "vine_row": 0.08}},
		{"name": "Open ridge", "ink": Vector3(1.16, 1.06, 0.88), "forest": 0.10,
			"weights": {"tree": 0.16, "pine": 0.38, "vine_row": 0.1, "tuft": 3.3, "rock": 3.0, "bush": 2.0}}
	]
}


# The four routes pass through different parts of each location. Double one
# existing scenery weight per route without increasing the placement budget.
const ROUTE_SCENERY := {
	"meadow": ["flowers", "barn", "bale", "tree"],
	"gorge": ["rock", "mesa", "rock", "mesa"],
	"canyon": ["cactus", "mesa", "tent", "rock"],
	"autumn": ["tree", "cabin", "logs", "pine"],
	"moor": ["heather", "house", "rock", "pine"],
	"pinewood": ["bush", "cabin", "logs", "pine"],
	"harbour": ["crates", "house", "lamp", "rock"],
	"alpine": ["cabin", "snowbank", "rock", "pine_snow"],
	"lakes": ["birch", "cabin", "snowbank", "rock"],
	"taiga": ["lamp", "cabin", "logs", "pine_snow"],
	"cliffs": ["flowers", "house", "bush", "rock"]
}

## 44 stages: every location as a Sprint (4 km), Classic (8 km), Long (10 km) and Marathon (15 km).
## The 12 rallycross circuits are built but not yet released: flip to true to list them.
const RX_ENABLED := true


static func stages() -> Array:
	if _stages.is_empty():
		for li in locations().size():
			var loc: Dictionary = locations()[li]
			for v in VARIANTS.size():
				var st := loc.duplicate(true)
				var signature: String = ROUTE_SCENERY[loc["id"]][v]
				st["kinds"][signature] = int(st["kinds"][signature]) * 2 + 1
				st["loc"] = li
				st["variant"] = v
				st["id"] = "%s_%s" % [loc["id"], VARIANTS[v][0].to_lower()]
				st["loc_id"] = loc["id"]
				st["stacked"] = loc.id == "gorge" and v == 1
				st["name"] = loc["name"]
				st["variant_name"] = VARIANTS[v][0]
				st["length"] = float(VARIANTS[v][1])
				# Long stages mix in more fast sections, like real marathon stages.
				st["twist"] = float(loc["twist"]) * [1.0, 0.9, 0.82, 0.72][v]
				st["seed"] = int(loc["seed"]) + v * 977
				st["tod"] = int(loc.get("tod", 0))
				_stages.append(st)
		var arena: Dictionary = locations()[1].duplicate(true)
		arena.merge({"id": "sandstone_arena", "loc_id": "arena", "name": "Sandstone Eight",
			"variant_name": "Rallycross", "loc": -1, "variant": 0, "circuit": true,
			"length": 965.0, "width": 12.0, "seed": 7641, "elev": {"hills": 2.4},
			"barriers": [], "kinds": {"tree": 6, "rock": 5, "bush": 2, "tuft": 3},
			"desc": "A sandy figure-eight with grandstands, a bridge crossing and a shallow ford."}, true)
		_stages.append(arena)
		var rx_index := 0
		for c: Dictionary in (Rallycross.circuits() if RX_ENABLED else []):
			var kit: Dictionary = Rallycross.KITS[c.kit]
			var base: Dictionary = {}
			for loc: Dictionary in locations():
				if loc.id == kit.base:
					base = loc.duplicate(true)
			base.merge({"id": c.id, "loc_id": "rx_" + str(c.id), "name": c.name, "variant_name": "Rallycross", "loc": -1,
				"variant": 0, "circuit": true, "rx": c, "length": float(c.length), "width": 16.0, "seed": 7000 + rx_index * 31,
				"elev": {"hills": 3.0}, "barriers": [], "bridges": [], "kinds": kit.kinds.duplicate(), "desc": c.desc,
				"weather": c.weather, "tod": 0, "stacked": false}, true)
			base.erase("coast")
			base.erase("forest")
			base.erase("leaves")
			base.pal = base.pal.duplicate()
			base.pal["road"] = Color("#7b7872")
			base.pal["rut"] = Color("#5d5a55")
			_stages.append(base)
			rx_index += 1
	return _stages


## Stage indices of the 12 rallycross circuits (Sandstone Eight stays in the stage list).
static func rallycross_indices() -> Array[int]:
	var out: Array[int] = []
	for i in stages().size():
		if stages()[i].has("rx"):
			out.append(i)
	return out


const WEATHER_PICK := ["dry_day", "rain_overcast", "snow_bright"]
const WEATHER_NAMES := ["Dry", "Rain", "Snow"]


## Run a stage in its own weather (override -1) or in dry, rain or snow.
static func apply_weather(stage_index: int, override: int) -> void:
	var st: Dictionary = stages()[stage_index]
	if not st.has("weather_default"):
		st["weather_default"] = st["weather"]
	st["weather"] = st["weather_default"] if override < 0 else WEATHER_PICK[clampi(override, 0, 2)]


static func stage_preview(stage: Dictionary) -> Texture2D:
	var variant_path := "res://ui/previews/routes/%s.jpg" % stage.id
	if stage.get("circuit", false) and not ResourceLoader.exists(variant_path):
		return load("res://ui/previews/canyon.png")
	return load(variant_path) if ResourceLoader.exists(variant_path) else load("res://ui/previews/%s.png" % stage.loc_id)


static func record_id(stage: Dictionary) -> String:
	return stage.id + "_overpass" if stage.get("stacked", false) else stage.id


static func stage_title(i: int) -> String:
	var st: Dictionary = stages()[i]
	return "%s - %s" % [st["name"], st["variant_name"]]


## Time-of-day lighting on top of a weather set: Dusk (low warm sun, violet fill) and Night (pale
## blue moon, deep navy shadows, lit windows). Car headlights switch on at dusk and night.
static func lighting(weather_id: String, tod: int) -> Dictionary:
	var w: Dictionary = weather(weather_id).duplicate()
	w["tod"] = tod
	w["headlights"] = tod > 0
	var snow: bool = w["kind"] == "snow"
	if tod == 1:
		w.merge({"key": Color("#ffb38a"), "key_e": float(w["key_e"]) * 0.8, "elev": 22.0, "fill": Color("#6f63a8"), "fill_e": 0.28,
			"amb": Color(w["amb"]).lerp(Color("#a898d0"), 0.6), "amb_e": 0.3, "leak": Color("#5e5c98") if snow else Color("#6a4a8a"),
			"wrap": 0.36, "glow": 1.1, "vig": 0.14, "vig_col": Color("#1a1430"), "exposure": 1.0, "contrast": 1.06,
			"tint": Vector3(1.01, 0.98, 1.01)}, true)
	elif tod == 2:
		# Real night: a faint moon, deep navy shadows; headlights, lamps and windows do the lighting.
		w.merge({"key": Color("#a9bcef"), "key_e": 0.11, "elev": 52.0, "fill": Color("#4a5a90"), "fill_e": 0.04,
			"amb": Color("#2a3870"), "amb_e": 0.14 if snow else 0.11, "leak": Color("#141c48"), "wrap": 0.4, "glow": 1.9,
			"vig": 0.3, "vig_col": Color("#04050e"), "exposure": 1.0, "contrast": 1.08, "sat": 1.0,
			"tint": Vector3(0.98, 0.98, 1.03), "green_pull": 0.1}, true)
	return w


static func series() -> Array:
	if _series.is_empty():
		_series = [
			{"id": "sprint", "name": "Sprint Cup", "desc": "Five 4 km Sprint stages.", "stages": [0, 16, 28, 4, 20]},
			{"id": "dry", "name": "Dry Cup", "desc": "Three dry 8 km Classic stages: meadow, canyon and forest.", "stages": [1, 5, 9]},
			{"id": "storm", "name": "Storm Cup", "desc": "Three rain-soaked 8 km stages with puddles and mud.", "stages": [13, 17, 21]},
			{"id": "winter", "name": "Winter Cup", "desc": "Three snow and ice 8 km stages. Very low grip.", "stages": [25, 29, 33]},
			{"id": "night", "name": "Night Rally", "desc": "Four stages always run at night, on headlights alone.", "stages": [25, 16, 5, 34], "night": true},
			{"id": "coast", "name": "Coast Cup", "desc": "Harbour cobbles and clifftop lanes above the sea.", "stages": [21, 36, 37, 22]},
			{"id": "grand", "name": "Grand Rally", "desc": "Ten locations at 10 and 15 km.", "stages": [2, 14, 27, 6, 18, 31, 10, 22, 35, 39]},
		]
	return _series


const AI_NAMES := ["M. Okafor", "L. Varga", "S. Lindqvist", "R. Moreau", "A. Tanaka", "J. Kowalski", "E. Duarte", "K. Brennan"]
const POINTS := [10, 8, 6, 4, 2, 1]
