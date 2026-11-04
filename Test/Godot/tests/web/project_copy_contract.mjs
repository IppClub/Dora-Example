// CPU contract checks for owned-copy rollback and capability negotiation.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const {GodotWebBridge}=await import(pathToFileURL(process.argv[2]));
function filesystem(){
 const nodes=new Map([['/',{mode:1}]]);let cwd='/';
 const fs={isDir:mode=>mode===1,analyzePath:p=>({exists:nodes.has(p)}),lookupPath:p=>{assert(nodes.has(p));return{node:nodes.get(p)};},
 readdir:p=>['.','..',...Array.from(nodes.keys()).filter(k=>k!=='/'&&k.slice(0,k.lastIndexOf('/'))===(p==='/'?'':p)).map(k=>k.slice(k.lastIndexOf('/')+1))],
 mkdir:p=>{assert(!nodes.has(p));nodes.set(p,{mode:1});},writeFile:(p,b)=>nodes.set(p,{mode:0,bytes:new Uint8Array(b)}),readFile:p=>nodes.get(p).bytes,
 unlink:p=>{assert(nodes.get(p).mode===0);nodes.delete(p);},rmdir:p=>{assert.notEqual(p,cwd);assert.equal(fs.readdir(p).length,2);nodes.delete(p);},cwd:()=>cwd,chdir:p=>{assert(nodes.has(p));cwd=p;}};return fs;
}
const source=filesystem(),target=filesystem();source.mkdir('/game');source.writeFile('/game/project.godot',[1,2]);target.mkdir('/cache');target.writeFile('/cache/shader',[8]);
const bridge=new GodotWebBridge({FS:source,HEAPU8:new Uint8Array(128)},{FS:target},null);
bridge.copyProject('/game');target.chdir('/game');target.writeFile('/game/user-save',[9]);bridge.releaseProjectCopy();
assert(!target.analyzePath('/game/project.godot').exists);assert(target.analyzePath('/game/user-save').exists);assert(target.analyzePath('/cache/shader').exists);assert.equal(target.cwd(),'/');
bridge.copyProject('/game');bridge.releaseProjectCopy();assert(target.analyzePath('/game/user-save').exists);
target.writeFile('/game/project.godot',[99]);assert.throws(()=>bridge.copyProject('/game'),/collides/);assert.deepEqual([...target.readFile('/game/project.godot')],[99]);
target.unlink('/game/project.godot');const write=target.writeFile;target.writeFile=(p,b)=>{write(p,b);throw Error('disk failure');};assert.throws(()=>bridge.copyProject('/game'),/disk failure/);assert(!target.analyzePath('/game/project.godot').exists);target.writeFile=write;
assert.equal(bridge.dispatch(0,0,0,0,0,0),1);assert.equal(bridge.dispatch(0,0,1,0,0,0),1);bridge.godot._dora_web_project_state=()=>2;assert.equal(bridge.dispatch(0,0,0,0,0,0),1);assert.equal(bridge.dispatch(0,0,1,0,0,0),3);assert.equal(bridge.dispatch(22,0,0,0,0,0),2);
bridge.projectCopies=[{path:'/owned',directory:false}];assert.equal(bridge.dispatch(22,0,0,0,0,0),3);bridge.projectCopies=[];bridge.targets=[{}];assert.equal(bridge.dispatch(22,0,0,0,0,0),3);bridge.targets=[];
console.log('PASS owned project cleanup, cwd, unrelated files, collision, partial failure rollback, legacy/new Init and unload query');
