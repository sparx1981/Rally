// Overlapping cut-paper cloud layers, sampled from the stage's seamless noise.
shader_type sky;
uniform vec4 horizon : source_color;
uniform vec4 zenith : source_color;
uniform vec4 cloud_ink : source_color;
uniform vec4 light_ink : source_color;
uniform vec3 light_dir;
uniform vec2 offset;
uniform float cover;
uniform bool night;
uniform sampler2D paper_noise : repeat_enable, filter_linear_mipmap;

void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 base = mix(horizon.rgb, zenith.rgb, smoothstep(-0.06, 0.75, height));
	vec2 uv = EYEDIR.xz / (0.38 + height) * 0.73 + offset;
	float cloud = texture(paper_noise, uv).r * 0.75 + texture(paper_noise, uv * 2.84).r * 0.25;
	float sheets = smoothstep(cover, cover + 0.028, cloud);
	float rim = smoothstep(cover + 0.09, cover + 0.12, cloud);
	float disk = smoothstep(0.9980, 0.9986, dot(EYEDIR, light_dir));
	base = mix(base, light_ink.rgb, disk);
	if (night) {
		vec2 star_uv = SKY_COORDS * vec2(480.0, 240.0);
		float hash = fract(sin(dot(floor(star_uv),vec2(31.7, 75.1))) * 13275.5);
		base += step(0.984, hash) * (1.0 - smoothstep(0.06, 0.27, length(fract(star_uv)-0.5))) * height * 0.53;
	}
	COLOR = mix(base, mix(cloud_ink.rgb, horizon.rgb, rim * 0.30), sheets * smoothstep(-0.015, 0.12, EYEDIR.y) * 0.86);
}
