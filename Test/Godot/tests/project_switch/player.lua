local D = Dora
D.App.devMode = false
local projects = @PROJECTS@
local output = @OUTPUT@
local index, elapsed, captured, pending = 0, 0, false, false
local game, closing = nil, false
local rejecting, rejected, duplicate = false, false, false
local function state(value)
    assert(D.Content:save(output .. "/player.json", value))
end
local function load()
    index = index + 1
    if index > #projects then
        assert(rejected and duplicate, "recovery and single-client cases did not run")
        state('{"passed":true,"rejected_project_recovered":true,"single_client_enforced":true,"projects":' .. #projects .. '}')
        D.Director:endGameCapture()
        D.App:shutdown()
        return
    end
    if index == 3 and not rejected then
        game = assert(D.GodotNode(@INVALID@, "", 640, 360, 3))
        game:addTo(D.Director.ui)
        elapsed, rejecting, closing = 0, true, false
        return
    end
    local item = projects[index]
    game = assert(D.GodotNode(item.path, "", 640, 360, item.buffers), "Cannot load project " .. index)
    game:addTo(D.Director.ui)
    elapsed, captured, pending, closing = 0, false, false, false
    print("DORA_SWITCH_HOST opened=" .. index .. " tag=" .. item.tag)
end
assert(D.Director:beginGameCapture())
load()
local control = D.Node():addTo(D.Director.ui)
control:schedule(function(dt)
    local ok, message = pcall(function()
        elapsed = elapsed + dt
        if closing then return end
        if rejecting then
            if game.lastError ~= "" then
                assert(game.lastError == "Godot project has no main scene", game.lastError)
                local old = game
                rejecting, rejected, closing = false, true, true
                old:unloadAsync(function(ok, message)
                    assert(ok and old.unloaded, message)
                    game = nil
                    index = index - 1
                    print("DORA_SWITCH_HOST invalid-project-rejected")
                    load()
                end)
            else
                assert(elapsed < 15, "invalid project did not fail")
            end
            return
        end
        assert(game.lastError == "", game.lastError)
        if index == 1 and game.running and not duplicate then
            assert(D.GodotNode(projects[3].path, "", 640, 360, 3) == nil, "Two active clients were accepted")
            duplicate = true
            print("DORA_SWITCH_HOST duplicate-client-rejected")
        end
        local size, viewport = D.View.size, game.viewportSize
        game.scaleX, game.scaleY = size.width / viewport.width, size.height / viewport.height
        if elapsed > 0.65 and not pending and not captured then
            pending = true
            assert(D.Director:captureGameAsync(output .. "/" .. index .. ".png", function(ok)
                assert(ok, "capture failed")
                captured, pending = true, false
            end))
        end
        if elapsed > 1.0 and captured and not pending then
            local old, closedIndex = game, index
            closing = true
            local calls = 0
            old:unloadAsync(function(ok, message)
                assert(ok and old.unloaded, message)
                calls = calls + 1
                print("DORA_SWITCH_HOST closed=" .. closedIndex)
            end)
            old:unloadAsync(function(ok, message)
                assert(ok and old.unloaded and calls == 1, message)
                calls = calls + 1
                old:unloadAsync(function(ok, message)
                    assert(ok and old.unloaded and calls == 2, message)
                    print("DORA_SWITCH_HOST unload-ack=" .. closedIndex)
                    game = nil
                    collectgarbage("collect")
                    load()
                end)
            end)
        end
    end)
    if not ok then
        state('{"passed":false}')
        D.Content:save(output .. "/failure.txt", tostring(message))
        print("DORA_SWITCH_HOST failed=" .. tostring(message))
        D.App:shutdown()
        return true
    end
    return index > #projects
end)
