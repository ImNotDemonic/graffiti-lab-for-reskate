// Pixel processing runs locally. Only edges connected to the chosen border colour are cleared.
function removeBorder(image, colour, tolerance) {
  const {width:w,height:h,data}=image;
  const seen=new Uint8Array(w*h), queue=new Int32Array(w*h);
  let head=0,tail=0;
  function visit(i) {
    if(seen[i]) return;
    seen[i]=1;
    const p=i*4;
    if(data[p+3] && Math.max(...colour.map((v,c)=>Math.abs(data[p+c]-v)))>tolerance) return;
    data[p+3]=0; queue[tail++]=i;
  }
  for(let x=0;x<w;x++){visit(x); visit((h-1)*w+x);}
  for(let y=0;y<h;y++){visit(y*w); visit(y*w+w-1);}
  while(head<tail){
    const i=queue[head++],x=i%w;
    if(x) visit(i-1); if(x+1<w) visit(i+1);
    if(i>=w) visit(i-w); if(i+w<w*h) visit(i+w);
  }
}
function alphaBounds(image) {
  const {width:w,height:h,data}=image;
  let l=w,t=h,r=-1,b=-1;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++) if(data[(y*w+x)*4+3]){
    l=Math.min(l,x); t=Math.min(t,y); r=Math.max(r,x); b=Math.max(b,y);
  }
  if(r<0) throw Error('There is no visible artwork in this crop.');
  return [l,t,r-l+1,b-t+1];
}
function treatment(image,o) {
  const {data,width:w,height:h}=image, lum=new Float32Array(w*h);
  for(let i=0;i<lum.length;i++) {
    const j=i*4;
    for(let c=0;c<3;c++) data[j+c]=(data[j+c]-128)*o.contrast/100+128;
    lum[i]=.299*data[j]+.587*data[j+1]+.114*data[j+2];
  }
  for(let i=0;i<lum.length;i++) {
    const j=i*4,x=i%w,y=Math.floor(i/w),level=o.colours-1;
    if(o.style==='Stencil' || o.style==='Halftone'){
      const pitch=o.pitch,dx=((x+.5)%pitch)/pitch-.5,dy=((y+.5)%pitch)/pitch-.5;
      const white=o.style==='Stencil'?lum[i]>=o.threshold:(dx*dx+dy*dy)>(1-lum[i]/255)*.5;
      data[j]=data[j+1]=data[j+2]=white?255:0;
    } else if(o.style==='Poster' || o.style==='Comic'){
      const edge=Math.abs(lum[i]-lum[y*w+Math.max(0,x-1)])+Math.abs(lum[i]-lum[Math.max(0,y-1)*w+x]);
      for(let c=0;c<3;c++) data[j+c]=o.style==='Comic' && edge>200-o.edge?10:255*Math.round(data[j+c]*level/255)/level;
    }
  }
}
// Map source coordinates to output coordinates. Convex corner handles keep inversion single-valued.
function warpPoint(u,v,o) {
  let x=u,y=v,s=o.strength/100;
  if(o.warp==='Arch') y-=s*4*u*(1-u)*.4;
  if(o.warp==='Baseline') y+=s*(2*u-1)*(1-(2*u-1)**2)*v*.8;
  if(o.warp==='Bulge') y=.5+(v-.5)*(1+s*.75*Math.sin(Math.PI*u));
  if(o.warp==='Perspective') y=.5+(v-.5)*(1+s*(2*u-1)*.7);
  if(o.warp==='Corners'){
    const [a,b,c,d]=o.corners;
    x=(1-v)*((1-u)*a[0]+u*b[0])+v*((1-u)*d[0]+u*c[0]);
    y=(1-v)*((1-u)*a[1]+u*b[1])+v*((1-u)*d[1]+u*c[1]);
  }
  return [x,y];
}
function warpImage(src,o) {
  if(o.warp==='None') return src;
  if(o.warp==='Corners') {
    for(let i=0;i<4;i++) {
      const [a,b,c]=[0,1,2].map(k=>o.corners[(i+k)%4]);
      if((b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0])<.05) throw Error('Keep the four corners in order and apart.');
    }
  }
  let l=0,t=0,r=1,b=1;
  for(let i=0;i<=96;i++) for(const v of [0,1]) {
    const [x,y]=warpPoint(i/96,v,o);
    l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);
  }
  const w=Math.ceil((r-l)*src.width),h=Math.ceil((b-t)*src.height);
  const out={width:w,height:h,data:new Uint8ClampedArray(4*w*h)};
  for(let y=0;y<h;y++) for(let x=0;x<w;x++){
    const tx=l+(x+.5)/src.width,ty=t+(y+.5)/src.height;
    let u=tx,v=ty;
    if(o.warp==='Corners'){
      const [a,p,c,d]=o.corners;
      for(let n=0;n<7;n++){
        const [px,py]=warpPoint(u,v,o),ex=tx-px,ey=ty-py;
        if(Math.abs(ex)+Math.abs(ey)<.00001) break;
        const xu=(p[0]-a[0])*(1-v)+(c[0]-d[0])*v, yu=(p[1]-a[1])*(1-v)+(c[1]-d[1])*v;
        const xv=(d[0]-a[0])*(1-u)+(c[0]-p[0])*u, yv=(d[1]-a[1])*(1-u)+(c[1]-p[1])*u,det=xu*yv-yu*xv;
        if(Math.abs(det)<1e-7){u=-1;break;}
        u+=(ex*yv-ey*xv)/det; v+=(xu*ey-yu*ex)/det;
      }
    } else {
      const top=warpPoint(u,0,o)[1],bottom=warpPoint(u,1,o)[1];
      v=(ty-top)/(bottom-top);
    }
    if(u<0||v<0||u>=1||v>=1) continue;
    const k=4*(Math.floor(v*src.height)*src.width+Math.floor(u*src.width));
    out.data.set(src.data.subarray(k,k+4),4*(y*w+x));
  }
  return out;
}
