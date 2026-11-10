#!/usr/bin/env python3
"""Compile a fresh generated TU with the real imported xmake file configuration."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--importer',choices=['generic','macos'],default='generic');a=p.parse_args()
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
assert not list((ROOT/'Projects/xmake/godot/wrappers').rglob('*.c')), 'Native variants must not require wrapper C sources'
cpp='#include "platform_config.h"\n#ifndef DORA_IMPORT_FLAG\n#error imported flags missing\n#endif\nint main() { return DORA_IMPORT_FLAG == 73 && DORA_PLATFORM_FLAG == 29 ? 0 : 1; }\n'
for case in ('absolute-control','relative-fixed'):
    root=out/case;manifest=root/'Projects/xmake/godot/probe.lua';manifest.parent.mkdir(parents=True)
    header=root/'Source/3rdParty/Godot/platform/android/platform_config.h';header.parent.mkdir(parents=True);header.write_text('#define DORA_PLATFORM_FLAG 29\n')
    db=root/'compile_commands.json';db.write_text(json.dumps([{'directory':str(root),'file':'main/probe.gen.cpp','command':'clang++ -o bin/obj/main/probe.android.template_release.arm64.o -c -std=gnu++17 -DDORA_IMPORT_FLAG=73 -Iplatform/android -I. main/probe.gen.cpp'}]))
    importer='import_macos_compile_db.lua' if a.importer=='macos' else 'import_compile_db.lua'
    extra=['--variant','generated_flags_fixture_readonly'] if a.importer=='macos' else ['--variant','generated_flags_fixture_readonly','--object-platform','android','--generated-root','build/generated']
    subprocess.run([os.environ.get('DORA_XMAKE','xmake'),'lua',str(ROOT/'Tools/Godot'/importer),str(db),str(manifest),*extra],check=True,stdout=subprocess.DEVNULL)
    if a.importer=='macos':manifest.write_text(manifest.read_text().replace('build/godot-xmake/generated','build/generated'))
    if case=='absolute-control':
        text=manifest.read_text();assert 'return path.relative(path.join(generated_root, relative), os.scriptdir())' in text
        manifest.write_text(text.replace('return path.relative(path.join(generated_root, relative), os.scriptdir())','return path.join(generated_root, relative)'))
    (root/'xmake.lua').write_text('''set_project("generated-flags-probe")
set_languages("cxx17")
target("godot-codegen")
    set_kind("phony")
    on_build(function ()
        local generated = path.join(os.projectdir(), "build/generated/main/probe.gen.cpp")
        os.mkdir(path.directory(generated))
        io.writefile(generated, [=[@CPP@]=])
    end)
target_end()
target("godot-main-platform")
    set_kind("binary")
    set_basename("probe")
    set_targetdir(path.join(os.projectdir(), "bin"))
    add_deps("godot-codegen")
    on_load(function (target)
        local file = "build/generated/main/probe.gen.cpp"
        assert(not os.isfile(file), "Fixture must load before first code generation")
        local config = target:fileconfig(file)
        assert(config and config.cxxflags and table.contains(config.cxxflags, "-DDORA_IMPORT_FLAG=73"),
            "Generated file lost imported flags before generation")
    end)
target_end()
includes("Projects/xmake/godot/probe.lua")
'''.replace('@CPP@',cpp))
    env=os.environ.copy();env['XMAKE_CONFIGDIR']=str(root/'config')
    commands=[['xmake','f','-P',str(root),'-c','-m','release','-y'],['xmake','build','-P',str(root),'godot-main-platform']]
    logs=[];status=0
    for command in commands:
        result=subprocess.run(command,cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);logs.append(result.stdout);status=result.returncode
        if status:break
    (root/'build.log').write_text('\n'.join(logs))
    if case=='absolute-control':assert status!=0 and 'Generated file lost imported flags before generation' in '\n'.join(logs)
    else:
        assert status==0,logs[-1]
        subprocess.run([str(root/'bin'/('probe.exe' if sys.platform=='win32' else 'probe'))],check=True)
assert not list((ROOT/'Projects/xmake/godot/wrappers').rglob('*.c')), 'Importer unexpectedly generated wrapper C sources'
(out/'verification.json').write_text(json.dumps({'passed':True,'absolute_control_rejected':True,'relative_first_generation_compiled_and_executed':True,'scope':'Real xmake configuration/codegen/compiler integration; no Godot engine boot or GPU acceptance'},indent=2)+'\n')
print('First-generation xmake flags: old absolute control rejected; fixed imported flags compiled and executed')
