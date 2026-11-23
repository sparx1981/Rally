// Opaque printed water. In the stream mesh +Z is downstream. The widely
// spaced marks soften to the base stock colour as they get smaller on screen.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 paper_tint : source_color = vec4(1.0);
varying vec2 sheet;

void vertex() {
	sheet = VERTEX.xz;
}

void fragment() {
	vec2 grid = sheet * vec2(0.8, 0.24);
	grid.y -= TIME * 0.18;
	grid.y += sin(floor(grid.x) * 4.7) * 2.0;
	vec2 tile = floor(grid);
	vec2 p = fract(grid) - 0.5;
	p.x += 0.16 * sin(dot(tile, vec2(3.1, 1.7)));
	float cut = abs(p.x + p.y * 0.20) * 7.0 + abs(p.y) * 2.8;
	float feather = max(fwidth(cut), 0.08);
	float mark = 1.0 - smoothstep(0.55 - feather, 0.55 + feather, cut);
	float fade = 1.0 - smoothstep(0.018, 0.12, max(fwidth(sheet.x) * 0.8, fwidth(sheet.y) * 0.24));
	ALBEDO = COLOR.rgb * paper_tint.rgb * (1.0 + mark * fade * 0.34);
	ROUGHNESS = 1.0;
}
