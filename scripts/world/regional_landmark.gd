class_name RegionalLandmark
extends MeshInstance3D
## One recognisable, terrain-fitted roadside scene per route in selected regions.
const REGIONS := ["harbour", "alpine", "pinewood", "lakes", "moor", "canyon", "autumn", "meadow", "taiga", "cliffs", "gorge"]
const TIMBER := Color("#8c6849")
const STEEL := Color("#50595b")
const RUBBER := Color("#353537")

var track: Track
var station := 0.0
var obstacles: Array[Vector3] = [] # world X, world Z and collision radius
var _origin := Vector2.ZERO
var _out := Vector2.RIGHT
var _approach := Vector2.ZERO
var _departure := Vector2.ZERO
var _base := 0.0
var _builder := PaperKit.Builder.new(41)


func build(region: String, course: Track, mat: Material) -> bool:
	track = course
	var best := -INF
	# Score both verges. Prefer sea access, the uphill side of a tight bend, or level working ground.
	for i in range(track.index_at(170), track.index_at(track.finish_s - 150), 11):
		var s := track.dist[i]
		for side: float in [-1, 1]:
			var axis := track.nrm[i] * side
			var p := track.pts[i] + axis * (track.width * 0.5 + 16.0)
			if track.clearance(p) < track.width * 0.5 + 12.0 or track.overlaps_water(p, 11) or track.terrain.is_sea(p):
				continue
			var y := track.terrain.height(p)
			var slope := track.terrain.height(p + axis * 7) - track.terrain.height(p - axis * 7)
			var score := -absf(slope) - absf(s / track.finish_s - 0.3)
			if region == "harbour":
				if not track.terrain.is_sea(p + axis * 20) or track.terrain.is_sea(p - axis * 4):
					continue
				score -= absf(y - track.terrain.sea_y - 1.8)
				score -= 32.0 * absf(track.chapter_progress(s) - 0.16)
			elif region in ["alpine", "canyon"]:
				score = minf(slope, 6.0) + 8.0 * (1.0 - track.tang[i-9].dot(track.tang[i+9]))
			if region == "alpine":
				score -= 21.0 * absf(track.chapter_progress(s) - 0.53)
			if region == "autumn":
				score -= 22.0 * absf(track.chapter_progress(s) - 0.17)
			if region == "cliffs":
				if not track.terrain.supports_prop(p,5.0):
					continue
				var sea_view := track.terrain.is_sea(p+axis*32) or track.terrain.is_sea(p+axis*55)
				score += 15.0 if sea_view else 0.0
			if region == "gorge":
				score += minf(slope,5.0)
			var eye := track.point_at(s-34)
			var ahead := (p-eye).normalized().dot(track.tang[track.index_at(s-34)])
			score += 2.0*ahead
			if score > best:
				best = score
				_origin = p
				_out = axis
				station = s
	if best == -INF:
		return false
	_approach = track.point_at(station-34.0)
	_departure = track.point_at(station+18.0)
	_base = track.terrain.height(_origin)
	position = Vector3(_origin.x, _base, _origin.y)
	rotation.y = atan2(-_out.y, _out.x)
	match region:
		"harbour": _boatyard()
		"alpine": _snow_fences()
		"pinewood": _loading_bay()
		"lakes": _ice_camp()
		"moor": _sheepfold()
		"canyon": _quarry()
		"autumn": _press_house()
	match region:
		"meadow": _dairy_field()
		"canyon": _quarry_entrance()
		"autumn": _harvest_rows()
		"moor": _peat_shelter()
		"pinewood": _forestry()
		"harbour": _fish_market()
		"lakes": _lake_launch()
		"taiga": _sauna()
		"cliffs": _lookout()
		"gorge": _catch_fence()
	if region in ["gorge","canyon"]:
		# The quarry haul track winds behind the site and crosses a fan of pale scree.
		for k in 20:
			var z := -18.0+k*1.8
			var a := _foot(12+sin(z*0.14)*3,z)+Vector3.UP*0.12
			var b := _foot(12+sin((z+1.8)*0.14)*3,z+1.8)+Vector3.UP*0.12
			_beam(a,b,2.4,0.10,Color("#ab9683"))
			if k<9:
				for j in 3:
					var q := _foot(8+k*0.45,z+j*0.53)
					_disc(q+Vector3.UP*0.10,Vector3.UP,0.32+j*0.20,0.18,Color("#baaa96"))
	if region in ["moor","pinewood"]:
		for side: float in [-1,1]:
			for k in 7:
				var z := -8.0+k
				_beam(_foot(-3+side*0.75,z)+Vector3.UP*0.07,_foot(-3+side*0.75,z+1)+Vector3.UP*0.07,0.23,0.07,Color("#605447"))
	if region in ["alpine","lakes"]:
		for k in 9:
			var z := -8.0+k*2.0
			var drift := _foot(6+0.5*sin(k),z)
			_disc(drift+Vector3.UP*0.14,Vector3.UP,1.1+(k%3)*0.35,0.32,Color("#dfebed"))
			_beam(_foot(4,z)+Vector3.UP*0.06,_foot(3,z+1.4)+Vector3.UP*0.06,0.36,0.05,Color("#aabfc9"))
	mesh = _builder.mesh()
	material_override = mat
	visibility_range_end = 200.0
	_builder = null
	return true


