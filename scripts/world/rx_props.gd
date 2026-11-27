class_name RxProps
extends Node3D
## Rallycross trackside kit built from paper boxes: start gantry with five lights, Joker gantry and
## boards, braking boards, marshal booths, apex bollards, race control tower, paddock, bleachers,
## floodlight masts, shipping containers, monument arch, and a broadcast drone.

var track: Track
var def: Dictionary
var material: Material
var night := false
var start_lights: Array[MeshInstance3D] = []
var _anim: Array = []   # {node, kind}
var _lamp_mat: StandardMaterial3D


var cones: Array = []         # knockable apex cones: {node, pos, y, hit, vel, axis, spin, rest}
var _cone_mesh: ArrayMesh
var _celebrate_t := 0.0
var _burst_t := 0.0
var _confetti_t := 0.0
var solids: Array = []        # [Vector2 position, radius] the car cannot drive through


func build(t: Track, d: Dictionary, mat: Material, is_dark: bool) -> void:
	track = t
	def = d
	material = mat
	night = is_dark
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color("#fff2c4")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color("#ffe9a0")
	_lamp_mat.emission_energy_multiplier = 1.6 if night else 0.35
	var rx: Dictionary = d.rx
	var b := PaperKit.Builder.new(int(d.seed))
	_start_gantry(b)
	_control_tower(b)
	_paddock(b)
	_braking_boards_and_booths(b)
	if not t.joker.is_empty():
		_joker_signage(b)
	_floodlights(b)
	if night:
		_track_lights(b)
	for band: Array in rx.get("bank", []):
		if float(band[2]) > 0.05:
			_bleachers(b, (float(band[0]) + float(band[1])) * 0.5 * t.length)
	match str(rx.kit):
		"D":
			_containers(b)
			_monument_arch(b, float(rx.get("arch", 0.2)) * t.length)
		"A":
			_campervans(b)
		"C":
			_mining_relics(b)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = material
	add_child(mi)
	_drone()


func _add_cone(p: Vector2, y: float) -> void:
	if _cone_mesh == null:
		var cb := PaperKit.Builder.new(3)
		var I := Transform3D()
		cb.box(Vector3(0, 0.025, 0), Vector3(0.44, 0.05, 0.44), I, Color("#2d2c30"))
		var widths := [0.34, 0.27, 0.20, 0.12]
		for k in 4:
			cb.box(Vector3(0, 0.05 + 0.15 * k + 0.075, 0), Vector3(widths[k], 0.15, widths[k]), I, PaperKit.CREAM if k == 1 else Color("#e8761f"))
		_cone_mesh = cb.mesh()
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _cone_mesh
	mi.material_override = material
	n.add_child(mi)
	add_child(n)
	n.position = Vector3(p.x, y, p.y)
	cones.append({"node": n, "pos": p, "y": y, "hit": false, "vel": Vector3.ZERO, "axis": Vector3.RIGHT, "spin": 0.0, "rest": false})


## A car driving through standing cones knocks them over; returns how many were hit.
func knock_cones(car) -> int:
	if car.airborne:
		return 0
	var f: Vector2 = car.fwd()
	var r: Vector2 = car.right_axis()
	var hits := 0
	for c: Dictionary in cones:
		if c.hit:
			continue
		var d: Vector2 = c.pos - car.pos
		if absf(d.dot(r)) < car.half_wid + 0.25 and absf(d.dot(f)) < car.half_len + 0.25 and absf(car.y - float(c.y)) < 1.2:
			c.hit = true
			var dir: Vector2 = car.vel.normalized() if car.vel.length() > 0.5 else f
			var spd := clampf(car.vel.length() * 0.7, 2.5, 14.0)
			c.vel = Vector3(dir.x * spd + randf_range(-1.5, 1.5), randf_range(2.5, 5.5), dir.y * spd + randf_range(-1.5, 1.5))
			c.axis = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
			c.spin = randf_range(6.0, 12.0)
			hits += 1
	return hits


## Finish-line party: confetti cannons beside the gantry and fireworks overhead for about 14 s.
func celebrate() -> void:
	_celebrate_t = 14.0
	_burst_t = 0.0
	_confetti_t = 0.0


