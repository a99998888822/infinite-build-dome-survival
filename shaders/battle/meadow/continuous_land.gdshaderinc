// One sampling path for the world ground, skyline fill, and distant ruin roots.
uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 view_size = vec2(1152.0,768.0);
uniform vec2 world_screen_origin;
uniform vec2 world_screen_x = vec2(1.0,0.0);
uniform vec2 world_screen_y = vec2(0.0,1.0);
uniform vec2 sample_offset = vec2(1056.0,728.0);
uniform float horizon_y = 72.0;

vec3 continuous_land(vec2 screen) {
	vec2 world = world_screen_origin+world_screen_x*screen.x+world_screen_y*screen.y;
	float distance = 1.0-smoothstep(horizon_y-12.0,horizon_y+110.0,screen.y);
	// A smooth change in texture density, with no secondary tile or UV reset.
	float remaining = 1.0-clamp((screen.y-horizon_y)/120.0,0.0,1.0);
	world += world_screen_y*(-43.333333*remaining*remaining*remaining);
	vec3 color = texture(ground_texture,(floor(world)+sample_offset+vec2(.5))/vec2(textureSize(ground_texture,0))).rgb;
	color = mix(color,vec3(.15,.18,.13),distance*.12);
	return color*(1.0-distance*.08);
}

float land_hash(float n) { return fract(sin(n*127.1+311.7)*43758.5453); }
float land_noise(float x) {
	float cell = floor(x);
	return mix(land_hash(cell),land_hash(cell+1.0),smoothstep(0.0,1.0,fract(x)));
}
float land_edge(float screen_x) {
	float x = screen_x+world_screen_origin.x*.12;
	return horizon_y-12.0+floor((land_noise(x/86.0)*9.0+land_noise(x/17.0)*3.0)/2.0)*2.0;
}
