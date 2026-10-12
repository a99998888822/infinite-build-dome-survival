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
        result = vec4(0.53, 0.40, 0.23, 1.0);
        if (edge > 0.8) result = vec4(0.83, 0.68, 0.39, 1.0);
        if (edge > 1.6) result = vec4(0.96, 0.88, 0.66, 1.0);
        if (edge > 2.4 && across < 1.2) result = vec4(1.0, 0.98, 0.86, 1.0);
    }
    return result;
}

void fragment() {
    // Quantize before transforming the wing: pixels stay square as it opens.
    vec2 pixel = (floor(local_point / 2.0) + 0.5) * 2.0;
    vec2 p = vec2(abs(pixel.x) - 6.0, pixel.y);
    float angle = mix(-0.70, 0.0, opening);
    p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
    p.x /= mix(0.36, 1.0, opening);
    vec4 result = vec4(0.0);
    // Long outer flight feathers open into a scalloped, upward-reaching fan.
    for (int i = 0; i < 7; i++) {
        float k = float(i);
        vec2 base = vec2(19.0 - k * 2.8, -17.0 + k * 3.0);
        vec2 tip = vec2(49.0 - k * k * 0.87, -43.0 + k * 10.0 - k * k * 0.20);
        vec4 layer = feather(p, base, tip, 5.7 - k * 0.28);
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
            result = vec4(1.0, 0.86, 0.48, 0.8);
        }
    }
    COLOR = result * vec4(1.0, 1.0, 1.0, opacity);
}
