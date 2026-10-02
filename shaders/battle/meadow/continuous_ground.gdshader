shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/continuous_land.gdshaderinc"
void fragment() {
	COLOR = vec4(continuous_land(SCREEN_UV*view_size),1.0);
}
