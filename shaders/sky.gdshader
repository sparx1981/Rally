// Overlapping cut-paper cloud layers, sampled from the stage's seamless noise.
shader_type sky;
uniform vec4 horizon : source_color;
uniform vec4 zenith : source_color;
uniform vec4 cloud_ink : source_color;
uniform vec4 light_ink : source_color;
uniform vec3 light_dir;
uniform vec2 offset;
uniform float cover;
uniform float night_amount;
uniform vec3 moon_dir;
uniform bool peaks;
uniform bool snowcaps;
uniform sampler2D paper_noise : repeat_enable, filter_linear_mipmap;

void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 base = mix(horizon.rgb, zenith.rgb, smoothstep(-0.06, 0.75, height));
	vec2 uv = EYEDIR.xz / (0.38 + height) * 0.73 + offset;
	float cloud = texture(paper_noise, uv).r * 0.75 + texture(paper_noise, uv * 2.84).r * 0.25;
	float sheets = smoothstep(cover, cover + 0.028, cloud);
	float rim = smoothstep(cover + 0.09, cover + 0.12, cloud);
	float disk = smoothstep(0.9980, 0.9986, dot(EYEDIR, light_dir));
	base = mix(base, light_ink.rgb, disk * (1.0 - night_amount));
	float moon = smoothstep(0.9985, 0.9991, dot(EYEDIR, moon_dir));
	base = mix(base, vec3(0.86, 0.89, 0.97), moon * night_amount);
	if (night_amount > 0.0) {
		vec2 star_uv = SKY_COORDS * vec2(480.0, 240.0);
		float hash = fract(sin(dot(floor(star_uv),vec2(31.7, 75.1))) * 13275.5);
		base += step(0.984, hash) * (1.0 - smoothstep(0.06, 0.27, length(fract(star_uv)-0.5))) * height * 0.53 * night_amount;
	}
	COLOR = mix(base, mix(cloud_ink.rgb, horizon.rgb, rim * 0.30), sheets * smoothstep(-0.015, 0.12, EYEDIR.y) * 0.86);

	if (peaks) {
		float angle = atan(EYEDIR.z, EYEDIR.x) + offset.x * 4.0;
		for (int layer = 0; layer < 2; layer++) {
			float a = angle + float(layer) * 1.7;
			float ridge = 0.045 + 0.14 * abs(fract(a*3.0/6.2831853)*2.0-1.0) + 0.075 * abs(fract(a*9.0/6.2831853)*2.0-1.0) + 0.032 * abs(fract(a*23.0/6.2831853)*2.0-1.0);
			ridge *= layer == 0 ? 1.0 : 0.62;
			vec3 rock = mix(horizon.rgb, zenith.rgb * 0.58, layer == 0 ? 0.32 : 0.55);
			float facing = smoothstep(-0.1, 0.1, sin(a*7.0)*cos(a*7.0));
			rock *= mix(0.89, 1.06, facing);
			if (snowcaps && layer == 0 && EYEDIR.y > ridge * 0.65 + 0.035) {
				rock = mix(rock, horizon.rgb, 0.65 + 0.16*facing);
			}
			COLOR = mix(COLOR, rock, 1.0 - smoothstep(ridge-0.001, ridge+0.001, EYEDIR.y));
		}
	}
}
