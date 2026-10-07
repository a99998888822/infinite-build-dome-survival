shader_type canvas_item;
render_mode unshaded;
uniform sampler2D particle_data : filter_nearest, repeat_disable;
uniform sampler2D square_png : filter_nearest, repeat_disable;
uniform sampler2D circle_png : filter_nearest, repeat_disable;
uniform float clock = 0.0;
varying vec4 particle_color;
varying vec2 core_extent;
varying vec2 glow_extent;
varying vec2 quad_extent;
varying float circle_core;
varying float circle_glow;
varying float glow_alpha;

vec4 row(float index, float y) {
	return texture(particle_data, vec2((index + 0.5) / 900.0, (y + 0.5) / 9.0));
}
void vertex() {
	float index = INSTANCE_CUSTOM.x;
	vec4 force = row(index, 1.0);
	vec4 params = row(index, 5.0);
	float age = max(0.0, clock - params.w);
	if (force.w <= 0.0 || age >= force.w) {
		particle_color = vec4(0.0);
		core_extent = vec2(1.0);
		glow_extent = vec2(1.0);
		quad_extent = vec2(1.0);
		circle_core = 0.0;
		circle_glow = 0.0;
		glow_alpha = 0.0;
		VERTEX = vec2(0.0);
	} else {
	vec4 motion = row(index, 0.0);
	vec4 shape = row(index, 2.0);
	vec4 first = row(index, 3.0);
	vec4 last = row(index, 4.0);
	vec4 flags = row(index, 8.0);
	float t = clamp(age / max(force.w,0.0001),0.0,1.0);
	particle_color = mix(first,last,t);
	if (flags.y > 0.5) {
		vec4 middle = row(index,6.0);
		vec4 final_color = row(index,7.0);
		particle_color = t < 0.45 ? mix(first,middle,t/0.45) : mix(middle,final_color,(t-0.45)/0.55);
	}
	particle_color.a *= (1.0-t)*(1.0-t)*params.z;
	if (force.w <= 0.0 || age >= force.w) particle_color.a = 0.0;
	float speed = length(motion.zw);
	float travel_time = force.z > 0.0 ? min(age,speed/force.z) : age;
	vec2 travel = speed > 0.0 ? motion.zw/speed * (speed*travel_time-0.5*force.z*travel_time*travel_time) : vec2(0.0);
	vec2 position = round(motion.xy + travel + 0.5*force.xy*age*age);
	core_extent = flags.x > 0.5 ? vec2(max(shape.x,shape.y)) : shape.xy;
	circle_core = flags.x;
	circle_glow = 1.0 - flags.z;
	glow_extent = flags.z > 0.5 ? vec2(shape.x*(0.9+params.x*0.25),max(shape.y,1.0)*(1.1+params.x*0.35))*params.y : vec2(max(shape.x,shape.y)*(1.5+params.x*0.35)*params.y*2.0);
	glow_alpha = params.x > 0.0 ? 0.12 : 0.0;
	quad_extent = max(core_extent,glow_alpha > 0.0 ? glow_extent : core_extent);
	vec2 local = VERTEX * quad_extent;
	float angle = shape.z + shape.w*age;
	VERTEX = position + mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*local;
	}
}
float mask(vec2 point, vec2 extent, float circle) {
	vec2 sample_uv = point / max(extent,vec2(0.00001)) + vec2(0.5);
	if (any(lessThan(sample_uv,vec2(0.0))) || any(greaterThanEqual(sample_uv,vec2(1.0)))) return 0.0;
	return circle > 0.5 ? texture(circle_png,sample_uv).a : texture(square_png,sample_uv).a;
}
void fragment() {
	vec2 point = (UV-vec2(0.5))*quad_extent;
	float core = mask(point,core_extent,circle_core)*particle_color.a;
	float glow = mask(point,glow_extent,circle_glow)*particle_color.a*glow_alpha;
	COLOR = vec4(particle_color.rgb,core+glow*(1.0-core));
}
