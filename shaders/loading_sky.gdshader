// Loading backdrop: a cut-paper sunrise or sunset over layered ridges.
shader_type canvas_item;

uniform vec4 top_col : source_color = vec4(0.17, 0.16, 0.37, 1.0);
uniform vec4 mid_col : source_color = vec4(0.85, 0.31, 0.48, 1.0);
uniform vec4 low_col : source_color = vec4(1.0, 0.48, 0.24, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform vec4 far_col : source_color = vec4(0.62, 0.34, 0.5, 1.0);
uniform vec4 near_col : source_color = vec4(0.11, 0.07, 0.16, 1.0);
uniform float aspect = 1.78;
uniform float seed = 1.0;
uniform float sun_x = 0.68;
uniform float horizon = 0.60;
uniform float stars = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += vnoise(p) * a;
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float h = clamp((horizon - uv.y) / horizon, 0.0, 1.0);
	vec3 col = mix(low_col.rgb, mid_col.rgb, smoothstep(0.0, 0.45, h));
	col = mix(col, top_col.rgb, smoothstep(0.35, 1.0, h));

	vec2 sp = vec2(sun_x * aspect, horizon - 0.11);
	float d = length(p - sp);
	col += sun_col.rgb * exp(-d * 2.2) * 0.6;
	col += low_col.rgb * exp(-abs(uv.y - horizon) * 9.0) * exp(-abs(p.x - sp.x) * 0.9) * 0.55;
	col = mix(col, sun_col.rgb, smoothstep(0.062, 0.058, d));
	if (stars > 0.0) {
		vec2 g = p * 70.0;
		float st = step(0.985, hash(floor(g))) * (1.0 - smoothstep(0.1, 0.4, length(fract(g) - 0.5)));
		col += vec3(st) * h * stars;
	}

	// Cut-paper cloud bands, lit from below by the sun.
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float cy = horizon - 0.04 - fk * 0.15;
		float n = fbm(vec2(p.x * (1.9 + fk * 0.6) + fk * 7.0, fk * 3.0));
		float band = cy - (n - 0.45) * 0.12;
		float th = 0.030 + fk * 0.012 + 0.03 * fbm(vec2(p.x * 3.0 + fk * 5.0, 9.0));
		float top_edge = band - th;
		float edge = smoothstep(top_edge, top_edge + 0.004, uv.y) * smoothstep(band + 0.004, band, uv.y);
		float thick = clamp((uv.y - top_edge) / th, 0.0, 1.0);
		vec3 under = mix(low_col.rgb * 1.15, mid_col.rgb * 1.1, fk * 0.45);
		vec3 top = mix(mid_col.rgb * 0.75, top_col.rgb * 1.35, 0.4 + fk * 0.15);
		vec3 cloud = mix(top, under, thick);
		cloud += sun_col.rgb * exp(-abs(p.x - sp.x) * 1.4) * (1.0 - fk * 0.3) * 0.22 * thick;
		col = mix(col, cloud, edge * (0.92 - fk * 0.1));
	}

	// Ridges, far to near, each a darker paper layer.
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float ridge = horizon + 0.02 + fk * 0.075 - fbm(vec2(p.x * (0.9 + fk * 0.55) + fk * 5.0, fk)) * (0.10 + fk * 0.025);
		float inside = smoothstep(ridge, ridge + 0.003, uv.y);
		vec3 layer = mix(far_col.rgb, near_col.rgb, fk / 3.0);
		// Warm rim along the top edge toward the sun.
		float rim = smoothstep(ridge + 0.016, ridge, uv.y) * exp(-abs(p.x - sp.x) * 0.8);
		layer = mix(layer, low_col.rgb, rim * 0.5 * (1.0 - fk * 0.2));
		col = mix(col, layer, inside);
	}
	// Soft paper grain and a gentle vignette.
	col *= 0.97 + 0.05 * vnoise(p * 380.0);
	col *= 1.0 - 0.28 * smoothstep(0.55, 1.1, length((uv - 0.5) * vec2(1.0, 1.25)));
	COLOR = vec4(col, 1.0);
}
