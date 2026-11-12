-- Production-compiled vision projection, evidence and shared-executor regression.

local J=require('dkjson')
local records={}
package.preload['Dora']=function()return {App={estimateTokens=function(_,s)return math.ceil(#s/4)end},json={null=J.null,encode=function(x)return J.encode(x)end,decode=function(s)local v,_,e=J.decode(s);return v,e end},Log=function()end,DB={query=function(_,sql)if sql:find('project_root',1,true)then return {{'/project'}}end;return records end},Content={},Path=function(...)return table.concat({...},'/')end}end
package.preload['Agent.Storage.Database']=function()return {TABLE_STEP='agent.AgentSessionStep'}end
package.preload['Agent.Config.LLMConfigMigration']=function()return {}end
package.preload['Agent.Tool.WebIDESync']=function()return {}end
package.preload['Agent.Tool.Registry']=function()return {}end
package.preload['Agent.Tool.Workspace']=function()return {resolveWorkspaceFilePath=function(root,path)return root..'/'..path end}end
local P=require('Agent.Runtime.HistoryProjection')
local messages={{role='assistant',content='',tool_calls={{id='vision-1',type='function', ['function']={name='analyze_image',arguments=J.encode({paths={'art/red.png','art/blue.png'},question='Compare images'})}}}},{role='tool',name='analyze_image',tool_call_id='vision-1',content=J.encode({success=true,paths={'art/red.png','art/blue.png'},images={{path='art/red.png',width=1,height=1},{path='art/blue.png',width=1,height=1}},report='Image 1: red. Image 2: blue.'})}}
local projected=J.encode(P.projectMessagesForCompression(messages))
assert(projected:find('art/red.png',1,true) and projected:find('art/blue.png',1,true),'compression lost image mapping')
print('PASS: compression preserves image-index/path mapping')
package.preload['Agent.Tool.Guards']=function()return {runAgentToolGuards=function()return nil end}end
local E=require('Agent.Tool.Executor');local L=require('lualib_bundle');local cancelled=false;local completed=false
local definition={name='analyze_image',inputSchema=function()return true end,outputSchema=true,handler=function()return L.__TS__AsyncAwaiter(function()cancelled=true;return {output={success=false,cancelled=true,requestIssued=true,usage={prompt_tokens=12,completion_tokens=8,total_tokens=20}}}end)end}
L.__TS__AsyncAwaiter(function()
 local result=L.__TS__Await(E.executeAgentToolDefinition(definition,{}, {cancellation={isCancelled=function()return cancelled end,reason=function()return 'user cancelled' end}}, {}, {}))
 assert(result.execution.status=='STOPPED' and result.output.requestIssued and result.output.usage.total_tokens==20 and not result.output.report)
 records={{'analyze_image',J.encode(result.output)}}
 local usage=require('Agent.Tool.VisionBudget').getVisionTaskUsage(1)
 assert(usage.requestCount==1 and usage.totalTokens==20,'cancelled work not counted after persistence')
 print('PASS: shared executor retains cancelled issued-request accounting through persisted budget reconstruction')
 completed=true
end)
assert(completed,'executor reproduction did not finish')


-- The same outer cancellation boundary must retain completed capture accounting.
local captureDone=false
cancelled=false
definition.name='execute_command'
definition.handler=function()return L.__TS__AsyncAwaiter(function()
 cancelled=true;return {output={success=true,output='do not publish cancelled output',visionCapture={batchCount=1,frameCount=2}}}
end)end
L.__TS__AsyncAwaiter(function()
 local result=L.__TS__Await(E.executeAgentToolDefinition(definition,{}, {cancellation={isCancelled=function()return cancelled end,reason=function()return 'user cancelled' end}}, {}, {}))
 assert(result.execution.status=='STOPPED' and not result.output.output and not result.control)
 records={{'execute_command',J.encode(result.output)}}
 local usage=require('Agent.Tool.VisionBudget').getVisionTaskUsage(1)
 assert(usage.captureBatchCount==1 and usage.captureFrameCount==2)
 captureDone=true
end)
assert(captureDone,'cancelled capture accounting failed')
print('PASS: cancelled command retains capture counts without publishing command output')
