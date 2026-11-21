const get=id=>document.getElementById(id);
const file=get('file'), canvas=get('preview'), save=get('save'), status=get('status');
const form=get('settings');
let original=null,output=null,filename='',revision=0,undo=[],redo=[],committed='',queued=false;
const cornersDefault=[[0,0],[1,0],[1,1],[0,1]];
let corners=structuredClone(cornersDefault);
function options(){
  return {...Object.fromEntries(new FormData(form)), ...Object.fromEntries(
    Array.from(form.querySelectorAll('input[type=range],input[type=number],select[name=rotate]'),e=>[e.name,Number(e.value)])),
    corners:structuredClone(corners)};
}
function restore(o){
  for(const e of form.elements) if(e.name && Object.hasOwn(o,e.name) && e.type!=='checkbox') e.value=o[e.name];
  for(const e of form.querySelectorAll('input[type=checkbox]')) e.checked=!!o[e.name];
  corners=structuredClone(o.corners||cornersDefault); update();
}
function update(){
  if(queued)return; queued=true; requestAnimationFrame(()=>{queued=false; render();});
}
function commit(label){
  const next=JSON.stringify(options());
  if(committed && next!==committed){undo.push({previous:committed,next,label}); if(undo.length>40)undo.shift(); redo=[];}
  committed=next;
}
function history(forward){
  const from=forward?redo:undo,to=forward?undo:redo,e=from.pop();
  if(!e)return;
  to.push(e); committed=forward?e.next:e.previous; restore(JSON.parse(committed));
}
function make(w,h){const c=document.createElement('canvas');c.width=w;c.height=h;return c;}
function clipped(original,o){
  const sx=Math.floor(original.width*o.left/100),sy=Math.floor(original.height*o.top/100);
  const sw=Math.ceil(original.width*(100-o.right)/100)-sx,sh=Math.ceil(original.height*(100-o.bottom)/100)-sy;
  if(sw<1||sh<1)throw Error('Choose a crop with a positive width and height.');
  const k=Math.min(1,384/Math.max(sw,sh)),w=Math.max(1,Math.round(k*sw)),h=Math.max(1,Math.round(k*sh));
  const turn=o.rotate%180!==0,c=make(turn?h:w,turn?w:h),ctx=c.getContext('2d',{willReadFrequently:true});
  ctx.translate(c.width/2,c.height/2);ctx.rotate(o.rotate*Math.PI/180);ctx.drawImage(original,sx,sy,sw,sh,-w/2,-h/2,w,h);
  let image=ctx.getImageData(0,0,c.width,c.height);
  if(o.border) removeBorder(image,[1,3,5].map(i=>parseInt(o.colour.slice(i,i+2),16)),o.tolerance);
  treatment(image,o);ctx.putImageData(image,0,0);
  if(o.trim)image=ctx.getImageData(...alphaBounds(image));
  const warped=warpImage(image,o),out=make(warped.width,warped.height);
  out.getContext('2d').putImageData(new ImageData(warped.data,warped.width,warped.height),0,0);
  return out;
}
function drawHandles(o){
  const pad=get('handles'),ctx=pad.getContext('2d');pad.hidden=o.warp!=='Corners';
  if(pad.hidden)return;
  ctx.clearRect(0,0,pad.width,pad.height);ctx.drawImage(original,32,32,128,128);
  ctx.strokeStyle='#ff6528';ctx.lineWidth=3;ctx.beginPath();
  for(const [i,[x,y]] of corners.entries()){if(i===0)ctx.moveTo(32+128*x,32+128*y);else ctx.lineTo(32+128*x,32+128*y);}
  ctx.closePath();ctx.stroke();ctx.fillStyle='white';
  for(const [x,y] of corners)ctx.fillRect(26+128*x,26+128*y,12,12);
}
function render(){
  save.disabled=true;output=null;
  get('undo').disabled=!undo.length;get('redo').disabled=!redo.length;
  get('undo').textContent=undo.length?'Undo '+undo.at(-1).label:'Undo edit';
  get('redo').textContent=redo.length?'Redo '+redo.at(-1).label:'Redo edit';
  if(!original)return;
  try{
    const o=options(),processed=clipped(original,o),aspect=processed.width/processed.height;
    if(aspect>16||aspect<1/16)throw Error('Keep the finished piece between 16:1 and 1:16.');
    drawHandles(o);
    const ctx=canvas.getContext('2d',{willReadFrequently:true});
    for(const longest of [96,72,48,32,24,16]){
      const w=canvas.width=Math.max(1,Math.round(longest*Math.min(1,aspect)));
      const h=canvas.height=Math.max(1,Math.round(longest*Math.min(1,1/aspect)));
      ctx.drawImage(processed,0,0,w,h);
      const parts=rectangles(quantise(ctx.getImageData(0,0,w,h).data),w,h);
      if(parts.length>256) continue;
      if(!parts.length) throw Error('There is no visible wall ink. Adjust the crop or border tolerance.');
      ctx.clearRect(0,0,w,h);
      for(const [x,y,dx,dy,c] of parts){ctx.fillStyle=palette[c-1];ctx.fillRect(x,y,dx,dy);}
      output=['GLART1 '+[w,h,processed.width,processed.height].join(' '),...parts.map(p=>p.join(' '))].join('\n');
      save.disabled=false;status.textContent=w+' × '+h+' wall pixels · '+parts.length+' ink shapes';return;
    }
  }catch(e){canvas.width=1;status.textContent=e.message;}
}
async function loadImage(){
  const ticket=++revision,selected=file.files[0]; original=null;output=null;save.disabled=true;canvas.width=1;get('before').width=1;
  if(!selected)return;
  try{
    if(selected.size>32*1024*1024)throw Error('Choose a source smaller than 32 MiB.');
    let src;
    if(/\.graffiti$/i.test(selected.name)){
      if(selected.size>8192)throw Error('Invalid wall artwork.');
      const lines=(await selected.text()).trim().split(/\r?\n/);
      const m=/^GLART1 (\d+) (\d+) (\d+) (\d+)$/.exec(lines.shift());
      if(!m||lines.length>256)throw Error('Invalid wall artwork.');
      const [w,h,sw,sh]=m.slice(1).map(Number);
      if(w<1||h<1||w>96||h>96||sw<1||sh<1||sw>1000000||sh>1000000||sw/sh>16||sh/sw>16)throw Error('Invalid dimensions.');
      src=make(w,h);const ctx=src.getContext('2d');
      for(const line of lines){const a=/^(\d+) (\d+) (\d+) (\d+) (\d+)$/.exec(line);if(!a)throw Error('Invalid ink shape.');
        const [x,y,dx,dy,c]=a.slice(1).map(Number);
        if(!dx||!dy||x+dx>w||y+dy>h||c<1||c>16)throw Error('Invalid ink shape.');
        ctx.fillStyle=palette[c-1];ctx.fillRect(x,y,dx,dy);}
      const fitted=make(Math.max(1,Math.round(384*Math.min(1,sw/sh))),Math.max(1,Math.round(384*Math.min(1,sh/sw))));
      fitted.getContext('2d').imageSmoothingEnabled=false;fitted.getContext('2d').drawImage(src,0,0,fitted.width,fitted.height);src=fitted;
    } else src=await createImageBitmap(selected);
    if(ticket!==revision){src.close?.();return;}
    if(src.width*src.height>40000000){src.close?.();throw Error('Choose a source up to 40 megapixels.');}
    original=src;filename=(selected.name.replace(/\.[^.]+$/,'').replace(/[^a-zA-Z0-9 _-]/g,'').slice(0,38).trim()||'My artwork')+' edit.graffiti';
    get('title').value=filename.slice(0,-9); form.reset();corners=structuredClone(cornersDefault);committed=JSON.stringify(options());undo=[];redo=[];
    const before=get('before'),k=Math.min(1,600/Math.max(src.width,src.height));before.width=Math.max(1,Math.round(src.width*k));before.height=Math.max(1,Math.round(src.height*k));before.getContext('2d').drawImage(src,0,0,before.width,before.height);
    render();
  }catch(e){if(ticket===revision)status.textContent=e.message;}
}
file.onchange=()=>{original?.close?.();loadImage();};
form.oninput=update;
form.onchange=e=>{commit(e.target.dataset.action||'artwork adjustment');update();};
get('reset').onclick=()=>{form.reset();corners=structuredClone(cornersDefault);commit('artwork reset');update();};
get('undo').onclick=()=>history(false);get('redo').onclick=()=>history(true);
document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&!['TEXTAREA','INPUT'].includes(e.target.tagName)&&['z','y'].includes(e.key.toLowerCase())){e.preventDefault();history(e.key.toLowerCase()==='y'||e.shiftKey);}});
get('cancel').onclick=()=>{revision++;original?.close?.();original=null;file.value='';output=null;save.disabled=true;canvas.width=1;get('before').width=1;get('handles').hidden=true;undo=[];redo=[];status.textContent='Edit cancelled.';update();};
get('backdrop').onchange=e=>canvas.className=e.target.value;
const pad=get('handles');let dragged=-1;
function coords(e){const r=pad.getBoundingClientRect();return [(192*(e.clientX-r.left)/r.width-32)/128,(192*(e.clientY-r.top)/r.height-32)/128].map(n=>Math.max(-.2,Math.min(1.2,n)));}
pad.onpointerdown=e=>{const [x,y]=coords(e);dragged=corners.reduce((best,p,i)=>Math.hypot(p[0]-x,p[1]-y)<Math.hypot(corners[best][0]-x,corners[best][1]-y)?i:best,0);pad.setPointerCapture(e.pointerId);};
pad.onpointermove=e=>{if(dragged>=0){corners[dragged]=coords(e);drawHandles(options());update();}};
pad.onpointerup=pad.onpointercancel=()=>{if(dragged>=0){dragged=-1;commit('corner drag');update();}};
save.onclick=async()=>{
  if(!output)return;
  const name=get('title').value.trim();
  if(!/^[A-Za-z0-9 _-]{1,64}$/.test(name)){status.textContent='Use 1–64 letters, numbers, spaces, hyphens or underscores.';return;}
  const blob=new Blob([output],{type:'text/plain'});filename=name+'.graffiti';
  try{
    if(window.showSaveFilePicker){
      const h=await showSaveFilePicker({id:'graffiti-lab-imports',suggestedName:filename,types:[{description:'Graffiti Lab artwork',accept:{'text/plain':['.graffiti']}}]});
      const writer=await h.createWritable();await writer.write(blob);await writer.close();
    }else{const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=filename;link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);}
    status.textContent='Save the artwork in imports, then refresh My imports in ReSkate.';
  }catch(e){if(e.name!=='AbortError')status.textContent=e.message;}
};

get('bundle').onclick=async()=>{
  try{
    const files=[...get('collection-files').files];
    if(!files.length||files.length>12)throw Error('Choose 1–12 artworks.');
    const items=[];
    for(const f of files){
      if(f.size>8192||!f.name.toLowerCase().endsWith('.graffiti'))throw Error('Choose finished .graffiti files, up to 8 KiB each.');
      const frame=await f.text();
      items.push({name:f.name.slice(0,-9).slice(0,64),frame});
    }
    const blob=new Blob([JSON.stringify({version:1,items})],{type:'application/json'});
    if(blob.size>64000)throw Error('Split this collection into smaller groups under 64 KB.');
    const url=URL.createObjectURL(blob),link=document.createElement('a');
    link.href=url;link.download='My artwork.collection';link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
    status.textContent='Put the .collection file in imports and reopen Artwork Library to import the group.';
  }catch(err){status.textContent=err.message;}
};
