#!/usr/bin/env python3
"""Exercise the real production component validator for both Windows flavours."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT
import json,subprocess,tempfile
root=ENGINE_ROOT
with tempfile.TemporaryDirectory(prefix='windows-component-backends-') as temp:
    temp=Path(temp); dll=temp/'dora_godot.dll';dll.write_bytes(b'Packaging fixture only, never loaded')
    for backend in ['d3d12','wgl']:
        package=temp/backend
        subprocess.run([sys.executable,str(root/'Tools/Godot/package_runtime.py'),'--source',str(root/'Source/3rdParty/Godot'),
            '--library',str(dll),'--output',str(package),'--architecture','x86_64','--build-target','template_release','--graphics-backend',backend],check=True,capture_output=True)
        command=[sys.executable,str(root/'Tools/Godot/build_component.py'),'--platform','windows','--arch','x64','--mode','release',
            '--stage-only','--runtime-package',str(package),'--stage',str(temp/('stage-'+backend))]
        explicit=command+['--windows-backend',backend]
        result=subprocess.run(explicit,capture_output=True,text=True)
        assert result.returncode==0,result.stderr
        assert json.loads(result.stdout)['graphics_backend']==backend
        if backend=='d3d12':
            assert subprocess.run(command,capture_output=True).returncode==0,'Default must be D3D12'
        for wrong in [['--windows-backend','wgl' if backend=='d3d12' else 'd3d12']]:
            assert subprocess.run(command+wrong,capture_output=True).returncode!=0,'Mismatched runtime accepted'
        invalid_arch=[('x86' if x=='x64' else x) for x in explicit]
        assert subprocess.run(invalid_arch,capture_output=True).returncode!=0,'32-bit runtime accepted'
print('PASS: Windows D3D12 default, both backend staging paths, backend mismatch and x86 rejection')
