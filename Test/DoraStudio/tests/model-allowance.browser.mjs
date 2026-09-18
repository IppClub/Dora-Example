import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {build} from 'esbuild';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';
import {createModelAllowanceRoute} from '../apps/server/model-allowance-route.mjs';
const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const dir=mkdtempSync(join(tmpdir(),'studio-allowance-browser-')),ledger=openModelLedger(join(dir,'ledger.db'));
const configure=(kind,key,extra={})=>ledger.configure(kind,key,{enabled:true,limit:1,amountLimit:10000000000n,...extra},{actorId:'fixture-admin'});
configure('api','api');configure('account','account');
for(const key of ['g','slow','next'])configure('grant',key,{accountId:'account',apiId:'api',amountLimit:key==='next'?3000000000n:5000000000n});
const bundle=await build({stdin:{contents:`import {createRoot} from 'react-dom/client';import {ModelAllowance} from './ModelAllowance';import './style.css';const root=createRoot(document.getElementById('root'));window.selectGrant=id=>root.render(<ModelAllowance grantId={id}/>);window.selectGrant('g');`,loader:'tsx',resolveDir:new URL('../apps/web/src/',import.meta.url).pathname},bundle:true,write:false,format:'esm',jsx:'automatic',outdir:'fixture'});
let origin,fail=false,releaseSlow,slowSeen=false;
const route=()=>createModelAllowanceRoute({studioOrigin:origin,ledger,authenticate:async()=>({accountId:'account'})});
const server=createServer(async(req,res)=>{
 if(req.url?.startsWith('/api/')){
  if(req.url.includes('/slow/')){slowSeen=true;await new Promise(resolve=>{releaseSlow=resolve;});}
  if(fail){res.statusCode=503;res.end();return;}
  if(await route()(req,res))return;
 }
 const ext=req.url==='/app.js'?'.js':req.url==='/app.css'?'.css':null;
 res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.css'?'text/css':'text/html');
 res.end(ext?bundle.outputFiles.find(file=>file.path.endsWith(ext)).text:'<!doctype html><meta name="viewport" content="width=device-width"><link rel="stylesheet" href="/app.css"><div id="root" style="max-width:380px;margin:auto"></div><script type="module" src="/app.js"></script>');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));origin=`http://127.0.0.1:${server.address().port}`;
let browser;
try{
 browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
 const page=await browser.newPage();const errors=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto(origin);await page.getByText('¥5.00',{exact:true}).waitFor();
 ledger.reserve({requestId:'r',accountId:'account',apiId:'api',grantId:'g',fingerprint:'fixture',reservation:1000000000n,rates:{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:1000000n}});
 await page.evaluate(()=>dispatchEvent(new Event('focus')));await page.getByText('¥4.00',{exact:true}).waitFor();await page.getByText('并发已满，调用需排队',{exact:true}).waitFor();
 ledger.transition('r',1,'dispatch');ledger.transition('r',2,'finish',{inputTokens:1n,outputTokens:0n});
 await page.evaluate(()=>dispatchEvent(new Event('focus')));await page.getByText('≈ ¥5.00',{exact:true}).waitFor();
 await page.getByText('使用明细',{exact:true}).click();assert.ok(await page.getByText('< ¥0.01',{exact:true}).count()>=1);
 mkdirSync('apps/web/artifacts',{recursive:true});
 for(const width of [1280,390,320]){
  await page.setViewportSize({width,height:900});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  await page.getByRole('region',{name:'模型使用额度'}).screenshot({path:`apps/web/artifacts/model-allowance-${width}.png`});
 }
 fail=true;await page.evaluate(()=>dispatchEvent(new Event('focus')));await page.getByText('额度暂时无法读取，不代表余额为零。',{exact:true}).waitFor();
 assert.equal(await page.getByText('≈ ¥5.00',{exact:true}).count(),0);fail=false;
 await page.evaluate(()=>window.selectGrant('slow'));await page.waitForFunction(()=>document.body.textContent.includes('正在读取模型额度'));
 await new Promise((resolve,reject)=>{const timer=setInterval(()=>{if(slowSeen){clearInterval(timer);clearTimeout(deadline);resolve();}},5);const deadline=setTimeout(()=>{clearInterval(timer);reject(new Error('slow request not received'));},3000);});
 await page.evaluate(()=>window.selectGrant('next'));await page.getByText('¥3.00',{exact:true}).waitFor();releaseSlow();
 await page.evaluate(()=>dispatchEvent(new Event('focus')));await page.getByText('¥3.00',{exact:true}).waitFor();
 assert.equal(await page.getByText('¥5.00',{exact:true}).count(),0);assert.deepEqual(errors,[]);
 console.log(`PASS Chrome ${browser.version()}: live SQLite allowance, automatic refresh, tiny usage, error state, grant switch, 1280/390/320 layouts.`);
}finally{releaseSlow?.();await browser?.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));ledger.close();rmSync(dir,{recursive:true,force:true});}
