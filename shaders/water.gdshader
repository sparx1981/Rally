// Short wind ripples ride on longer downstream swells. Fade the fine pattern
// with its screen footprint to keep distant water stable in chase view.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 paper_tint : source_color = vec4(1.0);
varying vec2 sheet;
varying vec3 across_view;
varying vec3 downstream_view;

void vertex() {
	sheet = VERTEX.xz;
	across_view = normalize((MODELVIEW_MATRIX * vec4(1., 0., 0., 0.)).xyz);
	downstream_view = normalize((MODELVIEW_MATRIX * vec4(0., 0., 1., 0.)).xyz);
}

void fragment() {
	vec2 p = sheet;
	float swell = p.y * 1.7 - TIME * 1.2 + 1.4 * sin(p.x * 0.72 + p.y * 0.17);
	float ripple = p.y * 5.2 - TIME * 3.2 + 1.8 * sin(p.x * 1.6 - p.y * 0.4);
	float detail = 1.0 - smoothstep(0.15, 1.2, fwidth(ripple));
	float slope = cos(swell) * 0.058 + cos(ripple) * 0.046 * detail;
	NORMAL = normalize(NORMAL + downstream_view * slope + across_view * 0.036 * sin(p.x * 1.3 + swell));
	float sky = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float crest = smoothstep(0.85, 0.99, sin(ripple)) * smoothstep(0.2, 0.92, sin(swell)) * detail;
	vec3 base = COLOR.rgb * paper_tint.rgb;
	ALBEDO = mix(base, vec3(0.57, 0.69, 0.71), sky * 0.42) + crest * 0.105;
	SPECULAR = 0.32;
	ROUGHNESS = 0.40;
}
