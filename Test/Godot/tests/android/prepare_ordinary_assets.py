#!/usr/bin/env python3
"""Stage every ordinary Android Release QA input without modifying source assets."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,hashlib,json,shutil,sys,zipfile
from pathlib import Path
ROOT=ENGINE_ROOT
sys.path.insert(0,str(ROOT/str(test_path('Tools/Godot/tests/bindings'))))
from object_ownership_fixture import fixture
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
p.add_argument('--dodge-project',type=Path)
p.add_argument('--dodge-baseline',type=Path,help='Previously audited upstream artifacts.json with source-file hashes')
p.add_argument('--await-cleanup',action='store_true',help='Stage pending-await cancellation/Activity shutdown fixture instead of the ordinary animation controller')
p.add_argument('--engine-readback',action='store_true',help='Stage canonical Godot get_image clock/resize fixture')
a=p.parse_args();out=a.output.resolve();assert not out.exists(),'Use a fresh assets directory'
assert bool(a.dodge_project)==bool(a.dodge_baseline),'Supply both Dodge project and baseline'
assert sum((a.await_cleanup,a.engine_readback,bool(a.dodge_project)))<=1,'Choose one fixture'
shutil.copytree(ROOT/'Assets',out)
(out/'Script/init.lua').write_bytes(Path(__file__).with_name('ordinary_release.lua').read_bytes())
for target,source in [('GodotProject',Path(__file__).with_name('release_project')),
                      ('GodotProjectFull',ROOT/str(test_path('Tools/Godot/tests/project')))]:
    # The readback startup runs GodotTimingCap, not the optional ordinary fixture.
    if target=='GodotProject' and a.engine_readback:continue
    shutil.copytree(source,out/target,ignore=shutil.ignore_patterns('.godot'))
(out/'ffi-trap.wasm').write_bytes(fixture())
if a.dodge_project:
    project=a.dodge_project.resolve();baseline=json.loads(a.dodge_baseline.read_text())
    actual={str(f.relative_to(project)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(project.rglob('*')) if f.is_file() and '.godot' not in f.relative_to(project).parts}
    assert actual==baseline['upstream_project_files'],'Upstream project differs from audited baseline'
    assert baseline['upstream_repository']=='https://github.com/godotengine/godot-demo-projects'
    assert baseline['upstream_project']=='2d/dodge_the_creeps'
    assert (project/'.godot/imported').is_dir(),'Use an already imported upstream project'
    archive=out/'GodotDodge.zip'
    packed={}
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted(project.rglob('*')):
            if not f.is_file():continue
            relative=f.relative_to(project)
            if '.godot' in relative.parts and not (relative.parts[:2]==('.godot','imported') or str(relative) in ('.godot/global_script_class_cache.cfg','.godot/uid_cache.bin','.godot/scene_groups_cache.cfg')):continue
            data=f.read_bytes();info=zipfile.ZipInfo(str(relative));info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data);packed[str(relative)]=hashlib.sha256(data).hexdigest()
    metadata={'upstream_repository':baseline['upstream_repository'],'upstream_project':baseline['upstream_project'],'upstream_commit':baseline['upstream_commit'],'upstream_project_files':actual,'baseline_sha256':hashlib.sha256(a.dodge_baseline.read_bytes()).hexdigest(),'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'packed_files':packed,'scope':'Source identical to previously audited Git baseline; generated import cache is separate'}
    (out/'GodotDodge.json').write_text(json.dumps(metadata,indent=2)+'\n')
    shutil.copy2(Path(__file__).with_name('dodge_release.lua'),out/'Script/GodotDodgeRelease.lua')
if a.await_cleanup:
    shutil.copytree(ROOT/str(test_path('Tools/Godot/tests/await_cleanup')),out/'GodotAwaitCleanup')
    shutil.copy2(Path(__file__).with_name('await_cleanup.lua'),out/'Script/init.lua')
if a.engine_readback:
    shutil.copytree(ROOT/str(test_path('Tools/Godot/tests/timing_cap_project')),out/'GodotTimingCap')
    for source in Path(__file__).with_name('timing_cap_adapter').iterdir():
        if source.is_file():shutil.copy2(source,out/'GodotTimingCap'/source.name)
    shutil.copy2(Path(__file__).with_name('timing_cap.lua'),out/'Script/init.lua')
files=[out/'Script/init.lua',out/'ffi-trap.wasm',*(out/'GodotProject').rglob('*'),*(out/'GodotProjectFull').rglob('*')]
if a.await_cleanup:files.extend((out/'GodotAwaitCleanup').rglob('*'))
if a.engine_readback:files.extend((out/'GodotTimingCap').rglob('*'))
manifest={'prepared':True,'assets':str(out),'fixture_files':{str(f.relative_to(out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(files) if f.is_file()},'scope':'QA assets only; not APK or runtime acceptance'}
out.with_name(out.name+'-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out)
