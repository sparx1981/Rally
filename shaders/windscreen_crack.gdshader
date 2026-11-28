// Cracks in laminated glass. The strips lie flush on the windscreen; each crack is a thin prism of broken glass, so
// the view behind it is bent sideways (more at the edges of the strip, in opposite directions on either side) and
// the edges catch the light. A frosted patch around the impact point scatters the view slightly and turns it milky.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bend = 0.014;          // refraction strength across a crack (screen UV)
uniform float frost = 0.012;         // blur radius of the frosted impact patch (screen UV)
uniform vec3 glint : source_color = vec3(0.92, 0.96, 1.0);

varying vec2 perp_view;
varying vec2 st;
varying float is_frost;

void vertex() {
	vec3 d = COLOR.rgb * 2.0 - 1.0;
	vec3 dv = (MODELVIEW_MATRIX * vec4(d, 0.0)).xyz;
	perp_view = dv.xy / max(length(dv.xy), 1e-4);
	st = UV;
	is_frost = COLOR.a;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void fragment() {
	if (is_frost > 0.5) {
		float r = clamp(st.x, 0.0, 1.0);
		float fall = 1.0 - smoothstep(0.15, 1.0, r);
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float a = float(i) * 1.0472 + hash(SCREEN_UV * 91.0) * 0.6;
			acc += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * frost * fall).rgb;
		}
		acc /= 6.0;
		ALBEDO = mix(acc, glint, 0.16 * fall);
		ALPHA = 0.9 * fall;
	} else {
		float e = clamp(st.x, -1.0, 1.0);          // -1 .. 1 across the crack
		float body = 1.0 - smoothstep(0.55, 1.0, abs(e));
		vec2 off = perp_view * e * bend * (1.0 - 0.4 * abs(e));
		vec3 bg = texture(screen_tex, SCREEN_UV + off).rgb;
		// Light catches the lit-side wall of the break; the other wall goes slightly dark.
		float lit = smoothstep(-0.2, 0.9, e);
		vec3 col = mix(bg * 0.78, glint, 0.30 + 0.55 * lit * lit);
		// The core of the crack is a hairline of bright scatter.
		col = mix(col, glint, 0.5 * (1.0 - smoothstep(0.0, 0.25, abs(e))));
		ALBEDO = col;
		ALPHA = body;
	}
}
