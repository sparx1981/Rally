extends Node

signal popped
## Game audio. Engine banks, gravel and exhaust shots come from mechanically recorded sources.
## Short effects combine recorded samples and synthesis.

const RATE := 22050
const SKID_OGG := preload("res://audio/kenney/skid.ogg")
const IMPACT_OGG := preload("res://audio/kenney/impact.ogg")
const LAND_OGG := preload("res://audio/kenney/land.ogg")
const AMBIENCE_OGG := preload("res://audio/kenney/ambience.ogg")
const UI_CLICKS := [preload("res://audio/kenney/placement-a.ogg"), preload("res://audio/kenney/placement-b.ogg"), preload("res://audio/kenney/placement-c.ogg")]
const UI_FOCUS := preload("res://audio/kenney/rotate.ogg")
const UI_TOGGLE := preload("res://audio/kenney/toggle.ogg")

const ANTILAG_STYLES := ["quattro", "t16", "integrale", "gt4", "impreza", "evo", "wrc", "rally1", "rally2"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _engine: AudioStreamPlayer
var _engine_voice: RecordedEngine
var _skid: AudioStreamPlayer
var _roll: AudioStreamPlayer
var _gravel_roll: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _amb2: AudioStreamPlayer

var _cabin_filter := AudioEffectLowPassFilter.new()
var _rpm := 900.0
var _thr := 0.0
var _prev_thr := 0.0
var _load := 0.0
var _interior_mix := 0.0
var _voice_duck := 0.0
var _shift_time := 0.0
var _shift_gain := 1.0
var _in_cockpit := false
var _co_driver_speaking := false
var _antilag := false
var _last_flap := 0.0
var _roll_kind := ""
var _gravel_mix := 0.0
var _rolling_speed := 0.0
var _rolling_kind := ""
var _gravel_contact := 0.0
var _gravel_slip := 0.0
var _pebble_t := 0.0
var _pop_cd := 0.0
var _rng := RandomNumberGenerator.new()
var _synthesis_task := -1
var _srng := RandomNumberGenerator.new()   # synthesis thread only


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 77
	_streams["impact"] = IMPACT_OGG
	_streams["land"] = LAND_OGG
	_streams["roll_wet"] = RecordedEngine.loop_from_file("wet_roll.wav")
	for i in 3:
		_streams["pop_%d" % i] = load("res://audio/recorded/exhaust_pop_%d.wav" % i)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_engine = AudioStreamPlayer.new()
	_engine.bus = RecordedEngine.BUS
	add_child(_engine)
	_cabin_filter.cutoff_hz = 19000.0
	var engine_bus := AudioServer.get_bus_index("Engine")
	if engine_bus >= 0:
		AudioServer.add_bus_effect(engine_bus, _cabin_filter)
	_skid = _looping_player(SKID_OGG, "SFX")
	_gravel_roll = _looping_player(RecordedEngine.loop_from_file("gravel_roll.wav"), "SFX")
	_roll = AudioStreamPlayer.new()
	_roll.bus = "SFX"
	add_child(_roll)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "SFX"
	add_child(_amb)
	_amb2 = AudioStreamPlayer.new()
	_amb2.bus = "SFX"
	add_child(_amb2)
	get_viewport().gui_focus_changed.connect(func(_c): _ui(UI_FOCUS, -20.0))
	# Synthesis takes a moment on phones: do it off the main thread.
	_synthesis_task = WorkerThreadPool.add_task(_synth_all)


func _exit_tree() -> void:
	if _synthesis_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_synthesis_task)


var _pending_amb := ""
var _ready_synth := false


