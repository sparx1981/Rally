class_name PerfGovernor
extends Node
## Keeps the frame rate steady without the player touching settings:
##  * Dynamic resolution: lowers the 3D render scale when frames run long, raises it again when there is headroom.
##  * First-launch self-check: a short hidden benchmark behind the title screen picks Low, Medium or High.

const MIN_SCALE := 0.55

var _avg := 0.0
var _n := 0
var _t := 0.0
var _scale := 1.0
var _cool := 0.0
var _up_ok := 0.0
var _bench_running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _target_ms() -> float:
	return 1000.0 / float(maxi(int(Settings.g("fps")), 30))


## The scale the player chose; dynamic resolution never goes above it.
func _user_scale() -> float:
	return clampf(float(Settings.g("render_scale")), 0.4, 1.0)


func _process(delta: float) -> void:
	if _bench_running or not bool(Settings.g("dynamic_res")):
		return
	var vp := get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	if get_tree().paused:
		return
	var ms := clampf(delta * 1000.0, 0.0, 100.0)
	_avg = lerpf(_avg, ms, 0.05) if _n > 0 else ms
	_n += 1
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var ceiling := _user_scale()
	if _scale > ceiling or absf(vp.scaling_3d_scale - _scale) > 0.2:
		_scale = ceiling
	var target := _target_ms()
	if _t < 1.0:
		return
	if _avg > target * 1.14 and _scale > MIN_SCALE:
		_scale = maxf(MIN_SCALE, _scale - 0.05)
		_cool = 8.0
		_up_ok = 0.0
		_t = 0.0
		vp.scaling_3d_scale = _scale
	elif _avg < target * 1.04 and _scale < ceiling and _cool <= 0.0:
		_up_ok += 1.0
		if _up_ok >= 4.0:
			_scale = minf(ceiling, _scale + 0.03)
			_up_ok = 0.0
			vp.scaling_3d_scale = _scale
		_t = 0.0
	else:
		_up_ok = 0.0
		_t = 0.0


## Hidden first-launch benchmark: measure the attract demo at High, then Medium, and keep the best preset that
## holds the frame-rate target. Runs once (the result is saved).
func run_self_check() -> void:
	if bool(Settings.g("benchmarked")) or DisplayServer.get_name() == "headless":
		return
	_bench_running = true
	var old_fps := Engine.max_fps
	var chosen := "low"
	for preset in ["high", "medium"]:
		Settings.apply_preset(preset)
		Engine.max_fps = 0
		get_viewport().scaling_3d_scale = _user_scale()
		await get_tree().create_timer(1.5).timeout   # settle after the change
		var samples: Array = []
		var t_end := Time.get_ticks_msec() + 4500
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			samples.append(Time.get_ticks_usec())
		var times: Array = []
		for i in range(1, samples.size()):
			times.append(float(samples[i] - samples[i - 1]) / 1000.0)
		times.sort()
		var p90: float = times[int(times.size() * 0.9)] if times.size() > 8 else 99.0
		var avg := 0.0
		for v in times:
			avg += float(v)
		avg /= maxf(times.size(), 1.0)
		print("SELFCHECK ", preset, " avg_ms=%.1f p90_ms=%.1f frames=%d" % [avg, p90, times.size()])
		if avg <= 17.0 and p90 <= 21.0:
			chosen = preset
			break
	Settings.apply_preset(chosen)
	Settings.set_value("benchmarked", true)
	Engine.max_fps = old_fps
	Settings.apply()
	_bench_running = false
