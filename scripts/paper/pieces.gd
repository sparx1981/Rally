class_name Pieces
extends RefCounted
## The scenery kit: every prop is cut and folded card, printed as a layered collage (3-5 inks, a
## lighter lit-side layer, an ornament), built from PaperKit cards. Each returns
## {mesh, r (collision radius), solid, h (height), size (flap size 0..1)}.

const SKIN := [Color("#e8c4a0"), Color("#c99470"), Color("#8f5f42"), Color("#f0d2b4")]
## Fictional sponsors (no real brands).
const SPONSORS := [["FOLDLINE OIL", "#c8553d", "#efe3c8"], ["CARDSTOCK TYRES", "#2b2b2b", "#e8b04a"], ["CREASE COLA", "#3f6fa8", "#efe3c8"],
	["PULPWORKS", "#2f8a8a", "#efe3c8"], ["SCISSOR SPEED", "#e8b04a", "#2b2b2b"], ["ORIGAMI AIR", "#efe3c8", "#c8553d"]]
const CLOTHES := [Color("#c8553d"), Color("#3f6fa8"), Color("#e8b04a"), Color("#2f8a8a"), Color("#7a3b3b"), Color("#e2763a"), Color("#5f7f4a")]


static func make(kind: String, pal: Dictionary, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match kind:
		"pine": return pine(pal, rng, false)
		"pine_snow": return pine(pal, rng, true)
		"tree": return tree(pal, rng)
		"birch": return birch(pal, rng)
		"bush": return bush(pal, rng)
		"tuft": return tuft(pal, rng, false)
		"flowers": return tuft(pal, rng, true)
		"heather": return heather(pal, rng)
		"rock": return rock(pal, rng)
		"mesa": return mesa(pal, rng)
		"cactus": return cactus(pal, rng)
		"house": return house(pal, rng, false)
		"cabin": return house(pal, rng, true)
		"barn": return barn(pal, rng)
		"bale": return bale(pal, rng)
		"logs": return logs(pal, rng)
		"tent": return tent(pal, rng)
		"crates": return crates(pal, rng)
		"lamp": return lamp(pal, rng)
		"snowbank": return snowbank(pal, rng)
		"spectators": return spectators(pal, rng)
		"post": return marker_post(pal, rng)
		"banner": return banner(rng)
		"board": return billboard(rng)
		"warn": return warn_sign(rng)
		"km": return km_board(rng)
		"flag": return feather_flag(rng)
		"tape": return tape(pal, rng)
	return bush(pal, rng)


## A flat lobed crown lying across the top of a slotted tree, so overhead views read as foliage
## rather than an X of two cards.
static func _crown(b: PaperKit.Builder, r: float, y: float, col: Color, col2: Color, seed_v: int) -> void:
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, y, 0))
	b.card(PaperKit.blob(r, 0, 0, 6, 0.12, seed_v, 22), lay, col, {"thick": 0.05, "edge": 0.04, "lip": 0.05})
	b.card(PaperKit.blob(r * 0.6, -r * 0.15, r * 0.12, 5, 0.14, seed_v + 1, 18), lay * Transform3D(Basis(), Vector3(0, 0, 0.04)), col2, {"thick": 0.02, "edge": 0.03, "lip": 0.0})


static func _out(b: PaperKit.Builder, r: float, solid: bool, h: float, size: float) -> Dictionary:
	return {"mesh": b.mesh(), "r": r, "solid": solid, "h": h, "size": size}


static func _y(a: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)


static func _xy(a: float, z: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 0, z))


# --- trees -------------------------------------------------------------------------------------------