func _celebration_step(delta: float) -> void:
	var i := track.index_at(0.0)
	var base := Vector3(track.pts[i].x, track.elev[i], track.pts[i].y)
	var tang := Vector3(track.tang[i].x, 0.0, track.tang[i].y)
	var side := Vector3(track.nrm[i].x, 0.0, track.nrm[i].y)
	var hw := track.road_half_width(0.0)
	_celebrate_t -= delta
	_confetti_t -= delta
	if _confetti_t <= 0.0:
		_confetti_t = 3.2
		for sd: float in [-1.0, 1.0]:
			_spawn_confetti(base + side * sd * (hw + 2.5) + tang * 3.0, -side * sd)
	_burst_t -= delta
	if _burst_t <= 0.0:
		_burst_t = randf_range(0.45, 0.9)
		var off := side * randf_range(-hw - 8.0, hw + 8.0) + tang * randf_range(8.0, 70.0)
		_spawn_firework(base + off + Vector3(0, randf_range(22.0, 42.0), 0))


func _spawn_confetti(at: Vector3, inward: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 5.0
	p.one_shot = true
	p.explosiveness = 0.35
	p.mesh = QuadMesh.new()
	(p.mesh as QuadMesh).size = Vector2(0.22, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84])
	g.colors = PackedColorArray([Color("#e8453c"), Color("#f2c630"), Color("#3f8fd8"), Color("#4fc46a"), Color("#f5f0e6"), Color("#e86fb0")])
	p.color_initial_ramp = g
	p.direction = (Vector3.UP * 1.6 + inward).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0, -3.2, 0)
	p.damping_min = 0.6
	p.damping_max = 1.4
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_max = 360.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at + Vector3(0, 0.8, 0)
	p.emitting = true
	get_tree().create_timer(7.0).timeout.connect(p.queue_free)
	Sfx.play("thud", -8.0, 1.9)


func _spawn_firework(at: Vector3) -> void:
	var cols := [Color("#ff5a3c"), Color("#ffd24a"), Color("#6ad0ff"), Color("#9bff7a"), Color("#ff7ad9"), Color("#ffffff")]
	var col: Color = cols[randi() % cols.size()]
	var p := CPUParticles3D.new()
	p.amount = 170
	p.lifetime = 2.3
	p.one_shot = true
	p.explosiveness = 0.9
	p.mesh = QuadMesh.new()
	(p.mesh as QuadMesh).size = Vector2(1.8, 1.8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.albedo_texture = _pool_texture()
	p.material_override = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 1.0).lightened(0.5), col, Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.0)])
	p.color_ramp = g
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 25.0
	p.gravity = Vector3(0, -5.0, 0)
	p.damping_min = 1.6
	p.damping_max = 2.4
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(3.5).timeout.connect(p.queue_free)
	Sfx.play("thud", -12.0, 2.4)


func _process(delta: float) -> void:
	if _celebrate_t > 0.0:
		_celebration_step(delta)
	for c: Dictionary in cones:
		if c.hit and not c.rest:
			var n: Node3D = c.node
			var v: Vector3 = c.vel
			v.y -= 22.0 * delta
			n.position += v * delta
			n.rotate(c.axis, c.spin * delta)
			c.vel = v
			if n.position.y <= float(c.y) + 0.12 and v.y < 0.0:
				if v.length() < 3.0:
					c.rest = true
					n.position.y = float(c.y) + 0.12
				else:
					v.y = -v.y * 0.3
					v.x *= 0.6
					v.z *= 0.6
					c.vel = v
					c.spin *= 0.6
	var t := Time.get_ticks_msec() * 0.001
	for a in _anim:
		var n: Node3D = a.node
		if not is_instance_valid(n):
			continue
		match a.kind:
			"orbit":
				var ang: float = a.phase + t * 0.35
				n.position = a.center + Vector3(cos(ang) * a.radius, 0.0, sin(ang) * a.radius) + Vector3(0, sin(t * 1.3) * 0.6, 0)
				n.rotation.y = -ang
			"rotor":
				n.rotation.y += delta * 40.0


# --- helpers ---------------------------------------------------------------------------------------

