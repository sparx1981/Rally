class_name RecordedEngine
extends RefCounted
## Crossfades the adjacent RPM bands in each of two recorded throttle banks.

const RPM_BANDS := [950.0, 1800.0, 3200.0, 4700.0, 6400.0]
const FAMILIES := {
	"classic": "compact", "mini": "compact", "escort": "compact", "estate": "compact",
	"impreza": "boxer", "gt4": "boxer", "wrc": "boxer", "rally2": "boxer", "rally1": "boxer",
	"truck": "heavy", "suv": "heavy", "buggy": "heavy",
}
## Heavy bodies need more weight than the shared recordings give: a louder, lower voice, and (for the
## truck) a sub-octave layer of the same engine so it rumbles.
const GAIN_MUL := {"truck": 1.75, "suv": 1.35, "buggy": 1.3}
const PITCH_MUL := {"truck": 0.8, "suv": 0.9}
const BUS := &"Engine"
static var _loops := {}

var _voices: Array[Node] = []
var _levels := PackedFloat32Array()
var _with_coast: bool
var _gain_mul := 1.0
var _pitch_mul := 1.0
var _sub: Array[Node] = []


func _init(parent: Node, style: String, with_coast: bool, exhaust_position := Vector3.ZERO) -> void:
	_with_coast = with_coast
	var family: String = FAMILIES.get(style, "turbo")
	_gain_mul = float(GAIN_MUL.get(style, 1.0))
	_pitch_mul = float(PITCH_MUL.get(style, 1.0))
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
	if style == "truck":
		# Sub-octave rumble: the two lowest bands again, an octave down.
		for band in [0, 1, 2]:
			var sub: Node
			if with_coast:
				sub = AudioStreamPlayer.new()
			else:
				var ex := AudioStreamPlayer3D.new()
				ex.unit_size = 4.5
				ex.max_distance = 65.0
				ex.position = exhaust_position
				sub = ex
			sub.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			sub.bus = BUS
			sub.stream = loop_from_file("%s_power_%d.wav" % [family, band])
			sub.volume_db = -80.0
			sub.set_meta("band", band)
			parent.add_child(sub)
			_sub.append(sub)


func stop() -> void:
	for sv in _sub:
		sv.stop()
		sv.queue_free()
	_sub.clear()
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
	gain *= _gain_mul
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
		voice.pitch_scale = clampf(rpm / RPM_BANDS[i % RPM_BANDS.size()] * _pitch_mul, 0.5, 1.95)
		voice.volume_db = linear_to_db(maxf(0.0001, amplitude))
		if not _with_coast:
			(voice as AudioStreamPlayer3D).max_db = voice.volume_db - 9.0
		if not voice.playing:
			voice.play()
	for sv in _sub:
		var band: int = int(sv.get_meta("band"))
		# Each sub layer follows its own band's weight in the crossfade.
		var weight := 0.0
		if band == low:
			weight = sqrt(1.0 - blend)
		elif band == high:
			weight = sqrt(blend)
		var amp := gain * 0.6 * power * weight
		if amp < 0.001 and not _with_coast:
			if sv.playing:
				sv.stop()
			continue
		sv.pitch_scale = clampf(rpm / RPM_BANDS[band] * _pitch_mul * 0.5, 0.3, 1.2)
		sv.volume_db = linear_to_db(maxf(0.0001, amp))
		if not _with_coast:
			(sv as AudioStreamPlayer3D).max_db = sv.volume_db - 9.0
		if not sv.playing:
			sv.play()