static func pine(pal: Dictionary, rng: RandomNumberGenerator, snow: bool) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := rng.randf_range(4.4, 7.0)
	var w := h * rng.randf_range(0.44, 0.54)
	var lean := rng.randf_range(-0.04, 0.04)
	var trunk := PaperKit.rect(w * 0.15, h * 0.3)
	var snow_c := Color("#f3f4f7")
	for k in 2:
		var a := k * PI * 0.5
		var xf := _y(a) * Transform3D(Basis(Vector3(0, 0, 1), lean), Vector3.ZERO)
		b.card(trunk, xf, pal["trunk"], {"thick": 0.08})
		for t in 3:
			var y0 := h * (0.2 + t * 0.24)
			var tw := w * (1.0 - t * 0.24)
			var th := h * (0.4 - t * 0.04)
			var tierp := PaperKit.wobble(PaperKit.tier(tw, th, y0, 4 - (t / 2), rng.randi()), tw * 0.01, rng.randi())
			b.card(tierp, xf, pal["f_dark"], {"thick": 0.07})
			# Lit-side layer: smaller, shifted up-left, one value step lighter.
			var lay := PaperKit.shift(PaperKit.scaled(tierp, 0.68, Vector2(0, y0 + th * 0.35)), Vector2(-tw * 0.06, th * 0.05))
			for side in [1.0, -1.0]:
				b.card(lay, xf * Transform3D(Basis(), Vector3(0, 0, 0.065 * side)), pal["f_mid"], {"thick": 0.03, "edge": 0.035, "lip": 0.04})
			if snow:
				var cap := PaperKit.tier(tw * 0.5, th * 0.42, y0 + th * 0.58, 3, rng.randi())
				for side in [1.0, -1.0]:
					b.card(cap, xf * Transform3D(Basis(), Vector3(0, 0, 0.1 * side)), snow_c, {"thick": 0.03, "edge": 0.03, "lip": 0.0})
			elif t == 0:
				# Ornament: a few chunky light dots (cones).
				for d in 3:
					var dot := PaperKit.circle(w * 0.045, rng.randf_range(-tw * 0.25, tw * 0.25), y0 + th * rng.randf_range(0.15, 0.4), 9)
					b.card(dot, xf * Transform3D(Basis(), Vector3(0, 0, 0.1)), pal["f_light"], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	_crown(b, w * 0.3, h * 0.62, pal["f_dark"], Color("#f3f4f7") if snow else pal["f_mid"], rng.randi())
	return _out(b, w * 0.18 + 0.3, true, h, 0.5)


static func tree(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := rng.randf_range(3.6, 5.6)
	var r := h * rng.randf_range(0.27, 0.33)
	var cy := h - r
	var trunk := PaperKit.rect(r * 0.28, cy + r * 0.2)
	var canopy := PaperKit.blob(r, 0.0, cy, 7, 0.1, rng.randi())
	var lay := PaperKit.blob(r * 0.62, -r * 0.18, cy + r * 0.2, 5, 0.12, rng.randi())
	var dot_c: Color = pal["accent"] if rng.randf() < 0.5 else pal["flower"]
	for k in 2:
		var xf := _y(k * PI * 0.5 + 0.3)
		b.card(trunk, xf, pal["trunk"], {"thick": 0.08})
		b.card(canopy, xf, pal["f_dark"], {"thick": 0.07})
		for side in [1.0, -1.0]:
			var lx := xf * Transform3D(Basis(), Vector3(0, 0, 0.065 * side))
			b.card(lay, lx, pal["f_mid"], {"thick": 0.03, "edge": 0.035})
			var hi := PaperKit.blob(r * 0.3, -r * 0.32, cy + r * 0.42, 4, 0.12, rng.randi())
			b.card(hi, lx * Transform3D(Basis(), Vector3(0, 0, 0.03 * side)), pal["f_light"], {"thick": 0.02, "edge": 0.03, "lip": 0.0})
			for d in 4:
				var a := rng.randf() * TAU
				var rr := rng.randf_range(0.3, 0.75) * r
				var dot := PaperKit.circle(r * 0.08, cos(a) * rr, cy + sin(a) * rr, 9)
				b.card(dot, lx * Transform3D(Basis(), Vector3(0, 0, 0.045 * side)), dot_c, {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	_crown(b, r * 0.8, cy + r * 0.15, pal["f_dark"], pal["f_mid"], rng.randi())
	return _out(b, r * 0.25 + 0.3, true, h, 0.5)


static func birch(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := rng.randf_range(4.2, 6.0)
	var r := h * 0.22
	var cy := h - r * 1.1
	var trunk := PaperKit.rect(r * 0.3, cy + r * 0.4)
	var canopy := PaperKit.blob(r, 0.0, cy, 6, 0.12, rng.randi(), 24, 1.35)
	for k in 2:
		var xf := _y(k * PI * 0.5 + 0.2)
		b.card(trunk, xf, pal["trunk"], {"thick": 0.08})
		for m in 4:
			var mark := PaperKit.rrect(r * 0.18, r * 0.07, 0.02, rng.randf_range(-0.04, 0.04), rng.randf_range(0.2, cy))
			for side in [1.0, -1.0]:
				b.card(mark, xf * Transform3D(Basis(), Vector3(0, 0, 0.05 * side)), Color("#3a3430"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
		b.card(canopy, xf, pal["f_mid"], {"thick": 0.07})
		var lay := PaperKit.blob(r * 0.6, -r * 0.2, cy + r * 0.3, 5, 0.12, rng.randi(), 20, 1.3)
		for side in [1.0, -1.0]:
			b.card(lay, xf * Transform3D(Basis(), Vector3(0, 0, 0.065 * side)), pal["f_light"], {"thick": 0.03})
	_crown(b, r * 0.75, cy + r * 0.2, pal["f_mid"], pal["f_light"], rng.randi())
	return _out(b, 0.45, true, h, 0.5)


static func bush(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var r := rng.randf_range(0.8, 1.3)
	var base := PaperKit.blob(r, 0.0, r * 0.55, 5, 0.14, rng.randi(), 22, 0.75)
	# Flatten everything below the fold so the bush sits on the ground.
	for i in base.size():
		base[i].y = maxf(base[i].y, 0.0)
	var lay := PaperKit.blob(r * 0.6, -r * 0.15, r * 0.7, 4, 0.14, rng.randi(), 18, 0.75)
	for k in 2:
		var xf := _y(k * PI * 0.5 + rng.randf())
		b.card(base, xf, pal["f_dark"], {"thick": 0.06})
		for side in [1.0, -1.0]:
			b.card(lay, xf * Transform3D(Basis(), Vector3(0, 0, 0.055 * side)), pal["f_mid"], {"thick": 0.03})
			for d in 3:
				var dot := PaperKit.circle(r * 0.09, rng.randf_range(-r * 0.6, r * 0.6), rng.randf_range(r * 0.3, r * 0.9), 8)
				b.card(dot, xf * Transform3D(Basis(), Vector3(0, 0, 0.085 * side)), pal["flower"], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	_crown(b, r * 0.7, r * 0.75, pal["f_dark"], pal["f_mid"], rng.randi())
	return _out(b, r * 0.6, false, r * 1.1, 0.3)


static func tuft(pal: Dictionary, rng: RandomNumberGenerator, flowers: bool) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var w := rng.randf_range(0.8, 1.4)
	var h := w * rng.randf_range(0.5, 0.7)
	var pts := PackedVector2Array([Vector2(-w * 0.5, 0)])
	var lobes := 4
	for k in lobes:
		var x0 := -w * 0.5 + w * float(k) / lobes
		var x1 := -w * 0.5 + w * float(k + 1) / lobes
		var top := h * rng.randf_range(0.7, 1.0)
		for s in 5:
			var t := float(s) / 4.0
			pts.append(Vector2(lerpf(x0, x1, t), top * (0.55 + 0.45 * sin(t * PI))))
	pts.append(Vector2(w * 0.5, 0))
	var col: Color = pal["f_mid"] if rng.randf() < 0.6 else pal["f_light"]
	for k in 2:
		var xf := _y(k * PI * 0.5 + rng.randf())
		b.card(pts, xf, col, {"thick": 0.04, "edge": 0.035, "lip": 0.04})
		if flowers:
			for d in 4:
				var x := rng.randf_range(-w * 0.4, w * 0.4)
				var fl := PaperKit.blob(0.11, x, h * rng.randf_range(0.7, 1.05), 5, 0.25, rng.randi(), 12)
				var fc: Color = pal["flower"] if d % 2 == 0 else pal["accent"]
				for side in [1.0, -1.0]:
					b.card(fl, xf * Transform3D(Basis(), Vector3(0, 0, 0.04 * side)), fc, {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	return _out(b, 0.3, false, h, 0.2)


static func heather(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var r := rng.randf_range(0.6, 1.0)
	var base := PaperKit.blob(r, 0, r * 0.4, 6, 0.16, rng.randi(), 22, 0.6)
	for i in base.size():
		base[i].y = maxf(base[i].y, 0.0)
	var top := PaperKit.blob(r * 0.7, 0, r * 0.55, 6, 0.2, rng.randi(), 20, 0.5)
	var hc: Color = pal["flower"] if rng.randf() < 0.7 else pal["accent2"]
	for k in 2:
		var xf := _y(k * PI * 0.5 + rng.randf())
		b.card(base, xf, pal["f_dark"], {"thick": 0.05})
		for side in [1.0, -1.0]:
			b.card(top, xf * Transform3D(Basis(), Vector3(0, 0, 0.05 * side)), hc, {"thick": 0.03})
	return _out(b, 0.4, false, r * 0.8, 0.25)


# --- rock -----------------------------------------------------------------------------------------

static func rock(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var s := rng.randf_range(0.9, 1.6)
	var stone: Color = pal["stone"]
	for k in 3:
		var w := s * rng.randf_range(0.9, 1.4)
		var h := s * rng.randf_range(0.7, 1.2) * (1.0 if k == 0 else 0.7)
		var p := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.42, h * 0.55),
			Vector2(w * 0.12, h), Vector2(-w * 0.28, h * 0.86), Vector2(-w * 0.5, h * 0.35)])
		var yaw := k * 1.1 + rng.randf_range(-0.2, 0.2)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(rng.randf_range(-0.3, 0.3) * s, 0, rng.randf_range(-0.3, 0.3) * s)) * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3.ZERO)
		var col := stone.darkened(0.12 * k)
		b.card(p, xf, col, {"thick": 0.08})
		var facet := PackedVector2Array([Vector2(-w * 0.36, h * 0.3), Vector2(w * 0.08, h * 0.18), Vector2(w * 0.1, h * 0.88), Vector2(-w * 0.22, h * 0.76)])
		for side in [1.0, -1.0]:
			b.card(facet, xf * Transform3D(Basis(), Vector3(0, 0, 0.06 * side)), stone.lightened(0.18), {"thick": 0.02, "edge": 0.03})
	return _out(b, s * 0.75, true, s * 1.2, 0.4)


static func mesa(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := rng.randf_range(4.5, 7.5)
	var w := h * rng.randf_range(0.8, 1.2)
	var stone: Color = pal["stone"]
	for k in 2:
		var p := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.36, h * 0.6), Vector2(w * 0.3, h),
			Vector2(-w * 0.26, h * 0.96), Vector2(-w * 0.34, h * 0.5)])
		var xf := _y(k * PI * 0.5 + 0.4)
		b.card(PaperKit.wobble(p, w * 0.01, rng.randi()), xf, stone, {"thick": 0.1})
		for band in 3:
			var y0 := h * (0.18 + band * 0.26)
			var bw := w * (0.86 - band * 0.12)
			var strip := PaperKit.rrect(bw, h * 0.07, 0.05, rng.randf_range(-0.1, 0.1) * w, y0)
			var bc := stone.lightened(0.16) if band % 2 == 0 else stone.darkened(0.14)
			for side in [1.0, -1.0]:
				b.card(strip, xf * Transform3D(Basis(), Vector3(0, 0, 0.07 * side)), bc, {"thick": 0.02, "edge": 0.03, "lip": 0.03})
	return _out(b, w * 0.4, true, h, 0.7)


static func cactus(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := rng.randf_range(2.0, 3.4)
	var tw := h * 0.2
	var body := PaperKit.rrect(tw, h, tw * 0.5, 0, 0, 4)
	var arm_y := h * rng.randf_range(0.35, 0.5)
	var arm1 := PaperKit.rrect(tw * 0.75, h * 0.38, tw * 0.37, tw * 1.05, arm_y, 3)
	var arm1b := PaperKit.rect(tw * 0.9, tw * 0.6, tw * 0.6, arm_y)
	var arm2 := PaperKit.rrect(tw * 0.7, h * 0.3, tw * 0.35, -tw * 1.0, arm_y + h * 0.1, 3)
	var arm2b := PaperKit.rect(tw * 0.9, tw * 0.55, -tw * 0.6, arm_y + h * 0.1)
	for k in 2:
		var xf := _y(k * PI * 0.5 + 0.5)
		for part in [arm1b, arm2b, arm1, arm2, body]:
			b.card(part, xf, pal["f_dark"], {"thick": 0.07})
		var stripe := PaperKit.rrect(tw * 0.35, h * 0.8, tw * 0.17, -tw * 0.12, h * 0.1)
		for side in [1.0, -1.0]:
			b.card(stripe, xf * Transform3D(Basis(), Vector3(0, 0, 0.06 * side)), pal["f_light"], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
			var fl := PaperKit.blob(tw * 0.28, 0, h + tw * 0.05, 5, 0.25, rng.randi(), 12)
			b.card(fl, xf * Transform3D(Basis(), Vector3(0, 0, 0.07 * side)), pal["flower"], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	return _out(b, tw * 0.8, true, h, 0.45)


# --- buildings ---------------------------------------------------------------------------------

static func _window(b: PaperKit.Builder, xf: Transform3D, x: float, y: float, w: float, h: float, frame: Color) -> void:
	b.card(PaperKit.rrect(w, h, 0.05, x, y), xf, frame, {"thick": 0.03, "edge": 0.03, "lip": 0.0})
	b.card(PaperKit.rect(w * 0.72, h * 0.72, x, y + h * 0.14), xf * Transform3D(Basis(), Vector3(0, 0, 0.025)), Color("#f0b85a"), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "glow": true, "sides": false})
	b.card(PaperKit.rect(w * 0.08, h * 0.72, x, y + h * 0.14), xf * Transform3D(Basis(), Vector3(0, 0, 0.035)), frame, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})


static func house(pal: Dictionary, rng: RandomNumberGenerator, cabin: bool) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var w := rng.randf_range(3.6, 4.6) * (0.8 if cabin else 1.0)
	var d := rng.randf_range(3.0, 3.8) * (0.85 if cabin else 1.0)
	var h := rng.randf_range(2.2, 2.8) * (0.85 if cabin else 1.0)
	var walls := [Color("#d98c6a"), Color("#7fa3b5"), Color("#e2c26a"), Color("#b7c99a"), Color("#efe3c8")]
	var wall: Color = pal["wood"] if cabin else (pal["wall"] if rng.randf() < 0.4 else walls[rng.randi() % walls.size()])
	var roof: Color = pal["roof"]
	var snow_roof := cabin and Color(pal["ground"]).v > 0.85
	var I := Transform3D()
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), I, wall)
	var rh := h * 0.55
	# Gable ends.
	var gable := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(0, rh)])
	for zs in [1.0, -1.0]:
		b.card(gable, Transform3D(Basis(), Vector3(0, h, d * 0.5 * zs - 0.03 * zs)), wall, {"thick": 0.06, "edge": 0.04})
	# Roof planes with overhang.
	var ov := 0.3
	var rc: Color = Color("#f3f4f7") if snow_roof else roof
	for xs in [1.0, -1.0]:
		var a := Vector3(0, h + rh + 0.05, -d * 0.5 - ov)
		var bq := Vector3(0, h + rh + 0.05, d * 0.5 + ov)
		var c := Vector3(xs * (w * 0.5 + ov), h - ov * 0.55, d * 0.5 + ov)
		var e := Vector3(xs * (w * 0.5 + ov), h - ov * 0.55, -d * 0.5 - ov)
		b.slab(a, bq, c, e, 0.09, rc)
	# Door and windows on the long sides and ends.
	var front := Transform3D(Basis(), Vector3(0, 0, d * 0.5 + 0.02))
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d * 0.5 - 0.02))
	b.card(PaperKit.rrect(w * 0.2, h * 0.62, 0.12, 0, 0), front, pal["wood"].darkened(0.2), {"thick": 0.03, "edge": 0.03})
	_window(b, front, -w * 0.3, h * 0.35, w * 0.18, h * 0.32, PaperKit.CREAM)
	_window(b, front, w * 0.3, h * 0.35, w * 0.18, h * 0.32, PaperKit.CREAM)
	_window(b, back, 0, h * 0.35, w * 0.22, h * 0.32, PaperKit.CREAM)
	for xs in [1.0, -1.0]:
		var side := Transform3D(Basis(Vector3.UP, xs * PI * 0.5), Vector3(xs * (w * 0.5 + 0.02), 0, 0))
		_window(b, side, 0, h * 0.35, d * 0.24, h * 0.32, PaperKit.CREAM)
	# Chimney.
	b.box(Vector3(w * 0.22, h + rh * 0.8, -d * 0.15), Vector3(0.45, rh * 0.9, 0.45), I, pal["stone"])
	# Doorstep flower boxes.
	for xs in [-0.3, 0.3]:
		b.card(PaperKit.blob(0.22, xs * w, h * 0.3, 4, 0.2, rng.randi(), 12, 0.7), front * Transform3D(Basis(), Vector3(0, 0, 0.05)), pal["accent"], {"thick": 0.03, "edge": 0.02, "lip": 0.0})
	var out := _out(b, maxf(w, d) * 0.55, true, h + rh, 0.7)
	out["chimney"] = Vector3(w * 0.22, h + rh * 1.28, -d * 0.15)
	return out


static func barn(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var w := rng.randf_range(5.0, 6.0)
	var d := rng.randf_range(4.0, 5.0)
	var h := 3.0
	var red: Color = pal["roof"]
	var I := Transform3D()
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), I, red)
	var rh := 1.9
	var gable := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.3, rh * 0.7), Vector2(0, rh), Vector2(-w * 0.3, rh * 0.7)])
	for zs in [1.0, -1.0]:
		b.card(gable, Transform3D(Basis(), Vector3(0, h, d * 0.5 * zs - 0.03 * zs)), red, {"thick": 0.06, "edge": 0.04})
	var rc := Color("#4a4a52")
	for xs in [1.0, -1.0]:
		b.slab(Vector3(0, h + rh + 0.05, -d * 0.5 - 0.3), Vector3(0, h + rh + 0.05, d * 0.5 + 0.3),
			Vector3(xs * w * 0.32, h + rh * 0.72, d * 0.5 + 0.3), Vector3(xs * w * 0.32, h + rh * 0.72, -d * 0.5 - 0.3), 0.09, rc)
		b.slab(Vector3(xs * w * 0.32, h + rh * 0.72, -d * 0.5 - 0.3), Vector3(xs * w * 0.32, h + rh * 0.72, d * 0.5 + 0.3),
			Vector3(xs * (w * 0.5 + 0.3), h - 0.2, d * 0.5 + 0.3), Vector3(xs * (w * 0.5 + 0.3), h - 0.2, -d * 0.5 - 0.3), 0.09, rc)
	var front := Transform3D(Basis(), Vector3(0, 0, d * 0.5 + 0.02))
	b.card(PaperKit.rect(w * 0.4, h * 0.8), front, PaperKit.CREAM, {"thick": 0.03, "edge": 0.04})
	b.card(PaperKit.rect(w * 0.34, h * 0.72, 0, h * 0.04), front * Transform3D(Basis(), Vector3(0, 0, 0.03)), red.darkened(0.15), {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	var diag := PackedVector2Array([Vector2(-w * 0.17, h * 0.04), Vector2(-w * 0.12, h * 0.04), Vector2(w * 0.17, h * 0.72), Vector2(w * 0.12, h * 0.76)])
	b.card(diag, front * Transform3D(Basis(), Vector3(0, 0, 0.05)), PaperKit.CREAM, {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	return _out(b, maxf(w, d) * 0.55, true, h + rh, 0.7)


static func bale(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var straw := Color("#e3c06a")
	var n := 1 + rng.randi() % 2
	for i in n:
		var yaw := rng.randf_range(-0.4, 0.4)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(i * 0.3, i * 0.9, i * 0.1))
		b.box(Vector3(0, 0.45, 0), Vector3(1.7, 0.9, 1.0), xf, straw, straw.lightened(0.12))
		for zs in [1.0, -1.0]:
			for k in 2:
				var band := PaperKit.rect(0.12, 0.9, -0.4 + k * 0.8, 0.0)
				b.card(band, xf * Transform3D(Basis(), Vector3(0, 0, 0.515 * zs)), straw.darkened(0.25), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
	return _out(b, 1.0, true, 0.9 * n, 0.35)


static func logs(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var L := rng.randf_range(2.2, 3.2)
	var rows := [[-0.42, 0.0, 0.42], [-0.21, 0.21], [0.0]]
	for row in rows.size():
		for x in rows[row]:
			var y := 0.24 + row * 0.42
			var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0))
			b.box(Vector3(x, y, 0), Vector3(0.4, 0.4, L), Transform3D(), pal["wood"])
			for zs in [1.0, -1.0]:
				var ring := PaperKit.circle(0.21, x, y, 10)
				var ex := Transform3D(Basis(), Vector3(0, 0, zs * (L * 0.5 + 0.02)))
				b.card(ring, ex, Color("#e6c08a"), {"thick": 0.03, "edge": 0.03, "lip": 0.0})
				b.card(PaperKit.circle(0.08, x, y, 8), ex * Transform3D(Basis(), Vector3(0, 0, zs * 0.02)), Color("#b98a5a"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return _out(b, L * 0.5, true, 1.3, 0.4)


static func tent(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var w := rng.randf_range(2.0, 2.6)
	var h := w * 0.6
	var d := w * 1.1
	var col: Color = pal["accent"] if rng.randf() < 0.5 else pal["accent2"]
	b.slab(Vector3(0, h, -d * 0.5), Vector3(0, h, d * 0.5), Vector3(w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), 0.06, col)
	b.slab(Vector3(0, h, -d * 0.5), Vector3(0, h, d * 0.5), Vector3(-w * 0.5, 0, d * 0.5), Vector3(-w * 0.5, 0, -d * 0.5), 0.06, col.darkened(0.1))
	var tri := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(0, h)])
	b.card(tri, Transform3D(Basis(), Vector3(0, 0, -d * 0.5)), col.lightened(0.15), {"thick": 0.05})
	var door := PackedVector2Array([Vector2(-w * 0.2, 0), Vector2(w * 0.2, 0), Vector2(0, h * 0.7)])
	b.card(tri, Transform3D(Basis(), Vector3(0, 0, d * 0.5)), col.lightened(0.15), {"thick": 0.05})
	b.card(door, Transform3D(Basis(), Vector3(0, 0, d * 0.5 + 0.04)), Color("#3a2a20"), {"thick": 0.02, "edge": 0.0, "lip": 0.0})
	return _out(b, w * 0.6, true, h, 0.5)


static func crates(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var wood: Color = pal["wood"].lightened(0.2)
	var spots := [Vector3(0, 0.45, 0), Vector3(1.0, 0.45, 0.1), Vector3(0.5, 1.35, 0.05)]
	var n := 2 + rng.randi() % 2
	for i in n:
		var yaw := rng.randf_range(-0.3, 0.3)
		var xf := Transform3D(Basis(Vector3.UP, yaw), spots[i])
		b.box(Vector3.ZERO, Vector3(0.9, 0.9, 0.9), xf, wood, wood.lightened(0.1))
		for zs in [1.0, -1.0]:
			var plank := PaperKit.rect(0.85, 0.12, 0, -0.06)
			b.card(plank, xf * Transform3D(Basis(), Vector3(0, 0, 0.465 * zs)), wood.darkened(0.22), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
	return _out(b, 1.0, true, 1.8, 0.35)


static func lamp(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := 3.6
	var ink := Color("#3a3430")
	var post := PaperKit.rect(0.18, h)
	for k in 2:
		var xf := _y(k * PI * 0.5)
		b.card(post, xf, ink, {"thick": 0.06})
		b.card(PaperKit.rect(0.5, 0.25, 0, 0), xf, ink, {"thick": 0.06})
	b.box(Vector3(0, h + 0.25, 0), Vector3(0.55, 0.5, 0.55), Transform3D(), Color("#ffd07a"), Color(-1, 0, 0), true)
	b.box(Vector3(0, h + 0.56, 0), Vector3(0.7, 0.12, 0.7), Transform3D(), ink)
	return _out(b, 0.35, true, h + 0.6, 0.45)


static func snowbank(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var w := rng.randf_range(1.8, 3.0)
	var base := PaperKit.blob(w * 0.5, 0, 0.0, 4, 0.12, rng.randi(), 24, 0.45)
	var p := PackedVector2Array()
	for q in base:
		p.append(Vector2(q.x, maxf(q.y, 0.0)))
	var snow := Color("#f3f4f8")
	var shade := Color("#cdd2e2")
	for k in 2:
		var xf := _y(k * PI * 0.5 + rng.randf())
		b.card(p, xf, shade, {"thick": 0.05})
		var top := PaperKit.blob(w * 0.4, -w * 0.05, w * 0.05, 4, 0.12, rng.randi(), 20, 0.4)
		for side in [1.0, -1.0]:
			b.card(top, xf * Transform3D(Basis(), Vector3(0, 0, 0.05 * side)), snow, {"thick": 0.03, "edge": 0.03})
	_crown(b, w * 0.32, w * 0.12, shade, snow, rng.randi())
	return _out(b, w * 0.3, false, w * 0.25, 0.3)


static func spectators(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var n := 3 + rng.randi() % 3
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.75 + rng.randf_range(-0.1, 0.1)
		var z := rng.randf_range(-0.3, 0.3)
		var s := rng.randf_range(0.85, 1.05)
		var cloth: Color = CLOTHES[rng.randi() % CLOTHES.size()]
		var skin: Color = SKIN[rng.randi() % SKIN.size()]
		for k in 2:
			var xf := Transform3D(Basis(Vector3.UP, k * PI * 0.5 + 0.3), Vector3(x, 0, z))
			b.card(PaperKit.rrect(0.16 * s, 0.75 * s, 0.05, -0.1 * s, 0), xf, Color("#3a3a44"), {"thick": 0.04, "edge": 0.025})
			b.card(PaperKit.rrect(0.16 * s, 0.75 * s, 0.05, 0.1 * s, 0), xf, Color("#3a3a44"), {"thick": 0.04, "edge": 0.025})
			b.card(PaperKit.rrect(0.52 * s, 0.7 * s, 0.14, 0, 0.7 * s), xf, cloth, {"thick": 0.05, "edge": 0.03})
			b.card(PaperKit.circle(0.17 * s, 0, 1.6 * s, 12), xf, skin, {"thick": 0.05, "edge": 0.03, "lip": 0.0})
			# One arm raised, cheering.
			var arm := PaperKit.rrect(0.12 * s, 0.55 * s, 0.05, 0.0, 0.0)
			var ax := xf * Transform3D(Basis(Vector3(0, 0, 1), rng.randf_range(2.4, 2.9)), Vector3(0.24 * s, 1.3 * s, 0.03))
			b.card(arm, ax, cloth.darkened(0.12), {"thick": 0.03, "edge": 0.02})
			if i == 0:
				var flag := PackedVector2Array([Vector2(0, 0), Vector2(0.55, 0.15), Vector2(0, 0.35)])
				b.card(flag, xf * Transform3D(Basis(), Vector3(0.5 * s, 1.9 * s, 0.05)), pal["accent"], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	return _out(b, n * 0.38, true, 2.0, 0.35)


# --- functional track furniture ------------------------------------------------------------------

## A label printed on a card: {text ("{TEXT}" = per-placement text), pos, yaw, size, color}.
static func _label(text: String, pos: Vector3, yaw: float, size: int, col: Color) -> Dictionary:
	return {"text": text, "pos": pos, "yaw": yaw, "size": size, "color": col}


## Sponsor A-frame banner leaning back so its print faces the sky and the camera.
static func banner(rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var sp: Array = SPONSORS[rng.randi() % SPONSORS.size()]
	var bg := Color(sp[1])
	var fg := Color(sp[2])
	var w := 5.6
	var pitch := -0.95
	var T := Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, 0.12, 0))
	b.card(PaperKit.rect(w, 1.3, 0, 0), T, bg, {"thick": 0.05, "edge": 0.05, "lip": 0.05})
	b.card(PaperKit.rect(w - 0.3, 0.07, 0, 0.18), T * Transform3D(Basis(), Vector3(0, 0, 0.03)), fg, {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
	for x in [-w * 0.42, w * 0.42]:
		var top := T * Vector3(x, 1.2, 0)
		b.slab(Vector3(x - 0.08, 0.0, top.z - 0.9), Vector3(x + 0.08, 0.0, top.z - 0.9), Vector3(x + 0.08, top.y, top.z - 0.05), Vector3(x - 0.08, top.y, top.z - 0.05), 0.04, Color("#6a4a32"))
	var out := _out(b, 0.5, false, 1.2, 0.4)
	out["labels"] = [{"text": sp[0], "pos": T * Vector3(0, 0.72, 0.035), "yaw": 0.0, "pitch": pitch, "size": 60, "color": fg}]
	out["breakable"] = true
	return out


## A big roadside billboard, tilted back on struts.
static func billboard(rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var sp: Array = SPONSORS[rng.randi() % SPONSORS.size()]
	var bg := Color(sp[1])
	var fg := Color(sp[2])
	var pitch := -0.7
	var T := Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, 0.3, 0))
	b.card(PaperKit.rrect(4.4, 2.2, 0.08, 0, 0), T, bg, {"thick": 0.06, "edge": 0.05, "lip": 0.06})
	b.card(PaperKit.rrect(4.0, 0.12, 0.04, 0, 0.55), T * Transform3D(Basis(), Vector3(0, 0, 0.035)), fg, {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
	for x in [-1.6, 1.6]:
		var top := T * Vector3(x, 2.1, 0)
		b.box(Vector3(x, top.y * 0.5, top.z - 0.1), Vector3(0.16, top.y, 0.16), Transform3D(), Color("#6a4a32"))
	var out := _out(b, 1.0, true, 2.0, 0.55)
	out["labels"] = [{"text": sp[0], "pos": T * Vector3(0, 1.4, 0.04), "yaw": 0.0, "pitch": pitch, "size": 76, "color": fg},
		{"text": "RALLY PARTNER", "pos": T * Vector3(0, 0.85, 0.04), "yaw": 0.0, "pitch": pitch, "size": 36, "color": fg}]
	out["breakable"] = true
	return out


## Warning triangle on a post with a word plate underneath ("{TEXT}": JUMP / WATER / CHICANE ...).
static func warn_sign(rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	b.card(PaperKit.rect(0.14, 1.9), Transform3D(), Color("#5a5a5a"), {"thick": 0.05, "edge": 0.0, "lip": 0.0})
	var tri := PackedVector2Array([Vector2(-0.6, 1.5), Vector2(0.6, 1.5), Vector2(0, 2.5)])
	b.card(tri, Transform3D(), Color("#c8553d"), {"thick": 0.05, "edge": 0.04, "lip": 0.04})
	b.card(PaperKit.scaled(tri, 0.68, Vector2(0, 1.82)), Transform3D(Basis(), Vector3(0, 0, 0.035)), PaperKit.CREAM, {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
	b.card(PaperKit.rect(0.08, 0.3, 0, 1.68), Transform3D(Basis(), Vector3(0, 0, 0.045)), Color("#2b2b2b"), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
	b.card(PaperKit.circle(0.05, 0, 1.6, 6), Transform3D(Basis(), Vector3(0, 0, 0.045)), Color("#2b2b2b"), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
	b.card(PaperKit.rrect(1.3, 0.42, 0.05, 0, 0.95), Transform3D(), PaperKit.CREAM, {"thick": 0.04, "edge": 0.03, "lip": 0.0})
	var out := _out(b, 0.3, true, 2.5, 0.35)
	out["labels"] = [_label("{TEXT}", Vector3(0, 1.16, 0.03), 0.0, 40, Color("#2b2b2b"))]
	out["breakable"] = true
	return out


## Distance board ("{TEXT}": 1 KM, 2 KM ...).
static func km_board(rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	b.card(PaperKit.rect(0.12, 1.2), Transform3D(), Color("#5a5a5a"), {"thick": 0.05, "edge": 0.0, "lip": 0.0})
	b.card(PaperKit.rrect(1.1, 0.7, 0.06, 0, 1.0), Transform3D(), Color("#f2f2ee"), {"thick": 0.05, "edge": 0.04, "lip": 0.0})
	b.card(PaperKit.rrect(1.0, 0.08, 0.02, 0, 1.08), Transform3D(Basis(), Vector3(0, 0, 0.03)), Color("#3f6fa8"), {"thick": 0.005, "edge": 0.0, "lip": 0.0, "sides": false})
	var out := _out(b, 0.3, true, 1.7, 0.3)
	out["labels"] = [_label("{TEXT}", Vector3(0, 1.4, 0.03), 0.0, 44, Color("#2b2b2b"))]
	out["breakable"] = true
	return out


## Sponsor feather flag on a bent pole.
static func feather_flag(rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var sp: Array = SPONSORS[rng.randi() % SPONSORS.size()]
	b.card(PaperKit.rect(0.07, 3.2), Transform3D(), Color("#3a3430"), {"thick": 0.04, "edge": 0.0, "lip": 0.0})
	var f := PackedVector2Array([Vector2(0.05, 0.6), Vector2(0.75, 0.75), Vector2(0.85, 2.4), Vector2(0.55, 3.1), Vector2(0.05, 3.15)])
	b.card(f, Transform3D(), Color(sp[1]), {"thick": 0.02, "edge": 0.03, "lip": 0.03})
	b.card(PaperKit.scaled(f, 0.55, Vector2(0.45, 1.9)), Transform3D(Basis(), Vector3(0, 0, 0.015)), Color(sp[2]), {"thick": 0.005, "edge": 0.0, "lip": 0.0})
	var out := _out(b, 0.25, false, 3.2, 0.4)
	out["breakable"] = true
	return out


## Road-edge marker post: chunky red-and-cream striped card post with a reflector dot.
static func marker_post(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	var h := 1.1
	for k in 2:
		var xf := _y(k * PI * 0.5 + 0.4)
		b.card(PaperKit.rrect(0.26, h, 0.06), xf, PaperKit.CREAM, {"thick": 0.05, "edge": 0.03, "lip": 0.0})
		for side in [1.0, -1.0]:
			b.card(PaperKit.rect(0.24, 0.2, 0, h * 0.62), xf * Transform3D(Basis(), Vector3(0, 0, 0.03 * side)), Color("#c8553d"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
			b.card(PaperKit.circle(0.06, 0, h * 0.85, 8), xf * Transform3D(Basis(), Vector3(0, 0, 0.035 * side)), Color("#e8b04a"), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
	return _out(b, 0.22, true, h, 0.25)


## Spectator tape: two stakes and a red-and-cream ribbon card between them (6 units long).
static func tape(pal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := PaperKit.Builder.new(rng.randi())
	for x in [-3.0, 0.0, 3.0]:
		for k in 2:
			b.card(PaperKit.rect(0.12, 1.0, 0, 0), Transform3D(Basis(Vector3.UP, k * PI * 0.5), Vector3(x, 0, 0)), Color("#6a4a32"), {"thick": 0.04, "edge": 0.0, "lip": 0.0})
	for i in 12:
		var x0 := -3.0 + i * 0.5
		var sag := sin(float(i % 6) / 6.0 * PI) * 0.06
		var c := Color("#c8553d") if i % 2 == 0 else PaperKit.CREAM
		b.card(PaperKit.rect(0.5, 0.14, x0 + 0.25, 0.8 - sag), Transform3D(), c, {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return _out(b, 0.3, false, 1.0, 0.3)


## Chevron board pointing the way of the bend (dir +1 = arrows point to the card's +X).
static func chevron(dir: float) -> ArrayMesh:
	var b := PaperKit.Builder.new(7)
	var red := Color("#c8553d")
	var ink := Color("#3a3430")
	for x in [-0.9, 0.9]:
		b.card(PaperKit.rect(0.16, 1.2, x, 0), Transform3D(), ink, {"thick": 0.05})
	b.card(PaperKit.rrect(2.6, 0.9, 0.08, 0, 1.0), Transform3D(), red, {"thick": 0.06})
	for side in [1.0, -1.0]:
		for k in 3:
			var cx := (-0.75 + k * 0.75) * dir
			var arrow := PackedVector2Array([Vector2(cx - 0.25 * dir, 1.15), Vector2(cx - 0.05 * dir, 1.15), Vector2(cx + 0.2 * dir, 1.45),
				Vector2(cx - 0.05 * dir, 1.75), Vector2(cx - 0.25 * dir, 1.75), Vector2(cx, 1.45)])
			b.card(arrow, Transform3D(Basis(), Vector3(0, 0, 0.045 * side)), PaperKit.CREAM, {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	return b.mesh()


## Start / finish gantry spanning the road.
static func arch(span: float, finish: bool) -> ArrayMesh:
	var b := PaperKit.Builder.new(11 if finish else 13)
	var post := Color("#3a3430")
	var banner := Color("#efe3c8")
	var h := 4.2
	for x in [-span * 0.5, span * 0.5]:
		b.box(Vector3(x, h * 0.5, 0), Vector3(0.45, h, 0.45), Transform3D(), post)
	b.card(PaperKit.rect(span + 0.8, 1.2, 0, h - 0.6), Transform3D(), banner, {"thick": 0.08})
	var n := int(span / 0.6)
	for side in [1.0, -1.0]:
		for i in n:
			for row in 2:
				if (i + row) % 2 == 0:
					var sq := PaperKit.rect(0.55, 0.5, -span * 0.5 + 0.4 + i * 0.6, h - 0.52 + row * 0.5)
					b.card(sq, Transform3D(Basis(), Vector3(0, 0, 0.05 * side)), Color("#2e2a28") if finish else Color("#c8553d"), {"thick": 0.01, "edge": 0.0, "lip": 0.0, "sides": false})
		# Bunting under the banner.
		for i in int(span / 0.9):
			var x := -span * 0.5 + 0.45 + i * 0.9
			var tri := PackedVector2Array([Vector2(x - 0.3, h - 0.62), Vector2(x + 0.3, h - 0.62), Vector2(x, h - 1.1)])
			var cols := [Color("#c8553d"), Color("#e8b04a"), Color("#3f6fa8"), Color("#2f8a8a")]
			b.card(tri, Transform3D(Basis(), Vector3(0, 0, 0.1 * side)), cols[i % 4], {"thick": 0.02, "edge": 0.02, "lip": 0.0})
	return b.mesh()


## A puddle printed on the road: stepped blue-grey tones, a cream ripple dash.
static func puddle(rng: RandomNumberGenerator) -> ArrayMesh:
	var b := PaperKit.Builder.new(rng.randi())
	var r := rng.randf_range(1.0, 2.0)
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	b.card(PaperKit.blob(r, 0, 0, 5, 0.1, rng.randi(), 20, 0.65), lay, Color("#6a7c88"), {"thick": 0.02, "edge": 0.04, "lip": 0.0})
	b.card(PaperKit.blob(r * 0.62, r * 0.1, 0.05, 4, 0.12, rng.randi(), 16, 0.6), lay * Transform3D(Basis(), Vector3(0, 0, 0.015)), Color("#7f93a0"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	b.card(PaperKit.rrect(r * 0.5, 0.08, 0.04, -r * 0.2, -0.1), lay * Transform3D(Basis(), Vector3(0, 0, 0.025)), Color("#d8dde0"), {"thick": 0.01, "edge": 0.0, "lip": 0.0})
	return b.mesh()


## Paper bird: two wing cards on a body (wings flap about the body hinge).
static func bird_body() -> ArrayMesh:
	var b := PaperKit.Builder.new(3)
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	b.card(PaperKit.rrect(0.22, 0.8, 0.1, 0, -0.4), lay, Color("#3a3430"), {"thick": 0.04, "edge": 0.02})
	return b.mesh()


static func bird_wing() -> ArrayMesh:
	var b := PaperKit.Builder.new(5)
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	var w := PackedVector2Array([Vector2(0, 0.2), Vector2(0.9, -0.05), Vector2(0.75, -0.2), Vector2(0, -0.2)])
	b.card(w, lay, Color("#efe3c8"), {"thick": 0.02, "edge": 0.025})
	return b.mesh()
