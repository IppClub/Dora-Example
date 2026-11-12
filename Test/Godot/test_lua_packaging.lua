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
            assert(C.data_digest("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            assert(C.data_digest("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
            local empty = path.join(temporary, "empty")
            C.write(empty, "")
            assert(C.digest(empty) == C.data_digest(""))
            -- Exercise the real MSI generator through its external WiX boundary.
            local W = import("Tools.WindowsPackage.package_windows", {rootdir = root})
            local stage = path.join(temporary, "windows-stage")
            local pe = "MZ" .. string.rep("\0", 58) .. string.char(64, 0, 0, 0)
                .. "PE\0\0" .. string.char(100, 134) .. string.rep("\0", 58)
            C.write(path.join(stage, "Dora.exe"), pe)
            C.write(path.join(stage, "wa.dll"), pe)
            C.write(path.join(stage, "empty.txt"), "")
            local original_run, wix_calls = C.run, 0
            C.run = function (tool, args)
                assert(tool == "wix" and args[1] == "build")
                local source = C.read(args[2])
                assert(source:find('Id="R' .. C.data_digest(""):sub(1, 28) .. '"', 1, true), "Missing root RemoveFolder ID")
                assert(source:find('Name="empty.txt"', 1, true), "Empty file was dropped")
                assert(source:find('Name="Dora.exe"', 1, true))
                wix_calls = wix_calls + 1
                C.write(args[#args], "test WiX output, not an executable installer")
            end
            try {function ()
                for _, backend in ipairs({"wgl", "d3d12"}) do
                    local output = path.join(temporary, "msi-" .. backend)
                    local hashes = W.package_windows(stage, output, backend, "msi", "1.10.2")
                    assert(#C.keys(hashes) == 1 and #C.read(path.join(output, "SHA256SUMS")) > 64)
                end
                assert(wix_calls == 2)
            end, finally {function (ok, errors)
                C.run = original_run
                if not ok then raise(errors) end
            end}}
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
    print("PASS: Lua packaging validates empty SHA-256, both MSI generators, native/NIR inventories and rejects tampering, traversal, symlinks and incompatible identities")
end