func blocks_view(p: Vector2, radius: float) -> bool:
	if p.distance_squared_to(_origin)>pow(60.0+radius,2):
		return false
	for eye: Vector2 in [_approach,_departure]:
		var near := Geometry2D.get_closest_point_to_segment(p,eye,_origin)
		if near.distance_squared_to(p)<pow(radius+1.15,2):
			return true
	return false


func overlaps(p: Vector2, radius: float) -> bool:
	var offset := p - _origin
	var bounds := mesh.get_aabb()
	var local := Vector2(offset.dot(_out), offset.dot(Vector2(-_out.y, _out.x)))
	return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(radius).has_point(local)


func _world(x: float, z: float) -> Vector2:
	return _origin + _out * x + Vector2(-_out.y, _out.x) * z


func _foot(x: float, z: float) -> Vector3:
	return Vector3(x, track.terrain.height(_world(x, z)) - _base, z)


func _solid(x: float, z: float, radius: float) -> void:
	var p := _world(x, z)
	obstacles.append(Vector3(p.x, p.y, radius))


func _beam(a: Vector3, b: Vector3, width: float, thickness: float, color: Color) -> void:
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.BACK
	_builder.box(Vector3.ZERO, Vector3(width, thickness, d.length()), Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5), color)


func _boatyard() -> void:
	var end := 12.0
	while end < 26 and not track.terrain.is_sea(_world(end, 0)):
		end += 1.0
	var toe := Vector3(end, track.terrain.sea_y - _base - 0.25, 0)
	var head := _foot(-3, 0) + Vector3.UP * 0.12
	_builder.slab(head + Vector3.FORWARD*2.2, head + Vector3.BACK*2.2, toe + Vector3.BACK*2.2, toe + Vector3.FORWARD*2.2, 0.18, Color("#a99d87"))
	for side: float in [-1, 1]:
		var rail := Vector3(0, 0.10, side * 1.15)
		_beam(head + rail, toe + rail, 0.11, 0.12, STEEL)
	var stand := _foot(-3, 4)
	for z: float in [-2, 2]:
		for x: float in [-1, 1]:
			_beam(stand + Vector3(1.4*x,0,z), stand + Vector3(0.65*x,1.15,z), 0.19, 0.19, TIMBER)
	_builder.prism(PackedVector2Array([Vector2(-3,1.65),Vector2(-2.5,0.82),Vector2(2.0,0.82),Vector2(3.4,1.95)]), -0.84, 0.84, Transform3D(Basis(), stand), Color("#477b78"))
	_solid(-3, 4, 1.9)
	for k in 5:
		var pot := _foot(-2 + k % 3 * 1.1, -3.8) + Vector3.UP * (0.28 + floori(k / 3.0)*0.58)
		_builder.box(pot, Vector3(0.97,0.54,0.7), Transform3D(), Color("#565247"))
		for hoop in 4:
			_builder.box(pot + Vector3((hoop-1.5)*0.24,0,0),Vector3(0.035,0.57,0.73),Transform3D(),TIMBER)


func _snow_fences() -> void:
	for row in 2:
		var x := float(row * 5)
		for span in 4:
			var a := _foot(x, -8 + span*4)
			var b := _foot(x, -4 + span*4)
			for z in ([a,b] if span == 3 else [a]):
				_beam(z, z + Vector3(0.4,2.2,0), 0.16,0.16,TIMBER)
				_beam(z + Vector3(1.4,0,0), z + Vector3(0.4,1.8,0), 0.12,0.12,TIMBER)
			for slat in 5:
				var lift := Vector3(0.065*slat,0.36+0.34*slat,0)
				_beam(a+lift,b+lift,0.13,0.20,Color("#936e51"))
		for z: float in [-7,0,7]:
			_solid(x, z, 1.0)
	for z: float in [-18,-12,-6,0,6]:
		var p := _foot(-11,z)
		for band in 5:
			_builder.box(p + Vector3.UP*(0.2+band*0.4),Vector3(0.085,0.4,0.085),Transform3D(),Color("#ce5f41") if band%2 else PaperKit.CREAM)


