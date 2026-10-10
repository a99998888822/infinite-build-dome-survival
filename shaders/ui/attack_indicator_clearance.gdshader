shader_type canvas_item;
render_mode unshaded;
uniform vec2 cast_origin = vec2(0.0);
uniform float clearance = 34.0;
uniform bool cast_available = true;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = floor((world_point - cast_origin) / 2.0);
	vec2 pixel_center = (cell + vec2(0.5)) * 2.0;
	// Reject the whole cell near the player, including its inward corner.
	if (length(pixel_center) < clearance + 1.414214) {
		discard;
	}
	// Pattern only the low-alpha fill; the two hard outline colors stay solid.
	if (COLOR.a < 0.3) {
		float pattern = mod(cell.x + cell.y, cast_available ? 8.0 : 6.0);
		COLOR.a *= cast_available ? (pattern < 1.0 ? 1.35 : 0.65) : (pattern < 2.0 ? 1.75 : 0.30);
	}
}
