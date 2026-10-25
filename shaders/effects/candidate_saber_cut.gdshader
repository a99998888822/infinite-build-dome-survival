shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float lifetime = 0.30;
uniform float length = 280.0;
uniform float width_scale = 1.0;
varying vec2 point;

void vertex() { point = VERTEX; }

void fragment() {
    vec2 offset = (floor(FRAGCOORD.xy / 2.0) + 0.5) * 2.0 - FRAGCOORD.xy;
    vec2 p = point + dFdx(point) * offset.x + dFdy(point) * offset.y;
    float t = clamp(floor(max(age, 0.0) * 48.0) / 48.0 / lifetime, 0.0, 1.0);
    // Both axes pass through the geometric center. One clean pointed lens.
    float x = abs(p.x) / max(length * 0.5, 1.0);
    float envelope = pow(max(1.0 - x * x, 0.0), 1.4);
    float collapse = 1.0 - smoothstep(0.48, 1.0, t);
    float width = envelope * (8.0 - t * 1.5) * collapse * width_scale;
    float distance = abs(p.y);
    vec4 c = vec4(0.0);
    if (x < 1.0 && distance < width) {
        c = vec4(0.21, 0.35, 0.39, 1.0);
        if (distance < width * 0.79) c = vec4(0.34, 0.60, 0.63, 1.0);
        if (distance < width * 0.50) c = vec4(0.64, 0.88, 0.86, 1.0);
        if (distance < width * 0.18 && t < 0.58) c = vec4(0.93, 1.0, 0.92, 1.0);
    }
    if (age < 0.0 || age >= lifetime) c.a = 0.0;
    COLOR = c;
}
