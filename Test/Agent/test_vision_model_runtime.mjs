// Opt-in integration against an explicitly supplied running native engine.
// Creates and deletes one fixture config; never changes the selected user config.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const root=process.env.DORA_SSR_ROOT,cli=process.env.DORA_CLI;
if(!root||!cli)throw new Error('Set DORA_SSR_ROOT and DORA_CLI for the running native engine.');
const output=resolve(root,'build/agent-vision-model-config-20261112/native-custom'),requests=[];
await mkdir(join(output,'art'),{recursive:true});
await writeFile(join(output,'art/sample.png'),Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC','base64'));
const server=createServer(async(req,res)=>{
 let raw='';for await(const chunk of req)raw+=chunk;
 requests.push({path:req.url,body:JSON.parse(raw),authorization:req.headers.authorization});
 res.setHeader('Content-Type','application/json');res.end(JSON.stringify({model:'fixture-vision-version',choices:[{finish_reason:'stop',message:{content:'Image 1: red.'}}],usage:{prompt_tokens:12,completion_tokens:8,total_tokens:20}}));
});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const endpoint=`http://127.0.0.1:${server.address().port}/CaseSensitive/chat/completions?route=Vision`;
const literal=x=>JSON.stringify(x.replaceAll('\\','/'));
const resultPath=join(output,'result.json');await rm(resultPath,{force:true});
const code=`local D=require('Dora');local U=require('Agent.Utils');local B=require('Agent.Tool.VisionBinding');local E=require('Agent.Tool.Executor');local T=require('Agent.Tools');local L=require('lualib_bundle')
local opts=assert(U.safeJsonEncode({visionModel='fixture-vision',auxiliaryOptions={}},false,false))
assert(D.DB:exec('INSERT INTO LLMConfig(name,url,model,api_key,context_window,temperature,max_tokens,reasoning_effort,custom_options,active) VALUES(?,?,?,?,?,?,?,?,?,0)',{'__vision_fixture',${literal(endpoint)},'fixture-text','fixture-only',64000,0.1,2048,'',opts})>0)
local id=D.DB:query('SELECT last_insert_rowid()')[1][1];local loaded=U.getLLMConfig(id);D.DB:exec('DELETE FROM LLMConfig WHERE id=?',{id});assert(loaded.success,loaded.message)
assert(U.validateAgentLLMConfig(loaded.config).success,'persisted empty auxiliary object rejected')
local binding=assert(B.resolveVisionBinding(loaded.config));assert(binding.provider=='custom' and binding.model=='fixture-vision' and binding.url==${literal(endpoint)})
local text=U.applyCustomLLMOptions({model='fixture-text'},loaded.config.customOptions);assert(text.visionModel==nil and text.model=='fixture-text')
local task=T.createTask('Explicit custom vision configuration integration fixture');assert(task.success)
local pending=L.__TS__AsyncAwaiter(function()
 local result=L.__TS__Await(E.executeRegisteredAgentTool({tool='analyze_image',input={paths={'art/sample.png'},question='Describe the image.'},schemaContext={searchDoraDocLimitMax=20},context={role='main',workMode='code',workingDir=${literal(output)},taskId=task.taskId,step=1,disabledAgentTools={},workflow={},services={},visionBinding=binding,cancellation={isCancelled=function()return false end,reason=function()return nil end}}}))
 T.setTaskStatus(task.taskId,result.output.success and 'DONE' or 'FAILED');D.Content:save(${literal(resultPath)},assert(U.safeJsonEncode({configRemoved=true,emptyAuxiliaryAccepted=true,textOptionsIsolated=true,result=result})))
end)
pending['catch'](pending,function(_,err)T.setTaskStatus(task.taskId,'FAILED');D.Content:save(${literal(resultPath)},assert(U.safeJsonEncode({error=tostring(err)})))end)
print('Custom vision fixture started')`;
const command=join(output,'command.json');await writeFile(command,JSON.stringify({mode:'lua',code,timeoutSeconds:30}));
try{
 const {stdout}=await promisify(execFile)(cli,['--asset',join(root,'Assets'),'cli','agent','command','-p',output,'--input',command]);assert.equal(JSON.parse(stdout).success,true,stdout);
 let result;
 for(let i=0;i<200;i++){try{result=JSON.parse(await readFile(resultPath,'utf8'));break;}catch{}await new Promise(done=>setTimeout(done,100));}
 assert.ok(result,'native vision request timed out');assert.equal(result.error,undefined);assert.equal(result.result.execution.status,'DONE');assert.equal(result.result.output.success,true);
 assert.equal(result.result.output.model,'fixture-vision');assert.equal(result.result.output.responseModel,'fixture-vision-version');assert.equal(result.result.output.images[0].path,'art/sample.png');
 assert.equal(requests.length,1);assert.equal(requests[0].path,'/CaseSensitive/chat/completions?route=Vision');assert.equal(requests[0].authorization,'Bearer fixture-only');
 const body=requests[0].body;assert.equal(body.model,'fixture-vision');assert.equal(body.thinking,undefined);assert.equal(body.visionModel,undefined);assert.equal(body.auxiliaryOptions,undefined);assert.match(body.messages[1].content[2].image_url.url,/^data:image\/png;base64,/);
 console.log('PASS: persisted config -> explicit custom binding -> registered analyze_image -> PNG request -> reported alias; fixture config removed, text model unchanged.');
}finally{await new Promise(done=>server.close(done));}
