local D=Dora
D.App.devMode=false
D.Content:insertSearchPath(1,D.Content.assetPath .. "/Script/Lib")
local player=require("GodotPlayer")()
assert(D.Director:beginGameCapture())
D.Director.clearColor=D.Color(0xff192331)
local projects={@FIRST@,@OTHER@,@FIRST@}
local names={"initial","other","recovered"}
local index,ticks,pending,game=0,0,false,nil
local function capture(name,done)
    pending=true
    assert(D.Director:captureGameAsync(@OUTPUT@ .. "/" .. name .. ".png",function(ok)
        assert(ok,name);pending=false;if done then done() end
    end))
end
local function nextProject()
    index=index+1;ticks=0
    player:switchAsync(projects[index],{scene="res://main.tscn",width=640,height=360,buffers=3},function(ok,node,error)
        assert(ok and node,error);game=node
        print("GODOT_PROJECT_BOUNDARY running=" .. names[index])
    end)
end
nextProject()
D.Node():addTo(D.Director.ui):schedule(function()
    if pending or not game then return false end
    assert(game.running and game.lastError=="",game.lastError)
    ticks=ticks+1
    if index~=2 then
        if ticks==30 then capture(names[index] .. "-a") end
        if ticks==60 then capture(names[index] .. "-b") end
    end
    if ticks==90 then
        game=nil
        player:unloadAsync(function(ok,_,error)
            assert(ok,error)
            if index==1 then capture("removed",nextProject)
            elseif index==2 then nextProject()
            else player:closeAsync(function(ok,error)
                assert(ok,error)
                print("GODOT_PROJECT_BOUNDARY complete=1 captures=5")
                D.Director:endGameCapture();D.App:shutdown()
            end) end
        end)
    end
    return false
end)