## Point beside the road at station s: clear of the road AND of any Joker lane on that side, plus offset.
func _at(s: float, side: float, offset: float) -> Dictionary:
	var i := track.index_at(s)
	var reach := track.road_half_width(s)
	var band := track.joker_band(s)
	if not is_nan(band.x):
		reach = maxf(reach, band.y if side > 0.0 else -band.x)
	if not track.joker.is_empty():
		# Keep clear of the lane just before and after it too.
		var near := track.index_at(clampf(s + 20.0, 0.0, track.length))
		var far := track.index_at(clampf(s - 20.0, 0.0, track.length))
		for k in [near, far]:
			var bk := track.joker_band(track.dist[k])
			if not is_nan(bk.x):
				reach = maxf(reach, bk.y if side > 0.0 else -bk.x)
	var p: Vector2 = track.pts[i] + track.nrm[i] * side * (reach + offset)
	if offset >= 3.0:
		# Switchbacks put other stretches of road close by: move out until clear of every road and lane,
		# trying the other side of the road as well; keep the clearest spot found.
		var need := 21.0 + minf(offset, 12.0) * 0.3
		var best_p := p
		var best_c := track.clearance(p)
		for sd: float in [side, -side]:
			var push := 0.0
			while push <= 56.0 and best_c < need:
				var q: Vector2 = track.pts[i] + track.nrm[i] * sd * (reach + offset + push)
				var cq := track.clearance(q)
				if cq > best_c:
					best_c = cq
					best_p = q
				push += 4.0
			if best_c >= need:
				break
		p = best_p
	# The ground now meets the road edge, so trackside props stand on it (a hair above the sunk terrain).
	var y := (track.terrain.height(p) + 0.1) if track.terrain else track.elev[i]
	return {"p": p, "y": y, "heading": track.heading_at(i), "i": i, "n": track.nrm[i]}


## Circles that make a prop solid: along its local z axis, so the car hits it instead of driving through.
func _solid_line(xf: Transform3D, length: float, r: float, centre := 0.0) -> void:
	var z := -length * 0.5 + r
	while z <= length * 0.5 - r + 0.01:
		var w := xf * Vector3(0, 0, z + centre)
		solids.append([Vector2(w.x, w.z), r])
		z += r * 1.5
	if length <= r * 2.0:
		var w2 := xf * Vector3(0, 0, centre)
		solids.append([Vector2(w2.x, w2.z), r])


func _frame(pt: Dictionary, yaw_extra := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(pt.heading) + yaw_extra), Vector3(pt.p.x, pt.y, pt.p.y))


func _turn_sign(i: int) -> float:
	var a := track.tang[maxi(i - 8, 0)]
	var c := track.tang[mini(i + 8, track.pts.size() - 1)]
	return signf(a.x * c.y - a.y * c.x)


# --- start line ------------------------------------------------------------------------------------

func _beam(b: PaperKit.Builder, xf: Transform3D, a: Vector3, z: Vector3, w: float, ink: Color) -> void:
	var dir := a.direction_to(z)
	var up := Vector3.BACK if absf(dir.y) > 0.98 else Vector3.UP
	var mid := (a + z) * 0.5
	b.box(Vector3.ZERO, Vector3(w, w, a.distance_to(z)), xf * Transform3D(Basis.looking_at(dir, up), mid), ink)


