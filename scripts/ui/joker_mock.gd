class_name JokerMock
extends Control
## Mockups for the Joker explainer (development only): variant "map" draws the real circuit as a paper map.

var track: Track
var variant := "map"
var t := 0.0
var _font: Font


func _ready() -> void:
	_font = PaperTheme.font()


func _draw() -> void:
	var font := _font
	draw_rect(Rect2(Vector2.ZERO, size), Color("#e9d6ad"))
	# Card
	var card := Rect2(Vector2(60, 50), Vector2(size.x - 120, size.y - 100))
	draw_rect(Rect2(card.position + Vector2(6, 8), card.size), PaperTheme.SHADOW)
	draw_rect(card, PaperTheme.CREAM)
	draw_rect(card, PaperTheme.EDGE, false, 4.0)
	var b := Rect2(track.pts[0], Vector2.ZERO)
	for p in track.pts:
		b = b.expand(p)
	var area := Rect2(card.position + Vector2(30, 30), Vector2(card.size.x * 0.58, card.size.y - 60))
	var sc := minf(area.size.x / b.size.x, area.size.y / b.size.y)
	var off := area.get_center() - b.get_center() * sc
	var main := PackedVector2Array()
	for i in range(0, track.pts.size(), 2):
		main.append(track.pts[i] * sc + off)
	main.append(main[0])
	# Cut-paper road: shadow, edge, surface, centre dashes.
	draw_polyline(main, PaperTheme.SHADOW, 26.0, true)
	draw_polyline(main, PaperTheme.EDGE, 22.0, true)
	draw_polyline(main, Color("#a89a84"), 17.0, true)
	var jk := track.joker
	var lane := PackedVector2Array()
	var i0 := int(jk.i0)
	var i1 := int(jk.i1)
	for i in range(i0, i1 + 1):
		var band := track.joker_band(track.dist[i])
		if is_nan(band.x):
			continue
		var p: Vector2 = track.pts[i] + track.nrm[i] * (band.x + band.y) * 0.5
		lane.append(p * sc + off)
	draw_polyline(lane, PaperTheme.EDGE, 15.0, true)
	draw_polyline(lane, Color("#e8b04a"), 10.0, true)
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	draw_polyline(lane, Color(1, 0.95, 0.7, 0.4 + 0.4 * pulse), 3.0, true)
	# Start/finish chequer and player car on the lane.
	var sp: Vector2 = track.pts[0] * sc + off
	draw_rect(Rect2(sp - Vector2(3, 14), Vector2(6, 28)), Color("#2b2b2e"))
	draw_string(font, sp + Vector2(10, 30), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PaperTheme.INK)
	var mid := lane[lane.size() / 2]
	draw_circle(mid + Vector2(2, 3), 9.0, PaperTheme.SHADOW)
	draw_circle(mid, 9.0, PaperTheme.ACCENT)
	draw_circle(mid, 9.0, PaperTheme.EDGE, false, 2.5)
	var tag := Rect2(lane[lane.size() / 3] + Vector2(-90, -52), Vector2(150, 30))
	draw_rect(tag, Color("#e8b04a"))
	draw_rect(tag, PaperTheme.EDGE, false, 3.0)
	draw_string(font, tag.position + Vector2(12, 22), "JOKER LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PaperTheme.INK)
	# Text panel
	var tx := card.position.x + card.size.x * 0.64
	draw_string(font, Vector2(tx, card.position.y + 80), "The Joker lane", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, PaperTheme.ACCENT)
	var lines := ["Every circuit has one extra", "route. It splits off the track", "and rejoins it further on.", "", "Take it ONCE per race, any lap.", "It is longer, so it costs a few", "seconds. Skip it and you get", "+15 seconds."]
	for k in lines.size():
		draw_string(font, Vector2(tx, card.position.y + 140 + k * 34), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PaperTheme.INK)
	var hud := Rect2(Vector2(tx, card.position.y + card.size.y - 80), Vector2(300, 44))
	draw_rect(hud, PaperTheme.CREAM)
	draw_rect(hud, PaperTheme.EDGE, false, 3.0)
	draw_string(font, hud.position + Vector2(16, 32), "JOKER: NEEDED NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#b0301f"))
