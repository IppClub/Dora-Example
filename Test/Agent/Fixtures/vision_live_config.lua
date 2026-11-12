local D=require('Dora');local U=require('Agent.Utils');local B=require('Agent.Tool.VisionBinding');local E=require('Agent.Tool.Executor');local T=require('Agent.Tools');local L=require('lualib_bundle')
local loaded=U.getLLMConfig(@CONFIG_ID@);assert(loaded.success,loaded.message);local cfg=loaded.config;local originalModel=cfg.model
local custom={};for k,v in pairs(cfg.customOptions or {}) do custom[k]=v end;custom.visionModel=@VISION_MODEL@;cfg.customOptions=custom
assert(U.validateAgentLLMConfig(cfg).success);local binding=assert(B.resolveVisionBinding(cfg));assert(binding.model==@VISION_MODEL@ and binding.url==cfg.url)
local opts=U.applyCustomLLMOptions({model=originalModel},custom);assert(opts.visionModel==nil and opts.model==originalModel)
local task=T.createTask('Real GLM 4.6V configured vision acceptance');assert(task.success)
local pending=L.__TS__AsyncAwaiter(function()
 local result=L.__TS__Await(E.executeRegisteredAgentTool({tool='analyze_image',input={paths={'art/config.png'},question='请根据图片简短回答：这是什么界面？视觉模型输入框是否为空？自定义参数里有哪些字段？右下角有什么按钮？只描述图中可见内容。'},schemaContext={searchDoraDocLimitMax=20},context={role='main',workMode='code',workingDir='@WORK_DIR@',taskId=task.taskId,step=1,disabledAgentTools={},workflow={},services={},visionBinding=binding,cancellation={isCancelled=function()return false end,reason=function()return nil end}}}))
 T.setTaskStatus(task.taskId,result.output.success and 'DONE' or 'FAILED');D.Content:save('@WORK_DIR@/result.json',assert(U.safeJsonEncode({sameEndpoint=true,requestedModel=binding.model,mainModel=originalModel,textOptionsIsolated=true,result=result})))
end)
pending['catch'](pending,function(_,err)T.setTaskStatus(task.taskId,'FAILED');D.Content:save('@WORK_DIR@/result.json',assert(U.safeJsonEncode({error=tostring(err)})))end)
print('GLM 4.6V real vision test started; saved configurations unchanged')