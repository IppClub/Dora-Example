local D = Dora
D.App.devMode=false
local control=D.Node():addTo(D.Director.ui)
local first=assert(D.GodotNode(@B@))
assert(not first.running)
local game,phase,ticks=nil,0,0
first:unloadAsync(function(ok,error)
    assert(ok and first.unloaded,error)
    phase=1
    game=assert(D.GodotNode(@B@)):addTo(D.Director.ui)
end)
control:schedule(function()
    if game then
        assert(game.lastError=="",game.lastError)
        if game.running then
            ticks=ticks+1
            if ticks==15 then
                local old=game
                game=nil
                old:unloadAsync(function(ok,error)
                    assert(ok and old.unloaded,error)
                    if phase==1 then
                        phase,ticks=2,0
                        game=assert(D.GodotNode(@A@)):addTo(D.Director.ui)
                    else
                        D.Content:save(@STATE@,'{"passed":true,"cancel_before_ready":true,"subsequent_switch":true}')
                        D.App:shutdown()
                    end
                end)
            end
        end
    end
    return false
end)
