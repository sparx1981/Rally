// Lab test 1: wet / dusty windscreen with a wiper sweep. Own implementation of the idea only.
shader_type canvas_item;
uniform sampler2D scene : filter_linear_mipmap, repeat_disable;
uniform int mode = 0;               // 0 = rain drops, 1 = dust film
uniform float wiper_from = -1.15;   // start of the swept arc (radians, 0 = straight up)
uniform float wiper_to = -0.15;     // current blade angle
uniform float show_blade = 1.0;
uniform float aspect = 1.7778;
uniform float amount = 1.0;
uniform vec3 dust_col : source_color = vec3(0.80, 0.66, 0.46);
uniform vec2 pivot = vec2(0.5, 1.12);

float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ return 0.5*vn(p) + 0.25*vn(p*2.03+7.1) + 0.125*vn(p*4.1+3.3) + 0.0625*vn(p*8.3); }

// returns uv refraction offset; m = drop coverage; hl = specular
vec2 drops(vec2 uv, float cells, float seed, float density, out float m, out float hl){
	vec2 g = vec2(uv.x * aspect, uv.y) * cells;
	vec2 id = floor(g); vec2 f = fract(g) - 0.5;
	m = 0.0; hl = 0.0;
	if (h21(id + seed) > density) return vec2(0.0);
	vec2 off = (vec2(h21(id+seed+1.7), h21(id+seed+3.1)) - 0.5) * 0.45;
	float rad = mix(0.12, 0.30, h21(id+seed+5.3));
	vec2 q = (f - off) / rad; q.y /= 1.15;
	float d = length(q);
	float inside = smoothstep(1.0, 0.86, d);
	// slide trail above the drop
	float tr = 0.0;
	if (h21(id+seed+7.7) > 0.45) {
		float ty = (off.y - f.y);
		tr = step(0.0, ty) * smoothstep(0.65, 0.0, ty) * smoothstep(rad*0.38, rad*0.12, abs(f.x - off.x)) * 0.55;
	}
	float rimd = smoothstep(0.6, 0.98, d) * inside;
	m = max(inside, tr);
	vec2 n = q * inside;
	hl = pow(clamp(dot(normalize(vec3(n, sqrt(max(1.0 - dot(n,n), 0.0)))), normalize(vec3(-0.4, -0.6, 0.7))), 0.0, 1.0), 22.0) * inside;
	return -n * rad * 0.8 / cells * vec2(1.0 / aspect, 1.0) + vec2(0.0, tr * 0.0);
}

void fragment(){
	vec2 uv = UV;
	vec3 sc = texture(scene, uv).rgb;
	vec3 blur = textureLod(scene, uv, 3.2).rgb;
	vec2 p = vec2((uv.x - pivot.x) * aspect, uv.y - pivot.y);
	float ang = atan(p.x, -p.y);
	float rad = length(p);
	float glass = smoothstep(0.70, 0.66, uv.y);
	float inside = step(0.30, rad) * step(rad, 1.12);
	float swept = inside * smoothstep(wiper_from - 0.015, wiper_from + 0.015, ang) * smoothstep(wiper_to + 0.02, wiper_to - 0.01, ang);
	vec3 dirty = sc;
	if (mode == 0) {
		float m1, h1, m2, h2, m3, h3;
		vec2 o1 = drops(uv, 8.0, 1.0, 0.42 * amount, m1, h1);
		vec2 o2 = drops(uv, 17.0, 9.0, 0.5 * amount, m2, h2);
		vec2 o3 = drops(uv, 40.0, 21.0, 0.5 * amount, m3, h3);
		float mist = fbm(uv * vec2(aspect, 1.0) * 9.0);
		dirty = mix(sc, blur, 0.38 * amount * smoothstep(0.25, 0.75, mist));
		vec3 r3 = texture(scene, uv + o3).rgb; dirty = mix(dirty, r3 * 0.95, m3 * 0.8) + h3 * 0.3;
		vec3 r2 = texture(scene, uv + o2).rgb; dirty = mix(dirty, r2 * 0.93, m2 * 0.85) + h2 * 0.45;
		vec3 r1 = texture(scene, uv + o1).rgb; dirty = mix(dirty, r1 * 0.9, m1 * 0.88) + h1 * 0.55;
	} else {
		float film = fbm(uv * vec2(aspect, 1.0) * 3.2) * 0.8 + 0.3 * fbm(uv * vec2(aspect, 1.0) * 14.0) + 0.18 * amount;
		film = smoothstep(0.35, 0.95, film) * amount;
		float lum = dot(blur, vec3(0.3, 0.55, 0.15));
		vec3 hazy = mix(sc, blur, 0.7 * film);
		dirty = mix(hazy, dust_col * (0.55 + lum * 0.7), film * 0.62);
	}
	// what the blade leaves behind
	vec3 clean = sc;
	if (mode == 0) {
		float edge = smoothstep(0.05, 0.0, abs(ang - wiper_to) * rad) * 0.0;
		float lines = vn(vec2(rad * 70.0, 3.0)) ;
		clean = mix(sc, blur, 0.10 * lines);
	} else {
		float streak = vn(vec2(rad * 55.0, 1.0));
		clean = mix(sc, mix(sc, dust_col * 0.8, 0.5), 0.10 * amount * streak);
		// dust bank at the end of the sweep
		float bank = smoothstep(0.04, 0.0, abs(ang - wiper_from - 0.015) * rad) * inside;
		clean = mix(clean, dust_col * 0.7, bank * 0.5 * amount);
	}
	vec3 col = mix(dirty, clean, swept);
	// blade + arm
	float bl = show_blade * inside * smoothstep(0.016, 0.008, abs(ang - wiper_to) * rad);
	float edge = show_blade * inside * smoothstep(0.012, 0.0, abs(ang - wiper_from) * rad) * 0.0;
	float arm = show_blade * smoothstep(0.006, 0.002, abs(ang - wiper_to) * rad) * step(rad, 1.12) * step(0.0, rad);
	col = mix(col, vec3(0.05, 0.045, 0.04), max(bl, arm * 0.6));
	COLOR = vec4(mix(sc, col, glass), 1.0);
}
