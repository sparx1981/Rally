extends Node
## Co-driver voice regression harness (real-time, dummy audio driver).
## Run: godot --headless --path . res://tools/voice_checks.tscn
## Drives a synthetic stage past CoDriverVoice with a mid-clip respawn and a lap restart, and checks
## that no pace note is spoken twice, no clip is cut mid-word, and calls keep a gap.

const NOTE_COUNT := 14
var voice
var log: Array = []
var station := 0.0
var t := 0.0
var _scripted := {}
var _failed := false


func _ready() -> void:
	var track := Track.new()
	for i in NOTE_COUNT:
		var kind := "corner" if i % 3 != 2 else "jump"
		track.notes.append({"s0": 140.0 + i * 70.0, "s1": 160.0 + i * 70.0, "kind": kind,
			"dir": -1.0 if i % 2 == 0 else 1.0, "sev": 1 + i % 6, "hairpin": false})
	Settings.data["codriver_timing"] = 2
	Settings.data["codriver_volume"] = 0.8
	voice = load("res://scripts/race/co_driver_voice.gd").new()
	add_child(voice)
	voice.setup(track)
	_time_real_setup()


var _prev_playing := false
var _prev_stream: AudioStream
var _prev_pos := 0.0
var _prev_len := 0.0


## Watch the player itself (works on any implementation): a start is a new stream or a rewind, a cut
## is a clip that stops or restarts before its end.
func _observe() -> void:
	var playing: bool = voice.playing
	var stream: AudioStream = voice.stream
	var pos: float = voice.get_playback_position() if playing else 0.0
	var restarted := playing and _prev_playing and (stream != _prev_stream or pos < _prev_pos - 0.2)
	if _prev_playing and (not playing or restarted) and _prev_pos < _prev_len - 0.25:
		if not log.is_empty():
			log[-1]["cut"] = true
	if playing and (not _prev_playing or restarted):
		var key := stream.resource_path.get_file().get_basename()
		var note := -1
		for i in NOTE_COUNT:
			var s0 := 140.0 + i * 70.0
			var sev_key := ("left" if i % 2 == 0 else "right") + str(1 + i % 6)
			var k2 := "jump" if i % 3 == 2 else sev_key
			if (key == sev_key or key == k2) and s0 > station - 15.0 and s0 < station + 140.0 + (700.0 if _scripted.has("lap") and station < 200.0 else 0.0):
				note = i
				break
		log.append({"t": t, "key": key, "st": station, "note": note, "cut": false})
	_prev_playing = playing
	_prev_stream = stream
	_prev_pos = pos
	_prev_len = stream.get_length() if stream else 0.0


func _process(delta: float) -> void:
	t += delta
	station += 32.0 * delta
	# Respawn 4 m back while a call is (probably) playing, as the reset button does.
	if not _scripted.has("reset") and not log.is_empty() and voice.playing and t > 4.0:
		_scripted["reset"] = t
		station -= 4.0
		_seek(station, false)
	# Lap restart at 700 m.
	if not _scripted.has("lap") and station > 700.0:
		_scripted["lap"] = t
		station = 0.0
		_seek(station, true)
	voice.call_ahead(station, 32.0)
	_observe()
	if t > 70.0 or (station > 900.0 and _scripted.has("lap")):
		set_process(false)
		_report()
		get_tree().quit()


## Preload cost on a real 15 km stage (this runs while the loading card is up).
func _time_real_setup() -> void:
	for stage_index in [3, 15, 35]:
		var def: Dictionary = Catalog.stages()[stage_index]
		var tr := Track.new()
		tr.build_stage_route(def, "dry")
		var v = load("res://scripts/race/co_driver_voice.gd").new()
		add_child(v)
		var t0 := Time.get_ticks_usec()
		v.setup(tr)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("VOICE preload stage=%s notes=%d clips=%d setup=%.1f ms" % [def.id, tr.notes.size(), v._streams.size(), ms])
		v.queue_free()


func _seek(st: float, new_lap: bool) -> void:
	var args := 1
	for m in voice.get_method_list():
		if m.name == "seek_course":
			args = m.args.size()
	if args >= 2:
		voice.seek_course(st, new_lap)
	else:
		voice.seek_course(st)


func _report() -> void:
	var seen := {}
	var dup := 0
	var cuts := 0
	var lap_marker: float = _scripted.get("lap", INF)
	for e in log:
		var id := "%s#%d@%s" % [e.key, e.note, "lap2" if e.t >= lap_marker else "lap1"]
		if seen.has(id):
			dup += 1
			print("VOICE DUP  t=%.1f %s" % [e.t, id])
		seen[id] = true
		if e.cut:
			cuts += 1
			print("VOICE CUT  t=%.1f %s" % [e.t, id])
	var min_gap := INF
	for i in range(1, log.size()):
		min_gap = minf(min_gap, float(log[i].t) - float(log[i - 1].t))
	print("VOICE calls=%d duplicates=%d cut_mid_clip=%d min_start_gap=%.2fs scripted=%s" % [log.size(), dup, cuts, min_gap, _scripted])
	if dup > 0 or cuts > 0:
		print("VOICE RESULT FAIL")
	else:
		print("VOICE RESULT PASS")
