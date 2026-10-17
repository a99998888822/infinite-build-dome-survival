shader_type canvas_item;
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

vec4 blast(vec2 p,float t,float u) {
    float growth=0.28+0.77*smoothstep(0.0,0.50,u);
    vec2 q=(p-vec2(0.0,-reach*0.10))/vec2(reach*growth,reach*growth*0.81);
    float a=atan(q.y,q.x);
    float rim=0.86+0.14*sin(a*5.0+1.4)+0.08*sin(a*8.0-u*4.0);
    float r=length(q);
    // A connected lobed blast with hard, nested heat planes.
    vec4 c=vec4(0.0);
    if(r<rim) {
        c=vec4(0.50,0.19,0.10,1.0);
        if(r<rim-0.13) c=vec4(0.87,0.31,0.07,1.0);
        if(r<rim-0.31) c=vec4(1.0,0.62,0.12,1.0);
        if(r<rim-0.49) c=vec4(1.0,0.86,0.38,1.0);
        if(r<0.25 && u<0.50) c=vec4(1.0,0.99,0.78,1.0);
        // One thick lightning zigzag is embedded in the fire volume.
        float bend=q.x<-0.2 ? -0.16 : (q.x<0.2 ? 0.16 : -0.08);
        if(abs(q.y-bend)<0.065 && abs(q.x)<0.73 && u<0.68) c=vec4(1.0,1.0,0.87,1.0);
    }
    c.a*=1.0-smoothstep(0.62,1.0,u);
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

float ice_edge(vec2 q) {
    float a=atan(q.y,q.x);
    return 0.96+0.055*cos(a*6.0+0.35);
}

vec4 ice_plate(vec2 p,float t,float u) {
    float growth=0.20+0.80*smoothstep(0.0,0.45,t);
    vec2 q=p/vec2(reach*growth,reach*growth*0.55);
    float r=length(q);
    float edge=ice_edge(q);
    vec4 c=vec4(0.0);
    if(r<edge) {
        // Seven adjacent polygonal plates. Seams retain ice beneath them.
        float first=100.0;
        float second=100.0;
        float tile=0.0;
        vec2 local=vec2(0.0);
        for(int i=0;i<7;i++) {
            float n=float(i);
            float a=(n-1.0)*1.0472+0.25;
            vec2 center=i==0 ? vec2(0.0) : vec2(cos(a),sin(a))*0.63;
            vec2 d=q-center;
            float dist=dot(d,d);
            if(dist<first) { second=first;first=dist;tile=n;local=d; }
            else second=min(second,dist);
        }
        c=vec4(0.23,0.43,0.57,0.78);
        if(second-first>0.045) {
            c=vec4(0.40,0.65,0.76,0.88);
            if(local.y+local.x*0.55<0.015) c=vec4(0.61,0.81,0.86,0.90);
            if(local.y+local.x*0.45<-0.20) c=vec4(0.79,0.92,0.91,0.94);
        }
        if(r>edge-0.08) c=vec4(0.29,0.56,0.69,0.87);
        if(r>edge-0.065 && q.y<-0.15) c=vec4(0.76,0.91,0.92,0.95);
    }
    c.a*=1.0-smoothstep(0.66,1.0,u);
    return c;
}

vec4 ice_front(vec2 p,float t,float u) {
    float radius=mix(extra,reach,smoothstep(0.0,0.62,u));
    vec2 q=p/vec2(max(radius,1.0),max(radius*0.55,1.0));
    float edge=ice_edge(q);
    float d=edge-length(q);
    vec4 c=vec4(0.0);
    if(d>0.0 && d<0.24) {
        c=vec4(0.30,0.57,0.74,0.84);
        if(d<0.16) c=vec4(0.60,0.85,0.91,0.94);
        if(d<0.065) c=vec4(0.90,0.99,0.97,1.0);
    }
    c.a*=1.0-smoothstep(0.38,1.0,u);
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
        float size=(i==1 ? 15.0 : 12.0)*(1.0-smoothstep(0.58,1.0,u)*0.55);
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
    vec2 p=(floor(point/3.0)+0.5)*3.0;
    float t=floor(effect_time*18.0)/18.0;
    vec4 c=vec4(0.0);
    if(kind==0) c=steam(p,t,progress);
    else if(kind==1) c=blast(p,t,progress);
    else if(kind==2) c=water_ribbon(p,t,progress);
    else if(kind==3) c=ice_plate(p,t,progress);
    else if(kind==4) c=ice_front(p,t,progress);
    else if(kind==5) c=conduct(p,t,progress);
    else if(kind==6) c=reflection(p,t,progress);
    else if(kind==7) c=thaw(p,t,progress);
    COLOR=c;
}
