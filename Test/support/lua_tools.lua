-- JSON transport for external test harnesses; all implementation runs in Lua.
function main(root, input, output)
    local C = import("Tools.Godot.common", {rootdir = root})
    local J = import("Tools.Godot.ordered_json", {rootdir = root})
    local request = J.decode(C.read(input))
    assert(request.module:match("^Tools%.[%w_%.]+$"), "Invalid test module")
    import("core.base.base64")
    import("core.base.json")
    local function decode(value)
        if value == json.null or value == json.purenull then return nil end
        if type(value) ~= "table" then return value end
        if value.__lua_bytes then return base64.decode(value.__lua_bytes):str() end
        for name, item in pairs(value) do value[name] = decode(item) end
        return value
    end
    local result
    try {function ()
        local module = import(request.module, {rootdir = root})
        local arguments = decode(request.args or {})
        local values = table.pack(assert(module[request.method], "Unknown Lua test API: " .. request.method)(table.unpack(arguments, 1, request.arg_count or #arguments)))
        local value = values[1]
        if request.multiple then value = {}; for index = 1, values.n do value[index] = values[index] end; C.array(value) end
        if request.binary_values then
            for name, data in pairs(value) do value[name] = {__lua_bytes = base64.encode(data)} end
        end
        if request.list_result and type(value) == "table" and table.empty(value) then value = C.array() end
        result = {ok = true, value = value == nil and C.null() or value}
    end, catch {function (errors) result = {ok = false, error = tostring(errors)} end}}
    C.save(output, result)
end
