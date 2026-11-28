// Lab test 5: pond surface with rain rings, plus a Kelvin wake behind a moving car.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float time = 0.8;
uniform float rings = 1.0;
uniform float wake = 0.0;
uniform vec2 car = vec2(0.0, 0.0);
uniform vec3 deep : source_color = vec3(0.16, 0.30, 0.36);
uniform vec3 horizon : source_color = vec3(0.95, 0.82, 0.68);
uniform vec3 zenith : source_color = vec3(0.50, 0.62, 0.78);
varying vec3 wp;
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float ringsH(vec2 p){
	float cell = 1.5; vec2 id = floor(p / cell); float h = 0.0;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 c = id + vec2(float(i), float(j));
		float seed = h21(c);
		float t = fract(time * 0.45 + seed);
		vec2 ctr = (c + vec2(h21(c + 3.7), h21(c + 9.1))) * cell;
		float d = length(p - ctr);
		float r = t * 0.9;
		float env = exp(-pow((d - r) / 0.09, 2.0)) * (1.0 - t) * (1.0 - t);
		h += env * sin((d - r) * 55.0) * 0.012;
	}
	return h;
}
float wakeH(vec2 p){
	vec2 rel = p - car; float d = -rel.x;
	if (d < 0.3) return 0.0;
	float az = abs(rel.y);
	float arm = az - 0.354 * d;
	float w = 0.18 + 0.07 * d;
	float chev = 0.65 + 0.35 * cos(d * 1.9);
	float a = exp(-pow(arm / w, 2.0)) * chev / (1.0 + 0.16 * d);
	float core = exp(-pow(az / (0.9 + 0.12 * d), 2.0)) * exp(-d * 0.10) * 0.55;
	return 0.06 * (a + core * 0.4 * (0.6 + 0.4 * sin(d * 2.4)));
}
float H(vec2 p){ return rings * ringsH(p) + wake * wakeH(p); }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz; float e = 0.03;
	vec3 n = normalize(vec3(H(p - vec2(e, 0.0)) - H(p + vec2(e, 0.0)), 2.0 * e, H(p - vec2(0.0, e)) - H(p + vec2(0.0, e))));
	vec3 nv = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 R = reflect(normalize(VERTEX), nv);
	float ry = clamp(dot(R, up), 0.0, 1.0);
	vec3 sky = mix(horizon, zenith, pow(ry, 0.6));
	float fres = pow(1.0 - clamp(dot(-normalize(VERTEX), nv), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, sky, clamp(0.25 + fres * 0.9, 0.0, 1.0));
	float foam = clamp(wakeH(p) * 14.0, 0.0, 1.0) * wake * 0.22;
	ALBEDO = col + foam;
}
