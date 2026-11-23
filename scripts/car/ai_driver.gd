class_name AIDriver
extends RefCounted
## Drives a Car along the stage: a look-ahead target on a racing line that cuts to the inside of
## bends, a speed target from the stage's ideal-speed profile, simple overtaking avoidance.

var car: Car
var skill := 1.0
var profile := PackedFloat32Array()
var _offset := 0.0
var _stuck := 0.0
var _wobble_seed := 0.0


func _init(c: Car, skill_v: float) -> void:
	car = c
	skill = skill_v
	_wobble_seed = randf() * 100.0
	var mu := Car.BASE_MU * float(c.stats["grip"]) * c.stage.grip()
	var top := c.top_speed()
	profile = c.track.speed_profile(mu * 0.8, Car.BRAKE * c.stage.grip() * 0.7, Car.BASE_ACC * float(c.stats["accel"]) * 0.6, top * 0.98)


func update(dt: float, others: Array, t: float) -> void:
	var tr := car.track
	var vl := car.v_long
	var look := 5.0 + absf(vl) * 0.5
	var j := tr.index_at(car.s + look)
	# Racing line: drift to the inside of the upcoming bend.
	var kav := 0.0
	for k in range(1, 6):
		kav += tr.curv[tr.index_at(car.s + look + k * 5.0)]
	kav /= 5.0
	var want := clampf(-kav * 140.0, -1.0, 1.0) * tr.width * 0.27
	# Avoid cars just ahead.
	for o in others:
		if o == car:
			continue
		var ds: float = o.s - car.s
		if ds > 0.0 and ds < 9.0 and absf(o.lat - car.lat - _offset * 0.0) < 2.4:
			want = o.lat + (2.8 if o.lat < 0.0 else -2.8)
	want += sin(t * 0.3 + _wobble_seed) * 0.6
	var lane := tr.forced_lane(car.s + 6.0)
	if not is_nan(lane):
		want = lane
	_offset = lerpf(_offset, clampf(want, -tr.width * 0.38, tr.width * 0.38), clampf(dt * (5.0 if not is_nan(lane) else 1.5), 0.0, 1.0))
	var target := tr.pts[j] + tr.nrm[j] * _offset
	var d := (target - car.pos).normalized()
	var f := car.fwd()
	var ang := atan2(f.x * d.y - f.y * d.x, f.dot(d))
	car.steer = clampf(ang * 2.4, -1.0, 1.0)
	# Speed target.
	var vt: float = profile[tr.index_at(car.s + 3.0)] * skill
	var dv := vt - vl
	if dv > 0.0:
		car.throttle = clampf(dv * 0.5 + 0.35, 0.0, 1.0)
		car.brake = 0.0
	else:
		car.throttle = 0.0
		car.brake = clampf(-dv * 0.22, 0.0, 1.0)
	car.handbrake = 1.0 if (absf(ang) > 0.9 and vl > 8.0) else 0.0
	# Recover if stuck.
	if not car.frozen and absf(vl) < 1.0 and not car.airborne:
		_stuck += dt
		if _stuck > 2.5:
			car.reset_to_track()
			_stuck = 0.0
	else:
		_stuck = 0.0
	if absf(car.lat) > tr.width * 2.0:
		car.reset_to_track()
