class_name CoDriverVoice
extends AudioStreamPlayer
## Optional presentation layer. The HUD and race rules still own their pace notes.
##
## Behaviour guarantees (checked by tools/voice_checks.tscn):
##  - a clip is never cut mid-word by a respawn, recovery or lap line;
##  - a pace note is spoken once per lap, however often the car is reset;
##  - clips are preloaded for this track, so no file is opened in the middle of a race;
##  - every clip is level-matched and kept below clipping whatever the volume slider says.

signal call_started(key: String, station: float, note: int)

const CLIP_DIRECTORY := "res://audio/codriver/"
const VOICE_NAMES := {
	"blake": "Blake",
	"darren": "Darren",
	"james": "James",
	"nick": "Nick",
	"stephane": "Stephane",
}
const LEAD_SECONDS := [0.0, 1.25, 2.05, 2.85]
const COMBINED_HAZARDS := ["jump", "crest", "splash", "chicane", "ice", "tunnel", "underpass", "bridge"]
## Calls are level-matched to this mean level, but never louder than the peak ceiling.
const TARGET_MEAN_DB := -19.0
const PEAK_CEILING_DB := -1.5
const MAX_BOOST_DB := 6.0
## Silence left after a call so two calls never run together into one garbled phrase.
const MIN_GAP_MS := 350
const FADE_SECONDS := 0.12

var _notes: Array = []
var _plan_key := PackedStringArray()    # call key per note ("left3", "left3_into_jump" ...)
var _plan_span := PackedInt32Array()    # notes the call covers (2 when a hazard follows a corner)
var _called := PackedByteArray()        # 1 once the note has been spoken this lap
var _cursor := 0
var _quiet_until := 0
var _fade: Tween
var _voice_id := ""
var _saved_voice := ""
var _streams := {}                       # call key -> {stream, gain_db}


static func clip_path(voice: String, call: String) -> String:
	var folder := "" if voice == "george" else voice + "/"
	return CLIP_DIRECTORY + folder + call + ".ogg"


static func available_voices() -> Array[String]:
	var voices: Array[String] = []
	for voice: String in VOICE_NAMES:
		if ResourceLoader.exists(clip_path(voice, "left1"), "AudioStream"):
			voices.append(voice)
	return voices


static func selected_voice(voices: Array[String]) -> String:
	var saved := str(Settings.g("codriver_voice"))
	if saved in voices:
		return saved
	if "nick" in voices:
		return "nick"
	return voices[0] if not voices.is_empty() else "george"


## Gain that level-matches a clip to the target and keeps its peak under the ceiling.
static func clip_gain_db(voice: String, call: String) -> float:
	var level = CoDriverLevels.LEVELS.get(voice, {}).get(call)
	if level == null:
		return 0.0
	var gain := clampf(TARGET_MEAN_DB - float(level[1]), -MAX_BOOST_DB, MAX_BOOST_DB)
	return minf(gain, PEAK_CEILING_DB - float(level[0]))


func _ready() -> void:
	finished.connect(func(): _quiet_until = Time.get_ticks_msec() + MIN_GAP_MS)
	if AudioServer.get_bus_index("Voice") >= 0:
		bus = "Voice"


func setup(track: Track) -> void:
	_notes = track.notes
	_plan_calls()
	_load_voice()
	seek_course(track.start_s, true)


## Work out, once, which call each note makes. A corner followed closely by a hazard is one phrase.
func _plan_calls() -> void:
	_plan_key = PackedStringArray()
	_plan_span = PackedInt32Array()
	for i in _notes.size():
		var note: Dictionary = _notes[i]
		var key := _key(note)
		var span := 1
		if note.kind == "corner" and i + 1 < _notes.size():
			var following: Dictionary = _notes[i + 1]
			if following.kind in COMBINED_HAZARDS and float(following.s0) - float(note.s1) < 28.0:
				key += "_into_" + str(following.kind)
				span = 2
		_plan_key.append(key)
		_plan_span.append(span)
	_called = PackedByteArray()
	_called.resize(_notes.size())


## Resolve the chosen voice once and load only the clips this track can ask for.
func _load_voice() -> void:
	var voices := available_voices()
	_voice_id = selected_voice(voices)
	_saved_voice = str(Settings.g("codriver_voice"))
	_streams.clear()
	for key in _plan_key:
		if _streams.has(key):
			continue
		var voice := _voice_id
		var path := clip_path(voice, key)
		if not ResourceLoader.exists(path, "AudioStream") and voice != "george":
			voice = "george"
			path = clip_path(voice, key)
		if ResourceLoader.exists(path, "AudioStream"):
			_streams[key] = {"stream": load(path), "gain_db": clip_gain_db(voice, key)}


## Re-aim after the car is moved (respawn, recovery, lap line). Never interrupts a clip that is
## playing, and never repeats a note already spoken. `new_lap` makes every note speakable again.
func seek_course(station: float, new_lap := false) -> void:
	if new_lap:
		_called.fill(0)
	_cursor = 0
	while _cursor < _notes.size() and (_called[_cursor] == 1 or float(_notes[_cursor].s0) < station - 7.0):
		_cursor += 1


## Fade out whatever is speaking (finish line, pause menu overlay) without a click.
func stop_calls() -> void:
	if not playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", -60.0, FADE_SECONDS)
	_fade.tween_callback(stop)


func call_ahead(station: float, speed: float) -> void:
	var timing := clampi(int(Settings.g("codriver_timing")), 0, LEAD_SECONDS.size() - 1)
	var volume := float(Settings.g("codriver_volume"))
	if timing == 0 or volume <= 0.001:
		stop_calls()
		return
	while _cursor < _notes.size() and (_called[_cursor] == 1 or float(_notes[_cursor].s0) < station - 7.0):
		_cursor += 1
	if playing or _cursor >= _notes.size() or speed < 1.8 or Time.get_ticks_msec() < _quiet_until:
		return
	var note: Dictionary = _notes[_cursor]
	var lead := clampf(speed * LEAD_SECONDS[timing] + 8.0, 16.0, 110.0)
	if float(note.s0) - station > lead:
		return
	if str(Settings.g("codriver_voice")) != _saved_voice:
		_load_voice()
	var index := _cursor
	var key := _plan_key[index]
	for k in _plan_span[index]:
		_called[index + k] = 1
	_cursor = index + _plan_span[index]
	if not _streams.has(key):
		return
	var clip: Dictionary = _streams[key]
	if _fade:
		_fade.kill()
	stream = clip.stream
	volume_db = linear_to_db(volume) + float(clip.gain_db)
	play()
	call_started.emit(key, station, index)


func _key(note: Dictionary) -> String:
	if note.kind != "corner":
		return str(note.kind).replace(" ", "_")
	var direction := "left" if float(note.dir) < 0.0 else "right"
	return "hairpin_" + direction if note.hairpin else direction + str(clampi(int(note.sev), 1, 6))
