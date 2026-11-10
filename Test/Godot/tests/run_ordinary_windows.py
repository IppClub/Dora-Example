#!/usr/bin/env python3
"""Ordinary Windows app: optional-runtime loading and safe fallback checks.

Default: bundled and missing runtime. --backend-mismatch-only checks rejection
by the default renderer with the selected runtime present.

Includes upstream runtime notices in each asset tree;
this does not verify installers, updates, signing or production distribution.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time
from pathlib import Path
from PIL import Image,ImageChops
root=ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__)
for name in ('binary','library','output'):p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--asset-root',type=Path,help='Copy this packaged asset root instead of the source Assets tree')
p.add_argument('--use-bundled-library',action='store_true',help='Require the sealed runtime to already exist in --asset-root')
p.add_argument('--backend-mismatch-only',action='store_true',help='Run the ordinary default renderer with the selected runtime present; require safe rejection and continuing Dora output')
p.add_argument('--backend',choices=['WGL','D3D12'],default='WGL')
p.add_argument('--warp',action='store_true',help='D3D12 WARP software validation; does not prove physical GPU support')
p.add_argument('--environment',choices=['unspecified','native','virtual-machine'],default='unspecified')
a=p.parse_args();assert sys.platform=='win32'
assert not a.warp or a.backend=='D3D12','--warp requires --backend D3D12'
out=a.output.resolve();assert not out.exists(),'Use a fresh evidence directory'
out.mkdir(parents=True);binary=a.binary.resolve();library=a.library.resolve()
asset_root=a.asset_root.resolve() if a.asset_root else None
assert not a.use_bundled_library or asset_root,'--use-bundled-library requires --asset-root'
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def pixels(image):return image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata()
try:
    assert b'dora_godot_node_test_main' not in binary.read_bytes(),'Use an ordinary host'
    subprocess.run([os.environ.get('DORA_XMAKE','xmake'), 'lua', str(root/'Tools/Godot/verify_package.lua'),str(library.parent),'--output',str(out/'package-integrity.json')],check=True)
    manifest=json.loads((library.parent/'manifest.json').read_text());assert manifest['library']==library.name
    assert manifest.get('graphics_backend')==a.backend.lower(),'Runtime package backend does not match --backend'
    original={str(path):digest(path) for path in (binary,library)}
    cases=[]
    for scenario in (['backend-mismatch'] if a.backend_mismatch_only else ['bundled-runtime','missing-library']):
        missing=scenario=='missing-library';mismatch=scenario=='backend-mismatch'
        template=Path(__file__).with_name('backend_mismatch_windows.lua' if mismatch else 'ordinary_native.lua')
        case=out/scenario;case.mkdir()
        assets=case/'assets';shutil.copytree(asset_root or root/'Assets',assets)
        executed_binary=assets/binary.name if asset_root else binary
        assert executed_binary.is_file() and digest(executed_binary)==digest(binary)
        bundled=assets/'dora_godot.dll'
        bundled.unlink(missing_ok=True)
        if not missing:
            packaged=asset_root/'dora_godot.dll' if asset_root else None
            if a.use_bundled_library:
                assert packaged.is_file() and digest(packaged)==digest(library)
                shutil.copy2(packaged,bundled)
            else:shutil.copy2(library,bundled)
        notices={}
        for name in manifest['licenses']:
            relative=Path(name);assert not relative.is_absolute() and '..' not in relative.parts
            source=library.parent/relative;destination=assets/'GodotNotices'/relative
            destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,destination)
            assert digest(destination)==digest(source)
            notices[str(destination)]=digest(destination)
        project=assets/'GodotProject'
        shutil.copytree(root/str(test_path('Tools/Godot/tests/project')),project,ignore=shutil.ignore_patterns('.godot'))
        (project/'.godot').mkdir();(project/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
        code=template.read_text()
        # Each loader reports its native module-not-found status exactly.
        expected_error=('This Windows host was built for the Godot '+a.backend+' bridge' if mismatch else
            'cannot load Dora/Godot '+('D3D12 ' if a.backend=='D3D12' else '')+'runtime DLL, Win32 error 126')
        old='assert(godot.lastError:find(@LIBRARY_NAME@, 1, true))'
        if not mismatch:
            assert code.count(old)==1
            code=code.replace(old,'assert(godot.lastError == '+json.dumps(expected_error)+')')
        for key,value in [('OUTPUT',case.as_posix()),('PROJECT','GodotProject'),('LIBRARY_NAME',bundled.name),('EXPECTED_PROJECT_PATH',str(project)),('UNSUPPORTED_REASON',expected_error)]:code=code.replace('@'+key+'@',json.dumps(value))
        code=code.replace('@MISSING@','true' if missing else 'false')
        startup=assets/'Script/init.lua';startup.write_text(code)
        executed={str(path):digest(path) for path in (executed_binary,startup)}
        if not missing:executed[str(bundled)]=digest(bundled)
        projects={str(path):digest(path) for path in project.rglob('*') if path.is_file() and '.godot' not in path.parts}
        (case/'artifacts.json').write_text(json.dumps({'original':original,'executed':executed,'project':projects,'notices':notices,'fixture_sha256':digest(template)},indent=2)+'\n')
        env=os.environ.copy()
        for key in list(env):
            if key.startswith(('DORA_GODOT_','DORA_BUILD_')):env.pop(key)
        env.update(SDL_AUDIODRIVER='dummy',GODOT_SILENCE_ROOT_WARNING='1')
        if not mismatch:
            env['DORA_GODOT_WINDOWS_D3D12' if a.backend=='D3D12' else 'DORA_GODOT_WINDOWS_GL']='1'
            if a.warp:env['DORA_GODOT_D3D12_WARP']='1'
        started=time.monotonic()
        with (case/'run.log').open('w') as log:subprocess.run([str(executed_binary),'--asset',str(assets)],cwd=assets,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=90)
        runtime=time.monotonic()-started;log=(case/'run.log').read_text()
        assert 'GODOT_ORDINARY complete=1' in log
        assert 'GODOT_NODE_TEST' not in log and 'BGFX LEAK:' not in log and 'C++ objects leaks' not in log
        assert ('Godot Engine v' in log)!=bool(missing or mismatch)
        expected='unsupported_backend_rejected=1' if mismatch else 'missing_library_rejected=1' if missing else 'running=1'
        assert 'GODOT_ORDINARY '+expected in log
        errors=[line for line in log.splitlines() if '[error]' in line or 'ERROR:' in line]
        assert (len(errors)==1 and errors[0].endswith('GodotNode: '+expected_error)) if missing or mismatch else not errors,errors
        images=[Image.open(case/f'frame-{i}.png').convert('RGB') for i in (1,2)]
        assert images[0].size==images[1].size
        centers=[]
        for image in images:
            # Iterate RGB data once; preserve exact renderer-sized screenshots.
            green=[index%image.width for index,(r,g,b) in enumerate(pixels(image)) if g>220 and r<30 and b<30]
            assert len(green)>500,'Ordinary Dora green content missing'
            centers.append(sum(green)/len(green))
        assert centers[1]-centers[0]>100,centers
        changed=sum(max(pixel)>20 for pixel in pixels(ImageChops.difference(*images)));assert changed>1000
        clients=re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
        readers=re.findall(r'GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
        cpu_fences=re.findall(r'GodotRuntime D3D12 CPU fence: buffers=(\d+), waits=(\d+), produced=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
        if missing or mismatch:
            assert bundled.exists()==mismatch and not clients and not readers and not cpu_fences
        else:
            assert len(clients)==1
            assert all(int(p)>0 and p==c and e=='0' for p,c,e in clients)
            if a.backend=='D3D12':
                assert not readers and len(cpu_fences)==1 and 'DORA_GODOT_D3D12_CPU enabled' in log
                for b,w,p,c,e in cpu_fences:assert b=='3' and int(w)>0 and int(p)>0 and p==c==clients[0][0] and e=='0'
                if a.warp:assert 'DORA_GODOT_D3D12_WARP compat=shadows force_disable_shadows=1 force_vertex_shading=0' in log
            else:
                assert len(readers)==1 and not cpu_fences
                for b,f,w,s,pending,c,e in readers:assert b=='3' and int(f)>0 and 0<int(w)<=int(s) and int(s)==int(f)*3 and pending=='0' and f==c and e=='0'
            w,h=images[0].size;box=(round(w*.4),round(h*.3),round(w*.6),round(h*.7));crops=[im.crop(box) for im in images]
            assert all(sum(g>70 and b>70 and r<g*.65 for r,g,b in pixels(im))>100 for im in crops),'Godot cube missing'
            assert sum(max(pixel)>8 for pixel in pixels(ImageChops.difference(*crops)))>100,'Godot cube did not animate'
        assert all(digest(Path(path))==sha for path,sha in {**original,**executed,**projects,**notices}.items()),'Inputs changed during execution'
        cases.append({'case':case.name,'passed':True,'runtime_seconds':runtime,'captures':2,'ordinary_green_centers':centers,'changed_pixels':changed,'godot_started':not (missing or mismatch),'relative_project_lookup':not mismatch,'runtime_lookup':'Default assets path; no library override','runtime_origin':'input desktop package' if a.use_bundled_library else 'test staging copy','gpu_clients':clients,'gpu_readers':readers,'gpu_cpu_fences':cpu_fences,'artifacts':executed,'notices':notices,'images_sha256':{f'frame-{i}.png':digest(case/f'frame-{i}.png') for i in (1,2)}})
    (out/'verification.json').write_text(json.dumps({'passed':True,'platform':'Windows default renderer with '+a.backend+' runtime' if a.backend_mismatch_only else 'Windows '+a.backend,'scope':__doc__,'environment':a.environment,'graphics_backend':a.backend.lower(),'adapter_scope':'WARP software adapter' if a.warp and not a.backend_mismatch_only else 'default adapter; physical GPU unverified','synchronization_scope':'not exercised; Godot rejected before startup' if a.backend_mismatch_only else 'CPU fence; GPU reader fences untested' if a.backend=='D3D12' else 'GL reader fences','ordinary_host_without_test_entry':True,'backend_mismatch_only':a.backend_mismatch_only,'cases':cases},indent=2)+'\n')
    print('Ordinary Windows backend-mismatch fallback: PASS' if a.backend_mismatch_only else 'Ordinary Windows bundled-runtime and missing-library fallback: PASS')
except BaseException as error:
    (out/'verification.json').unlink(missing_ok=True)
    (out/'failure.json').write_text(json.dumps({'passed':False,'type':type(error).__name__,'error':str(error)},indent=2)+'\n');raise
