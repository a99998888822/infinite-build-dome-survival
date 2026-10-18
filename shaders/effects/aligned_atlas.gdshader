shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 source_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec4 destination = vec4(0.0,0.0,1.0,1.0);
uniform vec2 atlas_size = vec2(1.0);
uniform float grid = 3.0;
varying vec2 point;
varying vec4 tint;
void vertex() { point=VERTEX; tint=COLOR; }
void fragment() {
    // Quantize in the final battle framebuffer, after scale, rotation and
    // ground projection. Derivatives map the cell center back to source art.
    vec2 offset=(floor(FRAGCOORD.xy/grid)+0.5)*grid-FRAGCOORD.xy;
    vec2 p=point+dFdx(point)*offset.x+dFdy(point)*offset.y;
    vec2 ratio=(p-destination.xy)/destination.zw;
    vec2 texel=source_rect.xy+clamp(ratio,vec2(0.0),vec2(1.0))*source_rect.zw;
    // Clamp to this frame, not the entire atlas: adjacent frames never bleed.
    texel=clamp(texel,source_rect.xy+0.5,source_rect.xy+source_rect.zw-0.5);
    vec4 c=texture(atlas,texel/atlas_size)*tint;
    if(any(lessThan(ratio,vec2(0.0))) || any(greaterThanEqual(ratio,vec2(1.0)))) c.a=0.0;
    COLOR=c;
}
