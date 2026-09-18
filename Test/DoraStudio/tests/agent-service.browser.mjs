import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {openLoginStore} from '../apps/server/login-store.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_AGENT_TEST_URL,dbPath=process.env.STUDIO_AGENT_TEST_DB,hostOrigin=process.env.STUDIO_AGENT_TEST_HOST_URL;
if(!origin||!dbPath||!hostOrigin)throw new Error('Launch frontend, API and dedicated HTTPS Agent host; set STUDIO_AGENT_TEST_URL/DB/HOST_URL');
const existingName=process.env.STUDIO_AGENT_TEST_ACCOUNT_NAME;
const name=existingName||`studio-agent-${Date.now().toString(36)}`;
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const context=await browser.newContext({ignoreHTTPSErrors:true}),page=await context.newPage(),errors=[],hostResponses=[],hostConsole=[],hostMessages=[],hostRequests=[],frameEvents=[];
page.on('pageerror',error=>errors.push(error.message));
page.on('response',response=>{if(response.url().startsWith(hostOrigin))hostResponses.push({status:response.status(),path:new URL(response.url()).pathname.split('/').at(-1)});});
page.on('console',message=>{if(message.type()==='error')hostConsole.push(message.text().slice(0,300));if(message.location().url.startsWith(hostOrigin))hostMessages.push({type:message.type(),text:message.text().slice(0,400)});});
page.on('requestfailed',request=>{if(request.url().startsWith(hostOrigin))hostRequests.push({path:new URL(request.url()).pathname.split('/').at(-1),failure:String(request.failure()?.errorText??'unknown').slice(0,200)});});
for(const event of ['frameattached','framenavigated','framedetached'])page.on(event,frame=>{if(frame.url().startsWith(hostOrigin)||event==='frameattached')frameEvents.push({event,url:frame.url().startsWith(hostOrigin)?new URL(frame.url()).pathname:frame.url()});});
try{
  if(process.env.STUDIO_AGENT_DIAGNOSE==='1')await page.addInitScript(()=>{
    window.__studioAgentProbe=[];
    window.__studioPortProbe=[];
    const send=MessagePort.prototype.postMessage;
    MessagePort.prototype.postMessage=function(value,...rest){
      if(value?.type)window.__studioPortProbe.push({type:value.type,sessionId:value.sessionId,requestId:value.requestId});
      return send.call(this,value,...rest);
    };
    const start=MessagePort.prototype.start;
    MessagePort.prototype.start=function(){
      this.addEventListener('message',event=>{if(event.data?.type)window.__studioPortProbe.push({received:event.data.type,sessionId:event.data.sessionId});});
      return start.call(this);
    };
    window.addEventListener('message',event=>{
      if(event.data?.type?.startsWith?.('studio-agent-'))window.__studioAgentProbe.push({type:event.data.type,origin:event.origin,sessionId:event.data.sessionId,requestId:event.data.requestId});
    });
  });
  await page.goto(origin);await page.getByText('尚未登录，可继续本地编辑').waitFor({timeout:8000});
  await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  if(existingName){
    await page.getByLabel('账号名').fill(name);await page.getByLabel('密码').fill('studio-agent-acceptance-password-123');
    await page.getByRole('button',{name:'登录账号'}).click();
  }else{
    const login=openLoginStore(dbPath),invite=login.issueInvite({administrator:true});login.close();
    await page.getByRole('button',{name:'邀请码注册',exact:true}).click();
    await page.getByLabel('邀请码').fill(invite.code);
    await page.getByLabel('账号名').fill(name);
    await page.getByLabel('密码').fill('studio-agent-acceptance-password-123');
    await page.getByRole('button',{name:'创建账号并登录'}).click();
  }
  await page.getByText('账号已连接').waitFor();
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('button',{name:/新建空白项目/}).click();
  await page.getByLabel('项目名称',{exact:true}).fill('宿主联调作品');
  await page.getByRole('button',{name:'创建并进入 Studio'}).click();
  await page.getByRole('button',{name:'上传已保存版本到云端',exact:true}).click();
  await page.getByText('已上传 · 云版本 1',{exact:false}).waitFor();
  const connect=page.getByRole('button',{name:'连接项目 Agent'});
  await connect.click();
  const iframe=page.locator(`iframe[src^="${hostOrigin}/agent-host/"]`);
  await iframe.waitFor({state:'attached',timeout:30000});
  const url=await iframe.getAttribute('src');assert.ok(url?.endsWith('/index.html'));
  const hostStatus=page.frameLocator(`iframe[src^="${hostOrigin}/agent-host/"]`).locator('#status');
  await hostStatus.waitFor({state:'attached',timeout:20000});
  let statusText='';for(let attempt=0;attempt<80;attempt++){
    statusText=await hostStatus.textContent({timeout:1000}).catch(()=>statusText);
    if(statusText.includes('Agent 已就绪'))break;
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  assert.match(statusText,/Agent 已就绪/);
  let leaseRenewed=false;for(let attempt=0;attempt<40;attempt++){
    leaseRenewed=hostResponses.some(response=>response.path==='renew'&&response.status===200);
    if(leaseRenewed)break;
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  assert.equal(leaseRenewed,true,'dedicated browser host must renew its authenticated launch lease');
  if(process.env.STUDIO_AGENT_DIAGNOSE==='1'){
    const frame=page.frames().find(candidate=>candidate.url().startsWith(hostOrigin));
    assert.ok(frame);
    await frame.evaluate(()=>{
      const module=window.Module,receive=module.doraStudioAgentEvent;
      window.__studioNativeProbe=[];
      module.doraStudioAgentEvent=payload=>{
        try{const value=JSON.parse(payload);window.__studioNativeProbe.push({kind:value.kind,requestId:value.requestId,sequence:value.sequence,length:value.payload?.length});}catch{/* Read-only diagnostic. */}
        return receive(payload);
      };
      module.ccall('dora_web_agent_request',null,['string'],[JSON.stringify({operation:'snapshot',sessionId:1,requestId:'manual-probe'})]);
    });
  }
  const sync=page.getByRole('button',{name:'同步已保存项目到 Agent'});
  await sync.waitFor({timeout:12000});await sync.click();
  await page.getByText('Agent 已确认本机项目 r0',{exact:false}).waitFor({timeout:30000});
  await page.getByRole('button',{name:'刷新账号'}).click();
  await page.getByText('账号已连接').waitFor();
  assert.equal(await iframe.getAttribute('src'),url);
  const configUrl=url.replace(/index\.html$/,'host-config.json');
  assert.equal((await page.request.get(configUrl)).status(),200);
  await page.getByRole('button',{name:'退出登录'}).click();
  await page.getByRole('button',{name:'登录 / 邀请码注册'}).waitFor();
  await iframe.waitFor({state:'detached',timeout:15000});
  let status;for(let attempt=0;attempt<20;attempt++){
    status=(await page.request.get(configUrl)).status();if(status===403)break;
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  assert.equal(status,403);
  assert.equal(errors.length,0,errors.join('\n'));
  process.stdout.write(JSON.stringify({connected:true,dedicatedHostReady:true,launchLeaseRenewed:true,authorProjectSynced:true,sessionRefreshKeepsHost:true,privateConfigBeforeLogout:200,iframeClosedOnLogout:true,privateConfigAfterLogout:403,browser:browser.version()})+'\n');
}catch(error){
  const frames=page.frames().filter(frame=>frame.url().startsWith(hostOrigin));
  const statuses=[];for(const frame of frames)try{statuses.push({url:new URL(frame.url()).pathname,status:await frame.locator('#status').textContent({timeout:1000}),runtime:await frame.evaluate(()=>({agentRequestExport:typeof window.Module?._dora_web_agent_request,agentEvent:typeof window.Module?.doraStudioAgentEvent,ccall:typeof window.Module?.ccall,nativeEvents:window.__studioNativeProbe?.slice(-8),portMessages:window.__studioPortProbe?.slice(-12)}))});}catch{/* Frame may already have closed. */}
  const alerts=await page.getByRole('alert').allTextContents().catch(()=>[]);
  const parentMessages=await page.evaluate(()=>({window:window.__studioAgentProbe,port:window.__studioPortProbe?.slice(-12)})).catch(()=>[]);
  const body=await page.locator('body').innerText({timeout:1000}).catch(()=>'<unavailable>');
  process.stderr.write(JSON.stringify({statuses,alerts,body:body.slice(0,700),parentMessages,frameEvents:frameEvents.slice(-15),responseCount:hostResponses.length,hostResponses:hostResponses.slice(-12),hostRequests:hostRequests.slice(-12),hostMessages:hostMessages.filter(item=>item.type!=='warning').slice(-20),hostConsole:hostConsole.slice(-12),pageErrors:errors.slice(-12)})+'\n');
  throw error;
}finally{await browser.close();}
