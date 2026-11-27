// Papercraft sky: drifting cut-paper cloud decks over a soft glowing haze.
// Sun and moon light bleeds through thin paper, silvers the cloud edges and
// fans out as light shafts. Three cloud decks (high, main, low) move at
// different speeds; storm = 1 turns them into a dark, heavy rain deck.
shader_type sky;

uniform vec4 horizon : source_color;
uniform vec4 mid_ink : source_color;
uniform vec4 zenith : source_color;
uniform vec4 cloud_ink : source_color;
uniform vec4 light_ink : source_color;
uniform vec4 glow_ink : source_color;
uniform vec4 moon_ink : source_color = vec4(0.78, 0.85, 1.0, 1.0);
uniform vec3 light_dir;
uniform vec3 moon_dir;
uniform vec2 offset;
uniform vec2 wind = vec2(0.012, 0.005);
uniform float t = 0.0;
uniform float cover = 0.54;
uniform float storm = 0.0;
uniform int layers = 3;
uniform float flash = 0.0;
uniform float rainbow = 0.0;
uniform float night_amount = 0.0;
uniform float glow_amount = 0.0;
uniform bool peaks;
uniform bool snowcaps;
uniform sampler2D paper_noise : repeat_enable, filter_linear_mipmap;

float dens(vec2 uv) {
	float a = texture(paper_noise, uv).r;
	// The fine layer drifts on its own, so cloud shapes slowly evolve.
	float b = texture(paper_noise, uv * 2.84 + vec2(t * 0.004, -t * 0.003)).r;
	return a * 0.74 + b * 0.26;
}

// One cut-paper deck. rgb = tone, a = coverage; body = soft density (for shafts).
vec4 cloud_layer(vec2 uv, float cov, float soft, vec2 sun_uv, vec3 shade, vec3 mid, vec3 lit, vec3 lamp, float align, float lining, out float body) {
	float d = dens(uv);
	float d2 = dens(uv + sun_uv * 0.045);
	float sheet = smoothstep(cov, cov + soft, d);
	// Slopes that rise away from the light face it; stepped into paper tones.
	float facing = clamp((d - d2) * 9.0 + 0.5, 0.0, 1.0);
	float tone = smoothstep(0.30, 0.36, facing) * 0.5 + smoothstep(0.62, 0.68, facing) * 0.5;
	vec3 c = tone < 0.5 ? mix(shade, mid, tone * 2.0) : mix(mid, lit, (tone - 0.5) * 2.0);
	c = mix(c, mix(shade, mid, 0.55), storm * 0.7);
	// Thin paper at the edge lets the light through: the silver lining.
	float thin = (1.0 - smoothstep(cov, cov + 0.12, d)) * sheet;
	c += lamp * thin * align * lining * (1.0 - storm * 0.85);
	body = smoothstep(cov - 0.1, cov + 0.1, d);
	return vec4(c, sheet);
}

