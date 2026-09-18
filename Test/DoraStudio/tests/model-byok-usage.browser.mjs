import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {build} from 'esbuild';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';
import {createByokUsageRoute} from '../apps/server/model-byok-usage-route.mjs';
const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const dir=mkdtempSync(join(tmpdir(),'studio-byok-usage-ui-')),ledger=openModelLedger(join(dir,'ledger.db'));
for(const accountId of ['a','b'])ledger.configure('account',accountId,{enabled:true,limit:1,amountLimit:100n},{actorId:'fixture-admin'});
for(let i=0;i<21;i++){const suffix=String(i).padStart(2,'0');ledger.beginByok({requestId:`r${suffix}`,accountId:'a',projectId:'星空冒险',configurationId:'my-config',model:`模型 ${suffix}`,fingerprint:`fixture-${suffix}`});}
ledger.recordByokUsage('a','r00',1,{inputTokens:16384n,outputTokens:2048n,cachedInputTokens:8192n,reasoningOutputTokens:1024n});
const bundle=await build({stdin:{contents:`import {createRoot} from 'react-dom/client';import {ByokUsage} from './ByokUsage';import './style.css';const root=createRoot(document.getElementById('root'));window.selectAccount=accountId=>root.render(<ByokUsage accountId={accountId}/>);window.selectAccount('a');`,loader:'tsx',resolveDir:new URL('../apps/web/src/',import.meta.url).pathname},bundle:true,write:false,format:'esm',jsx:'automatic',outdir:'fixture'});
let route,fail=false,accountId='a';
const server=createServer(async(req,res)=>{
 if(req.url?.startsWith('/api/')){if(fail){res.statusCode=503;res.end();return;}if(await route(req,res))return;}
 const ext=req.url==='/app.js'?'.js':req.url==='/app.css'?'.css':null;
 res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.css'?'text/css':'text/html');
 res.end(ext?bundle.outputFiles.find(file=>file.path.endsWith(ext)).text:'<!doctype html><meta name="viewport" content="width=device-width"><link rel="stylesheet" href="/app.css"><div id="root" style="max-width:760px;margin:20px auto"></div><script type="module" src="/app.js"></script>');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin=`http://127.0.0.1:${server.address().port}`;
route=createByokUsageRoute({studioOrigin:origin,ledger,authenticate:async()=>({accountId})});let browser;
try{
 browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
 const page=await browser.newPage();const errors=[];page.on('pageerror',error=>errors.push(error.message));await page.goto(origin);
 await page.getByText('16,384',{exact:true}).waitFor();assert.equal(await page.locator('.byok-usage-records details').count(),20);
 await page.locator('summary').filter({hasText:'模型 00'}).click();await page.getByText('缓存命中：8,192',{exact:true}).waitFor();
 await page.locator('summary').filter({hasText:'模型 01'}).click();await page.locator('details[open]').filter({hasText:'模型 01'}).getByText('用量尚未返回，等待补记。',{exact:true}).waitFor();
 mkdirSync('apps/web/artifacts',{recursive:true});
 for(const width of [1280,390,320]){await page.setViewportSize({width,height:900});await page.evaluate(()=>scrollTo(0,0));assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);await page.screenshot({path:`apps/web/artifacts/byok-usage-${width}.png`});}
 await page.getByRole('button',{name:'下一页记录'}).click();await page.getByText('模型 20',{exact:true}).waitFor();assert.equal(await page.locator('.byok-usage-records details').count(),1);assert.equal(await page.getByText('模型 00',{exact:true}).count(),0);
 assert.equal(await page.getByRole('button',{name:'下一页记录'}).count(),0);
 await page.getByRole('button',{name:'返回首页'}).click();await page.getByText('模型 00',{exact:true}).waitFor();
 fail=true;await page.getByRole('button',{name:'刷新记录'}).click();await page.getByText('用量暂时无法读取，不代表没有消费。',{exact:true}).waitFor();assert.equal(await page.getByText('16,384',{exact:true}).count(),0);
 fail=false;await page.getByRole('button',{name:'刷新记录'}).click();await page.getByText('16,384',{exact:true}).waitFor();
 accountId='b';await Promise.all([page.waitForResponse(response=>response.url().startsWith(`${origin}/api/byok/usage?`)),page.evaluate(()=>window.selectAccount('b'))]);
 await page.getByText('本页没有用量记录。',{exact:true}).waitFor();assert.equal(await page.getByText('16,384',{exact:true}).count(),0);assert.deepEqual(errors,[]);
 console.log(`PASS Chrome ${browser.version()}: BYOK usage summaries, unknown details, pagination, errors, account reset, 1280/390/320 layouts.`);
}finally{await browser?.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));ledger.close();rmSync(dir,{recursive:true,force:true});}
