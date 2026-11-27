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
var stop_at_s := -1.0     # parc fermé: brake to a stop here
var park_lat := 0.0
var joker_lap := 0         # rallycross: the lap (1-based) this driver plans to use the Joker; 0 = decided at start
var _jk_lat := 0.0
var _jk_abort_lap := -1   # a Joker attempt that got stuck is abandoned for that lap


func _init(c: Car, skill_v: float) -> void:
	car = c
	skill = skill_v
	_wobble_seed = randf() * 100.0
	var mu := Car.BASE_MU * float(c.stats["grip"]) * c.stage.grip()
	var top := c.top_speed()
	profile = c.track.speed_profile(mu * 0.8, c.profile_braking() * 0.7, c.profile_acceleration() * 0.6, top * 0.98)


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
		if o == car or absf(o.y-car.y) > 3.0:
			continue
		var ds: float = o.s - car.s
		if tr.circuit:
			ds = fposmod(ds, tr.length)
		if ds > 0.0 and ds < 9.0 and absf(o.lat - car.lat - _offset * 0.0) < 2.4:
			want = o.lat + (2.8 if o.lat < 0.0 else -2.8)
	want += sin(t * 0.3 + _wobble_seed) * 0.6
	var lane := tr.forced_lane(car.s + 6.0)
	if not is_nan(lane):
		want = lane
	var taking_joker := false
	var s_rel_lane := 0.0
	if not tr.joker.is_empty() and not car.joker_taken and car.laps_total > 0:
		if joker_lap == 0:
			joker_lap = 1 + (car.driver_name.hash() & 0xffff) % maxi(car.laps_total, 1)
		var is_lap := (car.lap + 1 == joker_lap or car.lap + 1 >= car.laps_total) and _jk_abort_lap != car.lap
		var s_rel := wrapf(car.s - float(tr.joker.s0), -tr.length * 0.5, tr.length * 0.5)
		s_rel_lane = s_rel
		if is_lap and s_rel > -90.0 and s_rel < float(tr.joker.s1) - float(tr.joker.s0):
			taking_joker = true
			var band := tr.joker_band(car.s + look)
			var lane_mid := float(tr.joker.side) * (tr.road_half_width(car.s) + float(tr.joker.w) * 0.5 + 0.5)
			if not is_nan(band.x):
				lane_mid = (band.x + band.y) * 0.5
			elif s_rel > 0.5 * (float(tr.joker.s1) - float(tr.joker.s0)):
				lane_mid = float(tr.joker.side) * tr.road_half_width(car.s + look) * 0.6   # past the merge: rejoin the road
			# Drift across gradually through the open funnel, not in one jump.
			var edge := float(tr.joker.side) * tr.road_half_width(car.s) * 0.8
			want = lerpf(lerpf(0.0, edge, smoothstep(-90.0, -40.0, s_rel)), lane_mid, smoothstep(-12.0, maxf(20.0, 0.25 * (float(tr.joker.s1) - float(tr.joker.s0))), s_rel))
			_jk_lat = want
	if stop_at_s > 0.0 and car.s > stop_at_s - 45.0:
		want = park_lat   # swing into the parking bay
		_offset = lerpf(_offset, want, clampf(dt * 1.6, 0.0, 1.0))
	else:
		if taking_joker:
			_offset = lerpf(_offset, want, clampf(dt * 3.0, 0.0, 1.0))
		else:
			var lim := tr.road_half_width(car.s) * 0.76
			_offset = lerpf(_offset, clampf(want, -lim, lim), clampf(dt * (5.0 if not is_nan(lane) else 1.5), 0.0, 1.0))
	var target := tr.pts[j] + tr.nrm[j] * _offset
	var d := (target - car.pos).normalized()
	var f := car.fwd()
	var ang := atan2(f.x * d.y - f.y * d.x, f.dot(d))
	car.steer = clampf(ang * 2.4, -1.0, 1.0)
	# Speed target.
	var vt: float = profile[tr.index_at(car.s + 3.0)] * skill * (0.99 if taking_joker else 1.0)
	if taking_joker and not is_nan(tr.joker_band(car.s).x) and absf(car.lat) > tr.road_half_width(car.s):
		# The lane is longer and looser: spread the circuit's Joker time delta evenly over its length.
		var lane_len := maxf(float(tr.joker.s1) - float(tr.joker.s0), 40.0)
		vt = 1.0 / (1.0 / maxf(vt, 4.0) + float(tr.rx_info.get("pace", 0.0)) / lane_len)
	if taking_joker and car.s > float(tr.joker.s0) - 40.0:
		# The lane's line has a different radius from the centre line the speed profile was made for.
		var k := float(tr.curv[tr.index_at(car.s + 6.0)])
		vt *= sqrt(clampf(1.0 - k * clampf(_jk_lat, -30.0, 30.0), 0.25, 1.0))
	if taking_joker and s_rel_lane < 25.0:
		vt = minf(vt, 17.0)   # slow for the lane mouth: the nose and the sideways move need a controlled entry
	if tr.rx and car.lap < 5:
		var patch_now := tr.patch_at(car.s + 3.0, car.lat)
		if patch_now.get('rx', false) and patch_now['kind'] != 'tarmac':
			vt *= lerpf(1.0, 0.92, maxf(0.0, 1.0 - 0.18 * float(car.lap)))   # still watered
	if stop_at_s > 0.0:
		vt = minf(vt, sqrt(maxf(0.0, 2.0 * 5.0 * (stop_at_s - car.s))))
	var dv := vt - vl
	if dv > 0.0:
		car.throttle = clampf(dv * 0.5 + 0.35, 0.0, 1.0)
		car.brake = 0.0
	else:
		car.throttle = 0.0
		car.brake = clampf(-dv * 0.22, 0.0, 1.0)
	car.handbrake = 1.0 if (absf(ang) > 0.9 and vl > 8.0) else 0.0
	# Recover if stuck.
	if not car.frozen and absf(vl) < 1.0 and not car.airborne and stop_at_s < 0.0:
		_stuck += dt
		if _stuck > 1.2 and taking_joker:
			_jk_abort_lap = car.lap
		if _stuck > 2.5:
			car.reset_to_track()
			_stuck = 0.0
	else:
		_stuck = 0.0
	if absf(car.lat) > maxf(tr.width * 2.0 + 20.0, absf(park_lat) + 4.0):
		car.reset_to_track()
