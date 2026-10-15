shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1280.0,720.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
varying float atlas_column;
varying vec4 grass_color;

void vertex() {
	atlas_column = INSTANCE_CUSTOM.r;
	grass_color = COLOR;
	vec2 root = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float tip = UV.y * UV.y;
	// Low-amplitude, world-coherent breeze; the roots remain planted.
	VERTEX.x += sin(TIME * 1.05 + root.x * .021 + root.y * .012) * tip * 1.25;
}

void fragment() {
	// QuadMesh UVs face the opposite Y direction to Sprite2D in canvas space.
	vec2 atlas_uv = vec2((UV.x + atlas_column) * .25, 1.0-UV.y);
	// COLOR already contains the default texture sample in canvas shaders.
	// Read the atlas in vertex-adjusted UVs instead; keep instance tint separate.
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR = texture(TEXTURE,atlas_uv) * grass_color;
	COLOR.rgb *= .83+.17*depth;
	COLOR.a *= depth;
}
