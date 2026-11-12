import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {build} from 'esbuild';
const require=createRequire(import.meta.url),ide=resolve('../Tools/dora-dora');
const ideRequire=createRequire(resolve(ide,'package.json'));
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const entry=`import React from 'react';import {createRoot} from 'react-dom/client';import {ThemeProvider} from '@mui/material/styles';import Dialog from './LLMConfigDialog';import {theme} from './Theme';import './i18n';window.configs=[];window.saved=[];createRoot(document.getElementById('root')).render(<ThemeProvider theme={theme}><Dialog open onClose={()=>{}}/></ThemeProvider>);`;
const mock=`export const listLLMConfigs=async()=>({success:true,items:window.configs});export const listLocalAgentConfigs=async()=>({success:true,supported:false,items:[]});
export const createLLMConfig=async payload=>{window.saved.push(payload);window.configs=[{...payload,id:1}];return {success:true,id:1};};
export const updateLLMConfig=async payload=>{window.saved.push(payload);window.configs=[payload];return {success:true,id:payload.id};};
export const deleteLLMConfig=async()=>({success:true});export const saveLocalAgentConfig=async()=>({success:false});export const verifyLocalAgentConfig=saveLocalAgentConfig;export const deleteLocalAgentConfig=saveLocalAgentConfig;`;
const bundled=await build({stdin:{contents:entry,loader:'tsx',resolveDir:resolve(ide,'src')},bundle:true,write:false,format:'esm',platform:'browser',jsx:'automatic',loader:{'.css':'empty'},alias:{react:dirname(ideRequire.resolve('react/package.json')),'react-dom':dirname(ideRequire.resolve('react-dom/package.json'))},plugins:[{name:'isolated-config-storage',setup(b){b.onResolve({filter:/^\.\/Service$/},args=>args.importer.endsWith('LLMConfigDialog.tsx')?{path:'service',namespace:'config-fixture'}:undefined);b.onLoad({filter:/.*/,namespace:'config-fixture'},()=>({contents:mock,loader:'js'}));}}]});
const server=createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/app.js'?'text/javascript':'text/html');res.end(req.url==='/app.js'?bundled.outputFiles[0].text:'<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><div id="root"></div><script type="module" src="/app.js"></script>');});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROMIUM_EXECUTABLE?{executablePath:process.env.STUDIO_CHROMIUM_EXECUTABLE}:{})});
const output=resolve('../build/agent-vision-model-config-20261112');await mkdir(output,{recursive:true});
try{
 const page=await browser.newPage({viewport:{width:1280,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.getByRole('button',{name:'Add',exact:true}).click();
 const helpTexts=[['Model help','Dora Agent requires a model endpoint that supports Function Calling.'],['Vision model (optional) help','Uses this API URL and key to analyze project PNG/JPEG images. Leave blank to keep the existing default behavior.'],['Custom Parameters (JSON, optional) help','Top-level parameters override or supplement normal model-call parameters. auxiliaryOptions configures additional parameters for memory-compression calls; when omitted or empty, those calls inherit the normal call configuration.']];
 for(const [name,text] of helpTexts){
  const button=page.getByRole('button',{name,exact:true});
  assert.equal(await page.getByRole('tooltip').count(),0);
  await button.hover();await page.getByRole('tooltip').waitFor();assert.equal(await page.getByRole('tooltip').innerText(),text);
  await page.mouse.move(0,0);await page.getByRole('tooltip').waitFor({state:'hidden'});
  await page.keyboard.press('Tab');await button.focus();await page.getByRole('tooltip').waitFor();assert.equal(await page.getByRole('tooltip').innerText(),text);
  await page.keyboard.press('Escape');await page.getByRole('tooltip').waitFor({state:'hidden'});
  await button.evaluate(el=>el.blur());
 }
 const input=page.getByRole('textbox',{name:'Vision model (optional)',exact:true});await input.waitFor();
 await page.getByRole('textbox',{name:'Name',exact:true}).fill('Vision config');
 await page.getByRole('textbox',{name:'URL',exact:true}).fill('https://relay.invalid/CaseSensitive/chat/completions');
 await page.getByRole('textbox',{name:'Model',exact:true}).fill('main-text-model');
 await page.getByRole('textbox',{name:'API Key',exact:true}).fill('fixture-only');
 const options=page.getByRole('textbox',{name:'Custom Parameters (JSON, optional)',exact:true});
 await options.fill(JSON.stringify({auxiliaryOptions:{},temperature:0.3,sentinel:'keep'}));await input.fill('custom-vl');
 assert.equal(JSON.parse(await options.inputValue()).visionModel,'custom-vl');
 await page.waitForTimeout(200);await page.screenshot({path:resolve(output,'vision-config-desktop.png')});
 await page.setViewportSize({width:390,height:844});await input.scrollIntoViewIfNeeded();
 await page.screenshot({path:resolve(output,'vision-config-mobile.png')});
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
 await page.getByRole('button',{name:'Create',exact:true}).click();await page.waitForFunction(()=>window.saved.length===1);
 const first=await page.evaluate(()=>window.saved[0]);assert.equal(JSON.parse(first.customOptions).visionModel,'custom-vl');assert.equal(first.model,'main-text-model');assert.equal(JSON.parse(first.customOptions).sentinel,'keep');
 await page.setViewportSize({width:1280,height:1000});await page.getByRole('button',{name:'Edit',exact:true}).click();await input.waitFor();assert.equal(await input.inputValue(),'custom-vl');
 await options.fill('{invalid');assert.equal(await input.isDisabled(),true); // invalid JSON remains authoritative
 await options.fill(JSON.stringify({auxiliaryOptions:{},visionModel:'from-json',sentinel:'keep'}));assert.equal(await input.inputValue(),'from-json');
 await input.fill('');assert.equal(JSON.parse(await options.inputValue()).visionModel,undefined);
 await page.getByRole('button',{name:'Save',exact:true}).click();await page.waitForFunction(()=>window.saved.length===2);
 const second=await page.evaluate(()=>window.saved[1]);assert.equal(JSON.parse(second.customOptions).visionModel,undefined);assert.equal(JSON.parse(second.customOptions).sentinel,'keep');assert.deepEqual(errors,[]);
 // Blank, whitespace and {} must save and reopen without auxiliary injection.
 for(const blank of ['', '   ', '{}']){
  await page.getByRole('button',{name:'Edit',exact:true}).click();await input.waitFor();
  await options.fill(blank);const count=await page.evaluate(()=>window.saved.length);
  await page.getByRole('button',{name:'Save',exact:true}).click();await page.waitForFunction(n=>window.saved.length===n+1,count);
  assert.equal((await page.evaluate(()=>window.saved.at(-1))).customOptions,blank.trim());
  await page.getByRole('button',{name:'Edit',exact:true}).click();await input.waitFor();assert.equal(await options.inputValue(),blank.trim());
  await page.getByRole('button',{name:'Close',exact:true}).last().click();
 }
 await page.getByRole('button',{name:'Edit',exact:true}).click();await input.waitFor();
 await options.fill('{"auxiliaryOptions":false}');const count=await page.evaluate(()=>window.saved.length);
 await page.getByRole('button',{name:'Save',exact:true}).click();await page.getByText('If provided, auxiliaryOptions must be a JSON object (can be empty).',{exact:true}).last().waitFor();
 assert.equal(await page.evaluate(()=>window.saved.length),count);
 await options.fill('{"temperature":0.4}');await page.getByRole('button',{name:'Save',exact:true}).click();await page.waitForFunction(n=>window.saved.length===n+1,count);
 assert.deepEqual(JSON.parse((await page.evaluate(()=>window.saved.at(-1))).customOptions),{temperature:0.4});
 assert.deepEqual(errors,[]);
 await page.getByRole('button',{name:'Add',exact:true}).click();await input.waitFor();
 await page.getByRole('textbox',{name:'Name',exact:true}).fill('Blank config');
 await page.getByRole('textbox',{name:'URL',exact:true}).fill('https://relay.invalid/chat/completions');
 await page.getByRole('textbox',{name:'Model',exact:true}).fill('main-text-model');
 await page.getByRole('textbox',{name:'API Key',exact:true}).fill('fixture-only');
 await options.fill('');const beforeCreate=await page.evaluate(()=>window.saved.length);
 await page.getByRole('button',{name:'Create',exact:true}).click();await page.waitForFunction(n=>window.saved.length===n+1,beforeCreate);
 assert.equal((await page.evaluate(()=>window.saved.at(-1))).customOptions,'');
 await page.getByRole('button',{name:'Edit',exact:true}).click();await input.waitFor();assert.equal(await options.inputValue(),'');
 assert.deepEqual(errors,[]);
 const touchContext=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true});
 const touchPage=await touchContext.newPage();await touchPage.goto(`http://127.0.0.1:${server.address().port}`);
 await touchPage.getByRole('button',{name:'Add',exact:true}).tap();
 await touchPage.getByRole('button',{name:'Vision model (optional) help',exact:true}).tap();
 await touchPage.getByRole('tooltip').waitFor();assert.equal(await touchPage.getByRole('tooltip').innerText(),helpTexts[1][1]);
 assert.ok(await touchPage.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
 await touchPage.waitForTimeout(250);await touchPage.screenshot({path:resolve(output,'vision-config-touch-tooltip.png')});await touchContext.close();
 await writeFile(resolve(output,'config-ui-report.json'),JSON.stringify({passed:true,checks:['optional field','preserved main model and custom options','save/reopen roundtrip','JSON editor synchronization','invalid JSON disables field','blank removes override','blank/whitespace/empty object save and reopen without injection','optional auxiliary validation','desktop/mobile layout','help tooltips hover/focus/Escape/touch'],errors},null,2));
 console.log('PASS: vision model configuration create/save/reopen/clear, optional custom parameters, JSON preservation and desktop/mobile layout.');
}finally{await browser.close();await new Promise(done=>server.close(done));}
