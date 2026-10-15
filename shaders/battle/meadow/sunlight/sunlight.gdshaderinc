// Shared in every receiver; p is on the uncompressed world ground plane.
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform float sun_time = 0.0;
uniform vec2 sun_center = vec2(80.0, 30.0);
uniform vec2 sun_radius = vec2(1620.0, 1250.0);
const float GROUND_Y = 0.6590909;

vec2 ground_plane(vec2 p) { return vec2(p.x, p.y / GROUND_Y); }

float opening_at(vec2 p) {
	vec2 q = (p - sun_center) / sun_radius;
	float edge = texture(cloud_texture, p / 840.0 + vec2(.73, .11)).g;
	return 1.0 - smoothstep(.64 + edge*.12, 1.10 + edge*.10, length(q));
}

vec2 drifting_cloud(vec2 p) {
	return p - sun_time * vec2(34.0, 16.0);
}

float cloud_at(vec2 p) {
	vec2 uv = drifting_cloud(p) / vec2(1740.0, 1440.0) + vec2(.025, .8);
	float broad = texture(cloud_texture, uv).r;
	float detail = texture(cloud_texture, uv * 1.87 + vec2(.23, .61)).g;
	return smoothstep(.34, .60, broad*.84 + detail*.16);
}

float sun_at(vec2 p) { return opening_at(p) * (1.0 - .88 * cloud_at(p)); }

float broken_light(vec2 p) {
	// Moving cloud gaps reveal irregular islands of warm light. A smaller,
	// nearly fixed rim-vegetation mask breaks up those islands without flicker.
	vec2 drift = drifting_cloud(p);
	vec2 q = vec2(drift.x + drift.y*.30, drift.y - drift.x*.12);
	float gaps = texture(cloud_texture, q / vec2(760.0, 460.0) + vec2(.41,.19)).g;
	vec2 breeze = vec2(sin(sun_time*.55+p.y*.003)*4.0,cos(sun_time*.43)*2.0);
	float leaves = texture(cloud_texture,(p+breeze)/vec2(265.0,185.0)).g;
	return smoothstep(.39,.61,gaps*.78+leaves*.22);
}

vec3 receive_sun(vec3 base, vec2 p, float face, float strength) {
	p = floor(p / 3.0) * 3.0;
	float sun = sun_at(p);
	float patch = broken_light(p);
	float ink = smoothstep(.08, .23, max(base.r, max(base.g, base.b)));
	// Restore half the contrast removed in the last softening pass.
	vec3 shade = mix(vec3(1.0), vec3(.69, .78, .92), .375);
	vec3 lit = mix(vec3(1.0), vec3(1.21, 1.15, .99), .75);
	float direct = sun * (.48 + .52*patch);
	vec3 result = base * mix(shade, lit, direct);
	result += vec3(1.0, .90, .51) * face * ink * sun * (.0105 + .09375 * patch);
	return mix(base, result, strength);
}
