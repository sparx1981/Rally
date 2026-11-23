class_name Catalog
extends RefCounted
## Static game data: cars, light/weather sets, stages and championship series.
## All names and designs are original to this project.

static var _cars: Array = []
static var _stages: Array = []
static var _weather: Dictionary = {}
static var _series: Array = []


static func cars() -> Array:
	if _cars.is_empty():
		_cars = [
			{"id": "pip", "name": "Pip 1300", "style": "hatch", "desc": "Tiny, nimble and forgiving. Turns on a coin.",
				"body": Color("#c8553d"), "accent": Color("#efe3c8"), "stripe": Color("#e8b04a"),
				"top": 0.88, "accel": 0.95, "grip": 1.02, "steer": 1.18},
			{"id": "kestrel", "name": "Kestrel GT", "style": "coupe", "desc": "Low, quick coupe that loves long fast bends.",
				"body": Color("#3f6fa8"), "accent": Color("#e8c05a"), "stripe": Color("#efe3c8"),
				"top": 1.06, "accel": 1.0, "grip": 0.95, "steer": 0.98},
			{"id": "badger", "name": "Badger 4x4", "style": "suv", "desc": "Heavy all-wheel-drive brute. Huge grip off the road.",
				"body": Color("#5f7f4a"), "accent": Color("#e08a3a"), "stripe": Color("#2f3a2a"),
				"top": 0.92, "accel": 0.86, "grip": 1.14, "steer": 0.9},
			{"id": "marten", "name": "Marten RS", "style": "saloon", "desc": "The all-rounder. Balanced on every surface.",
				"body": Color("#ece4d2"), "accent": Color("#2f8a8a"), "stripe": Color("#c8553d"),
				"top": 1.0, "accel": 1.0, "grip": 1.0, "steer": 1.0},
			{"id": "lynx", "name": "Lynx Turbo", "style": "turbo", "desc": "Brutal turbo power. Fastest car, slippery tail.",
				"body": Color("#35302c"), "accent": Color("#e2763a"), "stripe": Color("#e8c05a"),
				"top": 1.12, "accel": 1.12, "grip": 0.9, "steer": 0.96},
			{"id": "otter", "name": "Otter Estate", "style": "estate", "desc": "A family estate with a rally heart. Very stable.",
				"body": Color("#d9a441"), "accent": Color("#7a3b3b"), "stripe": Color("#efe3c8"),
				"top": 0.95, "accel": 0.93, "grip": 1.06, "steer": 1.02},
		]
	return _cars


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
				"wrap": 0.3, "grip": 0.56, "exposure": 0.86, "contrast": 1.08, "sat": 1.0, "tint": Vector3(1.0, 1.0, 1.02),
				"vig": 0.08, "vig_col": Color("#283048"), "green_pull": 0.1, "glow": 0.0, "particles": "snow"},
			"snow_ice": {"label": "Snow", "kind": "snow", "key": Color("#fbf0e0"), "key_e": 0.72, "elev": 44.0, "azim": 30.0,
				"fill": Color("#a4bbe0"), "fill_e": 0.22, "amb": Color("#dfe6f2"), "amb_e": 0.28, "leak": Color("#6c84b0"),
				"wrap": 0.3, "grip": 0.49, "exposure": 0.86, "contrast": 1.08, "sat": 1.0, "tint": Vector3(1.0, 1.0, 1.02),
				"vig": 0.08, "vig_col": Color("#283048"), "green_pull": 0.1, "glow": 0.0, "particles": "snow"},
			"snow_dusk": {"label": "Snow", "kind": "snow", "key": Color("#ffb38a"), "key_e": 0.7, "elev": 28.0, "azim": 45.0,
				"fill": Color("#6f63a8"), "fill_e": 0.3, "amb": Color("#c6bfd9"), "amb_e": 0.34, "leak": Color("#5e5c98"),
				"wrap": 0.36, "grip": 0.55, "exposure": 0.95, "contrast": 1.06, "sat": 0.98, "tint": Vector3(1.01, 0.98, 1.01),
				"vig": 0.14, "vig_col": Color("#1a1430"), "green_pull": 0.1, "glow": 1.1, "particles": "snow"},
		}
	return _weather[id]


