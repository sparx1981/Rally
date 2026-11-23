extends Node
## Session state (mode, car, stage, championship) and saved progress (best times, medals, cups).

const SAVE_PATH := "user://progress.cfg"

enum Mode { TIME_TRIAL, CHAMPIONSHIP, RACE }

var mode: int = Mode.TIME_TRIAL
var car_index := 3
var stage_index := 0
var series_index := 0

# Championship in progress.
var champ_round := 0
var champ_points := {}       # driver name -> points
var champ_entrants: Array = []   # [{name, car, skill, player}]
var champ_last_results: Array = []

var no_save := false         # test / screenshot runs never touch the player's progress
var best_times := {}         # "stage_id" -> {time, car}
var cups := {}               # "series_id" -> best finishing position


func _ready() -> void:
	_load()


func mode_name(m: int = -1) -> String:
	if m < 0:
		m = mode
	return ["Time Trial", "Championship", "Race vs AI"][m]


# --- Entrants ------------------------------------------------------------------------------------------

func make_entrants(count: int) -> Array:
	var cars := Catalog.cars()
	var out: Array = [{"name": "You", "car": car_index, "skill": 1.0, "player": true}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + series_index * 17 + stage_index
	var names: Array = Catalog.AI_NAMES.duplicate()
	for i in count:
		var c := (car_index + 1 + i) % cars.size()
		out.append({"name": names[i % names.size()], "car": c, "skill": rng.randf_range(0.93, 1.0), "player": false})
	return out


func difficulty_factor() -> float:
	return [0.86, 0.93, 0.99][clampi(int(Settings.g("ai_difficulty")), 0, 2)]


# --- Championship ----------------------------------------------------------------------------------

func start_championship(series_i: int) -> void:
	series_index = series_i
	champ_round = 0
	champ_entrants = make_entrants(int(Settings.g("opponents")))
	champ_points = {}
	for e in champ_entrants:
		champ_points[e["name"]] = 0
	champ_last_results = []
	stage_index = current_series()["stages"][0]


func current_series() -> Dictionary:
	return Catalog.series()[series_index]


func champ_total_rounds() -> int:
	return current_series()["stages"].size()


## results: Array of {name, time, finished} sorted by position.
func record_champ_round(results: Array) -> void:
	champ_last_results = results
	for i in results.size():
		var pts: int = Catalog.POINTS[i] if i < Catalog.POINTS.size() else 0
		var n: String = results[i]["name"]
		champ_points[n] = int(champ_points.get(n, 0)) + pts
	champ_round += 1
	if champ_round < champ_total_rounds():
		stage_index = current_series()["stages"][champ_round]
	else:
		var pos := standings().map(func(r): return r["name"]).find("You") + 1
		var sid: String = current_series()["id"]
		if not cups.has(sid) or pos < int(cups[sid]):
			cups[sid] = pos
			save()


func champ_finished() -> bool:
	return champ_round >= champ_total_rounds()


func standings() -> Array:
	var rows: Array = []
	for e in champ_entrants:
		rows.append({"name": e["name"], "car": e["car"], "points": int(champ_points.get(e["name"], 0))})
	rows.sort_custom(func(a, b): return a["points"] > b["points"])
	return rows


# --- Times & medals ----------------------------------------------------------------------------------

func best_time(stage_i: int) -> float:
	var sid: String = Catalog.stages()[stage_i]["id"]
	if best_times.has(sid):
		return float(best_times[sid]["time"])
	return -1.0


## Returns true if this is a new record.
func submit_time(stage_i: int, t: float) -> bool:
	var sid: String = Catalog.stages()[stage_i]["id"]
	if not best_times.has(sid) or t < float(best_times[sid]["time"]):
		best_times[sid] = {"time": t, "car": car_index}
		save()
		return true
	return false


static func fmt_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var m := int(t / 60.0)
	var s := t - m * 60.0
	return "%d:%05.2f" % [m, s]


func save() -> void:
	if no_save:
		return
	var cf := ConfigFile.new()
	cf.set_value("progress", "best_times", best_times)
	cf.set_value("progress", "cups", cups)
	cf.set_value("progress", "car_index", car_index)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	best_times = cf.get_value("progress", "best_times", {})
	cups = cf.get_value("progress", "cups", {})
	car_index = int(cf.get_value("progress", "car_index", 3))
