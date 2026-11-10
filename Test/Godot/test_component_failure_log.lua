function main(root, directory)
    local component = import("Tools.Godot.build_component", {rootdir = root})
    for _, linking in ipairs({false, true}) do
        local failed = false
        try {function () component.run_builder(os.programfile(), {"lua", "-c", 'raise("fixture compiler failure")'}, {}, directory, linking) end,
            catch {function () failed = true end}}
        assert(failed, "Compiler failure was swallowed")
    end
    local failed = false
    try {function () component.run_builder(os.programfile(), {"lua", "-c", 'raise("fixture compiler failure")'}, {}, path.join(directory, "missing"), false) end,
        catch {function () failed = true end}}
    assert(failed, "Missing log hid the failure")
end
