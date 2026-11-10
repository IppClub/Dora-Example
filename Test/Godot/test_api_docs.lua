function main(root)
    local generator=import("Tools.Godot.generate_api_docs",{rootdir=root})
    import("core.base.json")
    local temporary=os.tmpfile().."-godot-docs";local source=path.join(temporary,"source");local output=path.join(temporary,"docs")
    os.mkdir(path.join(source,"doc/classes"));os.mkdir(path.join(source,"modules/gdscript/doc_classes"))
    io.writefile(path.join(source,"UPSTREAM.json"),json.encode({version="test-stable",upstream_commit="fixture"}))
    for _,name in ipairs({"LICENSE.txt","COPYRIGHT.txt"}) do io.writefile(path.join(source,name),"Original notices\n") end
    io.writefile(path.join(source,"doc/classes/Node.xml"),[=[<class name="Node"><methods><method name="get_node"><return type="Node"/><param index="0" name="path" type="NodePath" default="&quot;Child&quot;"/><description>
[codeblocks]
[gdscript]
if true:
	var nodes: Array[Node] = []
[/gdscript]
[csharp skip-lint]
UnsupportedExample();
[/csharp]
[/codeblocks]
[code]Array[Node][/code] and [Node].
</description></method></methods></class>]=])
    local child=path.join(source,"doc/classes/Node2D.xml")
    io.writefile(child,'<class name="Node2D" inherits="Node"><signals><signal name="ready"/></signals></class>')
    io.writefile(path.join(source,"modules/gdscript/doc_classes/@GDScript.xml"),'<class name="@GDScript"/>')
    generator.generate(source,output)
    local manifest=json.loadfile(path.join(output,"manifest.json"));assert(manifest.class_count==3 and manifest.godot_version=="test-stable")
    local node=io.readfile(path.join(output,"classes/Node.md"))
    assert(node:find('get_node(path: NodePath = "Child") -> Node',1,true))
    assert(node:find('\tvar nodes: Array[Node] = []',1,true) and node:find('`Array[Node]`',1,true))
    assert(not node:find("UnsupportedExample",1,true))
    assert(io.readfile(path.join(output,"classes/Node2D.md")):find("@dora-doc/godot-api/classes/Node.md",1,true))
    local mtimes={};for _,file in ipairs(os.files(path.join(output,"**"))) do mtimes[file]=os.mtime(file) end
    generator.generate(source,output);generator.generate(source,output,true)
    for file,mtime in pairs(mtimes) do assert(os.mtime(file)==mtime,"Unchanged document was rewritten") end
    io.writefile(child,'<class name="Node2D" inherits="Node"><description>Updated.</description></class>')
    local ok=true;try {function()generator.generate(source,output,true)end,catch {function()ok=false end}};assert(not ok,"Stale output accepted")
    generator.generate(source,output);assert(json.loadfile(path.join(output,"manifest.json")).source_sha256~=manifest.source_sha256)
    os.rm(child);generator.generate(source,output);assert(not os.isfile(path.join(output,"classes/Node2D.md")))
    local user=path.join(temporary,"user");os.mkdir(user);io.writefile(path.join(user,"keep.txt"),"keep")
    ok=true;try {function()generator.generate(source,user)end,catch {function()ok=false end}};assert(not ok and io.readfile(path.join(user,"keep.txt"))=="keep")
    os.rm(temporary)
    print("PASS: Lua Godot docs preserve signatures/inheritance/code/notice provenance; stale and unsafe output rejected; unchanged output retained")
end
