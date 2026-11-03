-- Object order must come from the loaded graph, not sorted dependency inputs.
import("core.project.project")
import("core.project.config")
import("core.base.json")
function main(output)
    assert(not os.isfile(output), "Use a fresh output path")
    config.load()
    local target = assert(project.target("Dora"))
    assert(target:plat() == "macosx" and target:arch() == "arm64")
    json.savefile(output, {objects = target:objectfiles(), plat = target:plat(),
        arch = target:arch(), mode = config.get("mode"), targetfile = target:targetfile()})
end
