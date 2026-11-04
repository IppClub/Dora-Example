// Bounded real-project lifecycle acceptance. All owned processes close in finally.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const playwright=require(process.env.DORA_PLAYWRIGHT_MODULE||'playwright');
const directory=path.resolve(process.argv[2]),output=path.resolve(process.argv[3]);
const engine=process.env.DORA_BROWSER_ENGINE||'chromium',contextLoss=process.argv.includes('--context-loss');
fs.mkdirSync(output);
(async()=>{
 const server=http.createServer((req,res)=>{
  const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\//,'')||'index.html',file=path.resolve(directory,name);
  if(name==='favicon.ico'){res.writeHead(204).end();return;}
  if(!file.startsWith(directory+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(err,data)=>{res.writeHead(err?404:200,{'Content-Type':({'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});res.end(err?'Not found':data);});
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));let browser;const logs=[];let result={passed:false,engine};
 try{
  browser=await playwright[engine].launch(engine==='chromium'?{channel:'chrome',headless:true,args:['--use-angle=metal','--autoplay-policy=no-user-gesture-required']}:{headless:true});result.browser=await browser.version();
  const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
  page.on('console',m=>{logs.push(m.text());console.log(m.text());});page.on('pageerror',e=>console.log('PAGEERROR '+e));
  await page.addInitScript({path:path.join(__dirname,'acceptance_init.js')});await page.addInitScript({path:path.join(__dirname,'project_switch_init.js')});
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.waitForFunction(()=>document.documentElement.dataset.doraState==='running',null,{timeout:120000});
  await page.mouse.click(8,8);
  await page.waitForFunction(()=>Module.FS.analyzePath('/user/godot-switch/player.json').exists,null,{timeout:180000});
  result= {...result,...await page.evaluate(async()=>{
   await Promise.all(window.__projectSwitch.jobs);
   const {jobs,...switching}=window.__projectSwitch;
   const gl=Module.canvas.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');
   return {player:JSON.parse(new TextDecoder().decode(Module.FS.readFile('/user/godot-switch/player.json'))),switching,evidence:window.__doraAcceptance,audio:Module.doraTestAudioMetrics,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),distinctHeaps:Module.HEAPU8.buffer!==Module.doraGodotRuntime.HEAPU8.buffer};
  })};
  for(let i=1;i<=result.player.projects;i++)for(const name of ['a','b','c'])fs.writeFileSync(path.join(output,`${i}-${name}.png`),Buffer.from(await page.evaluate(p=>Array.from(Module.FS.readFile(p)),`/user/godot-switch/${i}-${name}.png`)));
  if(contextLoss){
   await page.evaluate(()=>{const ext=Module.canvas.getContext('webgl2').getExtension('WEBGL_lose_context');if(!ext)throw Error('No context-loss extension');ext.loseContext();});
   await page.waitForFunction(()=>document.documentElement.dataset.doraState==='faulted',null,{timeout:15000});
   result.contextLoss=await page.evaluate(()=>({state:document.documentElement.dataset.doraState,active:Module.doraWebPlatform.state.active,lost:Module.doraWebContextLost,openRejected:Module.doraGodotBridge.dispatch(3,0,0,0,0,0)===0,error:Module.doraGodotBridge.lastError}));
  }else{
   await page.evaluate(()=>Module.ccall('dora_web_stop','number',[],[]));
   await page.waitForFunction(()=>document.documentElement.dataset.doraState==='stopped',null,{timeout:15000});
  }
  result.teardown=await page.evaluate(()=>({state:document.documentElement.dataset.doraState,platform:Module.doraWebPlatform.state,disposeAgain:Module.doraWebPlatform.dispose({notifyEngine:false}),imePresent:Boolean(document.querySelector('#dora-ime-input'))}));
  result.passed=true;
 }catch(e){result.error=String(e);throw e;}
 finally{result.logs=logs;fs.writeFileSync(path.join(output,'execution.json'),JSON.stringify(result,null,2)+'\n');if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