func _loading_bay() -> void:
	# A compact gravel landing beneath the loader and its bunk.
	track.terrain.flatten_disc(_origin, 4.8, _base, 4.0)
	var pad := Transform3D(Basis(Vector3.RIGHT,-PI/2), Vector3.UP*0.045)
	_builder.card(PaperKit.rrect(7.2,9.6,0.9,0,-4.8),pad,Color("#ac987a"),{"thick":0.035,"lip":0.0})
	var p := _foot(0,0)
	var xf := Transform3D(Basis(),p)
	var paint := Color("#ba9139")
	_builder.box(Vector3(0,1.05,0),Vector3(2.15,0.52,5.5),xf,paint)
	_builder.box(Vector3(0,2.13,1.35),Vector3(1.65,1.6,1.65),xf,Color("#516b70"))
	_builder.box(Vector3(0,1.70,1.35),Vector3(1.74,0.39,1.70),xf,paint)
	_builder.box(Vector3(0,2.40,2.19),Vector3(1.32,0.62,0.035),xf,Color("#94aeb1"))
	for side: float in [-1,1]:
		_builder.box(Vector3(side*0.83,2.37,1.36),Vector3(0.045,0.64,1.26),xf,Color("#82969a"))
		_builder.box(Vector3(side*0.72,1.48,2.35),Vector3(0.23,0.13,0.12),xf,PaperKit.CREAM)
		for bunk in [-2.62,-0.48]:
			_builder.box(Vector3(side*0.92,1.88,bunk),Vector3(0.08,1.35,0.12),xf,STEEL)
	_builder.box(Vector3(0,3.0,1.35),Vector3(1.93,0.19,1.9),xf,paint)
	for z: float in [-2.15,-1.1,1.1,2.15]:
		for x: float in [-1.08,1.08]:
			var axle := xf * Transform3D(Basis(Vector3.UP, signf(x)*PI/2),Vector3(x,0.66,z))
			_builder.card(PaperKit.circle(0.68,0,0,12),axle,RUBBER,{"thick":0.37,"lip":0.0})
			_builder.card(PaperKit.circle(0.31,0,0,10),axle.translated_local(Vector3.BACK*0.20),paint,{"thick":0.035})
	var elbow := p + Vector3(0.45,4.1,-0.6)
	_beam(p+Vector3(0,1.4,0),elbow,0.24,0.29,STEEL)
	_beam(elbow,p+Vector3(1.35,2.15,-2.0),0.22,0.22,paint)
	for k in 5:
		var x := float(k%3-1)*0.58
		var stack := xf * Transform3D(Basis(),Vector3(x,1.57+floori(k/3.0)*0.52,-1.55))
		_builder.card(PaperKit.circle(0.27,0,0,9),stack,TIMBER,{"thick":2.7,"lip":0.0})
	_solid(0,1.2,1.45)
	_solid(0,-1.5,1.45)
	for k in 5:
		var stump := _foot(3.1+sin(k*3)*1.5,-5+k*2)
		_builder.card(PaperKit.circle(0.38,0,0,9),Transform3D(Basis(Vector3.RIGHT,-PI/2),stump+Vector3.UP*0.18),TIMBER,{"thick":0.52})