## Steel truss gantry over the line: braced twin legs on concrete footings and an open lattice beam
## (5.6 m clear underneath), so it reads as a built structure rather than a floating slab.
func _start_gantry(b: PaperKit.Builder) -> void:
	var i := track.index_at(0.0)
	var hw := track.road_half_width(0.0)
	var xf := Transform3D(Basis(Vector3.UP, track.heading_at(i)), Vector3(track.pts[i].x, track.elev[i], track.pts[i].y))
	var steel := Color("#7a8087")
	var dark := Color("#5a5f66")
	var span := hw + 1.4
	var low := 6.4
	var high := 7.4
	for side in [-1.0, 1.0]:
		var lx: float = side * span
		b.box(Vector3(lx, 0.45, 0), Vector3(1.6, 0.9, 2.2), xf, Color("#a9a49a"))      # footing
		for lz in [-0.7, 0.7]:
			b.box(Vector3(lx, 4.0, lz), Vector3(0.4, 7.4, 0.4), xf, steel)
		_beam(b, xf, Vector3(lx, 1.2, -0.7), Vector3(lx, 4.0, 0.7), 0.16, dark)         # cross braces
		_beam(b, xf, Vector3(lx, 1.2, 0.7), Vector3(lx, 4.0, -0.7), 0.16, dark)
		_beam(b, xf, Vector3(lx, 4.0, -0.7), Vector3(lx, 6.4, 0.7), 0.16, dark)
		_beam(b, xf, Vector3(lx, 4.0, 0.7), Vector3(lx, 6.4, -0.7), 0.16, dark)
	for lz in [-0.7, 0.7]:
		_beam(b, xf, Vector3(-span, high, lz), Vector3(span, high, lz), 0.3, steel)
		_beam(b, xf, Vector3(-span, low, lz), Vector3(span, low, lz), 0.3, steel)
		var n := maxi(4, int(span * 2.0 / 1.8))
		for k in n:
			var x0 := lerpf(-span, span, k / float(n))
			var x1 := lerpf(-span, span, (k + 1) / float(n))
			_beam(b, xf, Vector3(x0, low if k % 2 == 0 else high, lz), Vector3(x1, high if k % 2 == 0 else low, lz), 0.14, dark)
	for k in range(0, int(span * 2.0 / 1.8) + 1):
		var x: float = lerpf(-span, span, k / float(maxi(1, int(span * 2.0 / 1.8))))
		_beam(b, xf, Vector3(x, low, -0.7), Vector3(x, high, -0.7), 0.12, dark)
		_beam(b, xf, Vector3(x, low, 0.7), Vector3(x, high, 0.7), 0.12, dark)
		_beam(b, xf, Vector3(x, high, -0.7), Vector3(x, high, 0.7), 0.12, dark)
	# Timer board hung in the lattice, chequered.
	for k in 8:
		b.box(Vector3(-2.0 + k * 0.5, 6.9, -0.82), Vector3(0.5, 0.7, 0.06), xf, Color("#e9e9e4") if k % 2 == 0 else Color("#2b2b2e"))
	# Five lights, dark until the countdown lights them (see set_start_lights). The cars wait on the
	# -z side of the gantry, so each housing carries its lens on that face, under a small visor.
	for k in 5:
		var lx := -1.6 + k * 0.8
		var hb := PaperKit.Builder.new(31 + k)
		hb.box(Vector3.ZERO, Vector3(0.74, 0.74, 0.3), Transform3D(), Color("#26262a"))
		hb.box(Vector3(0, 0.44, -0.17), Vector3(0.74, 0.1, 0.34), Transform3D(), Color("#1a1a1d"))
		var hm := MeshInstance3D.new()
		hm.mesh = hb.mesh()
		hm.material_override = material
		hm.transform = xf * Transform3D(Basis(), Vector3(lx, 5.95, -0.2))
		add_child(hm)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.27
		cm.bottom_radius = 0.27
		cm.height = 0.06
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#3a1210")
		m.emission_enabled = true
		m.emission = Color("#ff2a1a")
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		# Cylinder axis is Y; turn it to face -z.
		mi.transform = xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(lx, 5.95, -0.2 - 0.16))
		add_child(mi)
		if LightHalo.enabled():
			var sh := LightHalo.make(Color("#ff3a24"), 2.2, 0.9)
			sh.visible = false
			add_child(sh)
			sh.global_position = xf * Vector3(lx, 5.95, -0.55)
			mi.set_meta("halo", sh)
		start_lights.append(mi)


## Light the first n of the five start lights (0 = all dark).
func set_start_lights(n: int) -> void:
	for k in start_lights.size():
		var m := start_lights[k].material_override as StandardMaterial3D
		m.emission_energy_multiplier = 3.0 if k < n else 0.0
		m.albedo_color = Color("#ff3a24") if k < n else Color("#3a1210")
		if start_lights[k].has_meta("halo"):
			(start_lights[k].get_meta("halo") as Node3D).visible = k < n


func _control_tower(b: PaperKit.Builder) -> void:
	var pt := _at(46.0, 1.0, 16.0)
	var xf := _frame(pt)
	b.box(Vector3(0, 4.0, 0), Vector3(7.0, 8.0, 6.0), xf, Color("#d4d0c6"))
	_solid_line(xf, 7.0, 3.6)
	for floor_i in 3:
		b.box(Vector3(0, 1.8 + floor_i * 2.5, -3.02), Vector3(6.2, 1.3, 0.06), xf, Color("#4f7487"), Color(-1, 0, 0), night)
		if night and LightHalo.enabled():
			var th := LightHalo.make(Color("#ffe2a0"), 5.0, 0.3)
			add_child(th)
			th.global_position = xf * Vector3(0, 1.8 + floor_i * 2.5, -3.6)
	b.box(Vector3(0, 8.3, 0), Vector3(7.8, 0.5, 6.8), xf, Color("#8a4a3a"))
	b.box(Vector3(2.8, 10.4, 2.0), Vector3(0.12, 4.0, 0.12), xf, Color("#6a6e74"))
	b.box(Vector3(2.8, 12.2, 1.0), Vector3(0.05, 0.5, 2.0), xf, Color("#e8903a"))   # wind sock


