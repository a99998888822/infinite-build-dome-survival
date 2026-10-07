shader_type canvas_item;
render_mode unshaded;

uniform sampler2D core_frames : filter_nearest, repeat_disable;
uniform sampler2D glow_frames : filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform float size_multiplier = 1.0;
uniform float glow_scale = 0.5;
uniform float alpha_multiplier = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
varying flat float atlas_row;
varying flat float frame_index;

void vertex() {
	float lifetime = max(INSTANCE_CUSTOM.z, 0.01);
	float age = min(elapsed, lifetime);
	vec2 velocity = INSTANCE_CUSTOM.xy;
	float speed = length(velocity);
	float drag = COLOR.g * 100.0;
	float travel_time = drag > 0.001 ? min(age, speed / drag) : age;
	vec2 travel = speed > 0.001 ? velocity / speed * (speed * travel_time - 0.5 * drag * travel_time * travel_time) : vec2(0.0);
	travel.y += 0.5 * COLOR.r * 100.0 * age * age;
	VERTEX = VERTEX * size_multiplier + round(travel);
	atlas_row = INSTANCE_CUSTOM.w;
	frame_index = min(floor(elapsed / lifetime * 23.0), 23.0);
}

void fragment() {
	vec2 atlas_size = vec2(24.0, 32.0);
	vec2 tile = vec2(frame_index, atlas_row);
	vec4 core = texture(core_frames, (tile + UV) / atlas_size);
	vec2 glow_uv = (UV - vec2(0.5)) / max(glow_scale, 0.0001) + vec2(0.5);
	float halo = 0.0;
	if (glow_scale > 0.0 && all(greaterThanEqual(glow_uv, vec2(0.0))) && all(lessThanEqual(glow_uv, vec2(1.0)))) {
		halo = texture(glow_frames, (tile + glow_uv) / atlas_size).a;
	}
	float alpha = core.a + halo * (1.0 - core.a);
	COLOR = vec4(tint.rgb, alpha * tint.a * alpha_multiplier);
}