static func _pal(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		out[k] = Color(d[k])
	return out


static func stages() -> Array:
	if _stages.is_empty():
		_stages = [
			{"id": "meadow", "name": "Meadow Run", "weather": "dry_day", "seed": 1101, "length": 1700.0, "twist": 0.35, "width": 8.5,
				"desc": "Rolling farmland lanes between hay fields and red barns.",
				"pal": _pal({"ground": "#d9d7bc", "ground2": "#cbcfa9", "ground3": "#e3dcc6", "road": "#c9ab7e", "rut": "#a88a62",
					"f_dark": "#5f7f4a", "f_mid": "#7d9a5a", "f_light": "#a3b56e", "trunk": "#7a5235", "accent": "#c8553d",
					"accent2": "#e8b04a", "wall": "#efe3c8", "roof": "#b5523b", "wood": "#8a5a3b", "stone": "#a99d8a", "flower": "#e8d06a"}),
				"kinds": {"tree": 5, "bush": 4, "tuft": 5, "flowers": 3, "house": 1, "barn": 1, "bale": 3, "rock": 1, "logs": 1, "spectators": 0}},
			{"id": "canyon", "name": "Sandstone Canyon", "weather": "dry_noon", "seed": 2207, "length": 1900.0, "twist": 0.5, "width": 8.5,
				"desc": "Sun-baked switchbacks through red mesas and cactus flats.",
				"pal": _pal({"ground": "#ead8b2", "ground2": "#e0c79c", "ground3": "#f0e2c4", "road": "#c99c6c", "rut": "#a87a50",
					"f_dark": "#5f7a50", "f_mid": "#7d9264", "f_light": "#a4b07a", "trunk": "#7a5235", "accent": "#2f8a8a",
					"accent2": "#e8c05a", "wall": "#e9cfa6", "roof": "#b5623b", "wood": "#8a5a3b", "stone": "#c9774a", "flower": "#e2763a"}),
				"kinds": {"cactus": 5, "mesa": 3, "rock": 5, "bush": 2, "tuft": 3, "tent": 1, "logs": 1}},
			{"id": "autumn", "name": "Autumn Ridge", "weather": "dry_golden", "seed": 3313, "length": 2000.0, "twist": 0.6, "width": 8.0,
				"desc": "Twisting forest gravel under copper and gold leaves.",
				"pal": _pal({"ground": "#e6d2a8", "ground2": "#dcc394", "ground3": "#ecdcbc", "road": "#b8946a", "rut": "#94704c",
					"f_dark": "#a8452e", "f_mid": "#d0682e", "f_light": "#e8a040", "trunk": "#6e4a32", "accent": "#e8c05a",
					"accent2": "#7a8a4a", "wall": "#efe3c8", "roof": "#8a4a32", "wood": "#7a5235", "stone": "#a89c8a", "flower": "#e8c05a"}),
				"kinds": {"tree": 7, "pine": 3, "bush": 3, "tuft": 3, "logs": 2, "rock": 2, "cabin": 1}},
			{"id": "moor", "name": "Moorland Mire", "weather": "rain_mist", "seed": 4421, "length": 1800.0, "twist": 0.45, "width": 8.5,
				"desc": "Wet peat tracks across heather moors. Puddles everywhere.",
				"pal": _pal({"ground": "#c2c6ad", "ground2": "#b2b99c", "ground3": "#cdcdb6", "road": "#8f7a62", "rut": "#6f5c48",
					"f_dark": "#5d7556", "f_mid": "#7b9068", "f_light": "#9aa87a", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#c9a447", "wall": "#e2dccb", "roof": "#5d6b7a", "wood": "#6e5038", "stone": "#9c9a90", "flower": "#a77ba0"}),
				"kinds": {"heather": 6, "rock": 4, "bush": 3, "tuft": 4, "pine": 1, "house": 1, "tent": 1}},
			{"id": "pinewood", "name": "Pinewood Deluge", "weather": "rain_mist", "seed": 5531, "length": 2000.0, "twist": 0.62, "width": 8.0,
				"desc": "Dark, dripping pine forest with tight muddy hairpins.",
				"pal": _pal({"ground": "#bcc2a8", "ground2": "#aab396", "ground3": "#c8c9b0", "road": "#7e6a55", "rut": "#5e4c3c",
					"f_dark": "#3f5e4a", "f_mid": "#557560", "f_light": "#6d8a6c", "trunk": "#6a4a36", "accent": "#d9a441",
					"accent2": "#c8553d", "wall": "#e2dccb", "roof": "#5d6b7a", "wood": "#6e5038", "stone": "#9a9a90", "flower": "#d9a441"}),
				"kinds": {"pine": 9, "bush": 3, "tuft": 3, "logs": 2, "rock": 2, "tent": 1, "cabin": 1}},
			{"id": "harbour", "name": "Harbour Lanes", "weather": "rain_overcast", "seed": 6619, "length": 1750.0, "twist": 0.55, "width": 8.0,
				"desc": "Slippery cobbles through a painted fishing village.",
				"pal": _pal({"ground": "#c9c5b3", "ground2": "#b9b7a6", "ground3": "#d6d1bd", "road": "#8a8278", "rut": "#6c665e",
					"f_dark": "#5d7556", "f_mid": "#7b9068", "f_light": "#9aa87a", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#2f8a8a", "wall": "#d98c6a", "roof": "#5d6b7a", "wood": "#7a5a40", "stone": "#9c988c", "flower": "#e2c26a"}),
				"kinds": {"house": 6, "crates": 3, "lamp": 2, "bush": 2, "tuft": 2, "rock": 1, "spectators": 0}},
			{"id": "alpine", "name": "Alpine Pass", "weather": "snow_bright", "seed": 7717, "length": 1900.0, "twist": 0.6, "width": 8.0,
				"desc": "High mountain hairpins on packed snow. Brake early.",
				"pal": _pal({"ground": "#e4e8ef", "ground2": "#d8dee8", "ground3": "#eef0f5", "road": "#cdd2dc", "rut": "#a7aec0",
					"f_dark": "#4a6b5e", "f_mid": "#628374", "f_light": "#7d9a88", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#3f6fa8", "wall": "#e8dcc8", "roof": "#8a4a3a", "wood": "#7a5235", "stone": "#9a9fae", "flower": "#f3f4f7"}),
				"kinds": {"pine_snow": 8, "rock": 3, "snowbank": 5, "cabin": 1, "logs": 1}},
			{"id": "lakes", "name": "Frozen Lakes", "weather": "snow_ice", "seed": 8803, "length": 1800.0, "twist": 0.4, "width": 9.0,
				"desc": "Fast, icy straights between birch woods. Almost no grip.",
				"pal": _pal({"ground": "#e2e7ee", "ground2": "#cddbe8", "ground3": "#edf0f5", "road": "#c9cfda", "rut": "#a3abbd",
					"f_dark": "#5a7a6a", "f_mid": "#7a9a7a", "f_light": "#a4b88a", "trunk": "#efeae0", "accent": "#d98c3a",
					"accent2": "#a84a3a", "wall": "#a84a3a", "roof": "#3f4a5a", "wood": "#7a5235", "stone": "#9aa0ae", "flower": "#f3f4f7"}),
				"kinds": {"birch": 6, "pine_snow": 3, "snowbank": 5, "cabin": 1, "rock": 2}},
			{"id": "taiga", "name": "Twilight Taiga", "weather": "snow_dusk", "seed": 9901, "length": 2000.0, "twist": 0.55, "width": 8.0,
				"desc": "Snowy forest at dusk, lit by cabin windows and lamps.",
				"pal": _pal({"ground": "#dcdbe6", "ground2": "#cfcfdd", "ground3": "#e6e5ee", "road": "#c2c1d0", "rut": "#9e9cb4",
					"f_dark": "#3e5a5a", "f_mid": "#53706a", "f_light": "#6d8a80", "trunk": "#6a4a36", "accent": "#c8553d",
					"accent2": "#e8c05a", "wall": "#a85a3a", "roof": "#4a4a5a", "wood": "#7a5235", "stone": "#9a9aae", "flower": "#f3f4f7"}),
				"kinds": {"pine_snow": 8, "snowbank": 4, "cabin": 2, "lamp": 2, "rock": 1, "logs": 1}},
		]
	return _stages


static func series() -> Array:
	if _series.is_empty():
		_series = [
			{"id": "dry", "name": "Dry Cup", "desc": "Three dry stages: meadow, canyon and forest.", "stages": [0, 1, 2]},
			{"id": "storm", "name": "Storm Cup", "desc": "Three rain-soaked stages with puddles and mud.", "stages": [3, 4, 5]},
			{"id": "winter", "name": "Winter Cup", "desc": "Three snow and ice stages. Very low grip.", "stages": [6, 7, 8]},
			{"id": "grand", "name": "Grand Rally", "desc": "The full season: all nine stages.", "stages": [0, 3, 6, 1, 4, 7, 2, 5, 8]},
		]
	return _series


const AI_NAMES := ["M. Okafor", "L. Varga", "S. Lindqvist", "R. Moreau", "A. Tanaka", "J. Kowalski", "E. Duarte", "K. Brennan"]
const POINTS := [10, 8, 6, 4, 2, 1]
