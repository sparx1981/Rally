shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 rubber : source_color;
uniform float clock_s;
varying vec3 mark;

void vertex() {
	mark = INSTANCE_CUSTOM.xyz; // wetness, time laid, wet strip flag
}

void fragment() {
	float edge = smoothstep(0.0, 0.13, min(UV.x, 1.0 - UV.x));
	float wet_alpha = mark.x * (1.0 - smoothstep(3.0, 17.0, clock_s - mark.y));
	ALBEDO = mix(rubber.rgb, vec3(0.06, 0.075, 0.08), mark.z);
	ALPHA = mix(0.60, wet_alpha * 0.53, mark.z) * edge;
}
