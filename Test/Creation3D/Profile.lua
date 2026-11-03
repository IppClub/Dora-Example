-- Cold sync/async A/B, including every loading frame (no warm-up exclusion).
local D=require('Dora'); local json=require('json')
local root=D.Content:getFullPath('Test/Creation3D/Profile.lua'):match('^(.*)/Test/Creation3D/Profile.lua$')
D.Content:insertSearchPath(1,root..'/Example/Creation3D')
local Game=require('Game'); local Adapter=require('Kit.Adapter')
return function(name,asset,mode)
  for _,path in ipairs({'assets/cube.glb','assets/sphere.glb','assets/cylinder.glb','assets/Fox.glb'}) do
    D.Cache:unload(D.Content:getFullPath(path))
  end
  local trace={name=name,asset=asset,mode=mode,cold=true,spans={},frames={}}
  local function wrap(object,key)
    local original=object[key]; local bucket={calls=0,ms=0,maxMs=0}; trace.spans[key]=bucket
    object[key]=function(...)
      local start=D.App.runningTime; local result=table.pack(original(...)); local ms=(D.App.runningTime-start)*1000
      bucket.calls=bucket.calls+1; bucket.ms=bucket.ms+ms; bucket.maxMs=math.max(bucket.maxMs,ms)
      return table.unpack(result,1,result.n)
    end
  end
  for _,key in ipairs({'preflight','load','play'}) do wrap(Adapter,key) end
  local started=D.App.runningTime
  local original=Game.create
  Game.create=function(cfg)
    local start=D.App.runningTime; local g=original(cfg); trace.createMs=(D.App.runningTime-start)*1000
    trace.readyMs=(D.App.runningTime-started)*1000
    wrap(g,'move'); return g
  end
  local g
  if mode=='regression' then g=require('Test.Creation3D.Verify')(name,{asset=asset})
  elseif mode=='async' then g=Game.launch({asset=asset})
  else g=Game.create({asset=asset}) end
  trace.entryMs=(D.App.runningTime-started)*1000
  D.threadLoop(function()
    local s=D.Director.entry.stats
    trace.frames[#trace.frames+1]={dtMs=D.App.deltaTime*1000,collectUs=s.collectMicros,submitUs=s.submitMicros,uploadUs=s.uploadMicros,uploadMaxUs=s.uploadMaxCommandMicros,triangles=s.triangles,phase=g.phase or 'ready'}
    if #trace.frames==150 then
      trace.status=(mode~='sync' and not g.ready and mode~='regression') and 'failed' or 'passed'
      assert(trace.readyMs,'scene never became ready')
      D.Content:save(root..'/Test/Creation3D/evidence/'..name..'-trace.json',assert(json.encode(trace)))
      return true
    end
    return false
  end)
  return g
end