func _synth_all() -> void:
	var out := {}
	out["flap"] = _wav(_make_flap(), false)
	out["flutter"] = _wav(_make_flutter(), false)
	out["crunch"] = _wav(_make_crunch(), false)
	out["splash"] = _wav(_make_splash(0.4, 1.0), false)
	out["splash_big"] = _wav(_make_splash(1.1, 1.6), false)
	out["tock"] = _wav(_make_tone(620.0, 0.12, 30.0), false)
	out["go"] = _wav(_make_tone(930.0, 0.4, 8.0), false)
	var finish := _make_tone(660.0, 0.12, 19.0)
	finish.append_array(_make_tone(880.0, 0.28, 10.0))
	out["finish"] = _wav(finish, false)
	out["gear"] = _wav(_make_gear(), false)
	out["pebble"] = _wav(_make_pebble(), false)
	out["cheer"] = _wav(_make_cheer(), false)
	out["thud"] = _wav(_make_thud(), false)
	out["rain"] = _wav(_make_rain(), true)
	out["wind"] = _wav(_make_wind(), true)
	out["roll_snow"] = _wav(_make_roll_snow(), true)
	out["roll_cobble"] = _wav(_make_roll_cobble(), true)
	call_deferred("_synth_done", out)


func _synth_done(out: Dictionary) -> void:
	for k in out.keys():
		_streams[k] = out[k]
	_ready_synth = true
	if _pending_amb != "":
		set_ambience(_pending_amb)
	if _engine_voice != null and _roll_kind != "":
		_roll.stream = _streams.get(_roll_kind)
		_roll.play()


func _looping_player(src: AudioStream, bus: String) -> AudioStreamPlayer:
	var st: AudioStream = src.duplicate()
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _ui(stream: AudioStream, db: float) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.play()


func click() -> void:
	_ui(UI_CLICKS[_rng.randi() % UI_CLICKS.size()], -6.0)


func toggle() -> void:
	_ui(UI_TOGGLE, -6.0)


