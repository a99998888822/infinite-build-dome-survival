shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float flame_time = 0.0;
uniform float reach = 240.0;
uniform float half_angle = 0.5235988;
uniform float opacity = 0.95;
varying vec2 local_point;

void vertex() {
    local_point = VERTEX;
}

void fragment() {
    // Model-authored variant of the copper lamp's stepped, flowing pixel fire.
    // The visual and warning use exactly the same muzzle, angle and radius.
    vec2 p = (floor(local_point / 2.0) + 0.5) * 2.0;
    float t = floor(flame_time * 18.0) / 18.0;
    float s = p.x / reach;
    float span = max(p.x * tan(half_angle), 1.0);
    float across = p.y / span;
    vec2 flow = vec2(s * 1.7 - t * 1.65, across * 0.58);
    float broad = texture(flow_noise, flow).r;
    float fine = texture(flow_noise, flow * 2.07 + vec2(-t * 0.25, 0.37)).r;
    float noise = broad * 0.72 + fine * 0.28 - 0.5;
    float sway = sin(t * 5.1 - s * 12.0) * s * 0.09;
    float density = 0.96 - abs(across + sway) + noise * (0.7 + s * 0.35);
    float tip = 0.85 + noise * 0.38 + sin(across * 11.0 - t * 6.0) * 0.10;
    vec4 result = vec4(0.0);
    if (s >= 0.0 && s < tip && density > 0.0) {
        result = vec4(0.12, 0.12, 0.34, 0.75);
        if (density > 0.12) result = vec4(0.16, 0.31, 0.73, 0.94);
        if (density > 0.32 && s < 0.76 + noise * 0.35) result = vec4(0.15, 0.67, 0.97, 1.0);
        if (density > 0.60 && s < 0.50 + noise * 0.35) result = vec4(0.56, 0.91, 1.0, 1.0);
        if (density > 0.84 && s < 0.22) result = vec4(0.89, 0.98, 1.0, 1.0);
    }
    // Distinct ghost-fire tongues and square embers flow away from the mouth.
    for (int i = 0; i < 8; i++) {
        float phase = float(i) * 0.618034;
        float age = fract(t * 0.95 + phase);
        float angle = sin(phase * 13.7) * half_angle * 0.80;
        vec2 center = vec2(cos(angle), sin(angle)) * reach * (0.48 + age * 0.52);
        center = (floor(center / 2.0) + 0.5) * 2.0;
        if (age > 0.15 && age < 0.95 && max(abs(p.x-center.x),abs(p.y-center.y)) < 2.1 && result.a == 0.0) {
            result = vec4(0.40, 0.82, 1.0, 0.9);
        }
    }
    if (p.x < 0.0 || abs(p.y) > span || length(p) > reach) result.a = 0.0;
    COLOR = result * vec4(1.0, 1.0, 1.0, opacity);
}
