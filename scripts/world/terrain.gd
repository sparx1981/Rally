class_name Terrain
extends RefCounted
## The landscape around the stage as a heightfield. Near the road the ground meets the road's own
## altitude (so climbs and descents carry the land with them); further out it rises into hills and
## ridges or drops away into valleys, by the location's hill amplitude. Drawn as a printed paper
## sheet with stacked contour layers (see ground.gdshader).

var origin := Vector2.ZERO
var cell := 5.0
var nx := 0
var nz := 0
var h := PackedFloat32Array()
var far := PackedByteArray()   # 1 = more than 300 m from any road (not meshed)
var min_h := 0.0
var max_h := 0.0
var sea_y := -INF                 # coastal stages: the sea surface; land outside the road's reach drops into it
var sea := PackedByteArray()      # 1 = open sea
var _mind := PackedFloat32Array() # distance from each cell to the road


## Coast: everything connected to the map edge that is more than `edge` metres from the road (with a
## ragged noise line) becomes sea. Land drops to it in a cliff, or slopes to a beach when `beach`.
func make_coast(track: Track, sea_level: float, edge: float, beach: bool, seed_v: int) -> void:
	sea_y = sea_level
	var total := nx * nz
	sea.resize(total)
	sea.fill(0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.0 / 90.0
	var cand := PackedByteArray()
	cand.resize(total)
	for k in total:
		var x := k % nx
		var z := k / nx
		var wx := origin.x + x * cell
		var wz := origin.y + z * cell
		var lim := track.width * 0.5 + edge + noise.get_noise_2d(wx, wz) * edge * 0.45
		cand[k] = 1 if _mind[k] > lim else 0
	# Flood from the map border through candidate cells.
	var queue := PackedInt32Array()
	for x in nx:
		for z in [0, nz - 1]:
			var k: int = z * nx + x
			if cand[k] == 1 and sea[k] == 0:
				sea[k] = 1
				queue.append(k)
	for z in nz:
		for x in [0, nx - 1]:
			var k: int = z * nx + x
			if cand[k] == 1 and sea[k] == 0:
				sea[k] = 1
				queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		var x := k % nx
		for nb in [k - 1, k + 1, k - nx, k + nx]:
			if nb < 0 or nb >= total:
				continue
			if (nb == k - 1 and x == 0) or (nb == k + 1 and x == nx - 1):
				continue
			if cand[nb] == 1 and sea[nb] == 0:
				sea[nb] = 1
				queue.append(nb)
	# Distance (in cells) from the sea, for the beach slope.
	var ds := PackedInt32Array()
	ds.resize(total)
	ds.fill(999)
	queue = PackedInt32Array()
	for k in total:
		if sea[k] == 1:
			ds[k] = 0
			queue.append(k)
	head = 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		if ds[k] >= 6:
			continue
		var x := k % nx
		for nb in [k - 1, k + 1, k - nx, k + nx]:
			if nb < 0 or nb >= total:
				continue
			if (nb == k - 1 and x == 0) or (nb == k + 1 and x == nx - 1):
				continue
			if ds[nb] > ds[k] + 1:
				ds[nb] = ds[k] + 1
				queue.append(nb)
	min_h = 1e9
	for k in total:
		if sea[k] == 1:
			h[k] = sea_y - 3.0 - minf(ds[k], 3) * 0.0
			far[k] = 0 if _mind[k] < track.width * 0.5 + 420.0 else 1
		elif beach and ds[k] <= 4:
			# Sand and grass ease down to the waterline (never above the land around them).
			var t := float(ds[k]) / 5.0
			h[k] = minf(h[k], lerpf(sea_y + 0.4, h[k], t * t))
		elif ds[k] == 1:
			# Cliff lip: a little raised ragged edge before the drop.
			h[k] = maxf(h[k] - 0.6, sea_y + 2.0)
		min_h = minf(min_h, h[k])


func is_sea(p: Vector2) -> bool:
	if sea.is_empty():
		return false
	var x := clampi(int(round((p.x - origin.x) / cell)), 0, nx - 1)
	var z := clampi(int(round((p.y - origin.y) / cell)), 0, nz - 1)
	return sea[z * nx + x] == 1


func build(track: Track, hills: float, seed_v: int, roughness := 1.0, bank_height := 0.0, drainage := false) -> void:
	var b := track.bounds().grow(210.0)
	# Keep the grid under ~240k cells whatever the stage size.
	cell = maxf(5.0, sqrt(b.size.x * b.size.y / 240000.0))
	origin = b.position
	nx = int(ceil(b.size.x / cell)) + 1
	nz = int(ceil(b.size.y / cell)) + 1
	var total := nx * nz
	var road_e := PackedFloat32Array()
	road_e.resize(total)
	var mind := PackedFloat32Array()
	mind.resize(total)
	mind.fill(1e9)
	var filled := PackedByteArray()
	filled.resize(total)
	var wsum := PackedFloat32Array()
	wsum.resize(total)
	var near_e := PackedFloat32Array()
	near_e.resize(total)
	# 1. Splat the road altitude into the cells near the road.
	var R := 46.0
	var r_cells := int(ceil(R / cell))
	var n := track.pts.size()
	for i in range(0, n, 2):
		var p := track.pts[i]
		var e := track.elev[i]
		var cx := int((p.x - origin.x) / cell)
		var cz := int((p.y - origin.y) / cell)
		for dz in range(-r_cells, r_cells + 1):
			var z := cz + dz
			if z < 0 or z >= nz:
				continue
			for dx in range(-r_cells, r_cells + 1):
				var x := cx + dx
				if x < 0 or x >= nx:
					continue
				var k := z * nx + x
				var d := Vector2(origin.x + x * cell - p.x, origin.y + z * cell - p.y).length()
				# Inverse-distance blend of nearby road altitudes (smooth slopes between switchbacks),
				# with the closest stretch of road dominating near the edge.
				var wgt := 1.0 / (d * d * d + 4.0)
				wsum[k] += wgt
				road_e[k] += e * wgt
				if d < mind[k]:
					mind[k] = d
					near_e[k] = e
				filled[k] = 1
	for k in total:
		if filled[k] == 1:
			var blended := road_e[k] / wsum[k]
			# Right beside the road the ground must meet this road exactly.
			road_e[k] = lerpf(near_e[k], blended, smoothstep(track.width * 0.5 + 1.0, track.width * 0.5 + 14.0, mind[k]))
	# 2. Flood the rest of the map from the nearest road (breadth-first).
	var queue := PackedInt32Array()
	for k in total:
		if filled[k] == 1:
			queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		var x := k % nx
		var z := k / nx
		for nb in [k - 1, k + 1, k - nx, k + nx]:
			if nb < 0 or nb >= total:
				continue
			if (nb == k - 1 and x == 0) or (nb == k + 1 and x == nx - 1):
				continue
			if filled[nb] == 0:
				filled[nb] = 1
				road_e[nb] = road_e[k]
				mind[nb] = mind[k] + cell
				queue.append(nb)
	# 3. Hills and valleys away from the road.
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / 170.0
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.45 * roughness
	h.resize(total)
	far.resize(total)
	_mind.resize(total)
	var hw := track.width * 0.5
	min_h = 1e9
	max_h = -1e9
	for k in total:
		var x := k % nx
		var z := k / nx
		var wx := origin.x + x * cell
		var wz := origin.y + z * cell
		var d := mind[k]
		_mind[k] = d
		var nv := noise.get_noise_2d(wx, wz)
		var away := smoothstep(hw + 4.0, hw + 62.0, d)
		var v := road_e[k] + nv * hills * away + absf(nv) * hills * 0.35 * away
		# Hillside cuttings rise outside the verge. A broad noise mask leaves
		# flat stretches between banks and avoids a continuous roadside berm.
		if (bank_height > 0.0 or drainage) and d < hw + 36.0:
			var edge := d - hw
			var sector := smoothstep(-0.20, 0.25, noise.get_noise_2d(wx * 2.2 + 907.0, wz * 2.2 - 671.0))
			var shoulder := smoothstep(3.8, 13.0, edge) * (1.0 - smoothstep(17.0, 35.0, edge))
			v += bank_height * sector * shoulder
			if drainage:
				var hollow := smoothstep(2.8, 5.8, edge) * (1.0 - smoothstep(6.2, 11.0, edge))
				v -= (0.55 + sector * 0.35) * hollow * smoothstep(-0.15, 0.24, noise.get_noise_2d(wx * 2.0 - 630.0, wz * 2.0))
		if d < hw + 2.5:
			v = road_e[k] - 0.1
		h[k] = v
		far[k] = 1 if d > hw + 300.0 else 0
		min_h = minf(min_h, v)
		max_h = maxf(max_h, v)


func height(p: Vector2) -> float:
	var fx := clampf((p.x - origin.x) / cell, 0.0, nx - 1.001)
	var fz := clampf((p.y - origin.y) / cell, 0.0, nz - 1.001)
	var x := int(fx)
	var z := int(fz)
	var tx := fx - x
	var tz := fz - z
	var k := z * nx + x
	var a := lerpf(h[k], h[k + 1], tx)
	var b := lerpf(h[k + nx], h[k + nx + 1], tx)
	return lerpf(a, b, tz)


## Chunked meshes (each with its own visibility range).
func build_meshes(parent: Node3D, mat: Material, chunk := 28) -> void:
	for cz in range(0, nz - 1, chunk):
		for cx in range(0, nx - 1, chunk):
			var x1 := mini(cx + chunk, nx - 1)
			var z1 := mini(cz + chunk, nz - 1)
			var needed := false
			for z in range(cz, z1 + 1, 4):
				for x in range(cx, x1 + 1, 4):
					if far[z * nx + x] == 0:
						needed = true
						break
				if needed:
					break
			if not needed:
				continue
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var idx := PackedInt32Array()
			var w := x1 - cx + 1
			# Vertices relative to the chunk centre: visibility ranges measure to the node origin.
			var cen := Vector3(origin.x + (cx + x1) * 0.5 * cell, 0.0, origin.y + (cz + z1) * 0.5 * cell)
			for z in range(cz, z1 + 1):
				for x in range(cx, x1 + 1):
					var k := z * nx + x
					v.append(Vector3(origin.x + x * cell, h[k], origin.y + z * cell) - cen)
					var hl := h[z * nx + maxi(x - 1, 0)]
					var hr := h[z * nx + mini(x + 1, nx - 1)]
					var hd := h[maxi(z - 1, 0) * nx + x]
					var hu := h[mini(z + 1, nz - 1) * nx + x]
					nn.append(Vector3(hl - hr, 2.0 * cell, hd - hu).normalized())
			for z in range(z1 - cz):
				for x in range(x1 - cx):
					var a := z * w + x
					# Clockwise front faces (Godot), viewed from above.
					idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.position = cen
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.visibility_range_end = 700.0
			parent.add_child(mi)


## Level the ground in a disc (the parc fermé lot), blending out over the rim.
func flatten_disc(c: Vector2, r: float, height: float, blend := 15.0) -> void:
	var r2 := r + blend
	var x0 := maxi(0, int((c.x - r2 - origin.x) / cell))
	var x1 := mini(nx - 1, int((c.x + r2 - origin.x) / cell) + 1)
	var z0 := maxi(0, int((c.y - r2 - origin.y) / cell))
	var z1 := mini(nz - 1, int((c.y + r2 - origin.y) / cell) + 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(origin.x + x * cell, origin.y + z * cell)
			var w := 1.0 - smoothstep(r, r2, p.distance_to(c))
			var k := z * nx + x
			h[k] = lerpf(h[k], height, w)
			if w > 0.0:
				far[k] = 0


## Cut a river channel along segment a-b: water surface at water_y, a gravel bed below it and
## grassy banks easing back into the land.
func carve_river(a: Vector2, b: Vector2, water_y: float, half := 5.5, depth := 1.65, taper_ends := false, bank_width := 10.5) -> void:
	var bank := half + bank_width
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (bank + cell)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (bank + cell)
	var x0 := maxi(0, int((lo.x - origin.x) / cell))
	var x1 := mini(nx - 1, int((hi.x - origin.x) / cell) + 1)
	var z0 := maxi(0, int((lo.y - origin.y) / cell))
	var z1 := mini(nz - 1, int((hi.y - origin.y) / cell) + 1)
	var bed := water_y - depth
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(origin.x + x * cell, origin.y + z * cell)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if d > bank:
				continue
			var k := z * nx + x
			var cut := 1.0 - smoothstep(half, bank, d)
			if taper_ends:
				var axis := a.direction_to(b)
				var to_end := minf((p - a).dot(axis), (b - p).dot(axis))
				cut *= smoothstep(0, 7, to_end)
			var target := lerpf(h[k], bed, cut)
			h[k] = minf(h[k], target)
			far[k] = 0
			min_h = minf(min_h, h[k])
