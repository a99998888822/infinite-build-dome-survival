shader_type canvas_item;
render_mode unshaded;
uniform vec2 cast_origin = vec2(0.0);
uniform float clearance = 34.0;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (distance(world_point, cast_origin) < clearance) {
		discard;
	}
}
