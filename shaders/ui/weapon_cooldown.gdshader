shader_type canvas_item;
uniform float remaining : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float progress = mod(atan(UV.x - 0.5, 0.5 - UV.y) / 6.28318530718 + 1.0, 1.0);
	float gray = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	float covered = step(1.0 - remaining, progress) * step(0.0001, remaining);
	COLOR = vec4(mix(sample_color.rgb, vec3(gray * 0.50), covered), sample_color.a);
}
