-- Parse complete bootstrap chunks: extracting test fragments misses Lua's
-- per-function local-variable limit in the real launcher and WebServer.
local root = assert(os.getenv('DORA_ENGINE_ROOT') or arg[1], 'Set DORA_ENGINE_ROOT')
for _, file in ipairs({'Assets/Script/init.lua', 'Assets/Script/Dev/Entry.lua', 'Assets/Script/Dev/WebServer.lua'}) do
    local chunk, message = loadfile(root .. '/' .. file)
    assert(chunk, file .. ': ' .. tostring(message))
end
local file = assert(io.open(root .. '/Assets/Script/Dev/Entry.lua'))
local source = file:read('a'); file:close()
local reserved = {}
for index = 1, 32 do reserved[index] = '__bootstrap_reserved_' .. index end
-- Reserve slots in the same top-level scope without executing the launcher.
-- This prevents a future edit from quietly returning to the 200-local cliff.
local guarded, message = load('local ' .. table.concat(reserved, ', ') .. '\n' .. source, 'launcher with 32 reserved locals')
assert(guarded, 'Launcher must leave at least 32 top-level local slots available: ' .. tostring(message))
print('PASS: bootstrap Lua chunks load; launcher retains at least 32 local-variable slots of headroom')
