shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float flame_time = 0.0;
uniform vec4 edge_color : source_color = vec4(0.46, 0.18, 0.12, 1.0);
uniform vec4 body_color : source_color = vec4(0.75, 0.29, 0.13, 1.0);
uniform vec4 heat_color : source_color = vec4(0.94, 0.59, 0.22, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.48, 1.0);
varying vec4 flame_data;

void vertex() {
    // RG: quad dimensions / 128; B: phase; A: pixel size / 4.
    flame_data = INSTANCE_CUSTOM;
    // QuadMesh uses the opposite vertical UV orientation to our original array.
    UV.y = 1.0 - UV.y;
}

void fragment() {
    vec2 dimensions = flame_data.rg * 128.0;
    float grid = flame_data.a * 4.0;
    vec4 modulation = COLOR;
    vec2 uv = (floor(UV * dimensions / grid) + 0.5) * grid / dimensions;
    float t = floor(flame_time * 18.0) / 18.0 + flame_data.b * 12.0;
    // Ground is at uv.y=0.94. Padding above the flame holds detached embers.
    float h = (0.94 - uv.y) / 0.76;
    float x = (uv.x - 0.5) * 2.0;
    float sway = sin(t * 2.8 - h * 6.2) * 0.18 * max(h, 0.0);
    sway += sin(t * 4.7 - h * 10.0) * 0.055 * max(h, 0.0);
    vec2 flow = vec2(x * 0.32 + flame_data.b, h * 0.42 - t * 0.25);
    float broad = texture(flow_noise, flow).r;
    float fine = texture(flow_noise, flow * 2.03 + vec2(0.31, -t * 0.07)).r;
    float noise = (broad * 0.72 + fine * 0.28 - 0.5);
    float width = 0.65 * pow(max(1.0 - h, 0.0), 0.78);
    width *= sqrt(clamp(h * 11.0 + 0.2, 0.0, 1.0));
    float density = width - abs(x - sway) + noise * (0.4 + h * 0.66);
    vec4 result = vec4(0.0);
    if (h >= 0.0 && h <= 1.05 && density > 0.0) {
        result = edge_color;
        if (density > 0.075) result = body_color;
        float heat_top = 0.61 + noise * 0.40;
        float core_top = 0.30 + noise * 0.26;
        if (density > 0.22 && h < heat_top) result = heat_color;
        if (density > 0.40 && h < core_top) result = core_color;
    }
    // Two analytic grid-aligned sparks per tongue; no CPU particle objects.
    for (int i = 0; i < 2; i++) {
        float n = float(i);
        float age = fract(t * 0.42 + n * 0.51 + flame_data.b);
        vec2 center = vec2(0.5 + sin(t * 1.3 + n * 4.4) * 0.10,
                           0.44 - age * 0.40);
        center = (floor(center * dimensions / grid) + 0.5) * grid / dimensions;
        vec2 d = abs(uv - center) * dimensions;
        if (age > 0.30 && age < 0.87 && max(d.x, d.y) < grid * 0.49 && result.a == 0.0) {
            result = age < 0.64 ? heat_color : body_color;
        }
    }
    COLOR = result * modulation;
}
