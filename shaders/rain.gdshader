// Camera-facing streak of fixed size. Particle instances supply only their centre.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 ink : source_color = vec4(0.78,0.82,0.86,1.0);

void vertex() {
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	vec3 fall = (VIEW_MATRIX * vec4(-0.12,1.0,-0.05,0.0)).xyz;
	vec2 transverse = vec2(fall.y,-fall.x);
	transverse /= max(length(transverse),0.01);
	vec3 point = center + vec3(transverse*VERTEX.x,0.0) + fall*VERTEX.y;
	// Inactive CPU particles have zero scale. Near-plane streaks can occupy
	// most of a phone screen, so omit rain falling inside the lens envelope.
	float scale = length(MODEL_MATRIX[0].xyz);
	POSITION = (scale>0.01 && scale<2.0 && center.z < -1.3)
		? PROJECTION_MATRIX*vec4(point,1.0) : vec4(2.0,2.0,2.0,1.0);
}

void fragment() {
	ALBEDO = ink.rgb;
}
