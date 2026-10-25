shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 mask = texture(TEXTURE,UV);
	COLOR = vec4(.048,.058,.060,mask.r*mask.a*.58);
}
