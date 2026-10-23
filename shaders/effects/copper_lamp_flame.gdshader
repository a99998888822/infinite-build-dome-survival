shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float flame_time = 0.0;
uniform float reach = 120.0;
uniform float half_angle = 0.5235988;
uniform float opacity = 0.88;
uniform int render_part = 0;
uniform vec2 ground_forward = vec2(1.0, 0.0);
uniform float projection_ratio = 0.6590909;
varying vec2 local_point;

void vertex() {
    local_point = VERTEX;
}

void fragment() {
    // Match the enchantment's stepped animation and four-color pixel fire.
    vec2 screen_p = (floor(local_point / 2.0) + 0.5) * 2.0;
    vec2 ground_p = screen_p / vec2(1.0, projection_ratio);
    vec2 side = vec2(-ground_forward.y, ground_forward.x);
    vec2 p = vec2(dot(ground_p, ground_forward), dot(ground_p, side));
    vec2 from_muzzle = p - vec2(16.0, 0.0);
    float span = max(from_muzzle.x * tan(half_angle), 0.1);
    float s = from_muzzle.x / max(reach - 16.0, 1.0);
    float across = from_muzzle.y / span;
    float t = floor(flame_time * 18.0) / 18.0;
    vec2 flow = vec2(s * 1.3 - t * 1.15, across * 0.43);
    float broad = texture(flow_noise, flow).r;
    float fine = texture(flow_noise, flow * 2.03 + vec2(-t * 0.19, 0.31)).r;
    float noise = broad * 0.72 + fine * 0.28 - 0.5;
    float sway = sin(t * 4.7 - s * 11.0) * s * 0.11;
    float density = 0.93 - abs(across + sway) + noise * (0.45 + s * 0.35);
    float tip = 0.79 + noise * 0.42 + sin(across * 8.0 - t * 5.0) * 0.10;
    vec4 result = vec4(0.0);
    if (s >= 0.0 && s < tip && density > 0.0) {
        result = vec4(0.46, 0.18, 0.12, 0.88);
        if (density > 0.09) result = vec4(0.75, 0.29, 0.13, 1.0);
        if (density > 0.28 && s < 0.63 + noise * 0.35) result = vec4(0.94, 0.59, 0.22, 1.0);
        if (density > 0.59 && s < 0.34 + noise * 0.25) result = vec4(1.0, 0.86, 0.48, 1.0);
    }
    // Detached embers continue along the spray, inside its true cone and radius.
    for (int i = 0; i < 5; i++) {
        float phase = float(i) * 0.618034;
        float age = fract(t * 0.72 + phase);
        float angle = sin(phase * 13.7) * half_angle * 0.82;
        vec2 center = vec2(16.0, 0.0) + vec2(cos(angle), sin(angle)) * (reach - 16.0) * (0.55 + age * 0.45);
        center = (ground_forward * center.x + side * center.y) * vec2(1.0, projection_ratio);
        center = (floor(center / 2.0) + 0.5) * 2.0;
        if (age > 0.18 && age < 0.90 && max(abs(screen_p.x - center.x), abs(screen_p.y - center.y)) < 1.1 && result.a == 0.0) {
            result = vec4(0.94, 0.59, 0.22, 1.0 - age * 0.5);
        }
    }
    // The same offset muzzle, angle and radial limit as AttackFootprint.in_lamp_cone.
    if (from_muzzle.x < 0.0 || abs(from_muzzle.y) > span || length(p) > reach) result.a = 0.0;
    bool foreground = (density > 0.0 && density < 0.18 && screen_p.y > 0.0) || density <= 0.0;
    if ((render_part == 1 && foreground) || (render_part == 2 && !foreground)) result.a = 0.0;
    if (render_part == 2) result.a *= 0.55;
    COLOR = result * vec4(1.0, 1.0, 1.0, opacity);
}
