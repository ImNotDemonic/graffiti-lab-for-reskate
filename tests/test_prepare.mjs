import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const file=new URL('../art/prepare.js',import.meta.url);
const api=vm.runInNewContext(readFileSync(file,'utf8')+';({removeBorder,alphaBounds,treatment,warpImage})');
const image=()=>({width:31,height:25,data:new Uint8ClampedArray(31*25*4).fill(255)});
const p=(x,y)=>(31*y+x)*4;
const original=image();
for(let y=4;y<=20;y++)for(let x=6;x<=24;x++)if(x===6||y===4||x===24||y===20)original.data.fill(5,p(x,y),p(x,y)+3);
const raw=structuredClone(original);
api.removeBorder(raw,[255,255,255],10);
assert.equal(raw.data[p(0,0)+3],0);
assert.equal(raw.data[p(15,12)+3],255);
assert.deepEqual(Array.from(api.alphaBounds(raw)),[6,4,19,17]);
for(const warp of ['Arch','Bulge','Baseline','Perspective','Corners']){
 const o={warp,strength:80,corners:[[-.08,.09],[1,0],[1.12,.9],[0,1]]};
 const out=api.warpImage(raw,o);
 const alphas=out.data.filter((_,i)=>i%4===3);
 assert(alphas.some(a=>a===0)&&alphas.some(a=>a===255),warp);
 assert.notDeepEqual(Array.from(out.data),Array.from(raw.data));
}
const hashes=new Set();
for(const style of ['Original','Stencil','Poster','Comic','Halftone']){
 const im=image();
 for(let i=0;i<31*25;i++){im.data[i*4]=(i*19)%256;im.data[i*4+1]=(i*11)%256;im.data[i*4+2]=(i*7)%256;}
 api.treatment(im,{style,threshold:90,pitch:8,contrast:115,edge:150,colours:4});
 hashes.add(Buffer.from(im.data).toString('base64'));
}
assert.equal(hashes.size,5);
assert.equal(original.data[p(0,0)+3],255);
console.log('PASS: connected border removal, enclosed whites, trim, five deformations, alpha preservation and four distinct photo treatments');
