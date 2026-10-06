shader_type canvas_item;
uniform float remaining : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered);
	float edge = max(fwidth(radius), 0.001);
	float circle = 1.0 - smoothstep(0.5 - edge, 0.5, radius);
	// Reveal clockwise from twelve o'clock as the remaining sector shrinks.
	float progress = mod(atan(centered.x, -centered.y) / 6.28318530718 + 1.0, 1.0);
	float covered = step(1.0 - remaining, progress) * step(0.0001, remaining);
	COLOR = vec4(COLOR.rgb, COLOR.a * circle * covered);
}
