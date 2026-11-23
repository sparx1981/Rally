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
var min_h := 0.0
var max_h := 0.0


func build(track: Track, hills: float, seed_v: int, roughness := 1.0) -> void:
	var b := track.bounds().grow(210.0)
	cell = 5.0 if b.size.x * b.size.y < 1.6e6 else 7.0
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
	var hw := track.width * 0.5
	min_h = 1e9
	max_h = -1e9
	for k in total:
		var x := k % nx
		var z := k / nx
		var wx := origin.x + x * cell
		var wz := origin.y + z * cell
		var d := mind[k]
		var nv := noise.get_noise_2d(wx, wz)
		var away := smoothstep(hw + 4.0, hw + 62.0, d)
		var v := road_e[k] + nv * hills * away + absf(nv) * hills * 0.35 * away
		if d < hw + 2.5:
			v = road_e[k] - 0.1
		h[k] = v
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
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var idx := PackedInt32Array()
			var w := x1 - cx + 1
			for z in range(cz, z1 + 1):
				for x in range(cx, x1 + 1):
					var k := z * nx + x
					v.append(Vector3(origin.x + x * cell, h[k], origin.y + z * cell))
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
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(mi)
