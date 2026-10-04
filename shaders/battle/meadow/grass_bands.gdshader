shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1152.0,768.0);
uniform float transition_bottom = 238.0;
uniform vec2 actor_key = vec2(0.0);
uniform bool front_pass = false;
uniform vec2 atlas_size = vec2(256.0);
void vertex() {
	float columns = atlas_size.x / 32.0;
	vec2 origin = vec2(mod(INSTANCE_CUSTOM.r,columns),floor(INSTANCE_CUSTOM.r/columns))*32.0+vec2(2.0);
	UV = (origin+vec2(UV.x,1.0-UV.y)*INSTANCE_CUSTOM.g)/atlas_size;
	// Compatibility may reduce custom-data precision. Compare exact byte pairs,
	// never an absolute world coordinate. Visible spans are <32768px from player.
	float high_delta = INSTANCE_CUSTOM.b-actor_key.x;
	if (high_delta>128.0) high_delta-=256.0;
	if (high_delta<-128.0) high_delta+=256.0;
	bool ahead = high_delta>0.0 || (high_delta==0.0 && INSTANCE_CUSTOM.a>=actor_key.y);
	if (ahead != front_pass) VERTEX=vec2(0.0);
}
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	vec3 ground_color = COLOR.rgb/max(source.rgb,vec3(.001));
	vec3 color = mix(source.rgb,ground_color,.40);
	float root = smoothstep(COLOR.a-3.0/32.0,COLOR.a,UV.y);
	float foreground = smoothstep(transition_bottom-15.0,transition_bottom+18.0,SCREEN_UV.y*view_size.y);
	COLOR = vec4(color*(1.0-root*.08),source.a*foreground);
}