void sky() {
	vec3 dir = EYEDIR;
	float height = max(dir.y, 0.0);
	float night = night_amount;
	float day = 1.0 - night;
	vec3 sun = normalize(light_dir);
	vec3 moon = normalize(moon_dir);

	// Gradient: horizon -> mid band -> zenith.
	vec3 base = mix(horizon.rgb, mid_ink.rgb, smoothstep(-0.02, 0.30, height));
	base = mix(base, zenith.rgb, smoothstep(0.22, 0.85, height));

	// Sunrise / sunset: a hot band under the sun, a wide soft wash around it.
	float az = max(dot(normalize(dir.xz + vec2(0.0001)), normalize(sun.xz + vec2(0.0001))), 0.0);
	base += glow_ink.rgb * glow_amount * (pow(az, 5.0) * exp(-height * 4.5) * 0.85 + pow(az, 1.5) * exp(-height * 1.6) * 0.16);

	float sd = dot(dir, sun);
	float md = dot(dir, moon);
	base = mix(base, light_ink.rgb * 1.1, smoothstep(0.9979, 0.9985, sd) * day);

	// Paper moon with a darker bite taken out of it.
	vec3 side = normalize(cross(moon, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	float bite = smoothstep(0.9983, 0.9988, dot(dir, normalize(moon + side * 0.011)));
	float mdisk = smoothstep(0.9983, 0.9988, md);
	base = mix(base, moon_ink.rgb * (1.0 - 0.38 * bite), mdisk * night);

	if (night > 0.01) {
		vec2 suv = SKY_COORDS * vec2(520.0, 260.0);
		vec2 cell = floor(suv);
		float h = fract(sin(dot(cell, vec2(31.7, 75.1))) * 13275.5);
		float twinkle = 0.72 + 0.28 * sin(t * 2.2 + h * 60.0);
		float star = step(0.984, h) * (1.0 - smoothstep(0.05, 0.28, length(fract(suv) - 0.5)));
		vec3 tint = mix(vec3(0.85, 0.90, 1.0), vec3(1.0, 0.92, 0.78), fract(h * 37.0));
		base += tint * star * twinkle * height * 0.75 * night;
		// A faint band of far stars.
		float lane = exp(-pow(dot(dir, normalize(vec3(0.35, 0.75, 0.55))) * 3.4, 2.0));
		float dust = texture(paper_noise, dir.xz * 1.6 + 0.3).r;
		base += vec3(0.36, 0.42, 0.62) * lane * smoothstep(0.35, 0.8, dust) * 0.09 * night * smoothstep(0.1, 0.4, height);
	}

	// Light that dominates the clouds: the sun by day, the moon by night.
	vec3 lamp = light_ink.rgb * day + moon_ink.rgb * night * 0.8;
	vec2 ldir = normalize(mix(sun.xz, moon.xz, night) + vec2(0.0001, 0.0));
	float align = pow(max(mix(sd, md, night), 0.0), 3.0);
	vec3 ink = cloud_ink.rgb;
	vec3 shade = mix(ink * 0.60, zenith.rgb * 0.85, 0.30);
	shade = mix(shade, shade * vec3(0.55, 0.58, 0.65), storm);
	// Sunset: undersides glow warm and the paper blushes.
	float blush = glow_amount * (1.0 - storm);
	shade += glow_ink.rgb * 0.32 * blush;
	vec3 mid = mix(ink, glow_ink.rgb * 0.92, blush * 0.45);
	vec3 lit = mix(ink, lamp, 0.5 + 0.3 * glow_amount) * (1.0 + 0.12 * day);
	lit = mix(lit, ink * 0.85, storm * 0.55);

	float fade = smoothstep(-0.02, 0.10, dir.y);
	float haze = 1.0 - smoothstep(0.0, 0.30, height);
	vec3 col = base;
	float cloudiness = 0.0;
	float body;

	if (layers >= 3) {
	vec2 uvh = dir.xz / (0.52 + height) * vec2(0.34, 0.5) + offset * 1.7 + wind * t * 0.55;
	vec4 hi = cloud_layer(uvh, mix(0.64, 0.40, storm), 0.05, ldir, shade, mid, lit, lamp, align, 1.2, body);
	col = mix(col, mix(hi.rgb, horizon.rgb, haze * 0.45), hi.a * fade * 0.55);
	cloudiness = max(cloudiness, body * 0.4);
	}

	vec2 uvm = dir.xz / (0.38 + height) * 0.73 + offset + wind * t;
	vec4 mc = cloud_layer(uvm, cover, 0.03, ldir, shade, mid, lit, lamp, align, 1.5, body);
	col = mix(col, mix(mc.rgb, horizon.rgb, haze * 0.35), mc.a * fade * 0.92);
	cloudiness = max(cloudiness, body);

	if (layers >= 2) {
	vec2 uvl = dir.xz / (0.24 + height) * 1.05 + offset * 0.6 + wind * t * 1.7 + vec2(0.37, 0.11);
	vec4 lo = cloud_layer(uvl, mix(0.69, 0.36, storm), 0.035, ldir, shade, mid, lit, lamp, align, 1.3, body);
	col = mix(col, mix(lo.rgb, horizon.rgb, haze * 0.3), lo.a * fade * mix(0.9, 0.97, storm));
	cloudiness = max(cloudiness, body);
	}
	cloudiness = max(cloudiness, body);

	// Distant rain curtains hanging under a storm deck.
	if (storm > 0.01) {
		float a = atan(dir.z, dir.x);
		float streak = texture(paper_noise, vec2(a * 0.9, t * 0.006 + 0.37)).r;
		float curtain = smoothstep(0.45, 0.75, streak) * (1.0 - smoothstep(0.0, 0.24, height)) * storm;
		col = mix(col, shade * 0.9, curtain * 0.45 * fade);
	}

	// Lamp glow bleeds through the paper.
	float s0 = max(sd, 0.0);
	float m0 = max(md, 0.0);
	float bloom_s = pow(s0, 7.0) * 0.30 + pow(s0, 60.0) * 0.55 + pow(s0, 500.0) * 0.8;
	float bloom_m = pow(m0, 40.0) * 0.22 + pow(m0, 400.0) * 0.5;
	vec3 bloom = light_ink.rgb * bloom_s * day * (1.0 - 0.75 * storm) + moon_ink.rgb * bloom_m * night;
	col += bloom * mix(1.0, 0.5, cloudiness);

	if (layers >= 2) {
	// Light shafts fan out from the lamp, strongest where cloud breaks up.
	vec3 L = normalize(mix(sun, moon, night));
	float ld = max(dot(dir, L), 0.0);
	vec3 up = abs(L.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 u = normalize(cross(L, up));
	vec3 v = cross(L, u);
	vec3 dd = dir - L * dot(dir, L);
	float ang = atan(dot(dd, v), dot(dd, u));
	float n1 = texture(paper_noise, vec2(cos(ang), sin(ang)) * 0.28 + 0.5 + vec2(t * 0.0025, 0.0)).r;
	float ray = smoothstep(0.40, 0.72, n1);
	float vis = (0.25 + 0.75 * cloudiness) * (1.0 - storm * 0.6) * smoothstep(-0.12, 0.05, L.y);
	float strength = mix(0.30 + 0.5 * glow_amount, 0.20, night);
	col += lamp * ray * pow(ld, 3.0) * vis * strength * fade;
	}

	if (rainbow > 0.0 && sun.y > 0.0) {
		float ang = acos(clamp(dot(dir, -sun), -1.0, 1.0));
		float k = (ang - 0.69) / 0.1;
		if (k > 0.0 && k < 1.0 && dir.y > 0.02) {
			vec3 rc = clamp(abs(fract(vec3(1.0, 0.667, 0.333) + (1.0 - k) * 0.78) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
			col = mix(col, rc, rainbow * 0.38 * sin(k * 3.14159));
		}
	}
	col += vec3(0.75, 0.82, 1.0) * flash * (0.35 + 0.65 * smoothstep(0.0, 0.5, height));
	COLOR = col;

	if (peaks) {
		float angle = atan(EYEDIR.z, EYEDIR.x) + offset.x * 4.0;
		for (int layer = 0; layer < 2; layer++) {
			float a = angle + float(layer) * 1.7;
			float ridge = 0.045 + 0.14 * abs(fract(a*3.0/6.2831853)*2.0-1.0) + 0.075 * abs(fract(a*9.0/6.2831853)*2.0-1.0) + 0.032 * abs(fract(a*23.0/6.2831853)*2.0-1.0);
			ridge *= layer == 0 ? 1.0 : 0.62;
			vec3 rock = mix(horizon.rgb, zenith.rgb * 0.58, layer == 0 ? 0.32 : 0.55);
			float facing = smoothstep(-0.1, 0.1, sin(a*7.0)*cos(a*7.0));
			rock *= mix(0.89, 1.06, facing);
			if (snowcaps && layer == 0 && EYEDIR.y > ridge * 0.65 + 0.035) {
				rock = mix(rock, horizon.rgb, 0.65 + 0.16*facing);
			}
			COLOR = mix(COLOR, rock, 1.0 - smoothstep(ridge-0.001, ridge+0.001, EYEDIR.y));
		}
	}
}