func _ice_camp() -> void:
	# An irregular frozen pond and paired runner grooves conform to the snow sheet.
	track.terrain.flatten_disc(_origin, 9.2, _base, 4.0)
	var ice := PaperKit.lin(Color("#deedef"))
	var rim := PaperKit.lin(Color("#eef4ed"))
	for k in 32:
		var a := k * TAU / 32.0
		var b := (k+1) * TAU / 32.0
		var shore_a := 1.0 + 0.07*sin(3*a) + 0.09*cos(5*a)
		var shore_b := 1.0 + 0.07*sin(3*b) + 0.09*cos(5*b)
		var pa := Vector3(cos(a)*9,0,sin(a)*7) * shore_a
		var pb := Vector3(cos(b)*9,0,sin(b)*7) * shore_b
		var lift := Vector3.UP * 0.065
		_builder.tri3(lift, pa*0.80+lift, pb*0.80+lift, Vector3.UP,ice,ice,ice)
		_builder.quad4(pa*0.80+lift,pa+lift,pb+lift,pb*0.80+lift,Vector3.UP,ice,rim,rim,ice)
	for k in 2:
		var x := -2.4 + k*5.0
		var z := -1.0 + k*3.7
		var xf := Transform3D(Basis(Vector3.UP,k*0.32),_foot(x,z))
		_builder.box(Vector3(0,1.15,0),Vector3(2.1,2.15,2.6),xf,Color("#a75f4d") if k==0 else Color("#718b86"))
		_builder.prism(PackedVector2Array([Vector2(-1.55,2.20),Vector2(1.55,2.20),Vector2(0,2.92)]),-1.22,1.22,xf,PaperKit.CREAM)
		_builder.box(Vector3(-1.065,1.30,0.3),Vector3(0.03,0.58,0.70),xf,Color("#536a75"))
		_builder.box(Vector3(0.67,2.75,0.2),Vector3(0.15,0.85,0.16),xf,STEEL)
		_solid(x,z,1.25)
	for side: float in [-0.29,0.29]:
		for i in 12:
			var z := -6.0+i*0.8
			var a := _foot(-5+sin(z*0.23)+side,z)+Vector3.UP*0.085
			var b := _foot(-5+sin((z+0.8)*0.23)+side,z+0.8)+Vector3.UP*0.085
			_beam(a,b,0.065,0.02,Color("#829da8"))


func _sheepfold() -> void:
	var stone := Color("#888574")
	for row in 3:
		for k in 28:
			var a := TAU*(k+row%2*0.5)/28
			if absf(wrapf(a-PI,-PI,PI)) < 0.32:
				continue
			var x := cos(a)*4
			var z := sin(a)*4
			var xf := Transform3D(Basis(Vector3.UP,-a),_foot(x,z)+Vector3.UP*(0.18+row*0.32))
			_builder.box(Vector3.ZERO,Vector3(0.58,0.34,0.93),xf,stone.lightened(0.04*(k%4)))
			if row==0 and k%2==0:
				_solid(x,z,0.57)
	var drain := _foot(-9,0)
	track.terrain.carve_river(_world(-9,-6),_world(-9,6),_base+drain.y-0.26,0.8,0.35,true,3.0)
	for bed in 12:
		var z := float(bed-6)
		var p := _foot(-9+0.18*sin(z*0.8),z)
		var q := _foot(-9+0.18*sin((z+1)*0.8),z+1)
		_beam(p+Vector3.UP*0.045,q+Vector3.UP*0.045,0.44*sin((bed+0.5)*PI/12),0.035,Color("#706653"))
	var a := _foot(-12,0)+Vector3.UP*0.20
	var b := _foot(-5,0)+Vector3.UP*0.20
	for side: float in [-0.75,0.75]:
		var edge := Vector3.BACK*side
		_beam(a+edge,b+edge,0.15,0.18,TIMBER)
		_beam(a+edge+Vector3.UP,b+edge+Vector3.UP,0.08,0.10,TIMBER)
		for end in [a,b]:
			_beam(end+edge,end+edge+Vector3.UP,0.10,0.10,TIMBER)
	for plank in 18:
		var at := a.lerp(b,(plank+0.5)/18.0)
		_builder.box(at+Vector3.UP*0.09,Vector3(0.39,0.09,1.65),Transform3D(),TIMBER.lightened(0.03*(plank%3)))


func _quarry() -> void:
	# Split sandstone faces step back from the working floor on the uphill verge.
	for tier in 3:
		for block in 6:
			var x := 2.0+tier*1.65+0.35*sin(block*2.1)
			var z := (block-2.5)*2.5
			var base := _foot(x,z)
			var h := 1.5+tier*0.9
			_builder.box(base+Vector3.UP*(h*0.5-0.2),Vector3(2.0,h,2.58),Transform3D(),Color("#ae7959").lightened(0.035*((block+tier)%3)))
			_builder.box(base+Vector3.UP*(h-0.2),Vector3(2.1,0.24,2.62),Transform3D(),Color("#d7ad80"))
			if tier == 0:
				_solid(x,z,1.25)
	var a := _foot(-4,-4)+Vector3.UP*0.72
	var z := _foot(-1.6,3)+Vector3.UP*2.65
	_beam(a,z,1.1,0.22,STEEL)
	for i in 5:
		var at := a.lerp(z,i/4.0)
		for side: float in [-0.57,0.57]:
			var foot := _foot(at.x+side,at.z)
			_beam(foot,at+Vector3.RIGHT*side,0.13,0.13,TIMBER)
		_solid(at.x,at.z,0.65)


