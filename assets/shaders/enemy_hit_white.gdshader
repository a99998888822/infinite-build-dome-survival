shader_type canvas_item;
render_mode unshaded;

uniform float white_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Keep the current frame's silhouette and death alpha, including atlas frames.
	COLOR = vec4(mix(COLOR.rgb, vec3(1.0), white_amount), COLOR.a);
}
