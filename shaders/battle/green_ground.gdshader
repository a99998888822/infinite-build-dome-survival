shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 world_origin;
uniform vec2 surface_size;
uniform vec2 sample_offset;

void fragment() {
	vec2 pixel = floor(UV * surface_size + world_origin) + sample_offset;
	COLOR = texture(ground_texture, (pixel + vec2(0.5)) / vec2(textureSize(ground_texture, 0)));
}
