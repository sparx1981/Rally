class_name RecordedEngine
extends RefCounted
## Crossfades the adjacent RPM bands in each of two recorded throttle banks.

const RPM_BANDS := [950.0, 1800.0, 3200.0, 4700.0, 6400.0]
const FAMILIES := {
	"classic": "compact", "mini": "compact", "escort": "compact", "estate": "compact",
	"impreza": "boxer", "gt4": "boxer", "wrc": "boxer", "rally2": "boxer", "rally1": "boxer",
	"truck": "heavy", "suv": "heavy", "buggy": "heavy",
}
const BUS := &"Engine"
static var _loops := {}

var _bank: Array[AudioStreamWAV] = []
var _voices := PackedInt32Array()
var _levels := PackedFloat32Array()
var _playback: AudioStreamPlaybackPolyphonic
var _with_coast: bool


func _init(player: Node, style: String, with_coast: bool) -> void:
	_with_coast = with_coast
	var family: String = FAMILIES.get(style, "turbo")
	var states := ["power", "coast"] if with_coast else ["power"]
	for state: String in states:
		for band in RPM_BANDS.size():
			_bank.append(loop_from_file("%s_%s_%d.wav" % [family, state, band]))
	_voices.resize(_bank.size())
	_voices.fill(AudioStreamPlaybackPolyphonic.INVALID_ID)
	_levels.resize(_bank.size())
	var stream := AudioStreamPolyphonic.new()
	stream.polyphony = 8 if with_coast else 4
	player.stream = stream
	player.play()
	_playback = player.get_stream_playback() as AudioStreamPlaybackPolyphonic


static func loop_from_file(file: String) -> AudioStreamWAV:
	if not _loops.has(file):
		var sample := load("res://audio/recorded/" + file) as AudioStreamWAV
		sample.loop_begin = 0
		sample.loop_end = roundi(sample.get_length() * sample.mix_rate)
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_loops[file] = sample
	return _loops[file]


func mix(rpm: float, load_amount: float, gain: float) -> void:
	if _playback == null:
		return
	var low := 0
	var last := RPM_BANDS.size() - 1
	while low < last - 1 and rpm >= RPM_BANDS[low + 1]:
		low += 1
	var high := low + 1
	var blend := smoothstep(RPM_BANDS[low], RPM_BANDS[high], rpm)
	var power := sqrt(load_amount) if _with_coast else 1.0
	_levels.fill(0.0)
	_levels[low] = gain * power * sqrt(1.0 - blend)
	_levels[high] = gain * power * sqrt(blend)
	if _with_coast:
		var coast := sqrt(1.0 - load_amount) * 0.49
		_levels[low + RPM_BANDS.size()] = gain * coast * sqrt(1.0 - blend)
		_levels[high + RPM_BANDS.size()] = gain * coast * sqrt(blend)

	for i in _bank.size():
		var amplitude := _levels[i]
		var voice := _voices[i]
		if amplitude < 0.001:
			if voice != AudioStreamPlaybackPolyphonic.INVALID_ID:
				_playback.stop_stream(voice)
				_voices[i] = AudioStreamPlaybackPolyphonic.INVALID_ID
			continue
		var pitch := clampf(rpm / RPM_BANDS[i % RPM_BANDS.size()], 0.64, 1.95)
		var db := linear_to_db(amplitude)
		if voice == AudioStreamPlaybackPolyphonic.INVALID_ID:
			_voices[i] = _playback.play_stream(_bank[i], 0.0, db, pitch, AudioServer.PLAYBACK_TYPE_STREAM, BUS)
		else:
			_playback.set_stream_volume(voice, db)
			_playback.set_stream_pitch_scale(voice, pitch)
