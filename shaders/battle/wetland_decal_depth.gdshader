shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/battle/horizon_depth.gdshaderinc"

void fragment() {
	vec4 source = COLOR;
	source.rgb = horizon_haze(source.rgb, SCREEN_UV);
	// Far loose rubble should not read as large foreground shapes on the fold.
	source.a *= mix(0.22, 1.0, horizon_nearness(SCREEN_UV));
	COLOR = source;
}
