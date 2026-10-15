shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/cavern_pit_palette.gdshaderinc"
uniform float darkness_end = 174.0;
uniform float reveal_end = 222.0;
uniform float view_height = 720.0;
uniform float art_scale = 1.666667;
uniform float top_arc_height = 72.0;

void fragment() {
	// Two sections of a broad ellipse enclose the sunlit floor. Keep the
	// centre open; the pit walls cast a deeper shadow down both sides.
	float x = clamp((SCREEN_UV.x-.5)/.62,-1.0,1.0);
	float arc = 1.0-sqrt(max(0.0,1.0-x*x));
	float y = SCREEN_UV.y*view_height;
	float top_offset = arc*top_arc_height*art_scale;
	// Both ends follow the same ellipse, preserving the curved pit boundary.
	float top = 1.0-smoothstep(darkness_end+top_offset,reveal_end+top_offset,y);
	float bottom_offset = arc*40.0*art_scale;
	float bottom = smoothstep(view_height-18.0*art_scale-bottom_offset,
		view_height+6.0*art_scale-bottom_offset,y)*.45;
	COLOR = vec4(CAVE_MATTE,1.0-(1.0-top)*(1.0-bottom));
}
