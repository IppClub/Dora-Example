import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const root=process.env.DORA_ENGINE_ROOT||process.env.DORA_SSR_ROOT;
if(!root)throw new Error('Set DORA_ENGINE_ROOT to the engine checkout');
const {GodotWebBridge}=await import(pathToFileURL(path.join(root,'Tools/Godot/web/runtime_bridge.js')));
let state=2,id=0,copies=0,released=0;
const strings=new Map(),freed=[],activated=[];
const g={stringToNewUTF8:value=>{strings.set(++id,value);return id;},UTF8ToString:ptr=>strings.get(ptr),_free:ptr=>freed.push(ptr),
 _dora_web_project_state:()=>state,
 _dora_web_check:(project,file,source)=>{
  assert.equal(strings.get(project),'/工程');assert.equal(strings.get(file),'/工程/main.gd');assert.equal(strings.get(source),'extends Node\n# 中文');
  return g.stringToNewUTF8(JSON.stringify({success:true,info:[]}));
 }};
const bridge=new GodotWebBridge({},g,{activate:value=>activated.push(value)});
bridge.copyProject=()=>{copies++;};bridge.releaseProjectCopy=()=>{released++;};
assert.deepEqual(JSON.parse(bridge.checkCode('/工程','/工程/main.gd','extends Node\n# 中文')),{success:true,info:[]});
assert.equal(copies,1);assert.equal(released,1);assert.equal(freed.length,3);assert.deepEqual(activated,['godot','host']);
state=1;bridge.checkCode('/工程','/工程/main.gd','extends Node\n# 中文');assert.equal(copies,1);assert.equal(released,1);
state=2;g._dora_web_check=()=>{throw Error('controlled check failure');};
assert.throws(()=>bridge.checkCode('/工程','/工程/main.gd','extends Node\n# 中文'),/controlled/);
assert.equal(released,2);assert.equal(freed.length,9);assert.equal(activated.at(-1),'host');
delete g._dora_web_check;assert.throws(()=>bridge.checkCode('/工程','/工程/main.gd',''),/no compiler-check API/);
console.log('Web compiler bridge UTF-8, isolated/active lifecycle and error cleanup passed');
