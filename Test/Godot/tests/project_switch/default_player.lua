local D = Dora
D.App.devMode=false
D.Content:insertSearchPath(1,D.Content.assetPath .. "/Script/Lib")
local player=require("GodotPlayer")()
local ready=0
player:switchAsync(@B@,{},function(ok,game,error) assert(ok and game,error);ready=ready+1 end)
player:switchAsync(@A@,{},function(ok,game,error) assert(ok and game,error);ready=ready+1 end)
player:closeAsync(function(ok,error)
    assert(ok and ready==2,error)
    D.Content:save(@STATE@,'{"passed":true,"default_switch":true}')
    D.App:shutdown()
end)
