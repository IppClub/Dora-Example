// Isolated browser event acceptance; no live engine, credentials or LLM required.
// Set DORA_TEST_CHROME when Chrome/Chromium is not installed at a standard path.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {buildSync} from 'esbuild';
const root=path.resolve(process.env.DORA_ENGINE_ROOT || process.env.DORA_SSR_ROOT || '../..');
const chrome=process.env.DORA_TEST_CHROME || [
 '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
 '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
 '/usr/bin/google-chrome','/usr/bin/chromium','/usr/bin/chromium-browser',
 process.env.PROGRAMFILES && path.join(process.env.PROGRAMFILES,'Google/Chrome/Application/chrome.exe'),
].filter(Boolean).find(candidate=>fs.existsSync(candidate));
assert.ok(chrome,'Install Chrome/Chromium or set DORA_TEST_CHROME');
const fixtures=[
(()=>{
const source=fs.readFileSync(path.join(root,'Tools/dora-dora/src/AgentPanel.tsx'),'utf8');
const handler=source.slice(source.indexOf('\tconst onSend = async'),source.indexOf('\n\tuseEffect(() => {',source.indexOf('\tconst onSend = async')));
const entry=`import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {flushSync} from 'react-dom';
import {SharedAgentComposer} from '../../Studio/packages/agent-ui/src/AgentComposer';
let api:any,resolveSend:any,rejectSend:any,calls:any[]=[],uploadFail=false;
function Harness(){
 const [prompt,setPrompt]=useState('原始 prompt'),[selectedSessionId,setSession]=useState(1),[running,setRunning]=useState(false);
 const workMode='code';
 const sendPromptText=(text:any,...args:any[])=>{calls.push({text,args});setRunning(true);return new Promise<boolean>((resolve,reject)=>{resolveSend=resolve;rejectSend=reject;});};
 ${handler}
 api={setPrompt,setSession,setRunning};
 return <><div id="messages">{running?'用户消息已发送 · 正在思考':''}</div><SharedAgentComposer prompt={prompt} onPromptChange={setPrompt} onSend={onSend} loading={false} running={running} attachmentScopeKey={String(selectedSessionId)} onUploadAttachment={async()=>{if(uploadFail)throw new Error('upload failed');return '.agent/tmp/test.png';}}/></>;
}
createRoot(document.getElementById('root')!).render(<Harness/>);
const tick=()=>new Promise(r=>setTimeout(r,30));
const check=(value:any,label:string)=>{if(!value)throw new Error(label);results.push(label);};
let results:string[]=[];
const input=()=>document.querySelector('textarea')!;
const type=(text:string)=>{const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value')!.set!;setter.call(input(),text);input().dispatchEvent(new Event('input',{bubbles:true}));};
const send=()=>input().dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));
const reset=async()=>{flushSync(()=>{api.setSession(Math.random());api.setRunning(false);api.setPrompt('原始 prompt');});await tick();};
const attach=async()=>{const el=document.querySelector('input[type=file]')!;const transfer=new DataTransfer();transfer.items.add(new File(['test'],'test.txt',{type:'text/plain'}));Object.defineProperty(el,'files',{configurable:true,value:transfer.files});el.dispatchEvent(new Event('change',{bubbles:true}));await tick();};
(async()=>{await tick();
 const startCount=calls.length;
 const key=(options:any)=>{const event=new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true,...options});input().dispatchEvent(event);return event;};
 let confirm=key({isComposing:true,keyCode:13});await tick();check(calls.length===startCount&&!confirm.defaultPrevented,'native composing Enter does not send or cancel IME');
 input().dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true,data:'原始'}));
 confirm=key({isComposing:false,keyCode:13});await tick();check(calls.length===startCount&&!confirm.defaultPrevented,'composition ref protects Enter');
 input().dispatchEvent(new CompositionEvent('compositionend',{bubbles:true,data:'原始 prompt'}));
 confirm=key({isComposing:false,keyCode:229});await tick();check(calls.length===startCount&&!confirm.defaultPrevented,'compositionend before confirming Enter does not send');
 check(input().value==='原始 prompt','IME confirmation preserves prompt');
 key({shiftKey:true,keyCode:13});await tick();check(calls.length===startCount,'Shift Enter does not send');
 send();await tick();check(input().value==='','plain cleared while request pending');check(calls.at(-1).text==='原始 prompt','plain payload preserved');
 type('新的草稿');await tick();resolveSend(true);await tick();check(input().value==='新的草稿','new draft preserved after success');
 await reset();send();await tick();resolveSend(false);await tick();check(input().value==='','rejected send stays clear');
 await reset();send();await tick();type('新的草稿');await tick();resolveSend(false);await tick();check(input().value==='新的草稿','failure preserves new draft');
 await reset();send();await tick();flushSync(()=>{api.setSession(Math.random());api.setPrompt('');});await tick();resolveSend(false);await tick();check(input().value==='','failure does not restore into another session');
 await reset();await attach();send();await tick();check(input().value==='','attachment prompt cleared while pending');check(calls.at(-1).text.includes('.agent/tmp/test.png'),'attachment payload preserved');resolveSend(false);await tick();check(input().value==='','attachment rejection stays clear');check(document.querySelectorAll('[role=listitem]').length===1,'attachment retained for retry');
 send();await tick();type('附件后的新草稿');await tick();resolveSend(true);await tick();check(input().value==='附件后的新草稿','attachment success preserves new draft');check(document.querySelectorAll('[role=listitem]').length===0,'accepted attachment removed');
 await reset();await attach();uploadFail=true;const count=calls.length;send();await tick();check(input().value==='原始 prompt'&&calls.length===count,'upload failure keeps draft without dispatch');uploadFail=false;
 await reset();send();await tick();resolveSend(true);await tick();check(input().value==='','waiting UI remains clear');
 document.getElementById('results')!.textContent=JSON.stringify({passed:results.length,results});document.body.dataset.done='true';
})().catch(error=>{document.getElementById('results')!.textContent=String(error.stack);document.body.dataset.done='failed';});`;
return entry;
})(),
(()=>{
const source=fs.readFileSync(path.join(root,'Tools/dora-dora/src/AgentMessageList.tsx'),'utf8');
const component=source.slice(source.indexOf('function AgentMessageList('),source.indexOf('\nconst sameMessages'));
const entry=`import React from 'react';import {createRoot} from 'react-dom/client';
import {Box,Button,IconButton,Stack,Tooltip,Typography} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';import EditIcon from '@mui/icons-material/Edit';import SendIcon from '@mui/icons-material/Send';
import {isImeKeyEvent,parseAgentMessageAttachments,replaceAgentMessageText} from '../../Studio/packages/agent-ui/src/index';
const Color={TextPrimary:'#eee'};const useTranslation=()=>({t:(key:string)=>key});
const MacScrollbar=({children}:any)=><div>{children}</div>,AgentMessageAttachments=()=>null,AgentAssistantMessageRow=()=>null;
${component}
let calls:any[]=[],resolveSend:any;
createRoot(document.getElementById('root')!).render(<AgentMessageList messages={[{id:1,role:'user',content:'原始消息'}]} editableMessageId={1} onResendPrompt={async(message,prompt)=>{calls.push(prompt);return new Promise<boolean>(resolve=>{resolveSend=resolve;});}}/>);
const tick=()=>new Promise(r=>setTimeout(r,30)),results:string[]=[];
const check=(value:any,label:string)=>{if(!value)throw new Error(label);results.push(label);};
const edit=async()=>{(document.querySelector('.agent-message-edit-button') as HTMLElement).click();await tick();};
const input=()=>document.querySelector('textarea');
const type=(text:string)=>{Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value')!.set!.call(input(),text);input()!.dispatchEvent(new Event('input',{bubbles:true}));};
const enter=(keyCode=13,isComposing=false)=>{const event=new KeyboardEvent('keydown',{key:'Enter',keyCode,isComposing,bubbles:true,cancelable:true});input()!.dispatchEvent(event);return event;};
(async()=>{await tick();await edit();type('修改后的消息');await tick();
 let event=enter(229);await tick();check(!!input()&&calls.length===0&&!event.defaultPrevented,'IME Enter keeps message editor open');
 event=enter(13,true);await tick();check(!!input()&&calls.length===0&&!event.defaultPrevented,'composing Enter does not resend');
 enter();await tick();check(!input()&&calls.length===1,'resend closes editor before response');check(calls[0]==='修改后的消息','resend payload preserved');
 await edit();type('下一次编辑');await tick();resolveSend(false);await tick();check(input()?.value==='下一次编辑','failed response preserves newer edit');
 enter();await tick();check(!input()&&calls.length===2,'next resend closes editor immediately');resolveSend(true);await tick();check(!input(),'successful resend leaves editor closed');
 document.getElementById('results')!.textContent=JSON.stringify({passed:results.length,results});document.body.dataset.done='true';
})().catch(error=>{document.getElementById('results')!.textContent=String(error.stack);document.body.dataset.done='failed';});`;
return entry;
})()
];
const temporary=fs.mkdtempSync(path.join(tmpdir(),'dora-agent-input-'));
const output=path.join(root,'build/agent-input-qa');fs.mkdirSync(output,{recursive:true});
const reports=[];
try{
 for(const [index,entry] of fixtures.entries()){
  const directory=path.join(temporary,String(index));fs.mkdirSync(directory);
  buildSync({stdin:{contents:entry.replaceAll('../../Studio/','./Studio/'),resolveDir:root,loader:'tsx'},bundle:true,platform:'browser',outfile:path.join(directory,'app.js'),nodePaths:[path.join(root,'Tools/dora-dora/node_modules')],loader:{'.css':'empty'},define:{'process.env.NODE_ENV':'"production"'}});
  const html=path.join(directory,'index.html');
  fs.writeFileSync(html,'<!doctype html><meta charset="utf-8"><style>body{background:#1e1e1e;color:#aaa;font-family:sans-serif;padding:40px}#results{white-space:pre-wrap}</style><div id="root"></div><pre id="results">running</pre><script src="app.js"></script>');
  const {stdout}=await promisify(execFile)(chrome,['--headless','--no-sandbox','--disable-gpu','--allow-file-access-from-files',`--user-data-dir=${path.join(temporary,'profile')}`,'--virtual-time-budget=5000',`--screenshot=${path.join(output,`fixture-${index}.png`)}`,'--window-size=1200,760','--dump-dom',pathToFileURL(html).href],{timeout:30000,maxBuffer:4*1024*1024});
  const text=stdout.match(/<pre id="results">([\s\S]*?)<\/pre>/)?.[1];
  assert.match(stdout,/data-done="true"/,text || 'browser fixture did not complete');
  reports.push(JSON.parse(text));
 }
 assert.equal(reports.reduce((sum,report)=>sum+report.passed,0),26);
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(reports,null,2));
 console.log('Passed 26 browser checks for IME, draft clearing and message resends.');
}finally{fs.rmSync(temporary,{recursive:true,force:true});}
