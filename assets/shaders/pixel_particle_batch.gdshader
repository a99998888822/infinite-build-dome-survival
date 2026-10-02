shader_type canvas_item;
varying float circle_shape;

void vertex() {
	circle_shape = INSTANCE_CUSTOM.r;
}

void fragment() {
	if (circle_shape > 0.5 && distance(UV, vec2(0.5)) > 0.5) {
		discard;
	}
}
