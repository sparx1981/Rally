// A slow band of reflected sky sliding across the windscreen, with a faint second band behind it.
shader_type canvas_item;
render_mode blend_add;

uniform float period = 7.0;
uniform float strength = 0.34;

void fragment() {
	float t = fract(TIME / period);
	float pos = mix(-0.5, 1.6, t);
	float d = UV.x + UV.y * 0.55 - pos;
	float band = exp(-d * d * 55.0) + 0.35 * exp(-(d + 0.22) * (d + 0.22) * 90.0);
	float sky = mix(0.55, 1.0, 1.0 - UV.y);        // brighter towards the top of the glass
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	vec3 col = mix(vec3(1.0, 0.86, 0.70), vec3(1.0, 0.72, 0.62), UV.y);
	COLOR = vec4(col * band * sky * edge * strength, 1.0);
}