func _press_house() -> void:
	track.terrain.flatten_disc(_origin,5.8,_base,3.0)
	var plaster := Color("#d5bc97")
	var tile := Color("#9f5946")
	var xf := Transform3D()
	_builder.box(Vector3(0,0.15,0),Vector3(6.2,0.40,8.0),xf,Color("#918473"))
	_builder.box(Vector3(2.8,1.7,0),Vector3(0.4,3.1,7.8),xf,plaster)
	for side: float in [-1,1]:
		_builder.box(Vector3(0,1.7,side*3.7),Vector3(6,3.1,0.35),xf,plaster)
		_beam(Vector3(-2.85,0.2,side*2.1),Vector3(-2.85,3.2,side*2.1),0.21,0.21,TIMBER)
		_builder.slab(Vector3(side*3.45,3.15,-4.3),Vector3(side*3.45,3.15,4.3),Vector3(0,4.7,4.3),Vector3(0,4.7,-4.3),0.22,tile)
		for station in 3:
			_solid(-2.0+2*station,side*3.7,1.0)
	_builder.box(Vector3(-2.85,3.0,0),Vector3(0.27,0.4,7.8),xf,TIMBER)
	var basket := Transform3D(Basis(Vector3.RIGHT,-PI/2), Vector3(-1,0.95,0))
	_builder.card(PaperKit.circle(0.89,0,0,12),basket,TIMBER,{"thick":1.05,"lip":0.0})
	for side: float in [-1.15,1.15]:
		_builder.box(Vector3(-1,1.55,side),Vector3(0.23,2.5,0.23),xf,TIMBER)
	_builder.box(Vector3(-1,2.65,0),Vector3(0.38,0.3,2.65),xf,TIMBER)
	_builder.box(Vector3(-1,2.05,0),Vector3(0.12,1.1,0.12),xf,STEEL)
	_solid(-1,0,1.2)
	for k in 4:
		var crate := _foot(-3.8,-2.7+k*0.78)
		_builder.box(crate+Vector3.UP*0.25,Vector3(0.83,0.5,0.72),xf,TIMBER.lightened(0.08))
		_builder.box(crate+Vector3.UP*0.49,Vector3(0.65,0.12,0.55),xf,Color("#775166"))


func _block(center: Vector3, size: Vector3, ink: Color) -> void:
	_builder.box(center,size,Transform3D.IDENTITY,ink)


func _disc(center: Vector3, axis: Vector3, radius: float, length: float, ink: Color) -> void:
	var up := Vector3.BACK if absf(axis.y)>0.95 else Vector3.UP
	var xf := Transform3D(Basis.looking_at(-axis.normalized(),up), center)
	_builder.card(PaperKit.circle(radius,0,0,10),xf,ink,{"thick":length,"lip":0.0})


func _hut(x: float, z: float, w: float, d: float, h: float, ink: Color, roof: Color) -> Vector3:
	var p := _foot(x,z)
	track.terrain.flatten_disc(_world(x,z),Vector2(w,d).length()*0.5,_base+p.y,1.5)
	_block(p+Vector3.UP*h*0.5,Vector3(w,h,d),ink)
	for side: float in [-1,1]:
		var e := p+Vector3(side*(w*0.5+0.25),h,0)
		var ridge := p+Vector3.UP*(h+w*0.24)
		var end := Vector3.BACK*(d*0.5+0.3)
		_builder.slab(e-end,e+end,ridge+end,ridge-end,0.16,roof)
		var corner := p+Vector3(0,0,side*d*0.5)
		_builder.card(PackedVector2Array([Vector2(-w*0.5,h),Vector2(w*0.5,h),Vector2(0,h+w*0.24)]),Transform3D(Basis.IDENTITY,corner),ink,{"thick":0.08})
	_solid(x,z,minf(w,d)*0.56)
	return p


func _dairy_field() -> void:
	var barn := _hut(2,1,4,6,2.8,Color("#a95943"),Color("#716a61"))
	var pad := barn+Vector3(-3.5,0.15,0)
	_block(pad,Vector3(3.3,0.32,4.4),Color("#aaa393"))
	for z: float in [-2,2]:
		_beam(pad+Vector3(-1.5,0,z),pad+Vector3(-1.5,2.5,z),0.13,0.13,STEEL)
	for strip in 10:
		_block(pad+Vector3(0,2.57+(strip%2)*0.045,(strip-4.5)*0.46),Vector3(3.55,0.12,0.48),Color("#8d958f"))
	_block(pad+Vector3(-0.55,0.23,0),Vector3(1.6,0.17,1.5),STEEL)
	for k in 5:
		var at := pad+Vector3(0.5-(k%2)*0.6,0.61,-1.5+k*0.47)
		_disc(at,Vector3.UP,0.25,0.72,Color("#c4c8be"))
		_disc(at+Vector3.UP*0.41,Vector3.UP,0.19,0.14,STEEL)
	for row in 11:
		var z := -6.5-row*0.75
		for k in 4:
			var x := -6.0+k*3
			_beam(_foot(x,z)+Vector3.UP*0.1,_foot(x+3,z)+Vector3.UP*0.1,0.16,0.16,Color("#c5ad62"))
		if row%2==0:
			var x := float(row%3)*3-3
			_block(_foot(x,z)+Vector3.UP*0.48,Vector3(1.6,0.96,1.0),Color("#c49a55"))
			_solid(x,z,0.75)


