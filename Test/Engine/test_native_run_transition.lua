-- Exercise the production native-IDE transition coroutine with controlled frames.
local root = assert(os.getenv('DORA_ENGINE_ROOT') or arg[1], 'Set DORA_ENGINE_ROOT')
local function fixture(options)
	options = options or {}
	local app = {frame = 0, runningTime = 0}
	local node = {running = false, lastError = '', parent = {}, unloaded = false}
	local status = {running = true, runId = 1}
	local children = options.empty and {} or {node}
	local tree = {traverseAll = function(_, callback)
		assert(not callback({}), "must continue past the scene root")
		for _, child in ipairs(children) do if callback(child) then return true end end
		return true
	end}
	local empty = {traverseAll = function() return true end}
	local dora = {App = app, Director = {entry = tree, ui = empty, ui3D = empty, postNode = empty},
		sleep = function()
			app.frame = app.frame + 1
			app.runningTime = app.runningTime + (options.step or 0.01)
			if options.tick then options.tick(app, node, status, children) end
		end}
	dora.tolua = {cast = function(value, name) assert(name == 'GodotNode'); return value.lastError and value or nil end}
	local env = setmetatable({require = function(name) assert(name == 'Dora'); return dora end}, {__index = _G})
	local module = assert(loadfile(root .. '/Assets/Script/Dev/RunTransition.lua', 't', env))()
	local ok, err = module.waitForFrameAsync({getCurrentEntryStatus = function() return status end}, 1, options.expected)
	return ok, err, app.frame
end
local ok, err, frame = fixture({tick = function(app, node) node.running = app.frame >= 5 end})
assert(ok and not err and frame == 7, 'must wait for Godot readiness and two submitted frames')
ok, err, frame = fixture({empty = true})
assert(ok and frame == 3, 'ordinary native runs wait for fresh Dora frames')
ok, err = fixture({empty = true, expected = true})
assert(not ok and err:find('did not create', 1, true))
ok, err = fixture({tick = function(_, node, _, children)
	node.lastError = 'runtime boot failed'; node.parent = nil; children[1] = nil
end})
assert(not ok and err == 'runtime boot failed', 'retain diagnostics even if the game update removes the node')
ok, err = fixture({tick = function(_, node) node.parent = nil end})
assert(not ok and err:find('removed', 1, true))
ok, err = fixture({tick = function(_, node) node.unloaded = true end})
assert(not ok and err:find('removed', 1, true))
for _, action in ipairs({'stop', 'supersede'}) do
	ok, err = fixture({tick = function(_, _, status)
		if action == 'stop' then status.running = false else status.runId = 2 end
	end})
	assert(not ok and err:find('superseded', 1, true))
end
ok, err = fixture({step = 15})
assert(not ok and err:find('timed out', 1, true))
ok, err, frame = fixture({tick = function(app, node) node.running = app.frame ~= 2 end})
assert(ok and frame == 5, 'readiness lost during drain must restart the frame wait')
print('PASS: native run transition waits for asynchronous Godot readiness and submitted frames; failures, removal, timeout, cancellation and superseded runs never switch views')

-- Exercise the generated /run handler: only embedded callers opt into the
-- transition, errors propagate, and request identity is captured before yield.
local file = assert(io.open(root .. '/Assets/Script/Dev/WebServer.lua'))
local source = file:read('a');file:close()
local first = assert(source:find('HttpServer:postSchedule("/run",', 1, true))
local last = assert(source:find('\nend%)', first)) + 4
local handler, calls, currentId, failScript, supersede, failTransition
local entry = {
 allClear = function() end,
 getCurrentEntryStatus = function() return {running=true,runId=currentId} end,
 enterEntryAsync = function()
  currentId=currentId+1
  if supersede then currentId=currentId+1 end
  return not failScript, failScript and 'script error' or nil
 end,
}
local path = setmetatable({getPath=function(_,p) return p:match('^(.*)/') end,
 getName=function(_,p) return p:match('([^/]+)$') end,
 getExt=function() return 'lua' end,replaceExt=function(_,p) return p:gsub('%.lua$','') end},
 {__call=function(_,...)return table.concat({...},'/')end})
local env=setmetatable({HttpServer={postSchedule=function(_,route,fn)assert(route=='/run');handler=fn end},
 Content={isAbsolutePath=function()return true end,exist=function()return true end,isdir=function()return true end},
 Path=path,getProjectDirFromFile=function()return '/game' end,
 require=function(name)
  if name=='Script.Dev.Entry' then return entry end
  assert(name=='Script.Dev.RunTransition')
  return {waitForFrameAsync=function(_,id,expected)
   calls=calls+1;assert(id==1 and expected)
   return not failTransition,failTransition and 'Godot boot error' or nil
  end}
 end},{__index=_G})
assert(load(source:sub(first,last),'production /run handler','t',env))()
for _,asProj in ipairs({true,false}) do
 for _,waitForFrame in ipairs({true,false}) do
  calls,currentId=0,0
  local result=handler({body={file='/game/init.lua',asProj=asProj,waitForFrame=waitForFrame}})
  assert(result.success and calls==(waitForFrame and 1 or 0))
 end
 calls,currentId,failTransition=0,0,true
 local result=handler({body={file='/game/init.lua',asProj=asProj,waitForFrame=true}})
 assert(not result.success and result.err=='Godot boot error');failTransition=false
 calls,currentId,failScript=0,0,true
 result=handler({body={file='/game/init.lua',asProj=asProj,waitForFrame=true}})
 assert(not result.success and result.err=='script error' and calls==0);failScript=false
 calls,currentId,supersede=0,0,true
 handler({body={file='/game/init.lua',asProj=asProj,waitForFrame=true}})
 assert(calls==1);supersede=false
end
print('PASS: production /run opts in only for embedded clients, preserves startup failures and captures run identity before yielding')
