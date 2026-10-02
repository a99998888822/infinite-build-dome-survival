shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/continuous_land.gdshaderinc"
void fragment() {
	vec2 screen = SCREEN_UV*view_size;
	COLOR = vec4(continuous_land(screen),step(land_edge(screen.x),screen.y));
}
