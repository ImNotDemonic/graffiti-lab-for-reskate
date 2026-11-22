// Public API for the ReSkate client. D1 contains the portable asset and its thumbnail.
const maxBody = 65536;
const encoder = new TextEncoder();
const failure = (status, message) => { throw Object.assign(new Error(message), {status}); };
const response = (status, data) => Response.json(data, {status, headers: {"Cache-Control":"no-store"}});
const integer = (n, lo, hi) => Number.isInteger(n) && n >= lo && n <= hi;

function field(value, limit, required = false) {
  if (typeof value !== "string" || value.length > limit || /[\x00-\x1f\x7f]/.test(value)) failure(400, "Invalid text field");
  const text = value.trim();
  if (required && !text) failure(400, "A required field is empty");
  return text;
}

function frame(raw) {
  if (typeof raw !== "string" || raw.length > 8192) failure(422, "Unsupported ink frame");
  const [header, ...lines] = raw.trimEnd().split(/\r?\n/);
  const match = /^GLART1 (\d{1,2}) (\d{1,2}) (\d{1,7}) (\d{1,7})$/.exec(header);
  if (!match || !lines.length || lines.length > 256) failure(422, "Invalid frame header or shape count");
  const [w,h,sw,sh] = match.slice(1).map(Number);
  if (!integer(w,1,96) || !integer(h,1,96) || !integer(sw,1,1000000) || !integer(sh,1,1000000) || sw/sh > 16 || sh/sw > 16) failure(422, "Invalid frame size");
  for (const line of lines) {
    if (!/^\d{1,2}( \d{1,2}){4}$/.test(line)) failure(422, "Invalid ink shape");
    const [x,y,dx,dy,c] = line.split(" ").map(Number);
    if (!dx || !dy || x+dx>w || y+dy>h || !integer(c,1,16)) failure(422, "Shape exceeds frame or palette");
  }
  return [header, ...lines].join("\n");
}

export function artwork(input) {
  if (!input || input.version !== 1 || input.kind !== "ink") failure(422,"Unsupported artwork version or kind");
  if (!Array.isArray(input.frames) || !integer(input.frames.length,1,8) || !integer(input.frameMs,100,5000)) failure(422,"Unsupported frame count or timing");
  const frames = input.frames.map(frame);
  const proportions = frames.map(raw => raw.split("\n",1)[0].split(" ").slice(-2).map(Number));
  if (proportions.some(([w,h]) => w*proportions[0][1] !== h*proportions[0][0])) failure(422,"Frames must share an aspect ratio");
  const asset = {version:1, kind:"ink", frames, frameMs:input.frameMs};
  return asset;
}

