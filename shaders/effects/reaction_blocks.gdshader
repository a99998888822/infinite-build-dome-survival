shader_type canvas_item;
// Approved production reaction art; the restored ice atlases are drawn separately.
render_mode unshaded;

uniform int kind = 0;
uniform int detail = 2;
uniform float reach = 72.0;
uniform float effect_time = 0.0;
uniform float progress = 0.0;
uniform vec2 direction = vec2(1.0,0.0);
uniform float extra = 0.0;
varying vec2 point;

void vertex() { point = VERTEX; }

float octagon(vec2 p) {
    p=abs(p);
    return max(max(p.x,p.y),(p.x+p.y)*0.7071);
}

vec4 steam(vec2 p,float t,float u) {
    // Overlapping volumes share a broad base; no hollow rings or loose dots.
    float growth=0.48+0.52*smoothstep(0.0,0.42,u);
    vec2 q=(p-vec2(0.0,-12.0-u*48.0))/growth;
    float best=1000.0;
    vec2 local=vec2(0.0);
    float radius=1.0;
    for(int i=0;i<3;i++) {
        float n=float(i);
        vec2 c=vec2((n-1.0)*24.0, -10.0-13.0*float(i==1));
        c.x+=sin(t*3.2+n*1.7)*3.0;
        float r=22.0+4.0*float(i==1);
        vec2 d=q-c;
        float sdf=octagon(d/vec2(1.05,0.92))-r;
        if(sdf<best) {best=sdf;local=d;radius=r;}
    }
    vec4 c=vec4(0.0);
    if(best<0.0) {
        c=vec4(0.37,0.48,0.50,0.94);
        if(best<-3.0) c=vec4(0.59,0.70,0.69,0.97);
        if(best<-6.0 && local.y+local.x*0.26<3.0) c=vec4(0.78,0.85,0.80,1.0);
        if(local.y+local.x*0.42<-radius*0.28 && best<-5.0) c=vec4(0.94,0.96,0.87,1.0);
    }
    c.a*=1.0-smoothstep(0.65,1.0,u);
    return c;
}

float blast_hash(float n) {
    return fract(sin(n*127.1+extra*19.7)*43758.5453);
}

vec4 blast(vec2 p,float t,float u) {
    vec2 q=(p-vec2(0.0,-reach*0.10))/vec2(reach,reach*0.81);
    float expansion=smoothstep(0.0,0.66,u);
    float growth=(0.38+0.62*smoothstep(0.0,0.22,u))*(1.0-0.58*smoothstep(0.46,1.0,u));
    vec4 c=vec4(0.0);
    // Unequal angular slabs overlap at contact, then break apart. There is no
    // shared radial rim, regular tip spacing or matching outline on each side.
    for(int i=0;i<9;i++) {
        if(detail==0 && i>3) continue;
        float n=float(i);
        float h=blast_hash(n+1.0);
        float h2=blast_hash(n+12.0);
        float angle=n*2.399963+(h-0.5)*1.3+extra*0.21;
        vec2 axis=vec2(cos(angle),sin(angle));
        vec2 side=vec2(-axis.y,axis.x);
        float travel=(0.06+expansion*(0.42+0.39*h2));
        vec2 center=axis*travel+side*(h-0.5)*0.17;
        center.y-=u*u*(0.03+0.11*h);
        vec2 relative=q-center;
        // Skew the pointed fragments away from their travel direction.
        float skew=(h2-0.5)*1.2;
        vec2 v=vec2(dot(relative,axis),dot(relative,side));
        v=mat2(vec2(cos(skew),sin(skew)),vec2(-sin(skew),cos(skew)))*v;
        v/=vec2(0.26+0.27*h,0.14+0.17*h2)*growth;
        float shoulder=-0.28+0.24*h;
        float half_width=v.x<shoulder ? (v.x+0.80)/(shoulder+0.80) : (1.0-v.x)/(1.0-shoulder);
        float cross_section=abs(v.y-v.x*(h2-0.5)*0.55);
        float inset=half_width-cross_section;
        if(v.x>-0.80 && v.x<1.0 && inset>0.0) {
            c=vec4(1.0,0.86,0.25,1.0);
            if(inset>0.18) c=vec4(1.0,0.97,0.66,1.0);
            if(inset>0.32 && v.y+v.x*0.36<0.42) c=vec4(1.0,1.0,0.93,1.0);
            if(u<0.32 && inset>0.30) c=vec4(1.0);
        }
    }
    c.a*=1.0-smoothstep(0.68,1.0,u);
    return c;
}

