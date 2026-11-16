shader_type canvas_item;
render_mode unshaded;

uniform float opening = 0.0;
uniform float effect_time = 0.0;
uniform float opacity = 1.0;
varying vec2 local_point;

void vertex() {
    local_point = VERTEX;
}

// A pointed feather, with a broad rounded base and a fine tip.
vec4 feather(vec2 p, vec2 base, vec2 tip, float width) {
    vec2 axis = tip - base;
    float along = dot(p - base, axis) / dot(axis, axis);
    float across = dot(p - base, vec2(-axis.y, axis.x)) / length(axis);
    float half_width = width * pow(max(0.0, sin(clamp(along, 0.0, 1.0) * 3.141593)), 0.65);
    float edge = half_width - abs(across);
    vec4 result = vec4(0.0);
    if (along > 0.0 && along < 1.0 && edge >= 0.0) {
        result = vec4(0.72, 0.65, 0.43, 1.0);
        if (edge > 0.8) result = vec4(0.91, 0.88, 0.72, 1.0);
        if (edge > 1.6) result = vec4(0.99, 0.98, 0.91, 1.0);
        if (edge > 2.4 && across < 1.2) result = vec4(1.0, 1.0, 0.98, 1.0);
        if (abs(across) < 0.55 && along > 0.18 && along < 0.76) result = vec4(1.0, 1.0, 0.98, 1.0);
    }
    return result;
}

void fragment() {
    // Quantize before transforming the wing: pixels stay square as it opens.
    vec2 pixel = (floor(local_point / 2.0) + 0.5) * 2.0;
    vec2 p = vec2(abs(pixel.x) - 6.0, pixel.y);
    float beat = sin(clamp((effect_time - 0.32) / 0.35, 0.0, 1.0) * 3.141593) * 0.13;
    float angle = mix(-0.70, 0.0, opening) + beat;
    p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
    p.x /= mix(0.36, 1.0, opening);
    vec4 result = vec4(0.0);
    // Long outer flight feathers open into a scalloped, upward-reaching fan.
    for (int i = 0; i < 7; i++) {
        float k = float(i);
        vec2 base = vec2(19.0 - k * 2.8, -17.0 + k * 3.0);
        vec2 tip = vec2(49.0 - k * k * 0.87, -43.0 + k * 10.0 - k * k * 0.20);
        float reveal = smoothstep(k * 0.018, 0.24 + k * 0.018, effect_time);
        tip = mix(base, tip, reveal);
        vec2 drift = vec2(1.0, 0.55 + k * 0.06) * max(0.0, effect_time - 0.62 - k * 0.018) * 42.0;
        vec4 layer = feather(p - drift, base, tip + vec2(0.01), 5.7 - k * 0.28);
        if (effect_time > 0.68 + k * 0.018 && mod(floor(pixel.x / 2.0) + floor(pixel.y / 2.0) + k, 4.0) < (effect_time - 0.68 - k * 0.018) * 10.0) layer.a = 0.0;
        if (layer.a > 0.0) result = layer;
    }
    // Overlapping coverts join the feathers back to the shoulder.
    for (int i = 0; i < 5; i++) {
        float k = float(i);
        vec4 layer = feather(p, vec2(-2.0 + k * 3.0, 2.0 - k * 3.4), vec2(15.0 + k * 4.0, -3.0 - k * 5.6), 4.8);
        if (layer.a > 0.0) result = layer;
    }
    // Small square motes use the same grid and cadence as the lamp embers.
    for (int i = 0; i < 6; i++) {
        float k = float(i);
        float age = fract(effect_time * 0.65 + k * 0.1618);
        vec2 center = vec2(16.0 + k * 7.0, 14.0 - age * 66.0);
        center.x *= mix(0.4, 1.0, opening);
        center = (floor(center / 2.0) + 0.5) * 2.0;
        if (opening > 0.16 && age > 0.1 && age < 0.88 && max(abs(abs(pixel.x) - center.x), abs(pixel.y - center.y)) < 1.1 && result.a == 0.0) {
            result = vec4(1.0, 0.97, 0.82, 0.8);
        }
    }
    COLOR = result * vec4(1.0, 1.0, 1.0, opacity);
}
