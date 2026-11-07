shader_type canvas_item;
render_mode unshaded;
// Adapted from pixelfx water/ripples: expanding swells, signed slopes and lit crests.
// MIT, Patch. Coarser bands, game palette and battle projection; no raised crown.
uniform float effect_time = 0.0;
varying vec2 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
    vec2 p = (floor(local_point / 2.0) + 0.5) * 2.0;
    vec2 ground = vec2(p.x, p.y / 0.66);
    float r = length(ground), angle = atan(ground.y, ground.x);
    float t = floor(effect_time * 18.0) / 18.0;
    float fade = min(1.0, t * 18.0) * (1.0 - smoothstep(0.59, 0.85, effect_time));
    float edge = 1.0 - smoothstep(61.0, 75.3984, r);
    float slope = 0.0, crest = 0.0, shadow = 0.0;
    for (int i = 0; i < 3; i++) {
        float age = t - float(i) * 0.17;
        if (age < 0.0 || age > 0.85) { continue; }
        float q = age / 0.85;
        float radius = 2.0 + 69.0 * (1.0 - pow(1.0 - q, 3.0));
        float power = pow(1.0 - q, 1.5) * min(1.0, age / 0.08);
        float wobble = sin(angle * 3.0 + float(i) * 1.9) * (0.5 + age * 1.1);
        float d = r - radius - wobble;
        float width = 4.5 + age * 3.0;
        // Broader frequency than the original's 1.15/pixel; avoids hairline strips.
        slope += power * exp(-pow(d / width, 2.0)) * -sin(d * 0.48) * 1.5;
        crest = max(crest, (1.0 - smoothstep(1.0, 3.2, abs(d))) * power);
        shadow = max(shadow, exp(-pow((d + 4.0) / 4.0, 2.0)) * power);
    }
    float facing = dot(ground / max(r, 1.0), vec2(0.55, 0.84));
    float face = slope * facing;
    vec4 c = vec4(0.10, 0.27, 0.48, 0.42 * edge);
    if (shadow > 0.12) c = vec4(0.055, 0.17, 0.30, 0.65 * edge);
    if (face > 0.10) c = vec4(0.11, 0.49, 0.69, 0.86 * edge);
    if (face > 0.38 || crest > 0.30) c = vec4(0.30, 0.76, 0.83, 0.96 * edge);
    if (crest > 0.52 && facing > 0.22 && sin(angle * 4.7 + 1.9) > -0.25) c = vec4(0.78, 0.96, 0.91, edge);
    c.a *= fade;
    COLOR = c;
}
