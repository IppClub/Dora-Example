-- CPU-only regression checks for the xmake-Lua package tools.
function main(root)
    local C = import("Tools.Godot.common", {rootdir = root})
    local M = import("Tools.Godot.package_manifest", {rootdir = root})
    local V = import("Tools.Godot.verify_package", {rootdir = root})
    local J = import("Tools.Godot.ordered_json", {rootdir = root})
    local R = import("Tools.Godot.verify_nir_review", {rootdir = root})
    local temporary = os.tmpfile() .. "-godot-packaging"
    local package = path.join(temporary, "package")
    local function rejected(action, label)
        local failed = false
        try {action, catch {function () failed = true end}}
        assert(failed, "Invalid input accepted: " .. label)
    end
    try {
        function ()
            os.mkdir(package)
            C.write(path.join(package, "dora_godot.dll"), "fixture library, never executed")
            C.write(path.join(package, "LICENSE.txt"), "fixture notice\n")
            local manifest = {library = "dora_godot.dll", library_sha256 = C.digest(path.join(package, "dora_godot.dll")),
                graphics_backend = "wgl", architectures = {"x86_64"}, licenses = {"LICENSE.txt"}, build_target = "template_release"}
            local function seal()
                M.seal(package, manifest); C.save(path.join(package, "manifest.json"), manifest)
            end
            seal()
            local report = V.verify(package)
            assert(report.passed and report.files == 2 and report.godot_version == "4.7.2-stable")
            C.write(path.join(package, "unlisted.txt"), "unlisted")
            rejected(function () V.verify(package) end, "unlisted file")
            os.rm(path.join(package, "unlisted.txt"))
            C.write(path.join(package, "LICENSE.txt"), "tampered")
            rejected(function () V.verify(package) end, "tampered notice")
            seal()
            manifest.architectures = {"x86_64", "x86_64"}; C.save(path.join(package, "manifest.json"), manifest)
            rejected(function () V.verify(package) end, "duplicate architectures")
            manifest.architectures = {"x86_64"}
            for _, name in ipairs({"../escape", "/absolute", "x\\y", "x/../y", "x//y", "./file", "C:/file"}) do
                rejected(function () C.safe_relative(name) end, name)
            end
            C.write(path.join(temporary, "outside.txt"), "outside")
            os.ln(path.join(temporary, "outside.txt"), path.join(package, "linked.txt"), {symbolic = true})
            rejected(function () C.safe_file(package, "linked.txt") end, "symlink artifact")
            os.rm(path.join(package, "linked.txt"))
            -- Retained review hashes must survive the Python-to-Lua serializer change.
            local notices = path.join(root, "Tools/Godot/licenses/nir-25.3.1-1")
            local provenance = J.decode(C.read(path.join(notices, "GODOT-NIR-PROVENANCE.json")))
            assert(R.verify_review(provenance.license_review, provenance))
            manifest.graphics_backend = "d3d12"
            for _, name in ipairs({"GODOT-NIR-THIRD-PARTY-NOTICES.txt", "GODOT-NIR-PROVENANCE.json"}) do C.copy(path.join(notices, name), path.join(package, name)) end
            manifest.licenses = {"LICENSE.txt", "GODOT-NIR-THIRD-PARTY-NOTICES.txt"}; seal()
            assert(V.verify(package).nir_notice_schema == 3)
            provenance.license_review.files[1].reviewed = false
            rejected(function () R.verify_review(provenance.license_review, provenance) end, "review mutation")
            provenance = J.decode(C.read(path.join(notices, "GODOT-NIR-PROVENANCE.json")))
            provenance.historical_notice_sources[1].notice_text = "untrusted inherited notice"
            C.write(path.join(package, "GODOT-NIR-PROVENANCE.json"), J.encode(provenance) .. "\n"); seal()
            rejected(function () V.verify(package) end, "inherited notice provenance")
            manifest.bridge_abi = 2
            rejected(function () M.seal(package, manifest) end, "incompatible ABI")
        end,
        finally {function (ok, errors)
            os.tryrm(temporary)
            if not ok then raise(errors) end
        end}
    }
    print("PASS: Lua packaging validates native/NIR inventories and rejects tampering, traversal, symlinks and incompatible identities")
end
