local D = Dora
D.Content:insertSearchPath(1, D.Content.assetPath .. "/Script/Lib")
local Player = require("GodotPlayer")
D.App.devMode = false
local output, items = @OUTPUT@, @PROJECTS@
local player = Player()
local index, stage, closing, total = 0, nil, false, 0
local control = D.Node():addTo(D.Director.ui)
assert(D.Director:beginGameCapture())
local function fail(message)
    if closing then return end
    closing, stage = true, nil
    D.Content:save(output .. "/failure.txt", tostring(message))
    D.Content:save(output .. "/player.json", '{"passed":false}')
    player:closeAsync(function() D.Director:endGameCapture(); D.App:shutdown() end)
end
local function safe(fn)
    local ok, message = pcall(fn)
    if not ok then fail(message) end
end
local function nextProject()
    index = index + 1
    if index > #items then
        closing = true
        player:closeAsync(function(ok, message)
            if not ok then
                D.Content:save(output .. "/failure.txt", message)
                D.Content:save(output .. "/player.json", '{"passed":false}')
            else
                D.Content:save(output .. "/player.json", '{"passed":true,"projects":' .. #items .. ',"captures":' .. total .. '}')
                print("DORA_REAL_SWITCH complete=" .. #items .. " captures=" .. total)
            end
            D.Director:endGameCapture()
            D.App:shutdown()
        end)
        return
    end
    local item = items[index]
    assert(player:switchAsync(item.path, {width=item.width,height=item.height,buffers=item.buffers}, function(ok, game, message)
        safe(function()
            assert(ok, message)
            stage = {game=game,elapsed=0,captures=0,pending=false}
            print("DORA_REAL_SWITCH ready=" .. index .. " name=" .. item.name .. " buffers=" .. item.buffers)
        end)
    end))
end
local function capture(s, name)
    s.pending = true
    assert(D.Director:captureGameAsync(output .. "/" .. index .. "-" .. name .. ".png", function(ok)
        safe(function()
            assert(ok, "capture failed")
            s.pending = false
            s.captures = s.captures + 1
            total = total + 1
        end)
    end))
end
nextProject()
control:schedule(function(dt)
    safe(function()
        if closing or not stage then return end
        local s = stage
        s.elapsed = s.elapsed + dt
        assert(s.game.lastError == "", s.game.lastError)
        local view, size = D.View.size, s.game.viewportSize
        local scale = math.min(view.width / size.width, view.height / size.height)
        s.game.scaleX, s.game.scaleY = scale, scale
        s.ticks = (s.ticks or 0) + 1
        if s.ticks == 3 then s.game:sendKey("Space",true) end
        if s.ticks == 10 then s.game:sendKey("Space",false);s.startReleased=s.elapsed end
        if s.startReleased and s.elapsed-s.startReleased>0.4 and s.ticks>22 and s.captures==0 and not s.pending then capture(s,"a") end
        if s.captures==1 and not s.move then
            s.move=true;s.moveAt=s.elapsed;s.moveTicks=s.ticks;s.game:sendKey("D",true)
        end
        if s.move and not s.stopMove and s.elapsed-s.moveAt>0.5 and s.ticks-s.moveTicks>=25 then
            s.stopMove=true;s.stopAt=s.elapsed;s.stopTicks=s.ticks;s.game:sendKey("D",false)
        end
        if s.stopMove and s.elapsed-s.stopAt>0.25 and s.ticks-s.stopTicks>=10 and s.captures==1 and not s.pending then
            s.afterAt=s.elapsed;capture(s,"b")
        end
        if s.afterAt and s.elapsed-s.afterAt>1.5 and s.captures==2 and not s.pending then capture(s,"c") end
        if s.captures==3 and not s.pending then
            stage = nil
            print("DORA_REAL_SWITCH switching=" .. index)
            nextProject() -- controller waits for the native unload acknowledgement
        end
    end)
    return false
end)
