class_name FlapSpring
extends RefCounted
## The paper flap from the papercraft skill (assets/lib/paper-motion.js), ported to GDScript.
## p: 0 = lying flat, 1 = upright, > 1 = overshoot. Rises on a soft spring, latches at upright into a
## stiff 4.5 Hz quiver (8-15 % overshoot, still by ~1 s), falls softly after a small unlatch twitch.

var p := 0.0
var v := 0.0
var target := 0.0
var locked := false
var at_rest := true
var k_up: float
var c_up: float
var w_l: float
var z_l: float
var drag_l: float
var fric_l: float
var k_dn: float
var c_dn: float
var g_dn: float
var antic: float
var rest := 0.25
var min_bounce: float

const SUB_HZ := 120.0


func _init(size := 0.4, jitter := 0.0) -> void:
	var t := clampf((size - 0.12) / 0.58, 0.0, 1.0)
	var fs := (1.14 + (0.88 - 1.14) * t) * (1.0 + jitter * 0.03)
	var wob := 1.0 + t
	k_up = 62.0 * fs * fs
	c_up = 5.0 * fs * (1.0 - 0.5 * t)
	w_l = TAU * 4.5 * (1.0 + jitter * 0.03)
	z_l = 0.04 / sqrt(wob)
	drag_l = 3.5 / sqrt(wob)
	fric_l = 2.2 * fs * (1.0 + 0.8 * t)
	k_dn = 10.0 * fs * fs
	c_dn = 4.5 * fs
	g_dn = 5.0 * fs * fs
	antic = 1.2 * fs
	min_bounce = 0.5 * fs


func reset(value: float) -> void:
	p = value
	v = 0.0
	target = value
	locked = value >= 1.0
	at_rest = true


func set_target(t: float) -> void:
	if t == target:
		return
	if t == 0.0 and at_rest and p >= 1.0:
		v = antic
	target = t
	at_rest = false
	if t == 0.0:
		locked = false


func step(dt: float) -> float:
	var steps := maxi(1, ceili(dt * SUB_HZ))
	var h := dt / steps
	for i in steps:
		if at_rest:
			break
		var a: float
		if target == 1.0:
			if not locked and p >= 1.0:
				locked = true
			if locked:
				a = -w_l * w_l * (p - 1.0) - (2.0 * z_l * w_l + drag_l * absf(v) + fric_l / (absf(v) + 0.05)) * v
			else:
				a = k_up * (1.0 - p) - c_up * v
		else:
			a = -k_dn * p - c_dn * v - g_dn
			if v > 0.0:
				a -= c_up * v * minf(1.0, p)
			if p > 1.0:
				a -= w_l * w_l * (p - 1.0) + 2.0 * z_l * w_l * v
		v += a * h
		p += v * h
		if p <= 0.0 and target == 0.0:
			p = 0.0
			v = -v * rest if v < -min_bounce else 0.0
			if v == 0.0:
				at_rest = true
		if target == 1.0 and absf(p - 1.0) < 0.002 and absf(v) < 0.024:
			p = 1.0
			v = 0.0
			at_rest = true
	return p