func _paddock(b: PaperKit.Builder) -> void:
	var pt := _at(-70.0, 1.0, 38.0)
	var xf := _frame(pt)
	# Hauler: cab and long trailer in team colours.
	b.box(Vector3(0, 1.9, 0), Vector3(2.5, 3.8, 14.0), xf, Color("#efe3c8"), Color("#d8ccb0"))
	_solid_line(xf, 18.0, 1.6, 2.0)
	b.box(Vector3(0, 1.5, 8.6), Vector3(2.5, 3.0, 3.0), xf, Color("#c8553d"))
	b.box(Vector3(0, 2.4, 0), Vector3(2.55, 0.5, 13.5), xf, Color("#3f6fa8"))
	# Awning tent and tyre racks.
	b.box(Vector3(9.0, 1.3, 0), Vector3(6.0, 2.6, 12.0), xf, Color("#ece6d8"))
	# Awning roof, in the paddock's own frame (it used to sit at the world origin), held up on four posts.
	var awn := [Vector3(5.5, 2.6, -6.5), Vector3(12.5, 2.6, -6.5), Vector3(12.5, 2.6, 6.5), Vector3(5.5, 2.6, 6.5)]
	b.slab(xf * awn[0], xf * awn[1], xf * awn[2], xf * awn[3], 0.1, Color("#3f6fa8"))
	for corner: Vector3 in awn:
		b.box(Vector3(corner.x, 1.3, corner.z), Vector3(0.18, 2.6, 0.18), xf, Color("#5a5f66"))
	for k in 4:
		b.box(Vector3(-4.0, 0.5 + (k % 2) * 0.9, -4.0 + k * 2.4), Vector3(1.4, 0.8, 1.6), xf, Color("#2b2b2f"))


# --- corners ---------------------------------------------------------------------------------------

func _braking_boards_and_booths(b: PaperKit.Builder) -> void:
	var booths := 0
	for c: Dictionary in track.corners:
		var i := int(c.apex)
		var turn := _turn_sign(i)
		if turn == 0.0:
			continue
		var outer := -turn
		var inner := turn
		if int(c.sev) <= 3:
			for dist in [100.0, 50.0]:
				var s: float = float(c.s0) - dist
				if s < 8.0:
					continue
				var pt := _at(s, outer, 1.6)
				var xf := _frame(pt, PI)
				b.box(Vector3(0, 0.6, 0), Vector3(0.07, 1.2, 0.07), xf, Color("#6a4a32"))
				b.box(Vector3(0, 1.25, 0), Vector3(1.0, 0.6, 0.06), xf, Color("#f2f2ee"))
				for k in int(dist / 50.0):
					b.box(Vector3(-0.28 + k * 0.28, 1.25, -0.04), Vector3(0.12, 0.42, 0.03), xf, Color("#c8553d"))
				if dist < 60.0:
					b.box(Vector3(0, 1.25, -0.04), Vector3(0.3, 0.1, 0.03), xf, Color("#2b2b2e"))
			# Apex cones on the inside kerb, each standing on the road at its own station. They can be knocked down.
			for k in 3:
				var sb: float = float(c.apex_s if c.has("apex_s") else track.dist[i]) + (k - 1) * 5.0
				var ib := track.index_at(sb)
				var lat_b := inner * (track.road_half_width(sb) - 0.5)
				var bp: Vector2 = track.pts[ib] + track.nrm[ib] * lat_b
				var by := track.road_h_i(ib) + track.bank_slope(ib) * lat_b
				_add_cone(bp, by)
		# Marshal booth with an LED flag panel at the exit of the bigger corners.
		if absf(float(c.s1) - float(c.s0)) > 14.0 and booths < 9:
			var pt := _at(float(c.s1) + 8.0, outer, 4.5)
			var xf := _frame(pt)
			b.box(Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 2.0), xf, Color("#efe3c8"))
			b.box(Vector3(0, 2.3, 0), Vector3(2.3, 0.2, 2.3), xf, Color("#c8553d"))
			b.box(Vector3(1.6, 1.6, 0), Vector3(0.1, 3.2, 0.1), xf, Color("#5a5f66"))
			b.box(Vector3(1.6, 3.3, 0), Vector3(0.1, 0.9, 1.1), xf, Color("#f2c630") if booths % 2 == 0 else Color("#3f6fa8"), Color(-1, 0, 0), true)
			if night and LightHalo.enabled():
				var bh := LightHalo.make(Color("#f2c630") if booths % 2 == 0 else Color("#6fa0e0"), 3.2, 0.5)
				add_child(bh)
				bh.global_position = xf * Vector3(1.6, 3.3, 0)
			booths += 1


