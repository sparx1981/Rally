extends Node
## Procedural audio: no sound files ship with the game. Paper-style sounds are soft, low and dull
## (papercraft skill: noise-based flaps, sparse, at least ~0.5 s apart). The engine is a small
## additive synth driven by rpm and throttle.

const RATE := 22050

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _engine: AudioStreamPlayer
var _engine_pb: AudioStreamGeneratorPlayback
var _skid: AudioStreamPlayer
var _amb: AudioStreamPlayer

var _rpm := 900.0
var _thr := 0.0
var _engine_on := false
var _phase := 0.0
var _phase2 := 0.0
var _lp := 0.0
var _lp2 := 0.0
var _last_flap := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 77
	_streams["flap"] = _wav(_make_flap(), false)
	_streams["thump"] = _wav(_make_thump(), false)
	_streams["click"] = _wav(_make_click(), false)
	_streams["splash"] = _wav(_make_splash(), false)
	_streams["tock"] = _wav(_make_tone(620.0, 0.12, 30.0), false)
	_streams["go"] = _wav(_make_tone(930.0, 0.35, 9.0), false)
	_streams["gear"] = _wav(_make_gear(), false)
	_streams["skid"] = _wav(_make_skid(), true)
	_streams["rain"] = _wav(_make_rain(), true)
	_streams["wind"] = _wav(_make_wind(), true)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_engine = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	_engine.stream = gen
	_engine.bus = "Engine"
	add_child(_engine)
	_skid = AudioStreamPlayer.new()
	_skid.stream = _streams["skid"]
	_skid.bus = "SFX"
	_skid.volume_db = -80.0
	add_child(_skid)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "SFX"
	add_child(_amb)


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Pop-up flaps: one per gesture, at least 0.5 s apart.
func flap(volume_db := -14.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flap < 0.5:
		return
	_last_flap = now
	play("flap", volume_db, _rng.randf_range(0.85, 1.15))


func click() -> void:
	play("click", -8.0, _rng.randf_range(0.95, 1.05))


func engine_start() -> void:
	_engine_on = true
	if not _engine.playing:
		_engine.play()
		_engine_pb = _engine.get_stream_playback()
	if not _skid.playing:
		_skid.play()


func engine_stop() -> void:
	_engine_on = false
	_engine.stop()
	_engine_pb = null
	_skid.stop()


func set_engine(rpm: float, throttle: float) -> void:
	_rpm = rpm
	_thr = throttle


func set_skid(amount: float) -> void:
	if amount < 0.03:
		_skid.volume_db = -80.0
	else:
		_skid.volume_db = linear_to_db(clampf(amount, 0.0, 1.0) * 0.55)
		_skid.pitch_scale = 0.85 + amount * 0.3


func set_ambience(kind: String) -> void:
	if kind == "rain":
		_amb.stream = _streams["rain"]
		_amb.volume_db = -10.0
		_amb.play()
	elif kind == "snow":
		_amb.stream = _streams["wind"]
		_amb.volume_db = -14.0
		_amb.play()
	else:
		_amb.stop()


func _process(_delta: float) -> void:
	if not _engine_on or _engine_pb == null:
		return
	var n := _engine_pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var f := 18.0 + _rpm / 60.0 * 2.0    # four-cylinder firing frequency
	var amp := 0.16 + 0.2 * _thr
	var alpha := clampf((500.0 + _rpm * 0.12) / RATE * TAU, 0.02, 0.9)
	var inc := f / RATE
	for i in n:
		_phase = fmod(_phase + inc, 1.0)
		_phase2 = fmod(_phase2 + inc * 0.5, 1.0)
		var x := sin(_phase * TAU) * 0.55 + sin(_phase2 * TAU) * 0.3 + (_phase * 2.0 - 1.0) * 0.25
		x += (_rng.randf() * 2.0 - 1.0) * (0.08 + _thr * 0.16)
		_lp += (x - _lp) * alpha
		_lp2 += (_lp - _lp2) * alpha
		var s := _lp2 * amp
		buf[i] = Vector2(s, s)
	_engine_pb.push_buffer(buf)


# --- synthesis helpers -------------------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _noise_band(n: int, lo_hz: float, hi_hz: float, env: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a_hi := clampf(hi_hz / RATE * TAU, 0.0, 1.0)
	var a_lo := clampf(lo_hz / RATE * TAU, 0.0, 1.0)
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		var x := _rng.randf() * 2.0 - 1.0
		l1 += (x - l1) * a_hi
		l2 += (l1 - l2) * a_lo
		out[i] = (l1 - l2) * float(env.call(float(i) / RATE))
	return out


func _make_flap() -> PackedFloat32Array:
	return _noise_band(int(RATE * 0.09), 900.0, 3200.0, func(t): return 1.4 * exp(-t * 45.0) * minf(1.0, t * 400.0))


func _make_click() -> PackedFloat32Array:
	return _noise_band(int(RATE * 0.04), 1200.0, 4000.0, func(t): return 1.0 * exp(-t * 110.0))


func _make_splash() -> PackedFloat32Array:
	return _noise_band(int(RATE * 0.35), 300.0, 2200.0, func(t): return 1.3 * exp(-t * 9.0) * minf(1.0, t * 60.0))


func _make_thump() -> PackedFloat32Array:
	var n := int(RATE * 0.22)
	var out := _noise_band(n, 60.0, 700.0, func(t): return 1.2 * exp(-t * 22.0))
	for i in n:
		var t := float(i) / RATE
		out[i] += sin(TAU * 68.0 * t) * exp(-t * 18.0) * 0.6
	return out


func _make_gear() -> PackedFloat32Array:
	var n := int(RATE * 0.08)
	var out := _noise_band(n, 200.0, 1400.0, func(t): return 0.7 * exp(-t * 60.0))
	for i in n:
		var t := float(i) / RATE
		out[i] += sin(TAU * 140.0 * t) * exp(-t * 50.0) * 0.4
	return out


func _make_tone(hz: float, dur: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * hz * t) * 0.6 + sin(TAU * hz * 2.01 * t) * 0.15) * exp(-t * decay) * minf(1.0, t * 300.0) * 0.6
	return out


func _make_skid() -> PackedFloat32Array:
	var n := RATE
	var out := _noise_band(n, 500.0, 1800.0, func(_t): return 1.0)
	for i in n:
		var t := float(i) / RATE
		out[i] *= 0.9 + 0.1 * sin(TAU * 3.0 * t)
	return out


func _make_rain() -> PackedFloat32Array:
	var n := RATE * 2
	var out := _noise_band(n, 200.0, 3000.0, func(_t): return 0.55)
	for k in 90:
		var at := _rng.randi_range(0, n - 400)
		var g := _rng.randf_range(0.2, 0.5)
		for i in 300:
			out[at + i] += (_rng.randf() * 2.0 - 1.0) * g * exp(-float(i) / 40.0)
	# Crossfade the loop seam.
	var fade := 800
	for i in fade:
		var a := float(i) / fade
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)
	return out


func _make_wind() -> PackedFloat32Array:
	var n := RATE * 3
	var out := _noise_band(n, 60.0, 500.0, func(t): return 0.6 + 0.4 * sin(TAU * t / 3.0))
	var fade := 1000
	for i in fade:
		var a := float(i) / fade
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)
	return out
