// Volumetric paper puffs (dust, smoke, spray, chimney smoke): faceted 3D crumpled-paper balls,
// lit with the same wrap / leak model as the cards so they have real volume and shading.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform vec3 leak : source_color = vec3(0.627, 0.376, 0.172);
uniform float wrap = 0.85;
uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	// Puffs right in front of the lens (low chase, bonnet) thin out with a paper-grain dither, so
	// the car is never hidden behind its own dust.
	float d = length(VERTEX);
	float keep = smoothstep(2.5, 7.0, d);
	if (keep < 0.999) {
		vec2 g = floor(FRAGCOORD.xy * 0.5);
		float hsh = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
		if (hsh > keep) {
			discard;
		}
	}
	// Flat facets: crumpled paper, not a smooth sphere.
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = min(COLOR.rgb * tint * 1.2, vec3(1.0));
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
