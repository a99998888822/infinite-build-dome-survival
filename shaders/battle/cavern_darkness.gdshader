shader_type canvas_item;
render_mode unshaded;
uniform float darkness_end = 180.0;
uniform float reveal_end = 235.0;
uniform float view_height = 720.0;
void fragment() {
	// Composite above the entire combat viewport, including enemy tips, status
	// effects and shadows. Monsters can never draw over the ultra-far caves.
	float opacity = 1.0-smoothstep(darkness_end,reveal_end,SCREEN_UV.y*view_height);
	COLOR = vec4(vec3(.051,.039,.071),opacity);
}
