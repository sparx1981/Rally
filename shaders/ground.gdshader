// The printed ground sheet: pale, low-saturation washes in 3 tones, a fibre tooth, drifting
// cloud shadows tinted with the world's leak colour. Same paper lighting as the cards.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.3;
uniform vec3 g0 : source_color = vec3(0.86, 0.84, 0.68);
uniform vec3 g1 : source_color = vec3(0.81, 0.79, 0.6);
uniform vec3 g2 : source_color = vec3(0.9, 0.86, 0.72);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D fibre : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float fibre_amount = 0.09;
uniform float cloud_amount = 0.18;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise, p * 0.0045).r;
	float n2 = texture(noise, p * 0.011 + vec2(0.3, 0.7)).r;
	// Stepped, hand-cut looking washes instead of smooth gradients.
	float a = smoothstep(0.52, 0.56, n1);
	float b = smoothstep(0.58, 0.62, n2);
	vec3 c = mix(g0, g1, a);
	c = mix(c, g2, b * (1.0 - a * 0.5));
	// Thin darker cut line at each wash edge.
	float edge = (smoothstep(0.5, 0.52, n1) - smoothstep(0.52, 0.56, n1)) + (smoothstep(0.56, 0.58, n2) - smoothstep(0.58, 0.62, n2));
	c *= 1.0 - clamp(edge, 0.0, 1.0) * 0.08;
	if (fibre_amount > 0.0) {
		float f = texture(fibre, p * 0.5).r * 0.6 + texture(fibre, p * 1.83 + vec2(0.37, 0.11)).r * 0.4;
		c *= 1.0 + (f - 0.5) * fibre_amount * 2.0;
	}
	// Slow cloud shadows.
	float cl = texture(noise, p * 0.006 + vec2(TIME * 0.004, TIME * 0.0025)).r;
	float cs = smoothstep(0.55, 0.68, cl) * cloud_amount;
	c = mix(c, c * leak * 1.3, cs);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float front = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 shadowed = mix(leak, vec3(1.0), ATTENUATION);
	DIFFUSE_LIGHT += front * LIGHT_COLOR * shadowed / PI;
}
