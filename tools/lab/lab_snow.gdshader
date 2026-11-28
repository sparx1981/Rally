// Lab test 4: tyre tracks pressed into snow. mode 0 = flat dark decal (like a plain marks strip), 1 = pressed trough with raised rims.
shader_type spatial;
render_mode cull_disabled;
uniform int mode = 1;
uniform float depth = 0.11;
uniform float rim = 0.055;
uniform vec3 snow : source_color = vec3(0.94, 0.96, 1.0);
varying float v_trough;
varying float v_comp;

float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
float cx(float z){ return 2.4 * sin(z * 0.075) + 0.6 * sin(z * 0.21); }
// x: trough depth (0..1), y: rim height (0..1)
vec2 prof(vec2 p, float wheel){
	float z = p.y;
	float d = abs(p.x - (cx(z) + wheel * 0.82));
	float fade = smoothstep(2.0, 9.0, z + 6.0);
	float dd = d + (vn(vec2(z * 3.0, wheel * 5.0)) - 0.5) * 0.05;
	float trough = (1.0 - smoothstep(0.12, 0.22, dd)) * fade;
	float lip = exp(-pow((dd - 0.30) / 0.10, 2.0)) * fade;
	return vec2(trough, lip);
}
float hgt(vec2 p){
	float base = (vn(p * 1.3) - 0.5) * 0.03 + (vn(p * 5.0) - 0.5) * 0.012;
	if (mode == 0) return base;
	vec2 a = prof(p, -1.0), b = prof(p, 1.0);
	return base - depth * max(a.x, b.x) + rim * max(a.y, b.y);
}
void vertex(){
	vec2 p = VERTEX.xz;
	float e = 0.05;
	float h = hgt(p);
	NORMAL = normalize(vec3(hgt(p - vec2(e, 0.0)) - hgt(p + vec2(e, 0.0)), 2.0 * e, hgt(p - vec2(0.0, e)) - hgt(p + vec2(0.0, e))));
	VERTEX.y = h;
	vec2 a = prof(p, -1.0), b = prof(p, 1.0);
	v_trough = max(a.x, b.x);
	v_comp = max(a.y, b.y);
}
void fragment(){
	vec3 col = snow;
	if (mode == 0) {
		col = mix(snow, vec3(0.46, 0.50, 0.58), v_trough * 0.8);
	} else {
		col = mix(snow, vec3(0.70, 0.80, 0.96), v_trough * 0.85);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
