-- Export xmake's serialized dependency data without changing the build graph.
function main(receipt, output)
    import("core.base.json")
    assert(not os.isfile(output), "Use a fresh output path")
    local data = assert(io.load(receipt), "Missing xmake link dependency receipt")
    assert(type(data.values[1]) == "string" and type(data.values[2]) == "table")
    json.savefile(output, {
        source = path.absolute(receipt),
        exporter = path.join(os.projectdir(), "Tools/Godot/export_macos_link_receipt.lua"),
        program = data.values[1], flags = data.values[2], files = data.files
    })
end