func _quarry_entrance() -> void:
	var cabin := _hut(-2,6,2.4,3.0,2.0,Color("#b9a584"),STEEL)
	_block(cabin+Vector3(-1.22,1.4,0),Vector3(0.06,0.69,1.75),Color("#647e83"))
	var scale := _foot(-5.5,6)
	_block(scale+Vector3.UP*0.09,Vector3(2.6,0.18,4.8),STEEL)
	for k in 6:
		_block(scale+Vector3(-1.2,0.4+k*0.45,-2.3),Vector3(0.23,0.45,0.16),PaperKit.CREAM if k%2 else Color("#ab513e"))
	var wash_y := minf(_foot(-7.5,-6).y,_foot(-7.5,1.9).y)+_base
	track.terrain.carve_river(_world(-7.5,-6),_world(-7.5,1.9),wash_y,1.3,0.36,false,2.2)
	for k in 10:
		var z := -6.0+k*0.78
		var p := _foot(-7.5,z)
		var q := _foot(-7.5,z+0.79)
		_beam(p+Vector3.UP*0.045,q+Vector3.UP*0.045,1.6,0.07,Color("#bca891"))
		_disc(p+Vector3(sin(k*1.7)*0.62,0.09,0),Vector3.UP,0.15+0.08*(k%3),0.12,Color("#978c7c"))
	var mouth := _foot(-7.5,1.9)+Vector3.UP*0.46
	_disc(mouth,Vector3.BACK,0.56,1.1,Color("#9c9789"))
	_disc(mouth+Vector3.FORWARD*0.56,Vector3.BACK,0.40,0.03,RUBBER)


func _harvest_rows() -> void:
	for row in 5:
		var row_x := 4.7+row*1.75
		var target_height := _foot(row_x,-5.6).y
		var last := Vector3.ZERO
		for k in 8:
			var z := -5.6+k*1.65
			var x := row_x
			var best := INF
			for step in 7:
				var test_x := row_x+(step-3)*0.20
				var cost := absf(_foot(test_x,z).y-target_height)+0.12*absf(test_x-(last.x if k else row_x))
				if cost<best:
					best = cost
					x = test_x
			var p := _foot(x,z)
			_beam(p,p+Vector3.UP*1.42,0.085,0.09,TIMBER)
			if k:
				_beam(last+Vector3.UP*1.16,p+Vector3.UP*1.16,0.04,0.05,STEEL)
				if (k+2*row)%6:
					_beam(last+Vector3.UP*0.97,p+Vector3.UP*1.06,0.52,0.46,Color("#9b793c").lightened(0.035*(k%3)))
			last = p
	var p := _foot(-5,-1)
	_block(p+Vector3.UP*0.76,Vector3(1.45,0.19,2.65),Color("#65765d"))
	for side: float in [-1,1]:
		_disc(p+Vector3(side*0.73,0.43,0),Vector3.RIGHT,0.39,0.19,RUBBER)
	for k in 3:
		_block(p+Vector3(0,0.95,(k-1)*0.81),Vector3(1.3,0.23,0.74),TIMBER)
		_block(p+Vector3(0,1.06,(k-1)*0.81),Vector3(1.17,0.1,0.60),Color("#72516a"))
	_solid(-5,-1,1.15)


