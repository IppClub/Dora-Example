// Observe production calls; never move function pointers between WASM tables.
(()=>{
 const evidence=window.__projectSwitch={opens:[],closes:[],queries:[],hashes:[],jobs:[]};
 const outer=Object.getOwnPropertyDescriptor(window,'Module');
 Object.defineProperty(window,'Module',{configurable:true,get:outer.get,set(module){
  outer.set(module);if(!module||module.__projectSwitchConfigured)return;module.__projectSwitchConfigured=true;
  const inner=Object.getOwnPropertyDescriptor(module,'doraGodotBridge');
  Object.defineProperty(module,'doraGodotBridge',{configurable:true,get:inner.get,set(facade){
   inner.set(facade);const dispatch=facade.dispatch.bind(facade);let project;
   facade.dispatch=(...args)=>{
    const path=args[0]===3?module.UTF8ToString(new DataView(module.HEAPU8.buffer).getUint32(args[1]+20,true)):null;
    const result=dispatch(...args),g=module.doraGodotRuntime;
    if(args[0]===3){
     evidence.opens.push({path,success:Boolean(result),state:g._dora_web_project_state(),heap:g.HEAPU8.buffer.byteLength});
     if(result){
      project=path;const files={};
      const copy=p=>{const node=g.FS.lookupPath(p).node;if(g.FS.isDir(node.mode)){for(const name of g.FS.readdir(p))if(name!=='.'&&name!=='..')copy(p+'/'+name);}else files[p.slice(path.length+1)||'game.pck']=g.FS.readFile(p).slice();};copy(path);
      const record={path,files:{}};evidence.hashes.push(record);
      evidence.jobs.push(Promise.all(Object.entries(files).map(async([name,bytes])=>{record.files[name]=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');})));
     }else evidence.opens.at(-1).copyReleased=!g.FS.analyzePath(path).exists;
    }
    if(args[0]===9){evidence.closes.push({path:project,state:g._dora_web_project_state(),copyReleased:!g.FS.analyzePath(project).exists});project=null;}
    if(args[0]===22)evidence.queries.push(result);
    return result;
   };
  }});
 }});
})();
