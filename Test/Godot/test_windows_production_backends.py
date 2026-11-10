import os
#!/usr/bin/env python3
"""Exercise the real production component validator for both Windows flavours."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT
import json,subprocess,tempfile,struct,shutil,importlib.util
root=ENGINE_ROOT
with tempfile.TemporaryDirectory(prefix='windows-component-backends-') as temp:
    temp=Path(temp); dll=temp/'dora_godot.dll'
    header=bytearray(128);header[:2]=b'MZ';struct.pack_into('<I',header,60,64);header[64:70]=b'PE\0\0\x64\x86';dll.write_bytes(header)
    # Execute the unchanged production staging function with real xmake file APIs.
    source=(root/'Projects/xmake/tasks/package.lua').read_text().split('local function package_macos',1)[0]
    (temp/'stage_runtime.lua').write_text(source.replace('local function stage_godot_runtime', 'function stage_godot_runtime', 1))
    (temp/'run_stage.lua').write_text('''function main(runtime, destination, modules, python)
    local stage = import("stage_runtime", {rootdir = modules, anonymous = true})
    stage.stage_godot_runtime(runtime, destination, "dora_godot.dll", {"x86_64"}, {
        ensure = assert, json = import("core.base.json"), os = os, path = path,
        find_tool = function() return {program = python} end, cprint = cprint
    })
end
''')
    from types import SimpleNamespace
    from lua_tools import call
    packager=SimpleNamespace(package=lambda *args: call('Tools.WindowsPackage.package_windows','package_windows',*args))
    for backend in ['d3d12','wgl']:
        package=temp/backend
        subprocess.run([os.environ.get('DORA_XMAKE','xmake'), 'lua', str(root/'Tools/Godot/package_runtime.lua'),'--source',str(root/'Source/3rdParty/Godot'),
            '--library',str(dll),'--output',str(package),'--architecture','x86_64','--build-target','template_release','--graphics-backend',backend],check=True,capture_output=True)
        command=[os.environ.get('DORA_XMAKE','xmake'), 'lua', str(root/'Tools/Godot/build_component.lua'),'--platform','windows','--arch','x64','--mode','release',
            '--stage-only','--runtime-package',str(package),'--stage',str(temp/('stage-'+backend))]
        explicit=command+['--windows-backend',backend]
        result=subprocess.run(explicit,capture_output=True,text=True)
        assert result.returncode==0,result.stderr
        assert json.loads(result.stdout)['graphics_backend']==backend
        if backend=='d3d12':
            assert subprocess.run(command,capture_output=True).returncode==0,'Default must be D3D12'
        for wrong in [['--windows-backend','wgl' if backend=='d3d12' else 'd3d12']]:
            assert subprocess.run(command+wrong,capture_output=True).returncode!=0,'Mismatched runtime accepted'
        staged=temp/('distribution-'+backend)
        stage_result=subprocess.run(['xmake','lua',str(temp/'run_stage.lua'),str(package),str(staged),str(temp),sys.executable],cwd=root,capture_output=True,text=True)
        assert stage_result.returncode==0,stage_result.stdout+stage_result.stderr
        manifest=json.loads((package/'manifest.json').read_text())
        for name in manifest['artifacts']:
            actual=staged/name if name==manifest['library'] else staged/'GodotRuntimeNotices'/name
            assert actual.read_bytes()==(package/name).read_bytes(),name
        for name in ['Dora.exe','wa.dll']:shutil.copyfile(dll,staged/name)
        subprocess.run([sys.executable,str(Path(__file__).parent/'tests/verify_desktop_package.py'),'--platform','windows','--package-root',str(staged),'--runtime-package',str(package),'--output',str(temp/('verified-'+backend+'.json'))],check=True,capture_output=True)
        packager.package(staged,temp/('zip-'+backend),backend,'zip','1.10.1')
        if backend=='d3d12':
            missing=staged/'GodotRuntimeNotices/GODOT-NIR-PROVENANCE.json';original=missing.read_bytes();missing.unlink()
            try:packager.package(staged,temp/'bad-zip',backend,'zip','1.10.1')
            except ValueError as error:assert 'GODOT-NIR-PROVENANCE.json' in str(error)
            else:raise AssertionError('Distribution missing provenance was accepted')
            missing.write_bytes(original+b'corrupt')
            try:packager.package(staged,temp/'bad-hash',backend,'zip','1.10.1')
            except ValueError:pass
            else:raise AssertionError('Distribution with corrupt provenance was accepted')
        invalid_arch=[('x86' if x=='x64' else x) for x in explicit]
        assert subprocess.run(invalid_arch,capture_output=True).returncode!=0,'32-bit runtime accepted'
print('PASS: Windows backend validation, real desktop staging, complete artifact inventory, missing/corrupt provenance rejection and x86 rejection')
