// Procedural ground detail for loose and paved surfaces: pebbles, clods, ripples, cracks, puddles.
// Everything is a function of world position (no textures, no tiling), strongest near the camera and
// faded out with distance so it never shimmers.
//
// kinds: 0 tarmac, 1 fine gravel / chalk, 2 coarse gravel / granite, 3 sand, 4 dirt / clay,
//        5 mud, 6 ice, 7 snow

float s_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 s_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float s_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(s_hash12(i), s_hash12(i + vec2(1.0, 0.0)), f.x), mix(s_hash12(i + vec2(0.0, 1.0)), s_hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float s_fbm(vec2 p) {
	return s_vnoise(p) * 0.55 + s_vnoise(p * 2.17 + 7.3) * 0.3 + s_vnoise(p * 4.63 + 3.1) * 0.15;
}

// Nearest feature point: x = distance, y = cell id, zw = vector from the point to that feature, w2 = edge gap.
vec4 s_cell(vec2 p, out float edge) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	float bid = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = s_hash22(ip + g);
			vec2 r = g + o * 0.9 + 0.05 - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = r;
				bid = s_hash12(ip + g + 17.0);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	edge = sqrt(d2) - sqrt(d1);
	return vec4(sqrt(d1), bid, best);
}

// Rounded stones: returns shaded albedo factor and a world-space tilt (xz) of the surface normal.
void s_pebbles(vec2 p, float scale, float contrast, float dust, out float shade, out vec2 tilt, out float tone) {
	float edge;
	vec4 c = s_cell(p * scale, edge);
	float rad = 0.34 + 0.16 * c.y;
	float inside = 1.0 - smoothstep(rad * 0.85, rad, c.x);
	float dome = clamp(1.0 - c.x / rad, 0.0, 1.0);
	vec2 dir = c.zw / max(c.x, 0.001);
	tilt = -dir * smoothstep(0.0, 0.8, 1.0 - dome) * inside * 0.9;
	tone = c.y;
	shade = mix(dust, 1.0 + (c.y - 0.5) * contrast * 2.0 + dome * 0.12, inside);
}

