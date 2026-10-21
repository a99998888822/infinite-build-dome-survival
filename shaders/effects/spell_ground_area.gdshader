shader_type canvas_item;
render_mode unshaded;
uniform vec2 axes = vec2(1.0);
uniform vec4 fill_color : source_color = vec4(0.3, 0.5, 0.7, 0.16);
uniform vec4 edge_color : source_color = vec4(0.6, 0.8, 1.0, 0.55);
uniform float growth = 1.0;
uniform float opacity = 1.0;
varying vec2 point;
void vertex() { point = VERTEX; }
void fragment() {
    vec2 p = (floor(point / 2.0) + 0.5) * 2.0;
    vec2 extent = max(axes * growth, vec2(0.001));
    float r = length(p / extent);
    float edge = 2.0 / max(min(extent.x, extent.y), 2.0);
    vec4 color = r > 1.0 - edge ? edge_color : fill_color;
    color.a *= opacity * float(r <= 1.0 && growth > 0.0);
    COLOR = color;
}
