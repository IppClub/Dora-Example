// One production Studio snapshot -> isolated pthread Player -> Godot GPU case.
import assert from 'node:assert/strict';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve, extname, sep, join} from 'node:path';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {build}=require('esbuild');
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const studio=process.env.DORA_STUDIO_ROOT,engine=resolve(studio,'..');
const runtime=resolve(process.env.STUDIO_RUNTIME_DIR||join(engine,'build/studio-runtime'));
const output=resolve(process.env.STUDIO_GODOT_OUTPUT||join(engine,'build/godot-production-v1/studio-browser'));
await mkdir(output,{recursive:true});
const manifest=JSON.parse(await readFile(join(runtime,'studio-runtime.json')));
assert.equal(manifest.godot,true);
const bundle=await build({stdin:{contents:`export {RuntimeHost} from './apps/web/src/runtime-host.ts'; export {serializeArtifactContent} from './packages/contracts/src/index.ts';`,resolveDir:studio},bundle:true,write:false,format:'iife',globalName:'StudioProbe',platform:'browser'});
const lua=`local D=require("Dora")
local node=assert(D.GodotNode("/game/godot", "",640,360,3))
D.Director.ui:addChild(node)
node:resume()
local frames=0
local announced=false
D.Director.postScheduler:schedule(function()
 frames=frames+1
 if node.running and frames>120 and not announced then announced=true; print("STUDIO_GODOT_READY") end
 assert(frames<3600 or announced, node.lastError)
 return false
end)
`;
const files=[{path:'init.lua',kind:'text',text:lua},
 {path:'godot/.godot/global_script_class_cache.cfg',kind:'text',text:'list=[]\n'}];
const fixture=resolve(process.env.DORA_TEST_REPO||join(engine,'../Dora-Example'),'Test/Godot/tests/web/node_project');
for(const name of ['project.godot','main.tscn','main.gd'])files.push({path:'godot/'+name,kind:'text',text:await readFile(join(fixture,name),'utf8')});
let playerOrigin;
const types={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json'};
const report={passed:false,logs:[],errors:[],missing:[]};
const serve=(parent)=>createServer(async(req,res)=>{
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cross-Origin-Resource-Policy','cross-origin');res.setHeader('Cache-Control','no-store');
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/favicon.ico'){res.writeHead(204).end();return;}
 if(parent){res.setHeader('Content-Type','text/html');res.end(`<!doctype html><body><style>iframe{width:1280px;height:720px}</style><script>${bundle.outputFiles[0].text}</script><script>
 window.events=[];
 const artifact={projectId:'godot-production',revision:1,buildId:'candidate',compilerVersion:'fixture',entry:'init.lua',files:${JSON.stringify(files)},sourceMaps:{}};
 (async()=>{artifact.sha256=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(StudioProbe.serializeArtifactContent(artifact))))].map(b=>b.toString(16).padStart(2,'0')).join('');
 window.host=new StudioProbe.RuntimeHost(document.body,{runtimeURL:${JSON.stringify(playerOrigin+'/index.html')},engineBuild:${JSON.stringify(manifest.engineBuild)},timeoutMs:120000,onEvent:e=>events.push(e)});
 window.run=host.start(artifact);window.ready=await run.ready;})();</script>`);return;}
 const file=resolve(runtime,'.'+(pathname==='/'?'/index.html':pathname));
 if(!file.startsWith(runtime+sep)){res.writeHead(403).end();return;}
 try{res.setHeader('Content-Type',types[extname(file)]||'text/plain');res.end(await readFile(file));}
 catch{report.missing.push(pathname);res.writeHead(404).end();}
});
const player=serve(false);await new Promise(r=>player.listen(0,'127.0.0.1',r));playerOrigin='http://127.0.0.1:'+player.address().port;
const parent=serve(true);await new Promise(r=>parent.listen(0,'127.0.0.1',r));let browser;
try{
 browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=metal','--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage({viewport:{width:1400,height:900}});
 page.on('console',m=>report.logs.push(m.text()));page.on('pageerror',e=>report.errors.push(String(e)));
 await page.goto('http://127.0.0.1:'+parent.address().port);
 await page.waitForFunction(()=>window.ready,null,{timeout:150000});
 assert.equal(await page.evaluate(()=>ready.state),'running');
 await page.waitForFunction(()=>events.some(e=>e.type==='log'&&JSON.stringify(e).includes('STUDIO_GODOT_READY')),null,{timeout:120000});
 const frame=page.frames().find(f=>f.url().startsWith(playerOrigin));assert(frame);
 report.heaps=await frame.evaluate(()=>({isolated:crossOriginIsolated,hostShared:Module.HEAPU8.buffer instanceof SharedArrayBuffer,godotShared:Module.doraGodotRuntime.HEAPU8.buffer instanceof SharedArrayBuffer,distinct:Module.HEAPU8.buffer!==Module.doraGodotRuntime.HEAPU8.buffer}));
 assert(Object.values(report.heaps).every(Boolean));
 const shots=[];
 for(let i=0;i<2;i++){
  if(i)await page.waitForTimeout(750);
  const shot=await page.evaluate(async()=>{const e=await run.capture();if(e.type!=='gameCaptured')throw Error(JSON.stringify(e));return{width:e.width,height:e.height,png:Array.from(e.png)};});
  await writeFile(join(output,i+'.png'),Buffer.from(shot.png));shots.push(shot);
 }
 assert.notDeepEqual(shots[0].png,shots[1].png,'Godot animation did not change');
 report.pixels=await page.evaluate(async(shots)=>{
  const images=[];
  for(const shot of shots){const image=await createImageBitmap(new Blob([new Uint8Array(shot.png)],{type:'image/png'}));const c=document.createElement('canvas');c.width=image.width;c.height=image.height;const ctx=c.getContext('2d');ctx.drawImage(image,0,0);images.push(ctx.getImageData(0,0,c.width,c.height).data);image.close();}
  let yellow=0,changed=0;
  for(let i=0;i<images[0].length;i+=4){if(images[0][i]>200&&images[0][i+1]>200&&images[0][i+2]<50)yellow++;if(Math.max(...[0,1,2].map(c=>Math.abs(images[0][i+c]-images[1][i+c])))>8)changed++;}
  return{yellow,changed};
 },shots);
 assert(report.pixels.yellow>100&&report.pixels.changed>100,'Missing Godot pixels/dynamic frame counter');
 assert.equal(await page.evaluate(()=>run.stop()),true);await page.waitForFunction(()=>document.querySelectorAll('iframe').length===0);
 assert.deepEqual(report.missing,[]);assert.deepEqual(report.errors,[]);
 report.passed=true;report.browser=await browser.version();report.scope='One actual Studio RuntimeHost snapshot and isolated pthread Player, Godot animation, controlled captures and iframe disposal';
}finally{
 if(browser)await browser.close();await Promise.all([new Promise(r=>parent.close(r)),new Promise(r=>player.close(r))]);
 await writeFile(join(output,'verification.json'),JSON.stringify(report,null,2)+'\n');
}
console.log('PASS production Studio Godot Player');
