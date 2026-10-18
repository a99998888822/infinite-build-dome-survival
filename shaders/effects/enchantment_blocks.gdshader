shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int kind = 0;
uniform int detail = 2;
uniform float reach = 55.2;
uniform float effect_time = 0.0;
uniform float progress = 0.0;
uniform vec2 direction = vec2(1.0,0.0);
varying vec2 point;

void vertex() { point = VERTEX; }

float flow(vec2 p, float t) {
    return texture(flow_noise, p * 0.72 + vec2(-t * 0.42, t * 0.13)).r - 0.5;
}

vec4 water(vec2 p, float t, float u) {
    // Restore the broad water body, without either raised curling crest.
    vec2 q=p/vec2(reach,reach*0.66);
    float a=atan(q.y,q.x);
    float n=flow(q+vec2(cos(a-t),sin(a-t))*0.3,t);
    float r=length(q);
    float front=0.27+0.77*sqrt(u);
    float crest=front+n*0.18+sin(a*3.0-t*5.0)*0.05;
    float d=crest-r;
    vec4 c = vec4(0.0);
    if(r<crest) {
        c=vec4(0.10,0.27,0.48,0.92);
        if(d<0.38+n*0.16) c=vec4(0.11,0.49,0.69,0.97);
        if(d<0.20+n*0.12) c=vec4(0.30,0.76,0.83,1.0);
        if(d<0.08 && sin(a*3.0-t*4.0)+n>-0.25) c=vec4(0.78,0.96,0.91,1.0);
    }
    c.a *= 1.0-smoothstep(0.67,1.0,u);
    return c;
}

vec4 shock(vec2 p, float t, float u) {
    vec2 q=p/vec2(reach,reach*0.72);
    float r=length(q);
    float a=atan(q.y,q.x);
    float n=flow(q,t);
    float front=0.16+0.90*sqrt(u);
    float d=front+n*0.11-r;
    vec4 c=vec4(0.0);
    if (d>0.0 && d<0.32-u*0.17) {
        c=vec4(0.39,0.43,0.48,0.85);
        if (d<0.21-u*0.1) c=vec4(0.69,0.75,0.77,0.96);
        if (d<0.095 && sin(a*5.0+t*4.0)>-0.72) c=vec4(0.94,0.98,0.97,1.0);
    }
    if (u<0.20 && abs(q.x)+abs(q.y)*1.4 < (0.30-u)) c=vec4(0.98,1.0,0.98,1.0);
    c.a *= 1.0-smoothstep(0.60,1.0,u);
    return c;
}

vec4 hole(vec2 p, float t, float u) {
    // Plasma-style fixed circular mask and internal clouds, with a lit sphere.
    // The one-pixel 3D airflow is drawn in separate front/back canvas layers.
    float opening=min(1.0,u*7.0)*(1.0-smoothstep(0.78,1.0,u)*0.40);
    float radius=max(reach*0.35*opening,0.01);
    vec2 q=(p-vec2(0.0,-reach*0.22))/radius;
    float r2=dot(q,q);
    vec4 c=vec4(0.0);
    if(r2<1.0) {
        vec3 normal=vec3(q,sqrt(1.0-r2));
        float lit=dot(normal,normalize(vec3(-0.50,-0.65,0.85)));
        float clouds=sin(q.x*5.0+t*3.0)*sin(q.y*4.0-t*2.0)*0.065;
        lit+=clouds;
        c=vec4(0.035,0.025,0.070,1.0);
        if(lit>0.12) c=vec4(0.105,0.070,0.180,1.0);
        if(lit>0.48) c=vec4(0.220,0.160,0.340,1.0);
        if(lit>0.76) c=vec4(0.390,0.310,0.530,1.0);
        if(lit>0.92) c=vec4(0.570,0.480,0.690,1.0);
    }
    c.a *= 1.0-smoothstep(0.87,1.0,u);
    return c;
}

vec4 wind(vec2 p, float t, float u) {
    vec2 q=p/max(reach,0.01);
    // A single beveled blade: broad at its belly, tapering to two sharp tips.
    float height=abs(q.y)/68.0;
    float bow=max(0.0,1.0-height*height);
    float edge=44.0-68.0*height*height;
    float thickness=32.0*pow(bow,1.15);
    vec4 c=vec4(0.0);
    if(height<1.0 && q.x<edge && q.x>edge-thickness) {
        float bevel=(edge-q.x)/max(thickness,0.01);
        c=vec4(0.19,0.40,0.42,0.95);
        if(bevel<0.82) c=vec4(0.31,0.68,0.59,1.0);
        if(bevel<0.44) c=vec4(0.62,0.89,0.74,1.0);
        if(bevel<0.15) c=vec4(0.89,1.0,0.90,1.0);
    }
    c.a *= min(1.0,u*12.0)*(1.0-smoothstep(0.70,1.0,u));
    return c;
}

void fragment() {
    vec2 p=(floor(point/3.0)+0.5)*3.0;
    float t=floor(effect_time*18.0)/18.0;
    vec4 c=vec4(0.0);
    if(kind==0) c=shock(p,t,progress);
    else if(kind==1) c=water(p,t,progress);
    else if(kind==2) c=hole(p,t,progress);
    else c=wind(vec2(dot(p,direction),dot(p,vec2(-direction.y,direction.x))),t,progress);
    COLOR=c;
}
