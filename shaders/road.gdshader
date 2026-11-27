// The rally road: a printed strip with a dark cut edge, a pale verge lip, wheel ruts and gravel
// speckle. UV.x runs across the road (0..1), UV.y along it in road widths.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/surface.gdshaderinc"

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.3;
uniform vec3 road : source_color = vec3(0.79, 0.67, 0.49);
uniform vec3 rut : source_color = vec3(0.66, 0.54, 0.38);
uniform vec3 edge_col : source_color = vec3(0.3, 0.2, 0.12);
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D fibre : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float fibre_amount = 0.09;
uniform float wet = 0.0;
uniform int surface_kind = 2;
uniform float detail = 1.0;
uniform vec3 lamp_pts[8];
uniform int lamp_n = 0;
uniform float refl = 0.0;

varying vec3 wpos;
varying float vdist;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vdist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec3 c = road;
	if (COLOR.r < 0.5) {
		// Side strip of the road card: darker print.
		c = road * 0.52;
	} else {
		float u = UV.x;
		float wob = (texture(noise, vec2(UV.y * 0.05, 0.5)).r - 0.5) * 0.06;
		float r1 = 1.0 - smoothstep(0.0, 0.05, abs(u - 0.3 - wob));
		float r2 = 1.0 - smoothstep(0.0, 0.05, abs(u - 0.7 - wob));
		c = mix(c, rut, clamp(r1 + r2, 0.0, 1.0) * 0.8);
		float sp = texture(noise, wpos.xz * 0.9).r;
		c *= 1.0 + (step(0.62, sp) * 0.08 - step(sp, 0.36) * 0.07);
		// Wet patches: a darker value step, never gloss.
		float wp = smoothstep(0.55, 0.6, texture(noise, wpos.xz * 0.03 + vec2(0.2, 0.9)).r);
		c *= 1.0 - wet * wp * 0.18;
		float e = min(u, 1.0 - u);
		c = mix(c, mix(road, vec3(1.0, 0.97, 0.9), 0.4), (1.0 - smoothstep(0.012, 0.03, e)) * 0.7);
		c = mix(c, edge_col, 1.0 - smoothstep(0.004, 0.012, e));
		if (fibre_amount > 0.0) {
			float f = texture(fibre, wpos.xz * 0.5).r * 0.6 + texture(fibre, wpos.xz * 1.83 + vec2(0.37, 0.11)).r * 0.4;
			c *= 1.0 + (f - 0.5) * fibre_amount * 2.0;
		}
	}
	if (COLOR.r >= 0.5 && detail > 0.0) {
		vec2 tilt;
		vec3 rich = surf_detail(surface_kind, wpos, vdist, c, wet, tilt);
		c = mix(c, rich, detail);
		vec3 nw = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		nw = normalize(nw + vec3(tilt.x, 0.0, tilt.y) * detail);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Wet night road: lamps mirrored in the water, broken up by puddle patches.
	if (refl > 0.0 && wet > 0.0 && lamp_n > 0) {
		vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 v = normalize(cam - wpos);
		vec3 rv = reflect(-v, vec3(0.0, 1.0, 0.0));
		float puddle = 0.55 + 0.45 * smoothstep(0.35, 0.6, texture(noise, wpos.xz * 0.05 + vec2(0.7, 0.3)).r);
		vec3 sp = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			if (i >= lamp_n) break;
			vec3 d = lamp_pts[i] - wpos;
			float dist = length(d);
			sp += vec3(1.0, 0.82, 0.55) * pow(max(dot(rv, d / dist), 0.0), 38.0) / (1.0 + dist * 0.02);
		}
		EMISSION += sp * refl * puddle * wet * 1.5;
	}
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
