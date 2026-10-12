-- Exercise the actual stable host with a disposable module graph.
local root = assert(os.getenv("DORA_SSR_ROOT"), "Set DORA_SSR_ROOT to the Dora-SSR checkout.")
local path = root .. "/Assets/Script/Dev/AgentHost.lua"
local files = {
	["Session.lua"] = [[local T=require("Agent.Tools"); return {isRuntimeIdle=function() return not TEST_BUSY end,sendPrompt=function() return T.build() end}]],
	["Tools.lua"] = [[return {build=function() return "v1" end}]],
	["Tool/Registry.lua"] = [[return {getToolDefinition=function() return {handler=function() end} end}]],
	["Runtime/SessionEvents.lua"] = "return {}",
}
local cache, app = {}, {runningTime=0}
local oldRequire, oldLoaded = require, package.loaded
package.loaded = cache
local content = {assetPath="assets"}
function content:getAllFiles() local out={}; for k in pairs(files) do out[#out+1]=k end; return out end
function content:load(p) return files[p:match("Agent/(.*)$")] end
function content:getFullPath(p) return p end
function content:isAbsolutePath() return false end
local p = setmetatable({getExt=function(_,v) return v:match("%.([^.]*)$") end}, {__call=function(_,...) return table.concat({...},"/") end})
_G.require = function(name)
	if name=="Dora" then return {Content=content,Path=p,App=app} end
	if cache[name] then return cache[name] end
	local source=assert(files[name:gsub("^Agent%.",""):gsub("%.","/")..".lua"],name)
	local value=assert(load(source,"@"..name,"t",_G))()
	cache[name]=value
	return value
end
local H=assert(loadfile(path))()
H.setAutomatic(false)
local session=H.proxy("Agent.Session")
assert(session.sendPrompt()=="v1" and H.status().generation==1)
local previous=cache["Agent.Session"]
files["Tools.lua"]=[[return {build=function() return "v2" end}]]
assert(H.reload().success and session.sendPrompt()=="v2")
assert(cache["Agent.Session"]~=previous and H.status().generation==2)
previous=cache["Agent.Session"]
files["Tools.lua"]="this is invalid Lua!"
assert(not H.reload().success and cache["Agent.Session"]==previous)
assert(session.sendPrompt()=="v2")
files["Tools.lua"]=[[require("Agent.Runtime.NewDependency"); error("candidate initialization failed")]]
files["Runtime/NewDependency.lua"]="return {}"
assert(not H.reload().success and cache["Agent.Session"]==previous)
assert(cache["Agent.Runtime.NewDependency"]==nil and session.sendPrompt()=="v2")
files["Tools.lua"]=[[return {build=function() return "v3" end}]]
TEST_BUSY=true
assert(H.reload().code=="AGENT_BUSY" and H.status().generation==2)
TEST_BUSY=false
local release=H.acquire()
assert(H.reload().code=="AGENT_BUSY")
release(); release()
assert(H.reload().success and session.sendPrompt()=="v3")
local subscription={}
cache["Agent.Runtime.SessionEvents"]=subscription
assert(H.reload().success and cache["Agent.Runtime.SessionEvents"]==subscription)
files["Runtime/SessionEvents.lua"]="return {changed=true}"
assert(not H.reload().success and cache["Agent.Runtime.SessionEvents"]==subscription)
files["Runtime/SessionEvents.lua"]="return {}"
-- Automatic detection is enabled only after manual success/rollback checks.
H.setAutomatic(true)
TEST_BUSY=true
files["Tools.lua"]=[[return {build=function() return "v4" end}]]
app.runningTime=app.runningTime+3
assert(H.status().pending and session.sendPrompt()=="v3")
TEST_BUSY=false
app.runningTime=app.runningTime+3
assert(session.sendPrompt()=="v4" and not H.status().pending)
files["Tools.lua"]="invalid candidate"
app.runningTime=app.runningTime+3
assert(session.sendPrompt()=="v4")
local failedGeneration=H.status().generation
app.runningTime=app.runningTime+3
assert(session.sendPrompt()=="v4" and H.status().generation==failedGeneration)
files["Tools.lua"]=[[return {build=function() return "v5" end}]]
app.runningTime=app.runningTime+3
assert(session.sendPrompt()=="v5")
-- Task admission cannot be hidden by the read-only poll throttle.
files["Tools.lua"]=[[return {build=function() return "v6" end}]]
assert(session.sendPrompt()=="v6")
files["Tools.lua"]=[[return {build=function() return {addCallbacks=function(_,resolve) TEST_RESOLVE=resolve end} end}]]
assert(H.reload().success)
H.proxy("Agent.Tools").build()
assert(H.reload().code=="AGENT_BUSY")
TEST_RESOLVE(); TEST_RESOLVE=nil
assert(H.reload().success)
local finish=H.holdSourceUpdate("assets/Script/Lib/Agent")
files["Tools.lua"]=[[return {build=function() return "batch" end}]]
assert(H.reload().code=="AGENT_BUSY")
finish(false)
assert(H.reload().code=="AGENT_BUILD_FAILED")
-- Repairing a smaller target cannot commit a previously failed whole batch.
H.holdSourceUpdate("assets/Script/Lib/Agent/Tools.lua")(true)
assert(H.reload().code=="AGENT_BUILD_FAILED")
H.holdSourceUpdate("assets/Script/Lib/Agent")(true)
assert(H.reload().success and session.sendPrompt()=="batch")
package.loaded, _G.require, TEST_BUSY = oldLoaded, oldRequire, nil
print("PASS: stable host manual reload, syntax/initialization rollback, busy/lease deferral, service identity and automatic update/recovery")
