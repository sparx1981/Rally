// Paper card material (papercraft skill, look.md section 2 / engines.md section 2):
// diffuse only, wrap-lit soft terminator, shadows that leak the world's colour instead of going
// grey, a quiet two-scale fibre fixed to the surface. Vertex alpha 0 marks a lit (glowing) pane.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.3;
uniform sampler2D fibre : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float fibre_amount = 0.09;
uniform float fibre_scale = 0.55;
uniform float glow = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.77, 0.35);

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (fibre_amount > 0.0) {
		vec3 an = abs(obj_n);
		vec2 uv = (an.z > an.x && an.z > an.y) ? obj_pos.xy : ((an.x > an.y) ? obj_pos.zy : obj_pos.xz);
		float f = texture(fibre, uv * fibre_scale).r * 0.6 + texture(fibre, uv * fibre_scale * 3.73 + vec2(0.37, 0.11)).r * 0.4;
		c *= 1.0 + (f - 0.5) * fibre_amount * 2.0;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float g = 1.0 - COLOR.a;
	EMISSION = c * glow_color * g * (0.35 + glow);
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float front = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 shadowed = mix(leak, vec3(1.0), ATTENUATION);
		DIFFUSE_LIGHT += front * LIGHT_COLOR * shadowed / PI;
	} else {
		// Headlights and lamps: plain wrap-lit falloff (their cone and shadow are in ATTENUATION).
		DIFFUSE_LIGHT += front * LIGHT_COLOR * ATTENUATION / PI;
	}
}