func _peat_shelter() -> void:
	var p := _foot(5,6)
	for row in 11:
		for col in range(-3,4):
			if row>3 and absi(col)>6-row:
				continue
			_block(p+Vector3(col*0.55+(row%2)*0.14,0.19+row*0.36,0),Vector3(0.53,0.35,0.55),Color("#8a8779").darkened(0.045*((col+row+4)%3)))
	for side: float in [-1,1]:
		for k in 4:
			var pos := _foot(5+side*1.7,6-k*0.65)
			_block(pos+Vector3.UP*0.32,Vector3(0.52,0.68,0.69),Color("#878774"))
			_solid(pos.x,pos.z,0.42)
	var peat_y := _base+_foot(-5.6,-3.1).y-0.23
	track.terrain.carve_river(_world(-5.6,-5.9),_world(-5.6,-0.4),peat_y,0.88,0.24,false,1.4)
	for k in 6:
		var at := _foot(-5.8+k%2*1.3,-5.5+k*0.80)
		_block(at+Vector3.UP*0.1,Vector3(1.5,0.20,0.69),Color("#655444"))
		_block(at+Vector3(0.64,0.18,0.12),Vector3(0.53,0.29,0.4),Color("#878453"))
	for plank in 4:
		var at := _foot(-9,-3+plank*0.23)
		_block(at+Vector3.UP*0.13,Vector3(1.35,0.13,0.21),TIMBER)


func _forestry() -> void:
	for k in 5:
		var root := _foot(5,-5+k*2.2)
		var tip := _foot(0.9,-7+k*2.2)+Vector3.UP*0.35
		_beam(root+Vector3.UP*0.7,tip,0.42,0.44,TIMBER)
		_disc(root+Vector3.UP*0.76,Vector3.RIGHT,0.78+0.1*(k%3),0.29,Color("#654f3b"))
		for twig in 4:
			var angle := twig*1.6+k
			var a := root+Vector3.UP*0.76
			_beam(a,a+Vector3(0.47,0.96*cos(angle),1.10*sin(angle)),0.12,0.1,TIMBER)
		_disc(tip,Vector3.RIGHT,0.21,0.08,PaperKit.CREAM)
		_solid(3,-6+k*2.2,0.95)
	var stick := _foot(-2.4,-4.5)
	for band in 8:
		_block(stick+Vector3.UP*(0.12+band*0.24),Vector3(0.11,0.24,0.12),PaperKit.CREAM if band%2 else Color("#be5644"))


func _fish_market() -> void:
	var face := _hut(-3,-9,3.0,6.1,2.8,Color("#be8067"),Color("#646f73"))
	for bay in 3:
		var door := face+Vector3(-1.54,1.14,(bay-1)*1.9)
		_block(door,Vector3(0.06,2.23,1.66),Color("#545752"))
		_block(door+Vector3(-0.69,1.02,0),Vector3(1.42,0.12,1.72),Color("#728d88"))
		for crate in 2:
			_block(door+Vector3(-0.55,-0.91+crate*0.38,0),Vector3(0.83,0.36,1.09),Color("#aab4af") if crate else Color("#738780"))
	var end := 3.0
	while end < 32 and not track.terrain.is_sea(_world(end,3.5)):
		end += 0.5
	var sea := track.terrain.sea_y-_base
	var lip := maxf(sea+1.4,_foot(end-1.5,3.5).y)
	var quay := Vector3(end,lip,3.5)
	_block(quay-Vector3(1.4,(lip-sea+0.6)*0.5,0),Vector3(2.8,lip-sea+0.6,4.1),Color("#999183"))
	for rung in range(ceili((lip-sea+0.3)/0.32)):
		_block(quay+Vector3(0.14,-rung*0.32,0),Vector3(0.09,0.059,0.59),STEEL)
	for side: float in [-1,1]:
		_beam(quay+Vector3(0.14,0.23,side*0.32),Vector3(end+0.14,sea-0.4,3.5+side*0.32),0.06,0.07,STEEL)
		_disc(quay+Vector3(0.09,-0.19,side*1.45),Vector3.RIGHT,0.18,0.07,STEEL)
		_disc(quay+Vector3(0.14,-0.19,side*1.45),Vector3.RIGHT,0.105,0.02,Color("#999183"))
	_block(Vector3(end+0.022,sea+0.28,3.5),Vector3(0.035,0.09,4.0),Color("#b6ae92"))


func _lake_launch() -> void:
	var p := _foot(6,0)
	for rail: float in [-0.58,0.58]:
		_beam(p+Vector3(-1,0.2,rail),p+Vector3(2,0.32,rail),0.14,0.15,TIMBER)
	for k in 5:
		_block(p+Vector3(-0.6+k*0.45,0.35,0),Vector3(0.38,0.086,1.45),TIMBER)
	var sled := p+Vector3(0.1,0.48,0)
	for rail: float in [-0.38,0.38]:
		_block(sled+Vector3(0,0,rail),Vector3(1.8,0.1,0.09),STEEL)
	_block(sled+Vector3.UP*0.18,Vector3(1.43,0.18,0.84),Color("#a15644"))
	_beam(sled+Vector3.RIGHT*0.75,p+Vector3(1.96,0.24,0.56),0.03,0.03,TIMBER)
	for k in 22:
		var a := k*0.42
		var q := _foot(7*cos(a),5.8*sin(a))
		_beam(q,q+Vector3(0.12,0.49+0.28*sin(k),0.06),0.055,0.045,Color("#aa925d"))


