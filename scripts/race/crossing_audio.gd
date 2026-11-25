class_name CrossingAudio
extends Node
## Optional procedural joint sounds. Marks are aligned to front and rear axles.

static var _bank := {}
var _marks: Array[Dictionary] = []
var _cursor := 0
var _previous := NAN
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func setup(track: Track, axle_half: float) -> void:
	for bridge in track.bridges:
		var key := "wood" if bridge.kind == "covered" else ("stone" if bridge.kind == "stone" else "steel")
		for sign_v: float in [-1.0, 1.0]:
			var joint := float(bridge.s) + sign_v * float(bridge.half)
			_marks.append({"s": joint - axle_half, "sound": key, "rear": false})
			_marks.append({"s": joint + axle_half, "sound": key, "rear": true})
	for tunnel in track.tunnels:
		for joint: float in [tunnel.s0 + 0.7, tunnel.s1 - 1.2]:
			_marks.append({"s": joint, "sound": "tunnel", "rear": false})
	if not track.stacked_crossing.is_empty():
		_marks.append({"s": float(track.stacked_crossing.lower) - 2.0, "sound": "tunnel", "rear": false})
	_marks.sort_custom(func(a, b): return a.s < b.s)
	for index in 2:
		var one_shot := AudioStreamPlayer.new()
		one_shot.bus = "SFX"
		add_child(one_shot)
		_players.append(one_shot)


func seek_course(station: float) -> void:
	stop()
	_previous = station
	_cursor = 0
	while _cursor < _marks.size() and _marks[_cursor].s <= station:
		_cursor += 1


func stop() -> void:
	for one_shot in _players:
		one_shot.stop()


func feed(station: float, speed: float, grounded: bool) -> void:
	if is_nan(_previous) or station - _previous > 30.0 or station < _previous - 5.0:
		seek_course(station)
	while _cursor < _marks.size() and _marks[_cursor].s <= station:
		var mark: Dictionary = _marks[_cursor]
		if mark.s > _previous and Settings.g("crossing_audio") and grounded and speed > 2.5:
			var one_shot := _players[_next_player]
			_next_player = (_next_player + 1) % _players.size()
			one_shot.stream = _sound(mark.sound)
			var intensity := clampf(speed / 26.0, 0.20, 1.0)
			one_shot.volume_db = -10.0 + linear_to_db(intensity) - (3.5 if mark.rear else 0.0)
			one_shot.pitch_scale = lerpf(0.83, 1.15, intensity)
			one_shot.play()
		_cursor += 1
	_previous = station


static func _sound(kind: String) -> AudioStreamWAV:
	if _bank.has(kind):
		return _bank[kind]
	const RATE := 22050
	var tail := 0.39 if kind == "tunnel" else 0.15
	var samples := PackedByteArray()
	samples.resize(roundi(tail * RATE) * 2)
	var freq := float({"wood": 143.0, "stone": 84.0, "steel": 497.0, "tunnel": 105.0}[kind])
	var decay := float({"wood": 39.0, "stone": 34.0, "steel": 43.0, "tunnel": 51.0}[kind])
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var noise := 0.0
	for i in samples.size() / 2:
		var t := float(i) / RATE
		noise = lerpf(noise, rng.randf_range(-1, 1), 0.25)
		var motion := (sin(TAU * freq * t) * 0.42 + sin(TAU * freq * 1.73 * t) * 0.20) * exp(-decay * t)
		var hit := noise * exp(-65.0 * t) * 0.92 + motion
		if kind == "tunnel":
			for bounce: float in [0.052, 0.126, 0.213]:
				var after := t - bounce
				if after > 0.0:
					hit += sin(TAU * (freq - 31.0) * after) * exp(-47.0 * after) * (0.38 - bounce)
		var amplitude := hit * minf(t * 580.0, 1.0)
		samples.encode_s16(i * 2, roundi(clampf(amplitude, -0.97, 0.97) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = samples
	_bank[kind] = sound
	return sound
