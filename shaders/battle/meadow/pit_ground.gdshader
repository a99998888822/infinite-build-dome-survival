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
	vec2 source_point = vec2(world_point.x,world_point.y/projection_y)+sample_offset;
	vec3 surface = texture(surface_texture,source_point/vec2(textureSize(surface_texture,0))).rgb;
	// Keep the authored greens/earth colors and stable world-space texels.
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR = vec4(surface,depth);
}
