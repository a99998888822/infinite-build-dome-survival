import {writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {dirname,join} from 'node:path';import {fileURLToPath} from 'node:url';
import {createFrame,painterFor,composite} from '../../../pixelfx/src/core/index.js';
import {spriteSheet} from '../../../pixelfx/tools/lib/fxlib.mjs';
import * as art from './tornado_art.mjs';
const root=join(dirname(fileURLToPath(import.meta.url)),'../..'),out=join(root,'assets/effects/tornado');mkdirSync(out,{recursive:true});
const manifest={};
let guardViolations=0,framesTotal=0;
for(const element of ['air','fire','ice'])for(const layer of ['back','front']){
 const w=192,h=184,n=60,fps=30,frames=[];
 for(let i=0;i<n;i++){
  const f=createFrame(w,h),p=painterFor(f).place(96,158),o={...art.meta.options,element};
  (layer==='back'?art.drawBack:art.draw)(p,i/fps,o);
  const clear=composite(f,new Uint8ClampedArray(w*h*4));let nonempty=0;
  for(let j=3;j<clear.length;j+=4)if(clear[j]){nonempty++;const x=((j-3)/4)%w,y=Math.floor((j-3)/4/w);if(x<2||x>=w-2||y<2||y>=h-2)guardViolations++}
  if(!nonempty)throw Error('Empty frame');
  frames.push({t:i/fps,clear,color:clear});
 }
 const key=`tornado_${element==='ice'?'frost':element}_${layer}`,r={w,h,n,fps,frames},fx={meta:{...art.meta,options:{element}},id:key,mod:art},s=spriteSheet(fx,r,key);
 writeFileSync(join(out,key+'.png'),s.png);manifest[key]={sheet:key+'.png',width:w,height:h,count:n,columns:s.json.meta.pixelfx.columns,fps,pivot:[96,158],alpha:'straight',grid:1,palette:art.palettes[element],sha256:createHash('sha256').update(s.png).digest('hex')};framesTotal+=n;
}
if(guardViolations)throw Error('Edge guard violations '+guardViolations);
writeFileSync(join(out,'manifest.json'),JSON.stringify({revision:'R04',clips:manifest},null,2)+'\n');
console.log(JSON.stringify({clips:Object.keys(manifest).length,newFrames:framesTotal,fps:30,grid:1,paletteSteps:8,layeredBands:true,guardViolations}));