async function hash(text) {
  const bytes = await crypto.subtle.digest("SHA-256",encoder.encode(text));
  return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2,"0")).join("");
}
async function owner(db, token) {
  if (typeof token !== "string" || !/^[a-f0-9]{64}$/.test(token)) failure(401,"A creator key is required");
  const result = await db.prepare("SELECT id, display_name FROM creators WHERE token_hash=?").bind(await hash(token)).first();
  if (!result) failure(401,"Creator key was rejected");
  return result;
}
async function body(request) {
  if (Number(request.headers.get("content-length")) > maxBody) failure(413,"Artwork exceeds 64 KiB");
  if (!request.headers.get("content-type")?.startsWith("application/json")) failure(415,"Send JSON");
  const reader = request.body?.getReader();
  if (!reader) failure(400,"Empty request");
  const data = new Uint8Array(maxBody);
  let used = 0;
  while (true) {
    const {done,value} = await reader.read();
    if (done) break;
    if (used + value.length > maxBody) { await reader.cancel(); failure(413,"Artwork exceeds 64 KiB"); }
    data.set(value,used); used += value.length;
  }
  try {
    const result = JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(data.subarray(0,used)));
    if (result && typeof result === "object" && !Array.isArray(result)) return result;
  } catch {}
  failure(400,"Invalid JSON object");
}
function tile(row) {
  return {id:row.id, title:row.title, description:row.description, creator:row.creator,
    tags:JSON.parse(row.tags), thumbnail:row.thumbnail, created:row.created};
}
const columns = "a.id,a.title,a.description,a.tags,a.thumbnail,a.created,c.display_name AS creator";
async function route(request, env) {
  if (!env.DB) failure(503,"Gallery database is unconfigured");
  const url = new URL(request.url);
  const path = url.pathname;
  if (path === "/v1/browse" && request.method === "GET") {
    const page = Number(url.searchParams.get("page") || 1);
    if (!integer(page,1,100000)) failure(400,"Invalid page");
    const query = field(url.searchParams.get("q") || "",80);
    const sql = "SELECT "+columns+" FROM artworks a JOIN creators c ON c.id=a.owner WHERE a.visible=1 AND instr(lower(a.title||' '||a.tags||' '||c.display_name),lower(?))>0 ORDER BY a.created DESC,a.id DESC LIMIT 9 OFFSET ?";
    const rows = (await env.DB.prepare(sql).bind(query,8*(page-1)).all()).results;
    return response(200,{page,more:rows.length>8,items:rows.slice(0,8).map(tile)});
  }
  if ((path.startsWith("/v1/art/") && request.method === "GET") || (path === "/v1/download" && request.method === "POST")) {
    let id;
    let downloadedBy;
    if (request.method === "POST") {
      const data = await body(request);
      downloadedBy = (await owner(env.DB, data.token)).display_name;
      id = field(data.id,64,true);
    } else {
      id = path.slice("/v1/art/".length);
    }
    const item = await env.DB.prepare("SELECT "+columns+",a.asset FROM artworks a JOIN creators c ON c.id=a.owner WHERE a.id=? AND a.visible=1").bind(id).first();
    if (!item) failure(404,"Artwork is unavailable");
    return response(200,{...tile(item),asset:artwork(JSON.parse(item.asset)),downloadedBy});
  }
  if (request.method !== "POST" || !["/v1/publish","/v1/unpublish","/v1/report"].includes(path)) failure(404,"Unknown gallery endpoint");
  const data = await body(request);
  const user = await owner(env.DB,data.token);
  if (path === "/v1/publish") {
    const title=field(data.title,64,true), description=field(data.description,240);
    data.tags ??= [];
    if (!Array.isArray(data.tags) || data.tags.length>8) failure(400,"Use up to eight tags");
    const tags = JSON.stringify([...new Set(data.tags.map(t=>field(t,24,true)))]);
    const operation=field(data.operation,80,true);
    const parsed=artwork(data.asset), asset=JSON.stringify(parsed);
    const digest=await hash(JSON.stringify([title,description,tags,asset]));
    const id=crypto.randomUUID();
    await env.DB.prepare("INSERT INTO artworks(id,owner,operation,digest,title,description,tags,asset,thumbnail,created) VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner,operation) DO NOTHING")
      .bind(id,user.id,operation,digest,title,description,tags,asset,parsed.frames[0],Date.now()).run();
    const row=await env.DB.prepare("SELECT id,digest,visible FROM artworks WHERE owner=? AND operation=?").bind(user.id,operation).first();
    if (row.digest!==digest || !row.visible) failure(409,"Start a new publication for a different revision");
    return response(row.id===id?201:200,{id:row.id});
  }
  const id=field(data.id,64,true);
  if (path === "/v1/report") {
    const found=await env.DB.prepare("SELECT id FROM artworks WHERE id=? AND visible=1").bind(id).first();
    if (!found) failure(404,"Artwork is unavailable");
    await env.DB.prepare("INSERT INTO reports VALUES(?,?,?) ON CONFLICT(artwork,reporter) DO UPDATE SET reason=excluded.reason")
      .bind(id,user.id,field(data.reason,240,true)).run();
    return response(200,{reported:true});
  }
  const result=await env.DB.prepare("UPDATE artworks SET visible=0 WHERE id=? AND owner=?").bind(id,user.id).run();
  if (!result.meta.changes) failure(404,"You do not own a publication with that ID");
  return response(200,{unpublished:true});
}
export default {async fetch(request,env) {
  try { return await route(request,env); }
  catch (error) {return response(error.status || 503,{error:error.status?error.message:"Gallery temporarily unavailable"});}
}};
