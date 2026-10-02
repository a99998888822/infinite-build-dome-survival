shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/continuous_land.gdshaderinc"
uniform float distance_fraction = .5; // 0 far, 1 near.
uniform float edge_fade = 1.0;
uniform float root_uv = .95;
void fragment() {
	float pixel_step = distance_fraction<.32 ? 2.0 : 1.0;
	vec2 cell = TEXTURE_PIXEL_SIZE*pixel_step;
	vec4 source = texture(TEXTURE,(floor(UV/cell)+vec2(.5))*cell);
	float gray = dot(source.rgb,vec3(.299,.587,.114));
	vec3 color = mix(source.rgb,vec3(gray),.16*(1.0-distance_fraction));
	color *= mix(.55,.88,distance_fraction);
	vec3 ground = continuous_land(SCREEN_UV*view_size);
	color = mix(color,ground,.12+smoothstep(root_uv-.06,root_uv,UV.y)*.28);
	COLOR = vec4(color,source.a*edge_fade);
}
