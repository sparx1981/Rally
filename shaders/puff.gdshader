// Volumetric paper puffs (dust, smoke, spray, chimney smoke): faceted 3D crumpled-paper balls,
// lit with the same wrap / leak model as the cards so they have real volume and shading.
shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_lambert, specular_disabled, cull_back;

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.85;
uniform vec3 tint : source_color = vec3(1.0);

void vertex() {
	// Every authored puff is under two metres. Reject a corrupt or singular
	// instance before rasterisation, including incomplete mobile instance data.
	float span = max(length(MODEL_MATRIX[0].xyz),max(length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz)));
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	POSITION = (span > 0.0001 && span < 3.0)
		? PROJECTION_MATRIX * view_pos : vec4(2.0,2.0,2.0,1.0);
}

void fragment() {
	if (length(VERTEX)<2.2) { discard; }
	ALBEDO = tint;
	ALPHA = clamp(COLOR.a, 0.0, 1.0);   // the emitter's colour ramp fades each puff in and out
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float front = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += front * LIGHT_COLOR * mix(leak, vec3(1.0), ATTENUATION) / PI;
	} else {
		DIFFUSE_LIGHT += front * LIGHT_COLOR * ATTENUATION / PI;
	}
}
