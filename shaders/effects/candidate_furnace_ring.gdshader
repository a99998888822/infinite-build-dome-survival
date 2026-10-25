shader_type canvas_item;
render_mode unshaded;

// Candidate art only. The palette, local pixel grid and rhythm follow Copper Lamp.
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float age = 0.0;
uniform float lifetime = 0.72;
uniform float reach = 160.0;
uniform float projection_ratio = 0.6590909;
uniform float seed_phase = 0.0;
uniform bool fragmented = false;
uniform float flare_count = 18.0;
uniform int render_part = 0;
varying vec2 point;

void vertex() { point = VERTEX; }

void fragment() {
    // Quantize before ground projection, just like Copper Lamp. World-sized
    // square pixels stay visible when the camera magnifies the broad color bands.
    vec2 screen_p = (floor(point / 2.0) + 0.5) * 2.0;
    vec2 p = screen_p / vec2(1.0, projection_ratio);
    float t = floor(max(age, 0.0) * 18.0) / 18.0;
    float phase = clamp(t / lifetime, 0.0, 1.0);
    float a = atan(p.y, p.x);
    vec2 cyclic = vec2(cos(a), sin(a));
    float noise = texture(flow_noise, cyclic * 0.61 + vec2(-t * 0.53, seed_phase)).r;
    float density = -1.0;
    float hot = 0.0;
    float radius = mix(18.0, reach, 1.0 - pow(1.0 - min(phase / 0.80, 1.0), 1.5));
    float release = 1.0 - smoothstep(0.60, 1.0, phase);
    float width = mix(40.0, 22.0, phase) * max(release, 0.01);
    if (!fragmented) {
        // Large connected color regions, with only broad angular variation.
        float lobes = sin(a * 7.0 - t * 5.0 + seed_phase) * 0.55
                    + sin(a * 11.0 + t * 4.0) * 0.20;
        float edge = radius + (noise - 0.5) * 10.0 + lobes * 7.0;
        float radial = (length(p) - edge) / width;
        density = 1.0 - abs(radial + 0.18);
        float broad_heat = sin(a * 3.0 - t * 4.0 + seed_phase) * 0.12
                         + sin(a * 5.0 + t * 2.0) * 0.06;
        hot = density - max(radial, 0.0) * 0.3 + broad_heat * smoothstep(0.15, 0.40, density);
    } else {
        // Eighteen individually tapered small flares arranged outside the main pulse.
        float sector = floor((a + 3.141593) / 6.283185 * flare_count + 0.5);
        float angle = sector / flare_count * 6.283185 - 3.141593 + seed_phase * 0.03;
        vec2 forward = vec2(cos(angle), sin(angle));
        vec2 side = vec2(-forward.y, forward.x);
        float growth = sin(clamp(phase * 1.2, 0.0, 1.0) * 3.141593);
        float x = dot(p, forward) - (reach + 13.0 + phase * 12.0);
        float y = dot(p, side);
        float flare_length = 10.0 + growth * 22.0;
        float along = clamp((x + 12.0) / (flare_length + 12.0), 0.0, 1.0);
        float span = (13.0 + growth * 7.0) * pow(max(sin(along * 3.141593), 0.0), 0.65) * release;
        density = 1.0 - abs(y + sin(x * 0.10 + t * 7.0 + sector) * 1.2) / max(span, 0.1);
        if (x < -12.0 || x > flare_length || growth < 0.08) density = -1.0;
        hot = density - max(x, 0.0) / max(flare_length, 1.0) * 0.6;
    }
    vec4 c = vec4(0.0);
    if (density > 0.0) {
        c = vec4(0.46, 0.18, 0.12, 1.0);
        if (density > 0.15) c = vec4(0.75, 0.29, 0.13, 1.0);
        if (hot > 0.38) c = vec4(0.94, 0.59, 0.22, 1.0);
        if (hot > 0.78 && phase < 0.68) c = vec4(1.0, 0.86, 0.48, 1.0);
    }
    // The entire colored band retracts. No noise holes or scattered color flecks.
    if (age < 0.0 || age >= lifetime) c.a = 0.0;
    bool foreground = screen_p.y > 0.0 && density > 0.0 && density < 0.27;
    if ((render_part == 1 && foreground) || (render_part == 2 && !foreground)) c.a = 0.0;
    COLOR = c;
}
