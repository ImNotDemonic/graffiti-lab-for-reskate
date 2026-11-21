// Run in a private terminal. Only the hash from the SQL instruction goes to D1.
import {randomBytes, randomUUID, createHash} from "node:crypto";
const name = process.argv[2]?.trim();
if (!name || !/^[\p{L}\p{N} _-]{1,48}$/u.test(name)) throw Error("Provide a display name of 1 to 48 letters, digits, spaces, dashes or underscores");
const token=randomBytes(32).toString("hex");
const digest=createHash("sha256").update(token).digest("hex");
console.log("Run this SQL in your D1 console:");
console.log("INSERT INTO creators(id,display_name,token_hash) VALUES('"+randomUUID()+"','"+name+"','"+digest+"');");
console.log("Deliver this creator key privately to its owner once:");
console.log(token);
