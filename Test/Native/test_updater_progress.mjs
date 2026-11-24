import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {resolve, join} from 'node:path';

const root = process.env.DORA_SSR_ROOT;
assert.ok(root, 'Set DORA_SSR_ROOT to the engine checkout');
const native = process.env.DORA_COMPILER_URL ?? 'http://127.0.0.1:8866';
const require = createRequire(resolve(root, 'Tools/dora-dora/package.json'));
const {build} = require('esbuild');
const testRequire = createRequire(new URL('../DoraStudio/package.json', import.meta.url));
const {chromium} = testRequire(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const component = join(resolve(root), 'Tools/dora-dora/src/EngineUpdate.tsx');
const bundle = (await build({stdin: {contents: `
import React from 'react';
import {createRoot} from 'react-dom/client';
import EngineUpdate from ${JSON.stringify(component)};
createRoot(document.getElementById('app')).render(<EngineUpdate open={true} onOpen={()=>{}} onClose={()=>{}} saveBeforeInstall={async()=>true}><span /></EngineUpdate>);
`, loader: 'tsx', resolveDir: resolve(root, 'Tools/dora-dora')}, bundle: true, write: false,
  platform: 'browser', define: {'process.env.NODE_ENV': '"production"'},
  plugins: [{name: 'updater-test-services', setup(builder) {
    builder.onResolve({filter: /^\.\/(Service|Info|Theme)$/}, args =>
      args.importer === component ? {path: args.path, namespace: 'updater-test'} : undefined);
    builder.onLoad({filter: /.*/, namespace: 'updater-test'}, args => ({contents:
      args.path === './Service' ? `
const post = async (route, body={}) => (await fetch('/engine-update/'+route, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})).json();
export const engineUpdateState = () => post('state');
export const engineUpdateAction = (name, data) => post(name,data);
` : args.path === './Info' ? 'export default {locale:"zh"};' : 'export const Color={Theme:"#ffc107",BackgroundDark:"#171717"};', loader: 'js'}));
  }}], logLevel: 'silent'})).outputFiles[0].text;
const states = [];
const server = createServer(async (req, res) => {
  try {
    if (req.url === '/') {res.setHeader('Content-Type','text/html');res.end('<div id="app"></div><script src="/app.js"></script>');return;}
    if (req.url === '/app.js') {res.setHeader('Content-Type','text/javascript');res.end(bundle);return;}
    if (req.url?.startsWith('/engine-update/')) {
      const chunks=[]; for await (const chunk of req) chunks.push(chunk);
      const result=await fetch(native+req.url,{method:'POST',headers:{'Content-Type':'application/json','Sec-Fetch-Site':'same-origin'},body:Buffer.concat(chunks)});
      const body=await result.text();
      if(req.url.endsWith('/state')) {
        assert.equal(result.status,200,'Updater state must remain serializable while checking');
        const state=JSON.parse(body);
        if(state.progress) {
          assert.equal(typeof state.progress.progress,'number');assert.equal(typeof state.progress.message,'string');
        }
        states.push(state);
      }
      res.writeHead(result.status,{'Content-Type':'application/json'});res.end(body);return;
    }
    res.writeHead(404);res.end();
  } catch(error) {res.writeHead(500);res.end(String(error));}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base=`http://127.0.0.1:${server.address().port}`;
const browser=await chromium.launch({headless:true});
try {
  const page=await browser.newPage();
  const failures=[];
  page.on('response',res=>{if(res.url().endsWith('/engine-update/state')&&res.status()!==200)failures.push(res.status());});
  await page.addInitScript(()=>{
    window.falseConnectionAlerts=[];window.expectConnectionFailure=false;
    new MutationObserver(()=>{
      if(!window.expectConnectionFailure && [...document.querySelectorAll('[role="alert"]')].some(node=>node.textContent.includes('无法连接引擎')))
        window.falseConnectionAlerts.push('connection alert during a healthy check');
    }).observe(document,{subtree:true,childList:true,characterData:true});
  });
  await page.goto(base);
  const idle=async()=>{
    const deadline=Date.now()+90000;
    while(Date.now()<deadline){
      const res=await fetch(base+'/engine-update/state',{method:'POST',body:'{}'});
      assert.equal(res.status,200,await res.text());
      const state=states.at(-1);
      if(!['idle','checking','canceling'].includes(state.phase))return state;
      await new Promise(resolve=>setTimeout(resolve,100));
    }
    throw new Error('Update check did not finish');
  };
  await idle();
  for(let attempt=0;attempt<3;attempt++) {
    const response=page.waitForResponse(res=>res.url().endsWith('/engine-update/check'));
    await page.getByRole('button',{name:'重新检查',exact:true}).click();
    assert.equal((await (await response).json()).success,true);
    await idle();
  }
  const originalSource=states[0].source;
  const alternateSource=originalSource==='AtomGit'?'GitHub':'AtomGit';
  for(const source of [alternateSource,originalSource]) {
    await page.getByRole('combobox').click();
    const response=page.waitForResponse(res=>res.url().endsWith('/engine-update/check'));
    await page.getByRole('option',{name:source,exact:true}).click();
    assert.equal((await (await response).json()).success,true);
    await idle();
    assert.equal(states.at(-1).source,source);
  }
  assert.ok(states.some(state=>state.phase==='checking'&&state.progress),'Must observe real in-flight update progress');
  assert.deepEqual(failures,[]);
  assert.deepEqual(await page.evaluate(()=>window.falseConnectionAlerts),[]);
  await page.evaluate(()=>{window.expectConnectionFailure=true;});
  await page.route('**/engine-update/state',route=>route.abort());
  await page.getByText('无法连接引擎，正在重试连接…',{exact:true}).waitFor();
  await page.unroute('**/engine-update/state');
  await page.getByText('无法连接引擎，正在重试连接…',{exact:true}).waitFor({state:'hidden'});
  console.log(`PASS: ${states.length} valid native update states, repeated checks and source switching without false alerts, simulated disconnect warning and recovery in Chrome ${browser.version()}`);
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
