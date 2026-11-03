-- Real-input observer only. Never calls move/restart/start or injects engine input.
local D=require('Dora'); local json=require('json')
return function(config)
  local source=D.Content:getFullPath('Example/Creation3D/Game.lua'):match('^(.*)/Game.lua$'); D.Content:insertSearchPath(1,source)
  local output=D.Content:getFullPath('Test/Creation3D/Input.lua'):match('^(.*)/Input.lua$')..'/evidence/'
  local Game=require('Game'); local last=''; local elapsed=0; local saved=0
  local log={asset=config.asset,keyboardFrames={},status='observing',inputMethod='native window keys/mouse, observer only',events={},completedRounds={}}
  Game.observe=function(g,dt)
    elapsed=elapsed+dt; log.loading=g.loading
    for _,key in ipairs({'Return','W','A','S','D','Up','Down','Left','Right','R'}) do
      if D.Keyboard:isKeyPressed(key) then log.keyboardFrames[key]=(log.keyboardFrames[key] or 0)+1 end
    end
    local s=g.state; local signature=string.format('%d:%s:%d:%s:%s',s.restarts,tostring(s.started),s.collected,tostring(s.won),tostring(s.collisionHits>0))
    if signature~=last then
      last=signature
      log.events[#log.events+1]={time=elapsed,round=s.restarts,started=s.started,collected=s.collected,won=s.won,x=s.x,z=s.z,inputEvents=s.inputEvents,collisionHits=s.collisionHits}
      if s.won and not log.completedRounds[tostring(s.restarts)] then
        log.completedRounds[tostring(s.restarts)]={screenshot=D.App:saveScreenshot(output..'input-'..config.asset..'-round-'..s.restarts),time=elapsed}
      end
    end
    if elapsed-saved>.5 then
      saved=elapsed; log.current={round=s.restarts,x=s.x,z=s.z,started=s.started,won=s.won,collected=s.collected,inputEvents=s.inputEvents,collisionHits=s.collisionHits}
      D.Content:save(output..'input-'..config.asset..'-live.json',assert(json.encode(log)))
    end
  end
  return Game.launch(config)
end
