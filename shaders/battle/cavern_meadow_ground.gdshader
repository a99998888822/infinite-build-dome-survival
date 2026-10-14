shader_type canvas_item;
render_mode unshaded;
uniform sampler2D surface_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 sample_offset = vec2(1056.0,728.0);
uniform float projection_y = .6590909;
uniform vec2 view_size = vec2(1280.0,720.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}

void fragment() {
	// Reuse the production surface with an explicit ground-plane projection.
	// A fixed source pixel grid retains crispness at every camera position.
	vec2 source_point = vec2(world_point.x,world_point.y/projection_y)+sample_offset;
	source_point = floor(source_point/3.0)*3.0+vec2(1.5);
	vec3 source = texture(surface_texture,source_point/vec2(textureSize(surface_texture,0))).rgb;
	float luminance = dot(source,vec3(.2126,.7152,.0722));
	float light = floor(clamp((luminance-.19)/.23,0.0,1.0)*7.0+.5)/7.0;
	float moss = clamp((source.g-source.r)*8.0+(source.g-source.b)*7.0,0.0,1.0);
	vec3 color = mix(vec3(.205,.210,.217),vec3(.38,.375,.32),light);
	color += moss*vec3(-.006,.021,-.015);
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR = vec4(color,depth);
}
