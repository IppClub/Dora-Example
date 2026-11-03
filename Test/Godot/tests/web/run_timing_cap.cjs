// Actual Godot get_image() pixels, extracted from the independent Godot heap.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const playwright=require(process.env.DORA_PLAYWRIGHT_MODULE||'playwright');
const engine=process.env.DORA_BROWSER_ENGINE||'chromium';
if(!['chromium','firefox','webkit'].includes(engine))throw Error('Unsupported browser engine');
const directory=path.resolve(process.argv[2]),out=path.resolve(process.argv[3]);
fs.mkdirSync(out,{recursive:false});
const metadata=JSON.parse(fs.readFileSync(path.join(directory,'timing-cap-source.json'),'utf8'));
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const artifacts={};for(const name of ['dora-player-runtime.js','dora-player-runtime.wasm','dora-web-manifest.json','godot/dora-godot.js','godot/dora-godot.wasm','godot/shared_gl.mjs','godot/runtime_bridge.mjs'])artifacts[name]=digest(fs.readFileSync(path.join(directory,name)));
(async()=>{
 const types={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json'};
 const server=http.createServer((request,response)=>{
  const relative=decodeURIComponent(new URL(request.url,'http://localhost').pathname).replace(/^\//,'')||'index.html';
  const file=path.resolve(directory,relative);
  if(!file.startsWith(directory+path.sep)){response.writeHead(403).end();return;}
  if(relative==='favicon.ico'){response.writeHead(204).end();return;}
  fs.readFile(file,(error,data)=>{response.writeHead(error?404:200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});response.end(error?'Not found':data);});
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let browser,report={passed:false,browser_engine:engine,artifacts,metadata};const logs=[],errors=[],warnings=[];
 try{
  const launch={headless:true};if(engine==='chromium')Object.assign(launch,{channel:process.env.DORA_BROWSER_CHANNEL||'chrome',args:['--use-angle=metal','--autoplay-policy=no-user-gesture-required']});
  browser=await playwright[engine].launch(launch);report.browser=await browser.version();
  const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
  page.on('console',message=>{const text=message.text();logs.push(text);console.log('BROWSER '+message.type()+': '+text);if(message.type()==='error'||text.includes('[error]'))errors.push(text);if(message.type()==='warning')warnings.push(text);});
  page.on('pageerror',error=>errors.push(String(error)));
  await page.addInitScript({path:path.join(__dirname,'acceptance_init.js')});
  await page.addInitScript(()=>{
   window.__capShutdown={calls:0,completed:0};
   window.addEventListener('dora-statechange',()=>{
    const g=window.Module?.doraGodotRuntime;
    if(!g||g.__capObserved)return;
    g.__capObserved=true;
    const shutdown=g._dora_web_shutdown;
    g._dora_web_shutdown=(...args)=>{
     window.__capShutdown.calls++;
     const result=shutdown(...args);
     window.__capShutdown.completed++;
     return result;
    };
   });
  });
  await page.goto(`http://127.0.0.1:${server.address().port}/`,{waitUntil:'domcontentloaded'});
  let copied=false;
  const deadline=Date.now()+90000;
  while(!logs.some(text=>text.includes('DORA_WEB_CAP_DONE'))&&Date.now()<deadline){
   if(errors.some(text=>!text.startsWith('Blocking on the main thread is very dangerous')))throw Error('Browser/native error');
   const data=await page.evaluate(()=>{
    const h=window.Module,g=h?.doraGodotRuntime;if(!g?.FS||!h?.FS)return null;
    if(g.FS.analyzePath('/game/godot/clock-a.png').exists)h.FS.writeFile('/user/cap-a.ready','ready');
    if(!g.FS.analyzePath('/game/godot/result.json').exists)return null;
    const files={};for(const name of ['clock-a.png','clock-b.png','result.json'])files[name]=Array.from(g.FS.readFile('/game/godot/'+name));
    h.FS.writeFile('/user/cap.done','copied');return files;
   });
   if(data&&!copied){for(const [name,bytes]of Object.entries(data))fs.writeFileSync(path.join(out,name),Buffer.from(bytes));copied=true;}
   if(metadata.host_shutdown&&copied&&await page.evaluate(()=>document.documentElement.dataset.doraState==='stopped'))break;
   await page.waitForTimeout(20);
  }
  if(!copied||(!metadata.host_shutdown&&!logs.some(text=>text.includes('DORA_WEB_CAP_DONE'))))throw Error('Web CPU readback timeout');
  if(!metadata.host_shutdown)await page.evaluate(()=>Module.ccall('dora_web_stop','number',[],[]));
  await page.waitForFunction(()=>document.documentElement.dataset.doraState==='stopped',null,{timeout:10000});
  const teardown=await page.evaluate(()=>({state:document.documentElement.dataset.doraState,platform:Module.doraWebPlatform.state,libgodot_shutdown:window.__capShutdown,gpu_lifecycle:Module.doraTestAudioMetrics}));
  report.teardown=teardown;
  if(teardown.platform.active||teardown.libgodot_shutdown.calls!==1||teardown.libgodot_shutdown.completed!==1)throw Error('Normal LibGodot stop missing');
  const sources=await page.evaluate(names=>{
   const files={host:{},godot:{}};for(const name of names){files.host[name]=Array.from(Module.FS.readFile('/game/godot/'+name));files.godot[name]=Array.from(Module.doraGodotRuntime.FS.readFile('/game/godot/'+name));}return files;
  },Object.keys({...metadata.fixture,...metadata.adapters}));
  for(const side of ['host','godot'])for(const [name,sha]of Object.entries({...metadata.fixture,...metadata.adapters}))if(digest(Buffer.from(sources[side][name]))!==sha)throw Error('Fixture changed in '+side+': '+name);
  const dimensions=JSON.parse(fs.readFileSync(path.join(out,'result.json'),'utf8'));
  if(dimensions['clock-a'].width!==640||dimensions['clock-a'].height!==360||dimensions['clock-b'].width!==800||dimensions['clock-b'].height!==450)throw Error('Godot CPU image resize mismatch');
  if(errors.some(text=>!text.startsWith('Blocking on the main thread is very dangerous'))||warnings.some(text=>/GL_INVALID|INVALID_OPERATION|INVALID_VALUE|INVALID_ENUM/.test(text)))throw Error('Browser diagnostics');
  report={...report,passed:true,teardown,source_hashes_verified:true,scope:'Godot get_image() CPU pixels with 2/3/4 target selection, resize, and normal shared GPU drain; image clock verifier additionally required'};
 }catch(error){report.error=String(error);throw error;}
 finally{
  report.logs=logs;report.browser_errors=errors;report.browser_warnings=warnings;
  fs.writeFileSync(path.join(out,'execution.json'),JSON.stringify(report,null,2));fs.writeFileSync(path.join(out,'run.log'),logs.join('\n'));
  if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));
 }
})().catch(error=>{console.error(error);process.exitCode=1;});
