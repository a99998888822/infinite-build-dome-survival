shader_type canvas_item;
render_mode unshaded, blend_mul;
uniform float darkness = 0.0;
uniform vec2 view_size = vec2(1920.0,1080.0);
uniform vec2 hero;
uniform vec2 bank;
uniform vec2 lamp_left;
uniform vec2 lamp_right;
uniform vec2 entrance;
uniform bool bunker_light_enabled = false;
uniform float pixel_scale = 1.0;

float pool(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(.15,1.0,length((p-center)/(radius*pixel_scale)));
}
void fragment() {
	vec2 p = floor(UV*view_size/(3.0*pixel_scale))*3.0*pixel_scale;
	float hero_light = pool(p,hero,vec2(510.0,410.0));
	// Keep a faint shelter silhouette; concentrate the light at the entrance.
	float bank_light = pool(p,bank,vec2(320.0,225.0))*.28;
	float door_light = pool(p,entrance,vec2(180.0,105.0))*.62;
	float lamps = max(pool(p,lamp_left,vec2(78.0,96.0)),pool(p,lamp_right,vec2(78.0,96.0)))*.76;
	float bunker_light = bunker_light_enabled ? max(bank_light,max(door_light,lamps)) : 0.0;
	float reveal = max(hero_light,bunker_light);
	vec3 tint = mix(vec3(.08,.12,.23),vec3(.92,.96,1.0),reveal);
	COLOR = vec4(mix(vec3(1.0),tint,darkness),1.0);
}