## Pop-up flaps: one per gesture, at least 0.5 s apart (papercraft skill sound rule).
func flap(volume_db := -14.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flap < 0.5:
		return
	_last_flap = now
	play("flap", volume_db, _rng.randf_range(0.85, 1.15))


func flutter(volume_db := -12.0) -> void:
	play("flutter", volume_db, _rng.randf_range(0.9, 1.15))


func impact(k: float, paper := false) -> void:
	play("impact", linear_to_db(clampf(k, 0.15, 1.0)) - 1.0, _rng.randf_range(0.8, 1.05) - k * 0.1)
	play("thud", linear_to_db(clampf(k, 0.15, 1.0)) - 4.0, _rng.randf_range(0.9, 1.1))
	if paper:
		play("crunch", linear_to_db(clampf(k, 0.2, 1.0)) - 6.0, _rng.randf_range(0.9, 1.2))


func land(k: float) -> void:
	play("land", linear_to_db(clampf(k, 0.2, 1.0)) + 2.0, 0.7)
	play("thud", linear_to_db(clampf(k, 0.2, 1.0)), 0.8)
	play("impact", linear_to_db(clampf(k, 0.2, 1.0)) - 8.0, 0.7)


func suspension(load: float) -> void:
	play("thud", linear_to_db(clampf(load, 0.1, 0.5)) - 7.0, 1.18)


func splash(big: bool, k := 1.0) -> void:
	play("splash_big" if big else "splash", linear_to_db(clampf(k, 0.2, 1.0)) - (0.0 if big else 3.0), _rng.randf_range(0.9, 1.1))


func cheer() -> void:
	play("cheer", -9.0, _rng.randf_range(0.95, 1.05))


func engine_start(style: String) -> void:
	_engine.stop()
	_engine_voice = RecordedEngine.new(_engine, style, true)
	_antilag = style in ANTILAG_STYLES
	_rpm = 900.0
	_thr = 0.0
	_prev_thr = 0.0
	_load = 0.0
	_shift_time = 0.0
	_shift_gain = 1.0
	_pop_cd = 0.0
	_rolling_speed = 0.0
	_gravel_contact = 0.0
	_gravel_mix = 0.0
	_pebble_t = 0.0
	if not _skid.playing:
		_skid.play()
	_gravel_roll.volume_db = -80.0
	_gravel_roll.play()


func engine_stop() -> void:
	_engine_voice = null
	_in_cockpit = false
	_co_driver_speaking = false
	_interior_mix = 0.0
	_voice_duck = 0.0
	_cabin_filter.cutoff_hz = 19000.0
	_engine.stop()
	_skid.stop()
	_gravel_roll.stop()
	_roll.stop()
	_roll_kind = ""


func set_engine(rpm: float, throttle: float, in_cockpit := false, co_driver_speaking := false) -> void:
	_rpm = rpm
	_thr = throttle
	_in_cockpit = in_cockpit
	_co_driver_speaking = co_driver_speaking


func engine_shift() -> void:
	if _engine_voice != null:
		_shift_time = 0.085
		play("gear", -14.0, _rng.randf_range(0.94, 1.08))


func set_skid(amount: float, kind := "dry") -> void:
	if amount < 0.03:
		_skid.volume_db = -80.0
		return
	var base: float = {"dry": 0.0, "rain": -4.0, "snow": -7.0}.get(kind, 0.0)
	_skid.volume_db = linear_to_db(clampf(amount, 0.0, 1.0) * 0.6) + base
	_skid.pitch_scale = (0.7 if kind == "snow" else 0.85) + amount * 0.25


## Ground contact drives a separate recorded gravel layer underneath the base surface.
func set_surface(kind: String, speed: float, gravel_contact: float, slip: float) -> void:
	_rolling_kind = kind
	_rolling_speed = speed
	_gravel_contact = gravel_contact
	_gravel_slip = slip


func _mix_surface(delta: float) -> void:
	var name := ""
	match _rolling_kind:
		"rain", "wet", "mud": name = "roll_wet"
		"snow", "ice", "deep snow": name = "roll_snow"
		"cobble": name = "roll_cobble"
	if name != _roll_kind and _ready_synth:
		_roll_kind = name
		_roll.stream = _streams.get(name)
		if _roll.stream:
			_roll.play()
	var k := clampf(_rolling_speed / 28.0, 0.0, 1.0)
	_gravel_mix = move_toward(_gravel_mix, _gravel_contact, delta * 6.0)
	_gravel_roll.volume_db = linear_to_db(maxf(0.0001, k * _gravel_mix * (0.36 + minf(_gravel_slip, 0.5) * 0.44)))
	_gravel_roll.pitch_scale = 0.76 + k * 0.48
	_roll.volume_db = linear_to_db(maxf(0.0001, k * 0.54 * (1.0 - _gravel_mix)))
	_roll.pitch_scale = 0.8 + k * 0.4
	_pebble_t -= delta
	if _gravel_mix > 0.1 and _gravel_slip > 0.16 and _rolling_speed > 6.0 and _pebble_t <= 0.0:
		play("pebble", -26.0 + k * 6.0, _rng.randf_range(0.7, 1.5))
		_pebble_t = _rng.randf_range(0.13, 0.38) / maxf(k, 0.2)


func set_ambience(kind: String) -> void:
	_amb2.stop()
	if not _ready_synth and kind != "":
		_pending_amb = kind
		return
	if kind == "rain":
		_amb.stream = _streams["rain"]
		_amb.volume_db = -9.0
		_amb.play()
	elif kind == "snow":
		_amb.stream = _streams["wind"]
		_amb.volume_db = -12.0
		_amb.play()
	else:
		var st: AudioStreamOggVorbis = AMBIENCE_OGG.duplicate()
		st.loop = true
		_amb.stream = st
		_amb.volume_db = -14.0
		_amb.play()


func _process(delta: float) -> void:
	if _engine_voice == null:
		return
	_load = lerpf(_load, _thr, 1.0 - exp(-delta * 18.0))
	_interior_mix = move_toward(_interior_mix, float(_in_cockpit), delta * 7.0)
	_voice_duck = move_toward(_voice_duck, float(_co_driver_speaking), delta * (18.0 if _co_driver_speaking else 4.0))
	_cabin_filter.cutoff_hz = lerpf(19000.0, 3400.0, _interior_mix)
	_shift_time = maxf(0.0, _shift_time - delta)
	_shift_gain = 1.0 - 0.43 * smoothstep(0.0, 0.085, _shift_time)
	var idle_level := lerpf(0.72, 1.0, smoothstep(1000.0, 2500.0, _rpm))
	var gain := idle_level * _shift_gain * db_to_linear(-3.0 * _voice_duck + _interior_mix)
	_engine_voice.mix(_rpm, _load, gain)
	_mix_surface(delta)
	# Exhaust pops when the throttle snaps shut at high revs.
	_pop_cd -= delta
	if _antilag and _prev_thr > 0.62 and _thr < 0.14 and _rpm > 4500.0 and _pop_cd <= 0.0 and _shift_time == 0.0:
		_pop_cd = 0.6
		popped.emit()
		play("pop_%d" % _rng.randi_range(0, 2), -13.0 - _interior_mix * 4.0, _rng.randf_range(0.93, 1.06))
	_prev_thr = _thr


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


func _buf(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	return b


## Band-limited noise between lo and hi Hz with an envelope env(t).
func _noise_band(n: int, lo_hz: float, hi_hz: float, env: Callable) -> PackedFloat32Array:
	var out := _buf(n)
	var a_hi := clampf(hi_hz / RATE * TAU, 0.0, 1.0)
	var a_lo := clampf(lo_hz / RATE * TAU, 0.0, 1.0)
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		var x := _srng.randf() * 2.0 - 1.0
		l1 += (x - l1) * a_hi
		l2 += (l1 - l2) * a_lo
		out[i] = (l1 - l2) * float(env.call(float(i) / RATE))
	return out


func _add_click(out: PackedFloat32Array, at: int, len: int, gain: float, bright: float) -> void:
	var lp := 0.0
	for i in len:
		if at + i >= out.size():
			return
		var x := (_srng.randf() * 2.0 - 1.0)
		lp += (x - lp) * bright
		out[at + i] += (x - lp) * gain * exp(-float(i) / (len * 0.25))


func _seam(out: PackedFloat32Array, fade: int) -> void:
	var n := out.size()
	for i in fade:
		var a := float(i) / fade
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)


func _norm(out: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in out:
		m = maxf(m, absf(v))
	for i in out.size():
		out[i] = out[i] / m * peak
	return out


func _make_flap() -> PackedFloat32Array:
	# A card flipping: two soft transients and a little air.
	var n := int(RATE * 0.16)
	var out := _noise_band(n, 500.0, 2800.0, func(t): return 0.5 * exp(-t * 25.0) * minf(1.0, t * 200.0))
	_add_click(out, 0, 160, 0.9, 0.25)
	_add_click(out, int(RATE * 0.035), 140, 0.6, 0.3)
	return _norm(out, 0.8)


func _make_flutter() -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var out := _buf(n)
	var t := 0.0
	while t < 0.62:
		_add_click(out, int(t * RATE), 220, 0.8 * (1.0 - t * 1.2), 0.18)
		t += _srng.randf_range(0.055, 0.075)
	return _norm(out, 0.7)


func _make_crunch() -> PackedFloat32Array:
	var n := int(RATE * 0.3)
	var out := _buf(n)
	for k in 22:
		_add_click(out, _srng.randi_range(0, int(RATE * 0.22)), _srng.randi_range(40, 160), _srng.randf_range(0.3, 1.0), 0.4)
	return _norm(out, 0.7)


func _make_splash(dur: float, size: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := _noise_band(n, 120.0, 1800.0 * size, func(t): return exp(-t * 6.0 / size) * minf(1.0, t * 80.0))
	# Droplets falling back: short pitched blips.
	for k in int(26 * size):
		var at := _srng.randi_range(int(RATE * 0.08), n - 900)
		var f := _srng.randf_range(700.0, 2200.0)
		var g := _srng.randf_range(0.1, 0.3)
		for i in 700:
			var tt := float(i) / RATE
			out[at + i] += sin(TAU * f * (1.0 + tt * 6.0) * tt) * g * exp(-tt * 70.0)
	return _norm(out, 0.9)


func _make_thud() -> PackedFloat32Array:
	var n := int(RATE * 0.3)
	var out := _noise_band(n, 40.0, 500.0, func(t): return exp(-t * 18.0))
	for i in n:
		var t := float(i) / RATE
		out[i] += sin(TAU * (75.0 - t * 80.0) * t) * exp(-t * 14.0) * 0.9
	return _norm(out, 0.9)


func _make_gear() -> PackedFloat32Array:
	var n := int(RATE * 0.09)
	var out := _noise_band(n, 200.0, 1600.0, func(t): return 0.6 * exp(-t * 60.0))
	for i in n:
		var t := float(i) / RATE
		out[i] += sin(TAU * 150.0 * t) * exp(-t * 50.0) * 0.5
	return _norm(out, 0.7)


func _make_pebble() -> PackedFloat32Array:
	var n := int(RATE * 0.06)
	var out := _buf(n)
	var f := _srng.randf_range(2200.0, 3400.0)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.73 * t) * 0.3) * exp(-t * 120.0)
	_add_click(out, 0, 60, 0.6, 0.6)
	return _norm(out, 0.6)


func _make_tone(hz: float, dur: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := _buf(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * hz * t) * 0.6 + sin(TAU * hz * 2.01 * t) * 0.15) * exp(-t * decay) * minf(1.0, t * 300.0) * 0.6
	return out


func _make_cheer() -> PackedFloat32Array:
	# A crowd: many voices as formant-filtered noise, swelling then fading.
	var n := int(RATE * 2.2)
	var out := _buf(n)
	for v in 5:
		var f1 := _srng.randf_range(450.0, 800.0)
		var part := _noise_band(n, f1 * 0.7, f1 * 1.5, func(t): return sin(clampf(t / 2.2, 0.0, 1.0) * PI) * (0.7 + 0.3 * sin(t * 9.0 + v)))
		for i in n:
			out[i] += part[i]
	return _norm(out, 0.6)


func _make_rain() -> PackedFloat32Array:
	var n := RATE * 3
	var out := _noise_band(n, 300.0, 5000.0, func(_t): return 0.35)
	var low := _noise_band(n, 40.0, 400.0, func(_t): return 0.25)
	for i in n:
		out[i] += low[i]
	for k in 420:
		_add_click(out, _srng.randi_range(0, n - 200), _srng.randi_range(30, 110), _srng.randf_range(0.1, 0.45), 0.5)
	_seam(out, 1200)
	return _norm(out, 0.6)


func _make_wind() -> PackedFloat32Array:
	var n := RATE * 4
	var out := _noise_band(n, 50.0, 420.0, func(t): return 0.5 + 0.35 * sin(TAU * t / 4.0) + 0.15 * sin(TAU * t * 0.9))
	var hi := _noise_band(n, 600.0, 1400.0, func(t): return 0.12 * maxf(0.0, sin(TAU * t / 4.0)))
	for i in n:
		out[i] += hi[i]
	_seam(out, 1500)
	return _norm(out, 0.6)


func _make_roll_snow() -> PackedFloat32Array:
	var n := RATE * 2
	var out := _noise_band(n, 150.0, 1600.0, func(t): return 0.25 + 0.25 * absf(sin(TAU * t * 7.0)))
	for k in 260:
		_add_click(out, _srng.randi_range(0, n - 200), _srng.randi_range(80, 200), _srng.randf_range(0.1, 0.3), 0.12)
	_seam(out, 800)
	return _norm(out, 0.6)


func _make_roll_cobble() -> PackedFloat32Array:
	var n := RATE * 2
	var out := _noise_band(n, 40.0, 500.0, func(_t): return 0.45)
	var t := 0.0
	while t < 1.95:
		var at := int(t * RATE)
		for i in 600:
			if at + i < n:
				var tt := float(i) / RATE
				out[at + i] += sin(TAU * 60.0 * tt) * exp(-tt * 40.0) * 0.5
		t += _srng.randf_range(0.06, 0.1)
	_seam(out, 800)
	return _norm(out, 0.6)
