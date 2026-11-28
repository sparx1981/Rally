// Loading screen backdrop: the painted sky drifts and breathes a little. Only the sky moves; the car, ground and
// (on the boot screen) the baked title are masked out so they stay perfectly still.
shader_type canvas_item;

uniform sampler2D drift_noise : repeat_enable, filter_linear;
uniform vec4 protect = vec4(0.0);   // uv rectangle (x0, y0, x1, y1) that must not move
uniform float amount = 0.0055;

void fragment() {
	vec2 uv = UV;
	float sky = smoothstep(0.47, 0.30, uv.y);
	// Keep the title / car area still, with a soft edge.
	vec2 pc = (uv - (protect.xy + protect.zw) * 0.5) / max((protect.zw - protect.xy) * 0.5, vec2(0.0001));
	float inside = 1.0 - smoothstep(0.85, 1.25, max(abs(pc.x), abs(pc.y)));
	if (protect.z > 0.0) {
		sky *= 1.0 - inside;
	}
	vec2 n = texture(drift_noise, uv * vec2(1.4, 0.9) + vec2(TIME * 0.007, TIME * 0.003)).rg - 0.5;
	vec2 o = n * amount * 2.0;
	o.x += sin(TIME * 0.18 + uv.y * 7.0) * amount * 0.5;
	o.y += sin(TIME * 0.13 + uv.x * 5.0) * amount * 0.25;
	COLOR = texture(TEXTURE, uv + o * sky);
}