func _joker_signage(b: PaperKit.Builder) -> void:
	var jk := track.joker
	var side: float = jk.side
	var yellow := Color("#f2c630")
	var black := Color("#232326")
	# Warning board 50 m before the split and a merge board 30 m before the rejoin.
	for entry in [[float(jk.s0) - 50.0, "JOKER", true], [float(jk.s1) - 30.0, "MERGE", false]]:
		var pt := _at(entry[0], -side if entry[2] else side, 1.8)
		var xf := _frame(pt, PI)
		b.box(Vector3(0, 0.9, 0), Vector3(0.08, 1.8, 0.08), xf, Color("#5a5f66"))
		b.box(Vector3(0, 1.9, 0), Vector3(1.8, 1.0, 0.08), xf, yellow)
		for k in 5:
			b.box(Vector3(-0.8 + k * 0.4, 1.9, -0.05), Vector3(0.18, 0.9, 0.03), xf, black if k % 2 == 0 else yellow)
		var label := Label3D.new()
		label.text = entry[1]
		label.font = PaperTheme.font()
		label.font_size = 56
		label.pixel_size = 0.0075
		label.modulate = Color("#232326")
		label.shaded = true
		label.double_sided = false
		label.transform = xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.9, 0.07))
		add_child(label)
	# Fluorescent gantry over the lane entrance.
	var s_g: float = float(jk.s0) + (float(jk.s1) - float(jk.s0)) * 0.2
	var band := track.joker_band(s_g)
	if not is_nan(band.x):
		var i := track.index_at(s_g)
		var mid := (band.x + band.y) * 0.5
		var base: Vector2 = track.pts[i] + track.nrm[i] * mid
		var xf := Transform3D(Basis(Vector3.UP, track.heading_at(i)), Vector3(base.x, track.elev[i], base.y))
		var w := absf(band.y - band.x) + 1.4
		for sd in [-1.0, 1.0]:
			b.box(Vector3(sd * w * 0.5, 2.6, 0), Vector3(0.3, 5.2, 0.3), xf, yellow)
		b.box(Vector3(0, 5.3, 0), Vector3(w + 0.6, 0.9, 0.5), xf, black)
		for k in int(w / 0.8):
			b.box(Vector3(-w * 0.5 + 0.4 + k * 0.8, 5.3, -0.28), Vector3(0.4, 0.8, 0.05), xf, yellow, Color(-1, 0, 0), k % 2 == 0)


# --- stands and masts ------------------------------------------------------------------------------