func _sauna() -> void:
	var p := _hut(1,2,3.2,4.2,2.3,Color("#856750"),Color("#6b6771"))
	for log in 8:
		_block(p+Vector3(-1.61,0.16+0.28*log,0),Vector3(0.08,0.046,4.26),TIMBER.darkened(0.20))
	_builder.box(p+Vector3(-1.67,1.44,0.65),Vector3(0.06,0.63,0.76),Transform3D(),Color("#efaf63"),Color(-1,0,0),true)
	_block(p+Vector3(0.7,3.02,-0.9),Vector3(0.27,1.07,0.29),STEEL)
	for log in 5:
		var log_pos := p+Vector3(-1.85,0.17+floori(log/3.0)*0.27,-1.8+(log%3)*0.31)
		_disc(log_pos,Vector3.RIGHT,0.16,0.51,TIMBER)
	var shore := _foot(-1,-6)
	track.terrain.flatten_disc(_world(-1,-6),3.3,_base+shore.y,2.0)
	_disc(shore+Vector3.UP*0.07,Vector3.UP,3.1,0.08,Color("#a1aeba"))
	for k in 8:
		var q := _foot(-2.0-k*0.22,1.5-k*1.31)
		_beam(q,q+Vector3.UP*0.55,0.09,0.09,TIMBER)
		_builder.box(q+Vector3.UP*0.65,Vector3(0.18,0.18,0.18),Transform3D(),Color("#e8b373"),Color(-1,0,0),true)
		_block(q+Vector3.UP*0.77,Vector3(0.23,0.06,0.23),STEEL)


func _lookout() -> void:
	var p := _hut(0,0,3.3,4.1,2.7,Color("#d6cbb3"),Color("#686c70"))
	for side: float in [-1,1]:
		_block(p+Vector3(side*1.66,2.03,0),Vector3(0.06,0.68,3.6),Color("#657e84"))
	_block(p+Vector3(-1.76,1.03,1.05),Vector3(0.29,0.64,0.65),Color("#ba533c"))
	var pole := _foot(2,3)
	_beam(pole,pole+Vector3.UP*5.0,0.10,0.10,STEEL)
	for k in 5:
		var r := 0.32-k*0.043
		_disc(pole+Vector3(0,4.76-k*0.064,0.19+k*0.34),Vector3.BACK,r,0.36,PaperKit.CREAM if k%2 else Color("#c46540"))


func _catch_fence() -> void:
	var mesh_ink := Color("#6b706c")
	for bay in 5:
		var a := _foot(-3,-7.5+bay*3.0)
		var z := _foot(-3,-4.5+bay*3.0)
		for foot in [a,z]:
			_beam(foot,foot+Vector3(0.4,2.55,0),0.13,0.13,STEEL)
		for wire in 4:
			var off := Vector3(0.1*wire,0.4+wire*0.65,0)
			_beam(a+off,z+off,0.035,0.035,mesh_ink)
		for strand in 4:
			var start := a.lerp(z,strand/4.0)+Vector3.UP*0.32
			var top := a.lerp(z,(strand+1)/4.0)+Vector3(0.4,2.4,0)
			_beam(start,top,0.036,0.036,mesh_ink)
			_beam(start+Vector3(0.4,2.08,0),top-Vector3(0.4,2.08,0),0.036,0.036,mesh_ink)
		_solid(a.x,a.z,0.38)
		for rock in 4:
			var q := _foot(-2.4+0.32*(rock%2),a.z+rock*0.6)
			_disc(q+Vector3.UP*0.17,Vector3.UP,0.29+0.06*(rock%3),0.31,Color("#928479"))
		var face := _foot(2.6,a.z+1.6)
		var rock_profile := PackedVector2Array([Vector2(-1.6,-0.15),Vector2(1.5,-0.15),Vector2(1.35,2.0),Vector2(0.46,2.7+0.3*sin(bay)),Vector2(-1.45,2.1)])
		_builder.prism(rock_profile,-0.9,1.2,Transform3D(Basis(Vector3.UP,0.09*sin(bay)),face),Color("#81767b"))
		var anchor := _foot(1.2,a.z+1.5)+Vector3.UP*0.22
		_disc(anchor,Vector3.UP,0.21,0.10,STEEL)
		_beam(a+Vector3(0.4,2.55,0),anchor,0.046,0.046,mesh_ink)
