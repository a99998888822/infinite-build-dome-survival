// Project adaptation of pixelfx nature/tornado and ice/blizzard-vortex (MIT),
// with fire heat bands informed by fire/fire-tornado / Sprite Fusion (Hugo Duprez, MIT).
// Project-specific crown, control footprint, density, palette and elemental geometry.
import {fit,rng,rand,cycle,smooth,clamp,lerp,TAU,tileNoise} from '../../../pixelfx/src/core/index.js';
export const palettes={
 air:['#1e292e','#303d42','#435356','#5d6d6b','#7b8b80','#9ca992','#bec5a9','#e1dfbf'],
 fire:['#492820','#753321','#a64b25','#cb672a','#e58d36','#f3b24e','#ffcf70','#ffe4a0'],
 ice:['#203943','#2a5365','#39788e','#509dac','#78bcc6','#a2d7da','#c7e9e3','#e6f4e6']
};
export const meta={name:'Project tornado R04',size:[192,184],origin:[96,158],duration:2,loop:true,fps:30,options:{element:'air',height:112,seed:4102026}};
function geo(o,t){const ph=TAU*t/2,H=o.height;return{H,axis:u=>6*Math.sin(ph-2.6*u)*(.15+.85*u)+2*Math.sin(ph*2+1.3-u*4.5)*u,rad:u=>3+20*Math.pow(u,1.5)+13*Math.pow(smooth(.78,1,u),2)}}
function blob(p,x,y,rx,ry,c,a){for(let yy=Math.floor(y-ry);yy<=y+ry;yy++)for(let xx=Math.floor(x-rx);xx<=x+rx;xx++)if(((xx+.5-x)/rx)**2+((yy+.5-y)/ry)**2<=1)p.blend(xx,yy,c,a)}
function body(p,C,g,t,o){
 for(let y=-g.H;y<0;y++){const u=-y/g.H,cx=g.axis(u),r=g.rad(u),rot=TAU*(2+(Math.floor(u*8)%2))*t/2;
  for(let x=Math.floor(cx-r*1.12);x<=cx+r*1.12;x++){
   const dx=(x+.5-cx)/r;if(Math.abs(dx)>1)continue;
   const n=tileNoise((Math.acos(dx)+rot)*6/TAU,y*.24,6,0,o.seed),depth=Math.sqrt(1-dx*dx);
   const stripe=(Math.sin(Math.asin(dx)*3+u*17-t*TAU*3+n*.7)+1)/2;
   const fade=Math.min(1,u*12+.15)*(1-smooth(.88,1.03,u));
   if(o.element==='fire'){
    const cut=smooth(.72,1,u);if(stripe<cut*.57)continue;
    const heat=.17+.25*depth+.48*stripe**3+.16*(1-u)+n*.07;
    const index=Math.max(0,Math.min(7,Math.floor(heat*8)));
    p.blend(x,y,C[index],fade*(.6+.35*depth));
   }else{
    let value=-dx*.32+.25+n*.44+stripe*.16;
    const index=Math.max(1,Math.min(6,Math.floor(value*5+1)));
    p.blend(x,y,C[index],fade*(o.element==='ice'?.15+.25*Math.abs(dx)**2:.22+.34*depth));
   }
  }
 }
}
function bands(p,C,g,t,o,back){
 for(let j=0;j<58;j++){
  const R=rng(o.seed,j),u=(j+R.range(.1,.9))/58,r=g.rad(u)*R.range(.98,1.09),cx=g.axis(u),y=-u*g.H;
  const turns=R.int(2,4),head=R.range(0,TAU)+TAU*turns*t/2,span=R.range(.8,2.1);
  for(let s=0;s<span;s+=.5/Math.max(2,r)){
   const th=head-s;if((Math.sin(th)<0)!==back)continue;const k=s/span;
   const x=cx+r*Math.cos(th),yy=y+r*.28*Math.sin(th)+k*2;
   const lit=Math.cos(th)<.2,index=back?(k<.3?3:2):(k<.13?6:k<.5?(lit?5:4):3);
   p.blend(x,yy,C[index],back?.65:1-k*.35);
   if(!back&&k<.44&&j%3===0)p.blend(x,yy+1,C[index-1],.85);
  }
 }
}
function crown(p,C,g,t,o,back){
 const cx=g.axis(1),r=g.rad(1),y=-g.H-2;
 if(back){blob(p,cx,y+2,r*.88,6,C[0],.6);blob(p,cx-5,y-3,r*.55,4,C[2],.42)}
 for(let j=0;j<16;j++){
  const R=rng(o.seed+19,j),rr=r*R.range(.42,1.1),head=R.range(0,TAU)+TAU*R.int(1,2)*t/2,span=R.range(1.5,2.8),thick=R.range(3,6),lift=R.range(-4,3)-(1-rr/r)*5;
  for(let s=0;s<span;s+=.6/rr){const th=head-s;if((Math.sin(th)<0)!==back)continue;
   const k=s/span,T=Math.max(1,Math.round(thick*Math.sin(Math.PI*Math.pow(1-k,.7)))),x=cx+rr*Math.cos(th),yy=y+lift+rr*.28*Math.sin(th);
   for(let n=0;n<T;n++){const index=n===0?(back?4:6):n===T-1?1:back?2:3;p.blend(x,yy-T/2+n,C[index],back?.6:.83)}
  }
 }
}
function foot(p,C,g,t,o,back){
 const dust=fit(o.element==='air'?['#34362a','#56513a','#847856','#b5a574','#d1c096']:palettes[o.element],5);
 cycle(t,2,30,o.seed+51,q=>q.range(.6,1.15),(age,life,R)=>{
  const k=age/life,th=R.range(0,TAU)+R.range(4,7)*age;if((Math.sin(th)<0)!==back)return;
  const rr=4+k*R.range(14,25),x=g.axis(0)+rr*Math.cos(th),y=-1-k*R.range(2,12)+rr*.26*Math.sin(th),s=R.range(2.3,4)*(1+k*.6);
  blob(p,x,y,s,s*.6,dust[back?1:2],Math.min(1,k*8)*(1-k)*.5);blob(p,x-s*.2,y-s*.3,s*.55,s*.25,dust[3],(1-k)*.3);
 });
 for(let j=0;j<5;j++){const R=rng(o.seed+52,j),r=R.range(12,27),head=R.range(0,TAU)+TAU*3*t/2;for(let s=0;s<.9;s+=.03){const th=head-s;if((Math.sin(th)<0)!==back)continue;p.blend(g.axis(0)+r*Math.cos(th),r*.22*Math.sin(th),dust[s<.3?3:2],1-s)}}
}
function debris(p,C,g,t,o,back){
 const count=o.element==='ice'?58:24;
 cycle(t,2,count,o.seed+79,q=>q.range(1.1,1.9),(age,life,R,j)=>{
  const k=age/life,u=clamp((k-.1)/.85),th=R.range(0,TAU)+TAU*R.range(2,3)*k;
  if((Math.sin(th)<0)!==back)return;
  const r=lerp(R.range(28,40),g.rad(u)*(1.1+smooth(.8,1,u)*.45)+R.range(2,7),smooth(0,.22,k)),x=g.axis(u)+r*Math.cos(th),y=-u*g.H+r*.28*Math.sin(th),a=Math.min(1,k*10)*(1-smooth(.85,1,k));
  if(o.element==='ice'){
   p.line(x+Math.sin(th)*3,y+2,x,y,C[back?3:5],a);p.dot(x,y,C[back?4:7],a);
   if(j%6===0){p.line(x,y-3,x,y+3,C[6],a);p.line(x-2,y,x+2,y,C[5],a)}
  }else if(o.element==='fire'){
   p.line(x+Math.sin(th)*4,y+3,x,y,C[back?2:4],a);p.dot(x,y,C[back?4:6],a);
   if(j%4===0){p.line(x,y+2,x+1,y-4,C[4],a);p.dot(x+1,y-4,C[6],a)}
  }else if(j%5===0){
   p.poly([[x-2,y],[x-1,y-3],[x+2,y-2],[x+3,y+1],[x,y+2]],C[back?2:3],a);p.line(x-1,y-2,x+1,y-2,C[5],a);
  }else{
   const leaf=fit(j%2?['#38422b','#646e39','#a1a454']:['#51402b','#8f6f3b','#c2a265'],3),sx=Math.cos(age*9+j)*3,sy=Math.sin(age*9+j)*1.7;
   p.line(x-sx,y-sy,x+sx,y+sy,leaf[back?0:1],a);p.dot(x,y,leaf[2],a);
  }
 });
}
function tongues(p,C,g,t,o){
 if(o.element!=='fire')return;
 for(let j=0;j<14;j++){
  const R=rng(o.seed+91,j),u=R.range(.2,.98),side=j%2?1:-1,x=g.axis(u)+side*g.rad(u)*.9,y=-u*g.H;
  const ph=(t*2+R.next())%1,h=5+ph*8,lean=side*(2+ph*4),w=2;
  p.poly([[x-w,y+2],[x-w,y-2],[x+lean,y-h],[x+w,y-3],[x+w+1,y+1]],C[3]);
  p.line(x,y,x+lean*.6,y-h*.6,C[5]);
 }
}
export function drawBack(p,t,o){const C=fit(palettes[o.element],8),g=geo(o,t);foot(p,C,g,t,o,true);flameRing(p,C,t,o,true);crown(p,C,g,t,o,true);bands(p,C,g,t,o,true);frostStreaks(p,C,g,t,o,true);debris(p,C,g,t,o,true);body(p,C,g,t,o)}
function frostStreaks(p,C,g,t,o,back){
 if(o.element!=='ice')return;
 cycle(t,2,32,o.seed+153,q=>q.range(.6,1),(age,life,R)=>{
  const h=R.range(3,g.H*.9)+age*15,u=Math.min(1,h/g.H),r=g.rad(u)*1.07;
  const head=R.range(0,TAU)+age*R.range(7,11),span=R.range(.65,1.2),fade=Math.min(1,age/.08)*(1-smooth(.7,1,age/life));
  for(let s=0;s<span;s+=.5/r){const a=head-s;if((Math.sin(a)<0)!==back)continue;const k=s/span;
   p.blend(g.axis(u)+r*Math.cos(a),-h+r*.28*Math.sin(a)+k*3,C[back?3:k<.15?7:k<.5?6:4],fade*(back?.65:1)*(1-k*.5));
  }
 });
}
function flameRing(p,C,t,o,back){
 if(o.element!=='fire')return;
 for(let j=0;j<12;j++){
  const a=j*TAU/12+t*TAU;if((Math.sin(a)<0)!==back)continue;
  const x=Math.cos(a)*16,y=Math.sin(a)*4,h=4+3*(1+Math.sin(t*TAU*3+j*2.1)),lean=-Math.sin(a)*3;
  p.poly([[x-2,y],[x-1,y-h*.6],[x+lean,y-h],[x+2,y-2],[x+2,y]],C[back?2:3],.9);
  p.line(x,y-1,x+lean*.5,y-h*.6,C[back?4:6],.9);
 }
}
export function draw(p,t,o){const C=fit(palettes[o.element],8),g=geo(o,t);bands(p,C,g,t,o,false);frostStreaks(p,C,g,t,o,false);crown(p,C,g,t,o,false);foot(p,C,g,t,o,false);flameRing(p,C,t,o,false);debris(p,C,g,t,o,false);tongues(p,C,g,t,o);
 if(o.element==='ice')cycle(t,2,7,o.seed+123,q=>q.range(.6,1.2),(age,life,R)=>{const k=age/life,x=g.axis(1)+R.range(-25,25)+age*R.range(-8,8),y=-g.H-age*12;blob(p,x,y,3+k*5,2+k*2,C[4],Math.min(1,k*8)*(1-k)*.18)});
}
