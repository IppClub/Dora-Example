import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {build} from 'esbuild';
import {resolve} from 'node:path';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const bundle=await build({stdin:{contents:"export {mountAgentHostFrame} from './agent-host-frame'; export {requestAgentFramePort} from './agent-frame-port'; export {connectAgentFrameSession} from './agent-frame-session'; export {installAgentFrameHost} from './agent-frame-host';",loader:'ts',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser'});
let studioOrigin;
const host=createServer((req,res)=>{
  if(req.url==='/host.js'){res.setHeader('Content-Type','text/javascript');res.end(bundle.outputFiles[0].text);return;}
  if(req.url==='/integrated'){
    res.setHeader('Content-Type','text/html');
    res.end(`<script type="module">
import {installAgentFrameHost} from '/host.js';
const detail={success:true,session:{id:1,projectRoot:'/game',title:'Integrated host source',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false};
let attempts=0;
for(const wrong of [{sessionId:0},{sessionId:1.5},{sessionId:99,projectId:'foreign'},{sessionId:99,generation:'old'}])parent.postMessage({type:'studio-agent-ready',version:1,projectId:'p',generation:'integrated',sessionId:1,...wrong},${JSON.stringify(studioOrigin)});
installAgentFrameHost(parent,${JSON.stringify(studioOrigin)},{projectId:'p',generation:'integrated',sessionId:1},{capture:()=>({payload:JSON.stringify(detail),sequence:0}),subscribe:listener=>{const timer=setTimeout(()=>listener(JSON.stringify({name:'AgentSessionPatch',sessionId:1,hasActivePlan:true}),1),10);return ()=>clearTimeout(timer);}},{persist:async()=>{await new Promise(resolve=>setTimeout(resolve,50));if(++attempts===1)throw Error('Injected storage failure');}});
</script>`);return;
  }
  res.setHeader('Content-Type','text/html');
  res.end(`<script>
const trustedParent=${JSON.stringify(studioOrigin)};
addEventListener('message',event=>{
  if(event.source!==parent||event.origin!==trustedParent)return;
  const data=event.data;
  if(data.type==='attack'){
    const channel=new MessageChannel();channel.port1.onmessage=()=>channel.port1.postMessage('attacker');
    parent.postMessage({type:'studio-agent-port',version:1,requestId:data.requestId},trustedParent,[channel.port2]);return;
  }
  if(data.type!=='studio-agent-connect')return;
  parent.postMessage({type:'test-spoof',requestId:data.requestId},trustedParent);
  const stale=new MessageChannel();
  parent.postMessage({type:'studio-agent-port',version:1,requestId:'old'},trustedParent,[stale.port2]);stale.port1.close();
  setTimeout(()=>{const channel=new MessageChannel();channel.port1.onmessage=message=>{
    if(message.data==='identify'){channel.port1.postMessage('trusted');return;}
    const request=message.data;
    if(request.type!=='subscribe')return;
    const binding={projectId:request.projectId,generation:request.generation,sessionId:request.sessionId};
    const detail={success:true,session:{id:request.sessionId,projectRoot:'/game',title:'Trusted host session',kind:'main',rootSessionId:request.sessionId,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false};
    channel.port1.postMessage({type:'snapshot',version:1,...binding,sequence:0,payload:JSON.stringify(detail)});
    channel.port1.postMessage({type:'patch',version:1,...binding,sequence:1,payload:JSON.stringify({name:'AgentSessionPatch',sessionId:request.sessionId,hasActivePlan:true})});
  };parent.postMessage({type:'studio-agent-port',version:1,requestId:data.requestId},trustedParent,[channel.port2]);},50);
});
</script>`);
});
await new Promise(done=>host.listen(0,'127.0.0.1',done));
const hostOrigin=`http://127.0.0.1:${host.address().port}`;
const studio=createServer((req,res)=>{
  if(req.url==='/client.js'){res.setHeader('Content-Type','text/javascript');res.end(bundle.outputFiles[0].text);return;}
  res.setHeader('Content-Type','text/html');res.end(`<iframe id="trusted" src="${hostOrigin}/trusted"></iframe><iframe id="attacker" src="${hostOrigin}/attacker"></iframe>`);
});
await new Promise(done=>studio.listen(0,'127.0.0.1',done));
studioOrigin=`http://127.0.0.1:${studio.address().port}`;
let browser;
try {
  browser=await chromium.launch({headless:true,executablePath:process.env.STUDIO_CHROME_PATH});
  const page=await browser.newPage();
  await page.goto(studioOrigin);
  const result=await page.evaluate(async hostOrigin=>{
    const {requestAgentFramePort,connectAgentFrameSession,mountAgentHostFrame}=await import('/client.js');
    const trusted=document.getElementById('trusted').contentWindow;
    const attacker=document.getElementById('attacker').contentWindow;
    let spoofReplies=0;
    const relay=event=>{
      if(event.data?.type==='test-spoof')attacker.postMessage({type:'attack',requestId:event.data.requestId},hostOrigin);
      if(event.source===attacker && event.data?.type==='studio-agent-port')spoofReplies++;
    };
    addEventListener('message',relay);
    try {
      const port=await requestAgentFramePort(trusted,hostOrigin,new AbortController().signal,2000);
      const identity=await new Promise(resolve=>{port.onmessage=event=>resolve(event.data);port.postMessage('identify');});
      port.close();
      const abort=new AbortController();abort.abort();
      let cancelled=false;try{await requestAgentFramePort(trusted,hostOrigin,abort.signal);}catch{cancelled=true;}
      const frame=document.getElementById('trusted');
      const connection=await connectAgentFrameSession(frame,hostOrigin,{projectId:'p',generation:'g',sessionId:1},new AbortController().signal);
      if(!connection.controller.state.hasActivePlan)await new Promise(resolve=>{const stop=connection.controller.subscribe(()=>{if(connection.controller.state.hasActivePlan){stop();resolve();}});});
      const sessionTitle=connection.controller.state.session.title;
      const closed=new Promise(resolve=>{const stop=connection.controller.subscribe(()=>{if(connection.controller.closed){stop();resolve();}});});
      frame.src=hostOrigin+'/navigated';
      await closed;
      const navigationClosed=connection.controller.closed;
      connection.close();
      await new Promise(resolve=>{frame.onload=()=>resolve();frame.src=hostOrigin+'/integrated';});
      const integrated=await connectAgentFrameSession(frame,hostOrigin,{projectId:'p',generation:'integrated',sessionId:1},new AbortController().signal);
      if(!integrated.controller.state.hasActivePlan)await new Promise(resolve=>{const stop=integrated.controller.subscribe(()=>{if(integrated.controller.state.hasActivePlan){stop();resolve();}});});
      const integratedTitle=integrated.controller.state.session.title;
      integrated.close();
      const count=document.querySelectorAll('iframe').length;
      const owned=mountAgentHostFrame(document.body,{url:hostOrigin+'/integrated',projectId:'p',generation:'integrated'});
      const ownedConnection=await owned.ready;
      const ownedTitle=ownedConnection.controller.state.session.title;
      const retirement=owned.persistAndClose();
      if(retirement!==owned.persistAndClose())throw Error('Concurrent retirement was not coalesced');
      let saveFailed=false;try{await retirement;}catch{saveFailed=true;}
      if(!saveFailed || document.querySelectorAll('iframe').length!==count+1 || ownedConnection.controller.closed)throw Error('Failed save destroyed host');
      await owned.persistAndClose();
      if(document.querySelectorAll('iframe').length!==count || !ownedConnection.controller.closed)throw Error('Owned host cleanup failed');
      const neverReady=mountAgentHostFrame(document.body,{url:hostOrigin+'/silent',projectId:'p',generation:'missing',sessionId:1},50);
      let timedOut=false;try{await neverReady.ready;}catch{timedOut=true;}
      if(document.querySelectorAll('iframe').length!==count)throw Error('Timed-out frame leaked');
      return {identity,spoofReplies,cancelled,sessionTitle,navigationClosed,integratedTitle,ownedTitle,timedOut,saveFailureRetry:true};
    }finally{removeEventListener('message',relay);}
  },hostOrigin);
  assert.equal(result.identity,'trusted');
  assert.ok(result.spoofReplies>0);
  assert.equal(result.cancelled,true);
  assert.equal(result.sessionTitle,'Trusted host session');
  assert.equal(result.navigationClosed,true);
  assert.equal(result.integratedTitle,'Integrated host source');
  assert.equal(result.ownedTitle,'Integrated host source');assert.equal(result.timedOut,true);
  console.log(JSON.stringify({passed:true,...result}));
}finally{
  await browser?.close();
  await Promise.all([new Promise(done=>studio.close(done)),new Promise(done=>host.close(done))]);
}
