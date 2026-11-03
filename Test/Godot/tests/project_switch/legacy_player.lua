local D = Dora
D.App.devMode=false
D.Content:insertSearchPath(1,D.Content.assetPath .. "/Script/Lib")
local player=require("GodotPlayer")()
local ready,rejected=false,false
player:switchAsync(@B@,{},function(ok,game,error) assert(ok and game,error);ready=true end)
player:switchAsync(@A@,{},function(ok,game,error)
    assert(not ok and not game and error:find("project lifecycle extension"),error)
    rejected=true
end)
player:closeAsync(function(ok,error)
    assert(ready and rejected and not ok and error~="",error)
    D.Content:save(@STATE@,'{"passed":true,"legacy_switch_refused":true}')
    D.App:shutdown()
end)
