class_name CoDriverVoice
extends AudioStreamPlayer
## Optional presentation layer. The HUD and race rules still own their pace notes.

const CLIP_DIRECTORY := "res://audio/codriver/"
const LEAD_SECONDS := [0.0, 1.25, 2.05, 2.85]
const COMBINED_HAZARDS := ["jump", "crest", "splash", "chicane", "ice", "tunnel", "underpass", "bridge"]

var _notes: Array
var _cursor := 0


func setup(track: Track) -> void:
	_notes = track.notes
	seek_course(track.start_s)


func seek_course(station: float) -> void:
	stop()
	_cursor = 0
	while _cursor < _notes.size() and float(_notes[_cursor].s0) < station:
		_cursor += 1


func call_ahead(station: float, speed: float) -> void:
	var timing := clampi(int(Settings.g("codriver_timing")), 0, LEAD_SECONDS.size() - 1)
	var volume := float(Settings.g("codriver_volume"))
	if timing == 0 or volume <= 0.001:
		stop()
		return
	while _cursor < _notes.size() and float(_notes[_cursor].s0) < station - 7.0:
		_cursor += 1
	if playing or _cursor >= _notes.size() or speed < 1.8:
		return
	var note: Dictionary = _notes[_cursor]
	var lead := clampf(speed * LEAD_SECONDS[timing] + 8.0, 16.0, 110.0)
	if float(note.s0) - station > lead:
		return
	var call := _key(note)
	_cursor += 1
	if note.kind == "corner" and _cursor < _notes.size():
		var following: Dictionary = _notes[_cursor]
		if following.kind in COMBINED_HAZARDS and float(following.s0) - float(note.s1) < 28.0:
			call += "_into_" + str(following.kind)
			_cursor += 1
	var path := CLIP_DIRECTORY + call + ".ogg"
	if ResourceLoader.exists(path, "AudioStream"):
		stream = load(path)
		volume_db = linear_to_db(volume)
		play()


func _key(note: Dictionary) -> String:
	if note.kind != "corner":
		return str(note.kind).replace(" ", "_")
	var direction := "left" if float(note.dir) < 0.0 else "right"
	return "hairpin_" + direction if note.hairpin else direction + str(clampi(int(note.sev), 1, 6))
