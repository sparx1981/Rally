extends Node
## Session state (mode, car, stage, championship) and saved progress (best times, medals, cups).

const SAVE_PATH := "user://progress.cfg"

enum Mode { TIME_TRIAL, CHAMPIONSHIP, RACE }

var mode: int = Mode.TIME_TRIAL
var car_index := 11
var livery := 0
var stage_index := 0
var circuit_laps := 5
var series_index := 0
var show_ghost := true
var ai_contact := true
var weather_override := -1   # -1 = the stage's own weather, otherwise an index into Catalog.WEATHER_PICK
var time_of_day := -1        # -1 = stage default, otherwise an index into Catalog.TOD_NAMES

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


## Time of day for the next race: championship night series forces night.
func race_tod() -> int:
	if mode == Mode.CHAMPIONSHIP:
		return 2 if bool(current_series().get("night", false)) else -1
	return time_of_day


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
	var pool: Array = []
	if bool(Settings.g("same_class")):
		var mine := Catalog.car_class(car_index)
		for ci in cars.size():
			if ci != car_index and Catalog.car_class(ci) == mine:
				pool.append(ci)
	for i in count:
		if pool.is_empty():
			var c := (car_index + 1 + i) % cars.size()
			out.append({"name": names[i % names.size()], "car": c, "skill": rng.randf_range(0.93, 1.0), "player": false})
		else:
			# Same-class grid: use each rival in turn; when the class runs out the models repeat in another livery.
			var entry := {"name": names[i % names.size()], "car": pool[i % pool.size()], "skill": rng.randf_range(0.93, 1.0), "player": false}
			entry["skill"] = float(entry["skill"]) * class_balance(int(entry["car"]))
			if i >= pool.size():
				entry["livery"] = 1 + (i / pool.size() - 1) % 2   # a repeated model is painted differently
			out.append(entry)
	return out


## Within a class the slower cars drive a little harder and the quicker ones a little easier, so the field
## stays close and driver skill (not just the car) decides the race. Based on measured pace (Catalog.PACE_TIME):
## the slower the car is than its class average, the more its AI driver commits (clamped -6% / +12%).
## Mixed-class grids are deliberately left unbalanced.
func class_balance(car_i: int) -> float:
	if OS.get_cmdline_user_args().has("--nobalance"):
		return 1.0
	var mean := Catalog.class_pace(Catalog.car_class(car_i))
	return clampf(pow(Catalog.pace_time(car_i) / mean, 1.5), 0.94, 1.12)


func difficulty_factor() -> float:
	return [0.86, 0.93, 0.99][clampi(int(Settings.g("ai_difficulty")), 0, 2)]


# --- Championship ----------------------------------------------------------------------------------

## Career ladder: each tier opens once the previous one has been finished.
func series_locked(i: int) -> bool:
	return i > 0 and not cups.has(Catalog.series()[i - 1]["id"])


func start_championship(series_i: int) -> void:
	series_index = series_i
	weather_override = -1
	champ_round = 0
	champ_entrants = make_entrants(int(Settings.g("opponents")))
	champ_points = {}
	for e in champ_entrants:
		champ_points[e["name"]] = 0
	champ_last_results = []
	stage_index = current_series()["stages"][0]


## Rebuild the grid (before the first round) after the opponent count changed on the confirmation screen.
func reset_champ_entrants() -> void:
	if champ_round > 0:
		return
	champ_entrants = make_entrants(int(Settings.g("opponents")))
	champ_points = {}
	for e in champ_entrants:
		champ_points[e["name"]] = 0


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
	var sid: String = Catalog.record_id(Catalog.stages()[stage_i])
	if best_times.has(sid):
		return float(best_times[sid]["time"])
	return -1.0


## Returns true if this is a new record.
func submit_time(stage_i: int, t: float) -> bool:
	var sid: String = Catalog.record_id(Catalog.stages()[stage_i])
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
	cf.set_value("progress", "livery", livery)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	best_times = cf.get_value("progress", "best_times", {})
	cups = cf.get_value("progress", "cups", {})
	livery = int(cf.get_value("progress", "livery", 0))
	car_index = clampi(int(cf.get_value("progress", "car_index", 11)), 0, Catalog.cars().size() - 1)
