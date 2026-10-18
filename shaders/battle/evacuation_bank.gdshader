shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 object_root;
uniform float night = 0.0;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	bool grass = distance(source.rgb,vec3(34.0,49.0,32.0)/255.0)<.005 || distance(source.rgb,vec3(53.0,71.0,41.0)/255.0)<.005 || distance(source.rgb,vec3(72.0,93.0,53.0)/255.0)<.005;
	bool lamp = distance(source.rgb,vec3(154.0,172.0,110.0)/255.0)<.005 || distance(source.rgb,vec3(89.0,114.0,70.0)/255.0)<.005;
	float height = max(0.0,object_root.y-world_point.y);
	vec2 plane = grass ? ground_plane(world_point) : ground_plane(vec2(world_point.x,object_root.y))-vec2(.42,.32)*height;
	vec3 color = receive_sun(source.rgb,plane,.40,grass ? 1.0 : .24*(1.0-night));
	if (lamp) color = mix(color,vec3(.27,.80,1.0),night*.93);
	else if (!grass) color += vec3(.035,.04,.05)*night;
	COLOR = vec4(color,source.a);
}
