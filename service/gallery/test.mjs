import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createServer } from "node:http";
import { once } from "node:events";
import worker from "./worker.mjs";

const db = new DatabaseSync(":memory:");
db.exec(readFileSync(new URL("./migrations/0001_gallery.sql",import.meta.url),"utf8"));
const env = {DB:{prepare(sql) {
  const statement=db.prepare(sql);
  return {bind(...values){return {
    first:()=>statement.get(...values),
    all:()=>({results:statement.all(...values)}),
    run:()=>({meta:statement.run(...values)})
  };}};
}}};
function account(name,token) {
  db.prepare("INSERT INTO creators VALUES(?,?,?)").run(name,name,createHash("sha256").update(token).digest("hex"));
}
const token="a".repeat(64), visitor="b".repeat(64);
account("Artist",token); account("Visitor",visitor);
const server=createServer(async(req,res)=>{
  const bytes=[]; for await(const block of req) bytes.push(block);
  const reply=await worker.fetch(new Request("http://local.test"+req.url,{method:req.method,headers:req.headers,body:bytes.length?Buffer.concat(bytes):undefined}),env);
  res.writeHead(reply.status,Object.fromEntries(reply.headers)); res.end(await reply.text());
});
server.listen(0,"127.0.0.1"); await once(server,"listening");
const root="http://127.0.0.1:"+server.address().port;
const post=(path,data)=>fetch(root+path,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(data)});
try {
  const raw="GLART1 16 16 16 16\n0 0 2 1 3", asset={version:1,kind:"ink",frameMs:200,frames:[raw]};
  const submission={title:"Orange line",description:"A gallery test",tags:["test"],token,operation:"1",asset};
  const created=await post("/v1/publish",submission); assert.equal(created.status,201);
  const {id}=await created.json();
  assert.deepEqual(await (await post("/v1/publish",submission)).json(),{id});
  assert.equal((await post("/v1/publish",{...submission,title:"changed"})).status,409);
  const browse=await (await fetch(root+"/v1/browse?q=Artist")).json();
  assert.equal(browse.items[0].id,id);assert.equal(browse.items[0].thumbnail,raw);
  assert.deepEqual((await (await fetch(root+"/v1/art/"+id)).json()).asset,asset);
  const visitorCopy=await (await post("/v1/download",{id,token:visitor})).json();
  assert.equal(visitorCopy.downloadedBy,"Visitor"); assert.equal(visitorCopy.creator,"Artist");
  assert.deepEqual(visitorCopy.asset,asset);
  assert.equal((await post("/v1/unpublish",{id,token:visitor})).status,404);
  assert.equal((await post("/v1/report",{id,token:visitor,reason:"test"})).status,200);
  assert.equal(db.prepare("select count(*) as n from reports").get().n,1);
  assert.equal((await post("/v1/publish",{...submission,token:"bad"})).status,401);
  assert.equal((await post("/v1/publish",{...submission,asset:{...asset,frames:[raw+"0"]}})).status,422);
  assert.equal((await post("/v1/publish",{...submission,title:"x".repeat(66000)})).status,413);
  assert.equal((await post("/v1/unpublish",{id,token})).status,200);
  assert.equal((await fetch(root+"/v1/art/"+id)).status,404);
  assert.equal((await (await fetch(root+"/v1/browse")).json()).items.length,0);
  console.log("PASS actual HTTP, SQL migration, publish, retry, search, download, bounds, ownership, report and removal");
} finally {server.closeAllConnections(); server.close(); db.close();}
