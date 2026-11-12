// Real shared composer + production uploader -> running native engine upload API.
// Only model/session submission is stubbed; no LLM request or saved config change.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {resolve,dirname,join} from 'node:path';
import {build} from 'esbuild';
const require=createRequire(import.meta.url),ide=resolve('../Tools/dora-dora'),ideRequire=createRequire(join(ide,'package.json'));
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const root=resolve(process.env.DORA_SSR_ROOT||'..'),output=join(root,'build/agent-attachments-qa'),project=join(output,'project');await mkdir(project,{recursive:true});
const component=join(root,'Studio/packages/agent-ui/src/AgentComposer.tsx');
const entry=`import React from 'react';import {createRoot} from 'react-dom/client';import {SharedAgentComposer} from ${JSON.stringify(component)};import {uploadAgentAttachment} from './AgentAttachments';window.sent=[];window.attempts=[];window.uploadCalls=[];window.releaseUpload=()=>{};function Fixture(){const [prompt,setPrompt]=React.useState(''),[scope,setScope]=React.useState('one'),[running,setRunning]=React.useState(false);window.setScope=setScope;window.setRunning=setRunning;return <SharedAgentComposer attachmentScopeKey={scope} prompt={prompt} onPromptChange={setPrompt} running={running} loading={false} onUploadAttachment={async(file,id,signal)=>{window.uploadCalls.push(file.name);if(window.delayUpload)await new Promise(done=>window.releaseUpload=done);return uploadAgentAttachment(${JSON.stringify(project)},file,id,signal);}} onSend={async(delivery,text,id)=>{const record={delivery,text:text??prompt,id};window.attempts.push(record);if(window.failSend)return false;window.sent.push(record);return true;}}/>;}createRoot(document.getElementById('root')).render(<Fixture/>);`;
const mock=`const post=async(path,body)=>{const res=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});if(!res.ok)throw new Error('Fixture API '+res.status);return res.json();};export const newFile=body=>post('/new',body);export const exist=body=>post('/exist',body);export const addr=path=>path;`;
const bundle=await build({stdin:{contents:entry,loader:'tsx',resolveDir:join(ide,'src')},bundle:true,write:false,platform:'browser',format:'esm',jsx:'automatic',loader:{'.css':'empty'},alias:{react:dirname(ideRequire.resolve('react/package.json')),'react-dom':dirname(ideRequire.resolve('react-dom/package.json'))},plugins:[{name:'native-engine-api',setup(b){b.onResolve({filter:/^\.\/Service$/},args=>args.importer.endsWith('AgentAttachments.ts')?{path:'service',namespace:'fixture'}:undefined);b.onLoad({filter:/.*/,namespace:'fixture'},()=>({contents:mock,loader:'js'}));}}]});
let uploadRequests=0,failUpload=false;
const server=createServer(async(req,res)=>{try{
 if(req.url==='/app.js'){res.setHeader('Content-Type','text/javascript');res.end(bundle.outputFiles[0].text);return;}
 if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:#1d1d1d;color:#eee;font-family:sans-serif}*{box-sizing:border-box}</style><div id="root"></div><script type="module" src="/app.js"></script>');return;}
 if(!['/upload','/new','/exist'].includes(new URL(req.url,'http://local').pathname)){res.statusCode=404;res.end();return;}
 const chunks=[];for await(const c of req)chunks.push(c);const body=Buffer.concat(chunks);
 if(req.url.startsWith('/upload')){uploadRequests++;if(failUpload){failUpload=false;res.statusCode=503;res.end();return;}}
 const target='http://127.0.0.1:8866'+req.url;
 const response=await fetch(target,{method:'POST',headers:{'Content-Type':req.headers['content-type']||'application/json',Origin:new URL(target).origin,'Sec-Fetch-Site':'same-origin'},body});res.statusCode=response.status;res.end(Buffer.from(await response.arrayBuffer()));
}catch(error){res.statusCode=500;res.end(String(error));}});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROMIUM_EXECUTABLE?{executablePath:process.env.STUDIO_CHROMIUM_EXECUTABLE}:{})});
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC','base64');
const files=[{name:'参考.png',mimeType:'image/png',buffer:png},{name:'notes.txt',mimeType:'text/plain',buffer:Buffer.from('Attachment fixture UTF-8 中文')},{name:'很长的文件名称用于验证固定卡片尺寸与两行省略显示.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF fixture')}];
try{
 const page=await browser.newPage({viewport:{width:1100,height:750}}),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(`http://127.0.0.1:${server.address().port}`);
 const input=page.locator('input[type=file]'),prompt=page.getByRole('textbox',{name:'Agent 描述'}),send=page.getByRole('button',{name:'发送',exact:true});
 const chooser=page.waitForEvent('filechooser');await page.getByRole('button',{name:'添加文件',exact:true}).click();await(await chooser).setFiles(files);
 assert.equal(await page.getByRole('listitem').count(),3);assert.equal(uploadRequests,0);const cards=await page.locator('[data-agent-file-card]').evaluateAll(items=>items.map(item=>({width:item.getBoundingClientRect().width,height:item.getBoundingClientRect().height})));assert.deepEqual(cards,[{width:160,height:112},{width:160,height:112}]);await page.screenshot({path:join(output,'file-cards-longname.png')});assert.equal(await page.getByRole('img',{name:'参考.png'}).count(),1);const imageStyle=await page.getByRole('img',{name:'参考.png'}).evaluate(img=>({width:img.getBoundingClientRect().width,height:img.getBoundingClientRect().height,fit:getComputedStyle(img).objectFit,border:getComputedStyle(img.parentElement).borderTopWidth}));assert.deepEqual(imageStyle,{width:120,height:120,fit:'cover',border:'0px'});
 await page.getByRole('button',{name:'移除附件 '+files[2].name,exact:true}).click();await prompt.fill('请分析附件');
 await page.screenshot({path:join(output,'attachments-desktop.png')});await send.click();await page.waitForFunction(()=>window.sent.length===1);
 assert.equal(uploadRequests,2);assert.equal(await page.getByRole('listitem').count(),0);assert.equal(await prompt.inputValue(),'');
 const first=await page.evaluate(()=>window.sent[0]);const references=first.text.split('\n').filter(line=>line.startsWith('{')).map(line=>JSON.parse(line));assert.equal(references.length,2);
 for(let i=0;i<2;i++){assert.match(references[i].path,/^\.agent\/tmp\/attachments\/[\w-]+\//);assert.deepEqual(await readFile(join(project,references[i].path)),files[i].buffer);}
 // Image paste is consumed as an attachment; ordinary text paste stays native.
 await prompt.evaluate((element,base64)=>{const data=new DataTransfer();data.items.add(new File([Uint8Array.from(atob(base64),c=>c.charCodeAt(0))],'paste.png',{type:'image/png'}));element.dispatchEvent(new ClipboardEvent('paste',{clipboardData:data,bubbles:true,cancelable:true}));},png.toString('base64'));
 assert.equal(await page.getByRole('listitem').count(),1);assert.equal(uploadRequests,2);
 await send.click();await page.waitForFunction(()=>window.sent.length===2);assert.equal(await prompt.inputValue(),'');
 // Failed upload keeps draft; a failed send reuses uploaded bytes and request ID.
 await input.setInputFiles([files[1]]);await prompt.fill('retry text');failUpload=true;await send.click();await page.getByRole('alert').waitFor();assert.equal(await prompt.inputValue(),'retry text');assert.equal(await page.getByRole('listitem').count(),1);assert.equal(await page.evaluate(()=>window.sent.length),2);
 await page.evaluate(()=>window.failSend=true);await send.click();await page.waitForFunction(()=>window.attempts.length===3);const beforeRetry=uploadRequests;
 await page.evaluate(()=>window.failSend=false);await send.click();await page.waitForFunction(()=>window.sent.length===3);assert.equal(uploadRequests,beforeRetry);const attempts=await page.evaluate(()=>window.attempts);assert.equal(attempts.at(-1).id,attempts.at(-2).id);
 // Typing a new draft during upload must not be cleared or sent accidentally.
 await input.setInputFiles([files[0]]);await prompt.fill('original');await page.evaluate(()=>window.delayUpload=true);await send.click();await prompt.fill('next draft');await page.evaluate(()=>{window.delayUpload=false;window.releaseUpload();});await page.waitForFunction(()=>window.sent.length===4);assert.equal(await prompt.inputValue(),'next draft');assert.match((await page.evaluate(()=>window.sent.at(-1))).text,/^original/);
 // Workspace/session switch cancels submission of the old attachment draft.
 await input.setInputFiles([files[0]]);await page.evaluate(()=>window.delayUpload=true);await send.click();await page.evaluate(()=>window.setScope('two'));await page.waitForFunction(()=>document.querySelectorAll('[role=listitem]').length===0);await page.evaluate(()=>{window.delayUpload=false;window.releaseUpload();});await page.waitForTimeout(300);assert.equal(await page.evaluate(()=>window.sent.length),4);
 await input.setInputFiles([files[0]]);await page.setViewportSize({width:390,height:844});await page.screenshot({path:join(output,'attachments-mobile.png')});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
 await page.evaluate(()=>window.setRunning(true));await page.getByRole('button',{name:'加入队列',exact:true}).click();await page.waitForFunction(()=>window.sent.length===5);assert.equal((await page.evaluate(()=>window.sent.at(-1))).delivery,'queue');
 await input.setInputFiles([files[1]]);await prompt.focus();const modifier=await page.evaluate(()=>/Mac|iPhone|iPad/.test(navigator.platform)?'Meta':'Control');await prompt.press(modifier+'+Enter');await page.waitForFunction(()=>window.sent.length===6);assert.equal((await page.evaluate(()=>window.sent.at(-1))).delivery,'steer');
 const jpeg=await readFile(join(root,'Assets/Image/banner.jpg'));
 await prompt.evaluate((element,base64)=>{const data=new DataTransfer();data.items.add(new File([Uint8Array.from(atob(base64),c=>c.charCodeAt(0))],'paste.jpg',{type:'image/jpeg'}));element.dispatchEvent(new ClipboardEvent('paste',{clipboardData:data,bubbles:true,cancelable:true}));},jpeg.toString('base64'));
 assert.equal(await page.getByRole('img',{name:'paste.jpg'}).count(),1);await page.getByRole('button',{name:'加入队列',exact:true}).click();await page.waitForFunction(()=>window.sent.length===7);
 const nativeTextPaste=await prompt.evaluate(element=>{const data=new DataTransfer();data.setData('text/plain','plain text');return element.dispatchEvent(new ClipboardEvent('paste',{clipboardData:data,bubbles:true,cancelable:true}));});assert.equal(nativeTextPaste,true);assert.equal(await page.getByRole('listitem').count(),0);
 await input.setInputFiles([{name:'same.txt',mimeType:'text/plain',buffer:Buffer.from('one')},{name:'same.txt',mimeType:'text/plain',buffer:Buffer.from('two')}]);await page.getByRole('button',{name:'加入队列',exact:true}).click();await page.waitForFunction(()=>window.sent.length===8);
 const duplicates=(await page.evaluate(()=>window.sent.at(-1))).text.split('\n').filter(line=>line.startsWith('{')).map(line=>JSON.parse(line));assert.notEqual(duplicates[0].path,duplicates[1].path);assert.equal(await readFile(join(project,duplicates[0].path),'utf8'),'one');assert.equal(await readFile(join(project,duplicates[1].path),'utf8'),'two');
 assert.deepEqual(errors,[]);await writeFile(join(output,'report.json'),JSON.stringify({passed:true,uploadRequests,references,checks:['native file chooser','multi-file previews/removal','send-time native upload with byte comparison','PNG/JPEG clipboard files','plain text paste unchanged','running queue and steering','duplicate filenames isolated','attachment-only message','failure retains draft','retry reuses paths and request ID','new draft preservation','scope change cancels send','desktop/mobile layout'],errors},null,2));
 console.log('PASS: composer attachment picker/paste, native upload byte equality, retry, queue draft isolation and desktop/mobile layout.');
}finally{await browser.close();await new Promise(done=>server.close(done));}
