// A road or sector surface with procedural detail (see surface.gdshaderinc). Vertex colour is the base
// print (including the faded sector ends and racing grooves); the detail rides on top.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/surface.gdshaderinc"

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.3;
uniform int kind = 2;
uniform float wet = 0.0;
uniform float strength = 1.0;

varying vec3 wpos;
varying float vdist;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vdist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 tilt;
	vec3 c = surf_detail(kind, wpos, vdist, COLOR.rgb, wet, tilt);
	ALBEDO = mix(COLOR.rgb, c, strength);
	vec3 nw = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	nw = normalize(nw + vec3(tilt.x, 0.0, tilt.y) * strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float front = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 shadowed = mix(leak, vec3(1.0), ATTENUATION);
		DIFFUSE_LIGHT += front * LIGHT_COLOR * shadowed / PI;
	} else {
		DIFFUSE_LIGHT += front * LIGHT_COLOR * ATTENUATION / PI;
	}
}
