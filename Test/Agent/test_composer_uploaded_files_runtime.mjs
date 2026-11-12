// Opt-in real tool acceptance for the files uploaded by agent-attachments.browser.
// DORA_VISION_CONFIG_ID enables one real provider request (may incur usage).
import assert from 'node:assert/strict';
import {readFile,writeFile,rm} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {join} from 'node:path';
const root=process.env.DORA_SSR_ROOT,cli=process.env.DORA_CLI;assert.ok(root&&cli,'Set DORA_SSR_ROOT and DORA_CLI');
const output=join(root,'build/agent-attachments-qa'),project=join(output,'project'),report=JSON.parse(await readFile(join(output,'report.json'),'utf8'));
const configId=Number(process.env.DORA_VISION_CONFIG_ID||0);assert.ok(Number.isInteger(configId)&&configId>=0);
const literal=x=>JSON.stringify(x);
const code=`local D=require('Dora');local U=require('Agent.Utils');local B=require('Agent.Tool.VisionBinding');local E=require('Agent.Tool.Executor');local T=require('Agent.Tools');local L=require('lualib_bundle')
local task=T.createTask('Uploaded composer files tool acceptance');assert(task.success)
local binding=nil;if ${configId}>0 then local c=U.getLLMConfig(${configId});assert(c.success);binding=assert(B.resolveVisionBinding(c.config)) end
local context={role='main',workMode='code',workingDir=${literal(project)},taskId=task.taskId,step=1,disabledAgentTools={},workflow={},services={},visionBinding=binding,cancellation={isCancelled=function()return false end,reason=function()return nil end}}
local pending=L.__TS__AsyncAwaiter(function()
 local read=L.__TS__Await(E.executeRegisteredAgentTool({tool='read_file',input={path=${literal(report.references[1].path)}},schemaContext={searchDoraDocLimitMax=20},context=context}))
 local vision=nil;if binding then vision=L.__TS__Await(E.executeRegisteredAgentTool({tool='analyze_image',input={paths={${literal(report.references[0].path)}},question='请简短描述图片的主要颜色。'},schemaContext={searchDoraDocLimitMax=20},context=context})) end
 T.setTaskStatus(task.taskId,'DONE');D.Content:save(${literal(join(output,'tool-result.json'))},assert(U.safeJsonEncode({read=read,vision=vision})))
end)
pending['catch'](pending,function(_,err)T.setTaskStatus(task.taskId,'FAILED');D.Content:save(${literal(join(output,'tool-result.json'))},assert(U.safeJsonEncode({error=tostring(err)})))end)
print('Uploaded file tool acceptance started')`;
const resultPath=join(output,'tool-result.json');await rm(resultPath,{force:true});const command=join(output,'tool-command.json');await writeFile(command,JSON.stringify({mode:'lua',code,timeoutSeconds:30}));
const {stdout}=await promisify(execFile)(cli,['--asset',join(root,'Assets'),'cli','agent','command','-p',project,'--input',command]);assert.equal(JSON.parse(stdout).success,true);
let result;for(let i=0;i<180;i++){try{result=JSON.parse(await readFile(resultPath,'utf8'));break;}catch{}await new Promise(done=>setTimeout(done,1000));}
assert.ok(result,'No tool result');assert.equal(result.error,undefined);assert.equal(result.read.output.success,true,JSON.stringify(result.read));assert.match(JSON.stringify(result.read.output),/Attachment fixture UTF-8 中文/);
if(configId){assert.equal(result.vision.output.success,true,JSON.stringify(result.vision));assert.equal(result.vision.output.images[0].path,report.references[0].path);}
console.log(JSON.stringify({passed:true,textRead:true,visionModel:result.vision?.output.model,visionUsage:result.vision?.output.usage,visionReport:result.vision?.output.report},null,2));
