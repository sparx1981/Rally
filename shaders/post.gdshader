// One post pass (papercraft skill look.md 6-7): a tilt-shift macro-lens blur band driven by screen
// height, then a mild grade: white-balance tint, contrast, saturation, a hue-masked pull on
// video-game yellow-greens, shadow lift toward the world's tint, a warm vignette and light grain.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform int taps = 12;
uniform float focus_y = 0.56;
uniform float band = 0.36;
uniform float ramp = 0.3;
uniform float max_blur_px = 9.0;
uniform float near_gain = 1.5;
uniform float exposure = 1.0;
uniform float contrast = 1.1;
uniform float saturation = 0.97;
uniform vec3 tint = vec3(1.03, 0.985, 0.97);
uniform float green_pull = 0.3;
uniform vec3 shadow_tint : source_color = vec3(0.23, 0.13, 0.05);
uniform float vignette = 0.08;
uniform vec3 vig_color : source_color = vec3(0.23, 0.13, 0.05);
uniform float grain = 0.01;
uniform float shimmer = 0.0;       // 0..1: heat haze behind the exhaust
uniform vec2 shimmer_pos = vec2(0.5, 0.7);
uniform float speed_blur = 0.0;   // 0..1: mild radial blur toward the screen edges (High only)
uniform float bloom = 0.0;          // glow around bright areas (used for the loading art)
uniform float bloom_px = 14.0;
uniform float bloom_cut = 0.72;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 suv = uv;
	if (shimmer > 0.0) {
		// A small rising column of heat above and behind the exhaust pipe, not a screen-wide wobble.
		vec2 d = (uv - shimmer_pos) * vec2(1.0, 1.6);
		float colm = exp(-dot(d - vec2(0.0, -0.035), d - vec2(0.0, -0.035)) * 520.0);
		suv.x += sin(uv.y * 160.0 + TIME * 11.0) * 0.0042 * shimmer * colm;
		suv.y += sin(uv.x * 120.0 + TIME * 7.0) * 0.0022 * shimmer * colm;
	}
	vec3 col = texture(screen, suv).rgb;
	if (taps > 0) {
		float sy = uv.y - focus_y;
		float a = clamp((abs(sy) - band * 0.5) / ramp, 0.0, 1.0);
		a = a * a * (3.0 - 2.0 * a) * 0.35 + a * 0.65;
		float coc = min(a * (sy > 0.0 ? near_gain : 1.0), 1.0) * max_blur_px;
		if (coc > 0.5) {
			vec3 acc = col;
			float wsum = 1.0;
			for (int i = 0; i < 24; i++) {
				if (i >= taps) break;
				float fi = float(i);
				float r = pow((fi + 0.5) / float(taps), 0.75) * coc;
				float ang = fi * 2.39996 + hash(uv * 311.0) * 0.6;
				vec2 o = vec2(cos(ang), sin(ang)) * r * SCREEN_PIXEL_SIZE;
				vec3 s = texture(screen, uv + o).rgb;
				float w = pow(max(r, 0.5), 0.667) * (1.0 + dot(s, vec3(0.3)) * 0.4);
				acc += s * w;
				wsum += w;
			}
			col = acc / wsum;
		}
	}
	if (speed_blur > 0.01) {
		vec2 dv = uv - vec2(0.5);
		float edge = smoothstep(0.22, 0.75, length(dv * vec2(1.0, 1.15)));
		vec3 acc2 = col;
		for (int k = 1; k <= 4; k++) {
			float kk = float(k) * 0.011 * speed_blur * edge;
			acc2 += texture(screen, uv - dv * kk).rgb;
		}
		col = mix(col, acc2 / 5.0, clamp(edge * speed_blur * 1.2, 0.0, 1.0));
	}
	if (bloom > 0.0) {
		vec3 glow = vec3(0.0);
		for (int ring = 1; ring <= 3; ring++) {
			float rr = bloom_px * float(ring) * 0.6;
			for (int k = 0; k < 10; k++) {
				float a = float(k) * 0.6283 + float(ring) * 0.4;
				vec3 sm = texture(screen, uv + vec2(cos(a), sin(a)) * rr * SCREEN_PIXEL_SIZE).rgb;
				glow += max(sm - vec3(bloom_cut), vec3(0.0)) / float(ring);
			}
		}
		col += glow * bloom * 0.28;
	}
	col *= exposure * tint;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.42) * contrast + 0.42;
	// Pull saturated yellow-green toward a muted paper green.
	float gm = smoothstep(0.1, 0.3, col.g - col.b) * smoothstep(-0.2, -0.05, col.g - col.r) * green_pull;
	col = mix(col, mix(vec3(l), col, 0.45) * vec3(0.97, 1.0, 1.03), gm);
	col += shadow_tint * 0.03 * (1.0 - smoothstep(0.0, 0.45, l));
	vec2 d = uv - 0.5;
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.25, 1.0)));
	col = mix(col, vig_color, v * vignette);
	col += (hash(uv * 977.0 + fract(TIME)) - 0.5) * grain * (1.0 - l * 0.5);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
