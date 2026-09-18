import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {createRequire} from 'node:module';
import {build} from 'esbuild';
const {chromium}=createRequire(import.meta.url)(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const bundle=await build({stdin:{contents:`
import {createRoot} from 'react-dom/client';
import {App} from './App';
import {LocalWorkspace} from './workspace';
import {createAgentRetirement} from './agent-retirement';
import {createAgentSessionController} from './agent-session-controller';
const root=createRoot(document.getElementById('root'));
root.render(<App/>);
window.configureHost=()=>root.render(<App agentHostOrigin="https://agent.invalid"/>);
window.calls=[];let saveFails=true,cleanupFails=true;
window.allowSave=()=>{saveFails=false};window.allowCleanup=()=>{cleanupFails=false};
window.bind=async()=>{
 const store=await LocalWorkspace.open();const projects=await store.list();store.close();
 const projectId=projects.find(p=>p.name==='Alpha').projectId;
 const controller=createAgentSessionController({projectId,generation:'test',sequence:0,snapshot:{session:{id:1,title:'Alpha Agent',status:'IDLE',workMode:'code'},messages:[],steps:[],checkpoints:[],relatedSessions:[],pendingQuestionnaire:null,spawnInfo:null,hasActivePlan:false,hasEarlierMessages:false}});
 const retirement=createAgentRetirement({persistAndClose:async()=>{window.calls.push('save');if(saveFails)throw Error('save failed');controller.close();},revoke:async()=>{window.calls.push('cleanup');if(cleanupFails)throw Error('cleanup failed');}});
 root.render(<App agent={{projectId,controller,retirement}}/>);
};
`,loader:'tsx',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser',jsx:'automatic',define:{'import.meta.env.BASE_URL':'"/"'},loader:{'.css':'empty'}});
const base=resolve('apps/web/dist');
let launchRequests=0;
const server=createServer(async(req,res)=>{
 try{
  if(req.url.startsWith('/api/projects/') && req.url.endsWith('/agent-launch')){launchRequests++;res.writeHead(403);res.end();return;}
  if(req.url==='/'){res.setHeader('content-type','text/html');res.end('<!doctype html><div id="root"></div><script type="module" src="/test.js"></script>');return;}
  if(req.url==='/test.js'){res.setHeader('content-type','text/javascript');res.end(bundle.outputFiles[0].text);return;}
  const path=resolve(base,'.'+new URL(req.url,'http://localhost').pathname);
  if(!path.startsWith(base+'/'))throw Error('path');
  res.setHeader('content-type',extname(path)==='.js'?'text/javascript':'application/octet-stream');res.end(await readFile(path));
 }catch{res.writeHead(404);res.end();}
});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
let browser;
try{
 browser=await chromium.launch({headless:true,executablePath:process.env.STUDIO_CHROME_PATH});
 const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.getByText('本地存储可用',{exact:false}).waitFor();
 for(const name of ['Beta','Alpha']){
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('button',{name:/新建空白项目/}).click();
  await page.getByLabel('项目名称',{exact:true}).fill(name);
  await page.getByRole('button',{name:'创建并进入 Studio'}).click();
  await page.getByRole('heading',{name,exact:true}).waitFor();
 }
 await page.evaluate(()=>window.bind());
 await page.getByText('Alpha Agent',{exact:true}).waitFor();
 const switchProject=()=>page.locator('.project-link').filter({hasText:'Beta'}).click();
 await switchProject();
 await page.getByRole('button',{name:'重试保存',exact:true}).waitFor();
 await page.getByRole('heading',{name:'Alpha',exact:true}).waitFor();
 await page.evaluate(()=>window.allowSave());await switchProject();
 await page.getByRole('button',{name:'重试清理',exact:true}).waitFor();
 await page.getByRole('heading',{name:'Alpha',exact:true}).waitFor();
 await page.evaluate(()=>window.allowCleanup());await switchProject();
 await page.getByRole('heading',{name:'Beta',exact:true}).waitFor();
 assert.equal(await page.getByText('Alpha Agent',{exact:true}).count(),0);
 assert.deepEqual(await page.evaluate(()=>window.calls),['save','save','cleanup','cleanup']);
 await page.evaluate(()=>window.configureHost());
 await page.getByRole('button',{name:'连接项目 Agent',exact:true}).click();
 await page.getByText('无法连接 Agent，请检查账号授权与服务配置。',{exact:true}).waitFor();
 assert.equal(launchRequests,1);
 assert.equal(await page.locator('iframe').count(),0);
 assert.equal(await page.getByRole('button',{name:'连接项目 Agent',exact:true}).isEnabled(),true);
 await page.getByRole('heading',{name:'Beta',exact:true}).waitFor();
 assert.deepEqual(errors,[]);
 console.log('PASS App project switch failure/retry and configured startup authorization failure preserves workspace without mounting a host.');
}finally{await browser?.close();await new Promise(done=>server.close(done));}
