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

var _voices: Array[Node] = []
var _levels := PackedFloat32Array()
var _with_coast: bool


func _init(parent: Node, style: String, with_coast: bool, exhaust_position := Vector3.ZERO) -> void:
	_with_coast = with_coast
	var family: String = FAMILIES.get(style, "turbo")
	var states := ["power", "coast"] if with_coast else ["power"]
	for state: String in states:
		for band in RPM_BANDS.size():
			# One stream per band keeps pitch and gain independently adjustable.
			var voice: Node
			if with_coast:
				voice = AudioStreamPlayer.new()
			else:
				var exhaust := AudioStreamPlayer3D.new()
				exhaust.unit_size = 4.5
				exhaust.max_distance = 65.0
				exhaust.position = exhaust_position
				voice = exhaust
			voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			voice.bus = BUS
			voice.stream = loop_from_file("%s_%s_%d.wav" % [family, state, band])
			voice.volume_db = -80.0
			parent.add_child(voice)
			_voices.append(voice)
	_levels.resize(_voices.size())


func stop() -> void:
	for voice in _voices:
		voice.stop()
		voice.queue_free()
	_voices.clear()


static func loop_from_file(file: String) -> AudioStreamWAV:
	if not _loops.has(file):
		var sample := load("res://audio/recorded/" + file) as AudioStreamWAV
		sample.loop_begin = 0
		sample.loop_end = roundi(sample.get_length() * sample.mix_rate)
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_loops[file] = sample
	return _loops[file]


func mix(rpm: float, load_amount: float, gain: float) -> void:
	if _voices.is_empty():
		return
	var low := 0
	var last := RPM_BANDS.size() - 1
	while low < last - 1 and rpm >= RPM_BANDS[low + 1]:
		low += 1
	var high := low + 1
	var blend := smoothstep(RPM_BANDS[low], RPM_BANDS[high], rpm)
	# Keep the loaded recording present on overrun. The separate coast
	# layer changes the character without swapping the whole engine voice.
	var power := sqrt(lerpf(0.11, 1.0, load_amount)) if _with_coast else 1.0
	_levels.fill(0.0)
	_levels[low] = gain * power * sqrt(1.0 - blend)
	_levels[high] = gain * power * sqrt(blend)
	if _with_coast:
		var coast := sqrt(1.0 - load_amount) * 0.64
		_levels[low + RPM_BANDS.size()] = gain * coast * sqrt(1.0 - blend)
		_levels[high + RPM_BANDS.size()] = gain * coast * sqrt(blend)

	for i in _voices.size():
		var amplitude := _levels[i]
		var voice := _voices[i]
		# Keep the player's loops running quietly between uses. A second
		# throttle press then returns to the current phase of each loop.
		if amplitude < 0.001 and not _with_coast:
			if voice.playing:
				voice.stop()
			continue
		voice.pitch_scale = clampf(rpm / RPM_BANDS[i % RPM_BANDS.size()], 0.64, 1.95)
		voice.volume_db = linear_to_db(maxf(0.0001, amplitude))
		if not _with_coast:
			(voice as AudioStreamPlayer3D).max_db = voice.volume_db - 9.0
		if not voice.playing:
			voice.play()
