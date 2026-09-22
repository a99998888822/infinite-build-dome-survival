shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.62, 0.80, 0.65, 1.0);
uniform float strength : hint_range(0.0, 0.4) = 0.16;
uniform float glow_time = 0.0;

void fragment() {
	// Quantize this effect locally; no changes to the game's pixel scale.
	vec2 pixel = floor(UV * vec2(104.0, 112.0)) + vec2(0.5);
	vec2 local = pixel - vec2(52.0, 56.0);
	float distance_to_body = length((local + vec2(0.0, 1.0)) / vec2(42.0, 44.0));
	float aura = pow(1.0 - smoothstep(0.12, 1.0, distance_to_body), 2.0);
	float distance_to_feet = length((local - vec2(0.0, 20.0)) / vec2(47.0, 20.0));
	float ground_light = pow(max(1.0 - distance_to_feet, 0.0), 2.0);
	float breath = 0.96 + 0.04 * sin(glow_time * 1.15);
	float alpha = (aura * strength + ground_light * 0.035) * breath;
	COLOR = vec4(glow_color.rgb, alpha * glow_color.a);
}
