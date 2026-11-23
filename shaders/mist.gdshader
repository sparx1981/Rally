// Low mist as cut paper (papercraft skill: "mist is paper, never a fog filter"): cream cloud sheets
// lying across the valleys, cut by a drifting noise threshold with a thin darker cut edge.
// Several sheets at different heights give the mist depth.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 col : source_color = vec3(0.93, 0.92, 0.88);
uniform vec3 leak : source_color = vec3(0.4, 0.45, 0.5);
uniform float cut = 0.55;
uniform float scale = 0.006;
uniform vec2 drift = vec2(0.006, 0.003);
uniform float seed = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale + vec2(seed, seed * 0.7) + TIME * drift;
	float n = texture(noise, p).r * 0.7 + texture(noise, p * 2.7 + 0.3).r * 0.3;
	if (n < cut) {
		discard;
	}
	float edge = 1.0 - smoothstep(cut, cut + 0.02, n);
	vec3 c = mix(col, col * 0.72, edge);
	c *= 1.0 + (smoothstep(cut + 0.05, cut + 0.2, n) * 0.05);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = abs(dot(NORMAL, LIGHT));
	float front = clamp((nl + 0.6) / 1.6, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += front * LIGHT_COLOR * mix(leak, vec3(1.0), ATTENUATION) / PI;
	} else {
		DIFFUSE_LIGHT += front * LIGHT_COLOR * ATTENUATION / PI;
	}
}