vec4 water_ribbon(vec2 p,float t,float u) {
    float length=max(reach,1.0);
    vec2 side=vec2(-direction.y,direction.x);
    float x=dot(p,direction)/length;
    float head=min(u*1.40,1.08);
    float tail=max(head-0.52,-0.08);
    float v=(x-tail)/max(head-tail,0.01);
    float arch=-sin(clamp(x,0.0,1.0)*3.14159)*13.0;
    float y=dot(p-vec2(0.0,arch),side);
    float half_width=13.0*pow(max(sin(v*3.14159),0.0),0.65);
    vec4 c=vec4(0.0);
    if(v>0.0 && v<1.0 && abs(y)<half_width) {
        c=vec4(0.10,0.29,0.47,1.0);
        if(y<half_width*0.54) c=vec4(0.10,0.53,0.69,1.0);
        if(y<-half_width*0.02) c=vec4(0.34,0.78,0.84,1.0);
        if(y<-half_width*0.60 && v>0.40) c=vec4(0.82,0.98,0.91,1.0);
    }
    c.a*=1.0-smoothstep(0.79,1.0,u);
    return c;
}

vec4 conduct(vec2 p,float t,float u) {
    vec2 q=p-vec2(0.0,-18.0);
    float step_time=floor(t*12.0);
    float bend=mod(step_time,3.0)-1.0;
    float x=q.x;
    float y;
    if(x<-10.0) y=(x+23.0)*0.60-4.0;
    else if(x<4.0) y=4.0-(x+10.0)*0.80;
    else y=-7.0+(x-4.0)*0.68;
    y+=bend*2.0;
    float width=5.5+2.0*max(0.0,1.0-abs(x)/25.0);
    vec4 c=vec4(0.0);
    if(abs(x)<27.0 && abs(q.y-y)<width) {
        c=vec4(0.10,0.32,0.64,1.0);
        if(abs(q.y-y)<width-2.0) c=vec4(0.16,0.66,0.93,1.0);
        if(abs(q.y-y)<2.0) c=vec4(0.79,0.98,1.0,1.0);
    }
    c.a*=1.0-smoothstep(0.78,1.0,u);
    return c;
}

vec4 reflection(vec2 p,float t,float u) {
    vec2 side=vec2(-direction.y,direction.x);
    float x=dot(p,direction);
    float y=dot(p,side);
    float fraction=x/max(reach,1.0);
    float width=(7.0+9.0*sin(clamp(fraction,0.0,1.0)*3.14159))*min(1.0,(1.0-fraction)*5.0);
    vec4 c=vec4(0.0);
    if(x>0.0 && x<reach && abs(y)<width) {
        c=vec4(0.25,0.51,0.67,1.0);
        if(y<width*0.65) c=vec4(0.51,0.81,0.86,1.0);
        if(y<width*0.15 && y>-width*0.67) c=vec4(0.94,1.0,0.89,1.0);
        if(y<-width*0.68) c=vec4(0.99,0.82,0.40,1.0);
    }
    vec2 crystal=p-vec2(0.0,-9.0);
    if(abs(crystal.x)/14.0+abs(crystal.y)/25.0<1.0) {
        c=vec4(0.30,0.57,0.70,1.0);
        if(crystal.x<0.0) c=vec4(0.62,0.87,0.88,1.0);
        if(crystal.x<0.0 && crystal.y<0.0) c=vec4(0.97,1.0,0.91,1.0);
    }
    c.a*=1.0-smoothstep(0.62,1.0,u);
    return c;
}

vec4 thaw(vec2 p,float t,float u) {
    vec4 c=vec4(0.0);
    for(int i=0;i<3;i++) {
        float n=float(i)-1.0;
        vec2 center=vec2(n*(16.0+u*23.0),-17.0-20.0*sin(u*3.14159)+u*u*26.0);
        vec2 q=p-center;
        float size=(i==1 ? 15.0 : 12.0)*(1.0-smoothstep(0.58,1.0,u)*0.55)/3.0;
        float d=abs(q.x)/size+abs(q.y)/(size*1.2);
        if(d<1.0) {
            c=vec4(0.23,0.48,0.64,1.0);
            if(q.x<2.0) c=vec4(0.47,0.78,0.86,1.0);
            if(q.x<1.0 && q.y<0.0) c=vec4(0.85,0.97,0.94,1.0);
        }
    }
    c.a*=1.0-smoothstep(0.55,1.0,u);
    return c;
}

void fragment() {
    // Quantize before all shape calculations: solid cells, including rotated rays.
    float grid=kind==7 ? 1.0 : 3.0;
    vec2 p=(floor(point/grid)+0.5)*grid;
    float t=floor(effect_time*18.0)/18.0;
    vec4 c=vec4(0.0);
    if(kind==0) c=steam(p,t,progress);
    else if(kind==1) c=blast(p,t,progress);
    else if(kind==2) c=water_ribbon(p,t,progress);
    else if(kind==5) c=conduct(p,t,progress);
    else if(kind==6) c=reflection(p,t,progress);
    else if(kind==7) c=thaw(p,t,progress);
    COLOR=c;
}