func _bleachers(b: PaperKit.Builder, station: float) -> void:
	var pt := _at(station, 1.0, 12.0)
	var xf := _frame(pt)
	_solid_line(xf, 10.0, 2.6, 0.0)
	for tier in 4:
		b.box(Vector3(0, 0.5 + tier * 0.55, tier * 1.0), Vector3(10.0, 0.4, 1.0), xf, Color("#b6b9bd"))
		for seat in 9:
			if (tier + seat) % 3 != 0:
				b.box(Vector3(-4.0 + seat, 0.95 + tier * 0.55, tier * 1.0), Vector3(0.45, 0.5, 0.4), xf, [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a")][(tier + seat) % 4])


func _floodlights(b: PaperKit.Builder) -> void:
	var n := 6
	for k in n:
		var s := track.length * (float(k) + 0.5) / n
		var pt := _at(s, 1.0 if k % 2 == 0 else -1.0, 14.0)
		var xf := _frame(pt)
		_solid_line(xf, 1.0, 0.9)
		for lx in [-0.5, 0.5]:
			for lz in [-0.5, 0.5]:
				b.box(Vector3(lx, 8.0, lz), Vector3(0.12, 16.0, 0.12), xf, Color("#8a8f96"))
		for h in 4:
			b.box(Vector3(0, 3.0 + h * 4.0, 0), Vector3(1.3, 0.08, 1.3), xf, Color("#8a8f96"))
		b.box(Vector3(0, 16.5, 0), Vector3(3.2, 1.0, 0.5), xf, Color("#4a4e54"))
		for h in 6:
			b.box(Vector3(-1.3 + h * 0.52, 16.5, -0.3), Vector3(0.36, 0.5, 0.1), xf, Color("#fff2c4"), Color(-1, 0, 0), night)
		if night and LightHalo.enabled():
			var fh := LightHalo.make(Color("#fff0c8"), 14.0, 0.8)
			add_child(fh)
			fh.global_position = xf * Vector3(0, 16.5, -0.6)


## Night: lamp masts along the main straight (the run into and out of the start line), each throwing a
## warm pool of light on the tarmac.
func _track_lights(b: PaperKit.Builder) -> void:
	var first_s := 90.0
	if not track.corners.is_empty():
		first_s = clampf(float(track.corners[0].s0) - 12.0, 60.0, 260.0)
	var last_s := track.length - 70.0
	if not track.corners.is_empty():
		last_s = maxf(float(track.corners[-1].s1) + 12.0, track.length - 260.0)
	var stations: Array = []
	var s := 8.0
	while s < first_s:
		stations.append(s)
		s += 34.0
	s = last_s
	while s < track.length - 6.0:
		stations.append(s)
		s += 34.0
	var pool_tex := _pool_texture()
	for k in stations.size():
		var st: float = stations[k]
		var side := 1.0 if k % 2 == 0 else -1.0
		var pt := _at(st, side, 1.4)
		var xf := _frame(pt)
		var i: int = pt.i
		# Mast, arm over the road and a lamp head.
		b.box(Vector3(0, 4.5, 0), Vector3(0.22, 9.0, 0.22), xf, Color("#6a6e75"))
		var toward := -side
		b.box(Vector3(0, 9.0, 0), Vector3(0.18, 0.18, 0.18), xf, Color("#6a6e75"))
		var head := Vector3(toward * 1.7, 9.0, 0)
		b.box(Vector3(toward * 0.85, 9.0, 0), Vector3(1.7, 0.14, 0.14), Transform3D(xf.basis, xf.origin), Color("#6a6e75"))
		b.box(head, Vector3(0.9, 0.18, 0.5), xf, Color("#fff2c4"), Color(-1, 0, 0), true)
		solids.append([pt.p, 0.4])
		if LightHalo.enabled():
			var hh := LightHalo.street(Color("#ffd9a0"), 9.0 + 0.1, 7.0, 0.85)
			add_child(hh)
			hh.global_position = xf * head + Vector3(0, -0.2, 0)
		# Pool of light on the road under the head.
		var c: Vector2 = track.pts[i]
		var pool := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(12.0, 24.0)
		pool.mesh = q
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_texture = pool_tex
		pm.albedo_color = Color(1.0, 0.82, 0.5, 1.0)
		pm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		pm.no_depth_test = false
		pool.material_override = pm
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pool)
		pool.position = Vector3(c.x, track.road_h_i(i) + 0.3, c.y)
		pool.rotation.y = atan2(track.tang[i].x, track.tang[i].y) + PI * 0.5


func _pool_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.3, 0.3, 0.3, 0.35), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# --- kit props -------------------------------------------------------------------------------------

func _containers(b: PaperKit.Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var cols := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#7a5a40")]
	for k in 9:
		var s := track.length * (0.36 + rng.randf() * 0.55)
		var pt := _at(s, 1.0 if k % 2 == 0 else -1.0, 9.0 + rng.randf() * 6.0)
		var xf := _frame(pt, rng.randf_range(-0.12, 0.12))
		var stack := 1 + rng.randi() % 3
		_solid_line(xf, 6.1 if k % 3 else 12.2, 1.4)
		for h in stack:
			b.box(Vector3(0, 1.3 + h * 2.62, 0), Vector3(2.5, 2.6, 6.1 if k % 3 else 12.2), xf, cols[(k + h) % cols.size()])
			for rib in 5:
				b.box(Vector3(1.27, 1.3 + h * 2.62, -2.4 + rib * 1.2), Vector3(0.04, 2.3, 0.12), xf, Color("#3a3a3e"))


func _monument_arch(b: PaperKit.Builder, station: float) -> void:
	var i := track.index_at(station)
	var xf := Transform3D(Basis(Vector3.UP, track.heading_at(i)), Vector3(track.pts[i].x, track.elev[i], track.pts[i].y))
	var hw := track.road_half_width(station)
	var stone := Color("#bdb8ae")
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * (hw + 2.2), 6.0, 0), Vector3(4.0, 12.0, 3.0), xf, stone, Color("#cdc8bd"))
		var cw := xf * Vector3(side * (hw + 2.2), 0, 0)
		solids.append([Vector2(cw.x, cw.z), 2.2])
	b.box(Vector3(0, 12.2, 0), Vector3(hw * 2.0 + 8.4, 3.0, 3.4), xf, stone, Color("#cdc8bd"))
	b.box(Vector3(0, 14.2, 0), Vector3(hw * 2.0 + 3.0, 1.2, 3.8), xf, Color("#a64b37"))


