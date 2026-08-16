shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 dark_tint : source_color = vec4(0.03, 0.05, 0.08, 0.62);
uniform float blur_radius = 3.0;


void fragment() {
	vec2 pixel_offset = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 blurred_color = texture(screen_texture, SCREEN_UV).rgb * 0.20;
	blurred_color += texture(screen_texture, SCREEN_UV + vec2(pixel_offset.x, 0.0)).rgb * 0.15;
	blurred_color += texture(screen_texture, SCREEN_UV - vec2(pixel_offset.x, 0.0)).rgb * 0.15;
	blurred_color += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel_offset.y)).rgb * 0.15;
	blurred_color += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel_offset.y)).rgb * 0.15;
	blurred_color += texture(screen_texture, SCREEN_UV + pixel_offset).rgb * 0.05;
	blurred_color += texture(screen_texture, SCREEN_UV - pixel_offset).rgb * 0.05;
	blurred_color += texture(screen_texture, SCREEN_UV + vec2(pixel_offset.x, -pixel_offset.y)).rgb * 0.05;
	blurred_color += texture(screen_texture, SCREEN_UV + vec2(-pixel_offset.x, pixel_offset.y)).rgb * 0.05;
	COLOR = vec4(mix(blurred_color, dark_tint.rgb, dark_tint.a), 1.0);
}