// Returns the surface albedo; tilt is the sideways lean of the normal in world xz.
vec3 surf_detail(int kind, vec3 wp, float dist, vec3 base, float wet, out vec2 tilt) {
	float fade = 1.0 - smoothstep(14.0, 55.0, dist);
	float calm = 1.0 - smoothstep(30.0, 90.0, dist);
	vec2 p = wp.xz;
	vec3 c = base;
	tilt = vec2(0.0);
	if (kind == 0) {
		// Tarmac: aggregate speckle, hairline cracks and darker repair patches.
		float g1 = s_hash12(floor(p * 90.0));
		float g2 = s_hash12(floor(p * 34.0) + 3.0);
		c *= 1.0 + (g1 - 0.5) * 0.22 * fade + (g2 - 0.5) * 0.12 * fade;
		float edge;
		vec2 warp = vec2(s_fbm(p * 0.9), s_fbm(p * 0.9 + 5.0)) * 1.4;
		vec4 cr = s_cell(p * 0.38 + warp + 4.0, edge);
		float crack = (1.0 - smoothstep(0.0, 0.018, edge)) * smoothstep(0.55, 0.72, s_fbm(p * 0.5 + 2.0));
		c *= 1.0 - crack * 0.3 * calm;
		float patch = smoothstep(0.62, 0.66, s_vnoise(p * 0.11 + 9.0));
		c *= 1.0 - patch * 0.12;
		tilt = vec2(g1 - 0.5, g2 - 0.5) * 0.18 * fade;
	} else if (kind == 1 || kind == 2) {
		float scale = kind == 1 ? 16.0 : 11.0;
		float sh;
		vec2 t1;
		float tone;
		s_pebbles(p, scale, kind == 1 ? 0.35 : 0.5, 0.72, sh, t1, tone);
		float sh2;
		vec2 t2;
		float tone2;
		s_pebbles(p + 11.0, scale * 3.1, 0.4, 0.8, sh2, t2, tone2);
		vec3 warm = mix(vec3(0.74, 0.78, 0.86), vec3(1.14, 1.02, 0.82), smoothstep(0.2, 0.8, tone));
		c *= mix(vec3(1.0), warm * sh * mix(1.0, sh2, 0.5), fade * 0.9 + 0.1);
		c *= 1.0 + (s_fbm(p * 0.7) - 0.5) * 0.18;
		tilt = (t1 * 0.85 + t2 * 0.35) * fade;
	} else if (kind == 3) {
		// Sand: wind ripples with fine grains.
		float w = s_fbm(p * 0.9) * 5.0;
		float rip = sin(dot(p, vec2(0.8, 0.6)) * 16.0 + w);
		c *= 1.0 + rip * 0.07 * fade + (s_hash12(floor(p * 70.0)) - 0.5) * 0.12 * fade;
		tilt = vec2(0.8, 0.6) * cos(dot(p, vec2(0.8, 0.6)) * 16.0 + w) * 0.12 * fade;
		float g;
		vec2 t3;
		float tn;
		s_pebbles(p + 5.0, 4.0, 0.2, 0.9, g, t3, tn);
		c *= mix(1.0, g, 0.5 * fade);
	} else if (kind == 4) {
		// Packed earth: clods split by cracks, scattered stones and flecks.
		vec2 wp2 = p + vec2(s_fbm(p * 1.3), s_fbm(p * 1.3 + 3.0)) * 0.5;
		float edge;
		vec4 cl = s_cell(wp2 * 2.2, edge);
		float seam = 1.0 - smoothstep(0.0, 0.07, edge);
		float damp = s_fbm(p * 0.45 + 12.0);
		c *= (0.9 + cl.y * 0.2) * (1.0 - seam * 0.14) * (0.92 + damp * 0.16);
		tilt = -cl.zw / max(cl.x, 0.001) * 0.12 * fade * smoothstep(0.0, 0.7, cl.x);
		float st;
		vec2 t4;
		float tn;
		s_pebbles(p + 21.0, 9.0, 0.7, 0.92, st, t4, tn);
		float st2;
		vec2 t5;
		float tn2;
		s_pebbles(p + 33.0, 24.0, 0.5, 0.95, st2, t5, tn2);
		c *= mix(1.0, st * mix(0.95, st2, 0.7), 0.7 * fade);
		tilt += (t4 * 0.7 + t5 * 0.35) * fade;
		float fleck = step(0.985, s_hash12(floor(p * 40.0)));
		c = mix(c, c * 0.55, fleck * fade);
	} else if (kind == 5) {
		// Mud: wet churned clumps with shiny puddles.
		float m = s_fbm(p * 0.6);
		float pud = smoothstep(0.52, 0.6, m);
		float edge;
		vec4 cl = s_cell(p * 4.5, edge);
		float lump = 1.0 - smoothstep(0.0, 0.5, cl.x);
		c *= (0.78 + lump * 0.3 + cl.y * 0.12);
		tilt = -cl.zw / max(cl.x, 0.001) * 0.35 * fade * (1.0 - pud);
		c = mix(c, c * vec3(0.55, 0.6, 0.7), pud * 0.8);
		tilt *= 1.0 - pud;
	} else if (kind == 6) {
		// Ice: pale blue sheet, white crack lines and a few bubbles.
		float edge;
		vec4 cr = s_cell(p * 0.8, edge);
		float line = 1.0 - smoothstep(0.0, 0.04, edge);
		float vein = s_vnoise(p * 3.0);
		c = mix(c, vec3(0.93, 0.97, 1.0), line * 0.5 * calm);
		c *= 0.94 + vein * 0.1;
		tilt = vec2(s_vnoise(p * 6.0) - 0.5, s_vnoise(p * 6.0 + 4.0) - 0.5) * 0.05;
	} else {
		// Snow: soft drift undulation, blue shadow in the dips, glitter.
		float h = s_fbm(p * 0.8);
		float h2 = s_fbm(p * 0.8 + vec2(0.4, 0.0));
		float h3 = s_fbm(p * 0.8 + vec2(0.0, 0.4));
		tilt = vec2(h2 - h, h3 - h) * -2.2 * calm;
		c *= 0.94 + h * 0.1;
		c = mix(c, c * vec3(0.88, 0.93, 1.02), smoothstep(0.55, 0.3, h) * 0.5);
		float glit = step(0.992, s_hash12(floor(p * 55.0))) * fade;
		c += vec3(glit) * 0.25;
	}
	// Rain darkens and flattens loose ground.
	c *= 1.0 - wet * 0.18;
	return c;
}
