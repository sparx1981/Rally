shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 ink : source_color = vec3(0.20, 0.17, 0.14);
uniform float opacity = 0.25;
uniform vec2 wheel_center = vec2(0.40, 0.32);

void fragment() {
	vec2 p = abs(UV - vec2(0.5));
	vec2 q = max(p - vec2(0.24, 0.27), vec2(0.0));
	float shell = 1.0 - smoothstep(0.015, 0.30, length(q * vec2(1.0, 1.25)));
	vec2 translated = (p - wheel_center) * vec2(1.0, 1.2);
	float tyres = 1.0 - smoothstep(0.035, 0.145, length(translated));
	ALBEDO = ink;
	ALPHA = max(shell * 0.64, tyres) * opacity;
}
