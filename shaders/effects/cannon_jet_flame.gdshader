shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float flame_time = 0.0;
uniform float reach = 187.5;
uniform float opacity = 1.0;
uniform vec2 ground_forward = vec2(1.0, 0.0);
uniform float projection_ratio = 0.6590909;
varying vec2 local_point;

void vertex() {
    local_point = VERTEX;
}

void fragment() {
    // Copper-lamp palette and advected noise, shaped into one forward impulse.
    vec2 screen_p = (floor(local_point / 3.0) + 0.5) * 3.0;
    vec2 ground_p = screen_p / vec2(1.0, projection_ratio);
    vec2 side = vec2(-ground_forward.y, ground_forward.x);
    vec2 p = vec2(dot(ground_p, ground_forward), dot(ground_p, side));
    vec2 nozzle = p - vec2(18.0, 0.0);
    float s = nozzle.x / max(reach - 18.0, 1.0);
    float t = floor(flame_time * 24.0) / 24.0;
    float front = min(1.0, 0.25 + flame_time * 16.0);
    float tail = max(0.0, (flame_time - 0.085) * 6.7);
    float span = 14.0 + max(nozzle.x, 0.0) * 0.38;
    float across = nozzle.y / span;
    vec2 flow = vec2(s * 1.55 - t * 5.4, across * 0.47);
    float broad = texture(flow_noise, flow).r;
    float detail = texture(flow_noise, flow * 1.9 + vec2(-t * 0.8, 0.3)).r;
    float noise = broad * 0.8 + detail * 0.2 - 0.5;
    float bend = sin(s * 8.0 - t * 24.0) * 0.13 * s;
    float density = 0.98 - abs(across + bend) + noise * 0.85;
    float tip = front + noise * 0.14 - abs(across) * 0.09;
    vec4 result = vec4(0.0);
    if (s >= tail + noise * 0.10 && s <= tip && s >= 0.0 && density > 0.0) {
        result = vec4(0.46, 0.18, 0.12, 1.0);
        if (density > 0.08) result = vec4(0.82, 0.31, 0.12, 1.0);
        if (density > 0.27) result = vec4(1.0, 0.64, 0.23, 1.0);
        if (density > 0.57 && s < front - 0.12 + noise * 0.30) result = vec4(1.0, 0.92, 0.62, 1.0);
    }
    // A few long burning fragments shoot ahead as the muzzle connection ends.
    for (int i = 0; i < 3; i++) {
        float index = float(i);
        float x = reach * (0.30 + flame_time * 2.8 + index * 0.11);
        float y = sin(index * 4.3 + 1.0) * (12.0 + flame_time * 75.0);
        vec2 d = abs(p - vec2(x, y));
        if (flame_time > 0.055 && flame_time < 0.24 && d.x < 10.0 && d.y < 4.0 && result.a == 0.0 && x < reach) {
            result = vec4(1.0, 0.64, 0.23, 1.0);
        }
    }
    result.a *= 1.0 - smoothstep(0.19, 0.28, flame_time);
    if (nozzle.x < 0.0 || p.x > reach) result.a = 0.0;
    COLOR = result * vec4(1.0, 1.0, 1.0, opacity);
}
