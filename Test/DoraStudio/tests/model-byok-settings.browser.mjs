import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {build} from 'esbuild';
import {openModelSecretVault} from '../apps/server/model-secret-vault.mjs';
import {createByokSecretRoute} from '../apps/server/model-byok-secret-route.mjs';
import {openModelConfigurationStore,authorizeOwnedByok} from '../apps/server/model-configuration-store.mjs';
const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const dir=mkdtempSync(join(tmpdir(),'studio-byok-ui-')),vault=openModelSecretVault(join(dir,'vault.db'),{activeKeyId:'fixture',keys:new Map([['fixture',randomBytes(32)]])});
const catalog=openModelConfigurationStore(join(dir,'vault.db'),{providerIds:new Set(['fixture-provider'])});
for(const id of ['owned','next'])catalog.put({id,kind:'byok',ownerId:'a',label:'我的模型配置',model:'fixture-model',providerId:'fixture-provider',enabled:true},{expectedVersion:0,actorId:'a'});
const bundle=await build({stdin:{contents:`import {createRoot} from 'react-dom/client';import {ByokSecretSettings} from './ByokSecretSettings';import './style.css';const root=createRoot(document.getElementById('root'));window.selectConfig=(id='owned',accountId='a')=>root.render(<ByokSecretSettings accountId={accountId} configurationId={id} label="我的模型配置"/>);window.selectConfig();`,loader:'tsx',resolveDir:new URL('../apps/web/src/',import.meta.url).pathname},bundle:true,write:false,format:'esm',jsx:'automatic',outdir:'fixture'});
let route,writes=0;const server=createServer(async(req,res)=>{
 if(req.url?.startsWith('/api/')){if(req.method!=='GET')writes++;if(await route(req,res))return;}
 const ext=req.url==='/app.js'?'.js':req.url==='/app.css'?'.css':null;
 res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.css'?'text/css':'text/html');
 res.end(ext?bundle.outputFiles.find(file=>file.path.endsWith(ext)).text:'<!doctype html><meta name="viewport" content="width=device-width"><link rel="stylesheet" href="/app.css"><div id="root" style="max-width:600px;margin:20px auto"></div><script type="module" src="/app.js"></script>');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin=`http://127.0.0.1:${server.address().port}`;
route=createByokSecretRoute({studioOrigin:origin,vault,authorizeConfiguration:authorizeOwnedByok(catalog,async()=>({accountId:'a'}))});
let browser;
try{
 browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
 const page=await browser.newPage();const errors=[];page.on('pageerror',error=>errors.push(error.message));await page.goto(origin);
 await page.getByText('未托管',{exact:true}).waitFor();
 const key=page.getByLabel('API Key',{exact:true});
 assert.equal(await page.getByRole('button',{name:'加密保存',exact:true}).isDisabled(),true);
 await key.fill('fixture-ui-key');assert.equal(await page.getByRole('button',{name:'加密保存',exact:true}).isDisabled(),true);
 await page.getByRole('checkbox').check();await page.getByRole('button',{name:'加密保存',exact:true}).click();
 await page.getByText('已托管',{exact:true}).waitFor();assert.equal(await key.inputValue(),'');assert.equal(await page.getByRole('checkbox').isChecked(),false);
 await vault.withSecret({kind:'byok',ownerId:'a',configurationId:'owned'},bytes=>assert.equal(bytes.toString(),'fixture-ui-key'));
 assert.equal(writes,1);assert.equal(await page.locator('body').innerText().then(text=>text.includes('fixture-ui-key')),false);
 mkdirSync('apps/web/artifacts',{recursive:true});
 for(const width of [1280,390,320]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);await page.getByRole('region',{name:'自带 API 密钥设置'}).screenshot({path:`apps/web/artifacts/byok-settings-${width}.png`});}
 vault.put({kind:'byok',ownerId:'a',configurationId:'owned'},Buffer.from('external-fixture-key'),{expectedVersion:1,actorId:'a'});
 await key.fill('stale-replacement');await page.getByRole('checkbox').check();await page.getByRole('button',{name:'保存替换',exact:true}).click();
 await page.getByText('配置已被修改，请重新读取状态。',{exact:true}).waitFor();assert.equal(await key.inputValue(),'');assert.equal(await key.isDisabled(),true);assert.equal(writes,2);
 await page.getByRole('button',{name:'刷新状态',exact:true}).click();await page.getByText('已托管',{exact:true}).waitFor();
 await page.getByRole('button',{name:'撤销托管',exact:true}).click();assert.equal(writes,2);
 await page.getByRole('button',{name:'确认撤销托管',exact:true}).click();await page.getByText('未托管',{exact:true}).waitFor();assert.equal(writes,3);
 assert.equal(vault.metadata({kind:'byok',ownerId:'a',configurationId:'owned'}).available,false);
 await key.fill('unsent-fixture');await page.getByRole('checkbox').check();
 await Promise.all([page.waitForResponse(response=>response.url()===`${origin}/api/byok/configurations/next/secret`),page.evaluate(()=>window.selectConfig('next'))]);
 await page.getByText('未托管',{exact:true}).waitFor();assert.equal(await key.inputValue(),'');assert.equal(await page.getByRole('checkbox').isChecked(),false);assert.equal(writes,3);
 assert.deepEqual(errors,[]);console.log(`PASS Chrome ${browser.version()}: BYOK consent, encrypted save, clear input, version conflict, explicit revoke, config reset, 1280/390/320 layouts.`);
}finally{await browser?.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));catalog.close();vault.close();rmSync(dir,{recursive:true,force:true});}
