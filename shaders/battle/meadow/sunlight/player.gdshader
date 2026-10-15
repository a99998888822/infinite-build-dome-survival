shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 object_root;

// A 128px action frame occupies 64 screen pixels in ordinary combat.
// Retain authored boundary ink when nearest sampling would skip that texel.
// Full-size art and interior details use the original nearest sample.
varying vec4 sprite_tint;
const vec3 INK = vec3(23.0, 35.0, 33.0) / 255.0;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 nearest = texture(TEXTURE, UV);
	vec2 footprint = (abs(dFdx(UV)) + abs(dFdy(UV))) / TEXTURE_PIXEL_SIZE;
	vec4 result = nearest;
	if (all(greaterThan(footprint, vec2(1.9))) && all(lessThan(footprint, vec2(2.1)))) {
		vec2 texel = TEXTURE_PIXEL_SIZE;
		vec2 base = (floor(UV / texel / 2.0) * 2.0 + 0.5) * texel;
		vec4 taps[4] = {texture(TEXTURE, base), texture(TEXTURE, base + vec2(texel.x, 0.0)),
			texture(TEXTURE, base + vec2(0.0, texel.y)), texture(TEXTURE, base + texel)};
		float coverage = taps[0].a + taps[1].a + taps[2].a + taps[3].a;
		if (coverage >= 2.0 || nearest.a > 0.5) {
			bool has_ink = false;
			for (int i = 0; i < 4; i++) {
				if (taps[i].a > 0.5 && distance(taps[i].rgb, INK) < 0.01) has_ink = true;
			}
			bool boundary = false;
			if (has_ink) {
				for (int y = -1; y <= 1; y++) {
					for (int x = -1; x <= 1; x++) {
						vec2 neighbor = base + vec2(float(x), float(y)) * texel * 2.0;
						float a = texture(TEXTURE, neighbor).a;
						float b = texture(TEXTURE, neighbor + vec2(texel.x, 0.0)).a;
						float c = texture(TEXTURE, neighbor + vec2(0.0, texel.y)).a;
						float d = texture(TEXTURE, neighbor + texel).a;
						if (a + b + c + d < 2.0 && d < 0.5) boundary = true;
					}
				}
			}
			if (has_ink && boundary) {
				result = vec4(INK, 1.0);
			} else if (nearest.a < 0.5) {
				// Recover covered silhouette cells using a real source color.
				float best_votes = 0.0;
				for (int i = 0; i < 4; i++) {
					float votes = 0.0;
					for (int j = 0; j < 4; j++) {
						if (taps[j].a > 0.5 && distance(taps[i].rgb, taps[j].rgb) < 0.01) votes += 1.0;
					}
					if (taps[i].a > 0.5 && votes > best_votes) {
						result = taps[i];
						best_votes = votes;
					}
				}
			}
		} else {
			result = vec4(0.0);
		}
	}
	result.rgb = receive_sun(result.rgb,ground_plane(object_root),.2,.35);
	COLOR = result * sprite_tint;
}
