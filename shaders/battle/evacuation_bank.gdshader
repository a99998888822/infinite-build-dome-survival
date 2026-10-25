shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 object_root;
uniform float night = 0.0;
varying vec2 world_point;

bool palette_color(vec3 color, vec3 rgb) {
	return distance(color, rgb / 255.0) < .005;
}

void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	bool grass = palette_color(source.rgb,vec3(34,49,32)) || palette_color(source.rgb,vec3(53,71,41)) || palette_color(source.rgb,vec3(72,93,53));
	bool lamp = palette_color(source.rgb,vec3(154,172,110)) || palette_color(source.rgb,vec3(89,114,70));
	// Match the field rocks: grey-green lit faces and muted violet shadows.
	// Select only the four stone inks, preserving wood, metal, coins and outlines.
	vec3 base = source.rgb;
	bool stone = true;
	if (palette_color(source.rgb,vec3(148,137,139))) base = vec3(104,119,109)/255.0;
	else if (palette_color(source.rgb,vec3(122,112,118))) base = vec3(85,99,94)/255.0;
	else if (palette_color(source.rgb,vec3(91,86,94))) base = vec3(63,69,76)/255.0;
	else if (palette_color(source.rgb,vec3(63,62,70))) base = vec3(46,44,58)/255.0;
	else stone = false;
	if (stone) {
		// A little ground bounce at the wall feet; leave the central steps clear.
		float wall_foot = smoothstep(.52,.83,UV.y)*(1.0-smoothstep(.87,.95,UV.y));
		wall_foot *= smoothstep(.16,.28,abs(UV.x-.52));
		float value = max(base.r,max(base.g,base.b));
		base = mix(base,vec3(.78,.92,.76)*value,wall_foot*.22);
	}
	float height = max(0.0,object_root.y-world_point.y);
	vec2 plane = grass ? ground_plane(world_point) : ground_plane(vec2(world_point.x,object_root.y))-vec2(.42,.32)*height;
	// Keep the same environmental response as nearby scenery through dusk.
	vec3 color = receive_sun(base,plane,.40,1.0);
	if (lamp) color = mix(color,vec3(.38,.74,.84),night*.93);
	COLOR = vec4(color,source.a);
}
