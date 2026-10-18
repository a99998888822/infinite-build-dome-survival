shader_type canvas_item;
render_mode unshaded, blend_mul;
uniform float darkness = 0.0;
uniform vec2 view_size = vec2(1920.0,1080.0);
uniform vec2 hero;
uniform vec2 bank;
uniform vec2 lamp_left;
uniform vec2 lamp_right;
uniform vec2 entrance;
uniform float pixel_scale = 1.0;

float pool(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(.15,1.0,length((p-center)/(radius*pixel_scale)));
}
void fragment() {
	vec2 p = floor(UV*view_size/(3.0*pixel_scale))*3.0*pixel_scale;
	float hero_light = pool(p,hero,vec2(255.0,205.0));
	float bank_light = pool(p,bank,vec2(340.0,245.0))*.42;
	float door_light = pool(p,entrance,vec2(225.0,125.0))*.62;
	float lamps = max(pool(p,lamp_left,vec2(78.0,96.0)),pool(p,lamp_right,vec2(78.0,96.0)))*.76;
	float reveal = max(max(hero_light,bank_light),max(door_light,lamps));
	vec3 tint = mix(vec3(.08,.12,.23),vec3(.92,.96,1.0),reveal);
	COLOR = vec4(mix(vec3(1.0),tint,darkness),1.0);
}