func _campervans(b: PaperKit.Builder) -> void:
	var cols := [Color("#efe3c8"), Color("#e8b04a"), Color("#3f6fa8")]
	for k in 4:
		var pt := _at(track.length * (0.08 + k * 0.22), 1.0 if k % 2 == 0 else -1.0, 16.0 + k * 2.0)
		var xf := _frame(pt, 0.4 * k)
		b.box(Vector3(0, 1.4, 0), Vector3(2.3, 2.8, 5.8), xf, cols[k % 3])
		_solid_line(xf, 6.4, 1.3)
		for wx in [-1.2, 1.2]:
			for wz in [-2.0, 2.0]:
				b.box(Vector3(wx, 0.45, wz), Vector3(0.3, 0.9, 0.9), xf, Color("#26262a"))
		for side_w in [-1.18, 1.18]:
			b.box(Vector3(side_w, 1.9, 0.4), Vector3(0.06, 0.7, 2.0), xf, Color("#4f7487"))
		b.box(Vector3(0, 1.1, -3.0), Vector3(2.2, 1.6, 1.2), xf, cols[k % 3].darkened(0.1))
		b.box(Vector3(0, 2.0, -3.62), Vector3(1.8, 0.7, 0.06), xf, Color("#4f7487"))
		b.box(Vector3(0, 2.9, 0), Vector3(2.0, 0.14, 4.6), xf, Color("#d8ccb0"))


func _mining_relics(b: PaperKit.Builder) -> void:
	# Piles of cut quarry blocks.
	for k in 4:
		var pt := _at(track.length * (0.15 + k * 0.2), -1.0 if k % 2 == 0 else 1.0, 14.0)
		var xf := _frame(pt, 0.7 * k)
		var blocks := [Vector3(-1.3, 0.8, 0), Vector3(1.3, 0.8, 0), Vector3(0, 2.4, 0), Vector3(-1.3, 0.8, 2.6), Vector3(1.3, 0.8, 2.6)]
		for bi in blocks.size():
			b.box(blocks[bi], Vector3(2.4, 1.6, 2.4), xf, Color("#9a6a50") if bi % 2 == 0 else Color("#8a5c44"))
		_solid_line(xf, 5.0, 2.2, 1.0)


func _drone() -> void:
	if track.corners.is_empty():
		return
	var c: Dictionary = track.corners[0]
	var ap := int(c.apex)
	var center := Vector3(track.pts[ap].x, track.elev[ap] + 20.0, track.pts[ap].y)
	var drone := Node3D.new()
	var b := PaperKit.Builder.new(9)
	b.box(Vector3.ZERO, Vector3(0.9, 0.25, 0.9), Transform3D(), Color("#2b2b2e"))
	b.box(Vector3(0, 0.0, 0.5), Vector3(0.25, 0.2, 0.2), Transform3D(), Color("#c8553d"), Color(-1, 0, 0), true)
	var body := MeshInstance3D.new()
	body.mesh = b.mesh()
	body.material_override = material
	drone.add_child(body)
	for k in 4:
		var rotor := Node3D.new()
		rotor.position = Vector3(0.55 * (1 if k % 2 == 0 else -1), 0.2, 0.55 * (1 if k < 2 else -1))
		var rb := PaperKit.Builder.new(k)
		rb.box(Vector3.ZERO, Vector3(0.7, 0.03, 0.08), Transform3D(), Color("#444"))
		var rm := MeshInstance3D.new()
		rm.mesh = rb.mesh()
		rm.material_override = material
		rotor.add_child(rm)
		drone.add_child(rotor)
		_anim.append({"node": rotor, "kind": "rotor"})
	add_child(drone)
	_anim.append({"node": drone, "kind": "orbit", "center": center, "radius": 28.0, "phase": 0.0})
