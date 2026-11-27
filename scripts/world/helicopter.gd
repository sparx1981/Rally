class_name Helicopter
extends Node3D
## A broadcast helicopter that now and then follows the course overhead: first pass shortly after
## the start, then every couple of minutes. Rotors spin, a nav light blinks and, after dark, a
## searchlight sweeps the road beneath it. The chop is positional, so it fades in and out.

const FIRST_PASS := 22.0
const GAP := 110.0
const SPEED := 38.0
const ALTITUDE := 26.0
const RUN := 1100.0

var track: Track
var _wait := FIRST_PASS
var _flying := false
var _s := 0.0
var _flown := 0.0
var _heading := 0.0
var _roll := 0.0
var _main_rotor: Node3D
var _tail_rotor: Node3D
var _strobe: MeshInstance3D
var _beam: SpotLight3D
var _audio: AudioStreamPlayer3D
var _t := 0.0
var _night := false


func setup(t: Track, mat: Material, night: bool) -> void:
	track = t
	_night = night
	var b := PaperKit.Builder.new(77)
	var I := Transform3D()
	var white := Color("#f1eadb")
	var red := Color("#c8553d")
	var ink := Color("#2b2b2e")
	b.box(Vector3(0, 0, 0.2), Vector3(1.7, 1.6, 3.4), I, white)
	b.box(Vector3(0, -0.05, 2.15), Vector3(1.5, 1.3, 1.0), I, white)
	b.box(Vector3(0, 0.15, 2.5), Vector3(1.3, 0.9, 0.4), I, Color("#5a6f80"))
	b.box(Vector3(0, -0.2, 0.3), Vector3(1.74, 0.28, 3.0), I, red)
	b.box(Vector3(0, 0.25, -3.2), Vector3(0.45, 0.55, 4.2), I, white)
	b.box(Vector3(0, 0.95, -5.1), Vector3(0.12, 1.3, 0.9), I, red)
	b.box(Vector3(0, 1.0, 0.1), Vector3(0.7, 0.4, 1.0), I, ink)
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.85, -1.25, 0.3), Vector3(0.08, 0.08, 3.2), I, ink)
		for pz: float in [-0.7, 1.2]:
			b.box(Vector3(sx * 0.85, -0.95, pz), Vector3(0.08, 0.6, 0.08), I, ink)
	var body := MeshInstance3D.new()
	body.mesh = b.mesh()
	body.material_override = mat
	add_child(body)
	_main_rotor = Node3D.new()
	_main_rotor.position = Vector3(0, 1.3, 0.1)
	var rb := PaperKit.Builder.new(78)
	rb.box(Vector3.ZERO, Vector3(10.0, 0.05, 0.32), I, ink)
	rb.box(Vector3.ZERO, Vector3(0.32, 0.05, 10.0), I, ink)
	rb.box(Vector3(0, -0.12, 0), Vector3(0.3, 0.25, 0.3), I, ink)
	var rm := MeshInstance3D.new()
	rm.mesh = rb.mesh()
	rm.material_override = mat
	_main_rotor.add_child(rm)
	add_child(_main_rotor)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.28, 1.0, -5.1)
	var tb := PaperKit.Builder.new(79)
	tb.box(Vector3.ZERO, Vector3(0.05, 1.5, 0.12), I, ink)
	tb.box(Vector3.ZERO, Vector3(0.05, 0.12, 1.5), I, ink)
	var tm := MeshInstance3D.new()
	tm.mesh = tb.mesh()
	tm.material_override = mat
	_tail_rotor.add_child(tm)
	add_child(_tail_rotor)
	var nb := PaperKit.Builder.new(80)
	nb.box(Vector3.ZERO, Vector3(0.28, 0.28, 0.28), I, Color("#ff4a3a"), Color(-1, 0, 0), true)
	_strobe = MeshInstance3D.new()
	_strobe.mesh = nb.mesh()
	_strobe.material_override = mat
	_strobe.position = Vector3(0, 1.9, -5.0)
	add_child(_strobe)
	if night:
		_beam = SpotLight3D.new()
		_beam.light_color = Color("#fff4d8")
		_beam.light_energy = 6.0
		_beam.spot_range = 70.0
		_beam.spot_angle = 14.0
		_beam.position = Vector3(0, -1.0, 2.0)
		_beam.rotation = Vector3(-1.2, PI, 0)
		add_child(_beam)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _chop()
	_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_audio.unit_size = 26.0
	_audio.max_distance = 260.0
	_audio.volume_db = -3.0
	add_child(_audio)
	visible = false


## Rotor chop: eleven thumps a second, each a short low thud with a band of air noise.
static func _chop() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var ph := fmod(float(i) / float(rate) * 11.0, 1.0)
		var env := exp(-ph * 9.0)
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.22
		var v := (sin(TAU * 70.0 * float(i) / float(rate)) * 0.6 + lp * 0.9) * env * 0.8
		v += sin(TAU * 150.0 * float(i) / float(rate)) * 0.12
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func update(dt: float, player_s: float) -> void:
	_t += dt
	if not _flying:
		_wait -= dt
		if _wait <= 0.0:
			_begin(player_s)
		return
	_s += SPEED * dt
	_flown += SPEED * dt
	var s := fposmod(_s, track.length) if track.rx else _s
	if _flown > RUN or (not track.rx and s >= track.finish_s - 10.0):
		_end()
		return
	var i := track.index_at(s)
	var ahead := track.index_at(minf(s + 30.0, track.length) if not track.rx else fposmod(s + 30.0, track.length))
	var p: Vector2 = track.pts[i]
	var q: Vector2 = track.pts[ahead]
	var sway := sin(_t * 0.5) * 6.0
	var pn: Vector2 = track.nrm[i]
	var pos2 := p + pn * sway
	var ground := track.terrain.height(pos2) if track.terrain else track.elev[i]
	var want_y := maxf(ground, track.elev[i]) + ALTITUDE + sin(_t * 0.7) * 2.0
	position.y = lerpf(position.y, want_y, clampf(dt * 1.5, 0.0, 1.0)) if position.y > 1.0 else want_y
	position.x = pos2.x
	position.z = pos2.y
	var want_h := atan2(q.x - p.x, q.y - p.y)
	_heading = lerp_angle(_heading, want_h, clampf(dt * 1.2, 0.0, 1.0))
	var turn := wrapf(want_h - _heading, -PI, PI)
	_roll = lerpf(_roll, clampf(-turn * 1.4, -0.35, 0.35), clampf(dt * 2.0, 0.0, 1.0))
	rotation = Vector3(0.06, _heading, _roll)
	_main_rotor.rotation.y += dt * 38.0
	_tail_rotor.rotation.x += dt * 50.0
	_strobe.visible = fmod(_t, 1.1) < 0.12
	if _beam:
		_beam.visible = true


func _begin(player_s: float) -> void:
	_flying = true
	_flown = 0.0
	_s = player_s - 160.0
	if not track.rx:
		_s = maxf(_s, track.start_s)
	var i := track.index_at(fposmod(_s, track.length) if track.rx else _s)
	position = Vector3(track.pts[i].x, track.elev[i] + ALTITUDE, track.pts[i].y)
	_heading = track.heading_at(i)
	visible = true
	_audio.play()


func _end() -> void:
	_flying = false
	visible = false
	_audio.stop()
	_wait = GAP
