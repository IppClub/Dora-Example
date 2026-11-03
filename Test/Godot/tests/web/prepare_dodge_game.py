#!/usr/bin/env python3
"""Stage the audited unchanged official project in a real Dora Web Player."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,hashlib,json,os,shutil,subprocess,zipfile
from pathlib import Path
root=ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__)
for name in ('package','runtime-package','source-bundle','stage'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();stage=a.stage.resolve();assert not stage.exists(),'Preserve previous staged input'
metadata=json.loads((a.source_bundle/'GodotDodge.json').read_text());archive=a.source_bundle/'GodotDodge.zip'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==metadata['archive_sha256']
with zipfile.ZipFile(archive) as z:
    assert b'worker_pool/max_threads' not in z.read('project.godot'),'Regression must exercise the default worker pool'
    hashes={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist()}
    assert hashes==metadata['packed_files']
    assert {n:h for n,h in hashes.items() if not n.startswith('.godot/')}==metadata['upstream_project_files']
stage.mkdir(parents=True)
shutil.copy2(archive,stage/'GodotDodge.zip')
source=root/str(test_path('Tools/Godot/tests/android/dodge_release.lua'));lua=source.read_text()
lua=lua.replace('print("DORA_DODGE capture=" .. name)','print("DORA_DODGE capture=" .. name)\n\t\tprint("DORA_WEB_NODE_CAPTURE " .. name .. " frame=" .. ticks)')
lua=lua.replace('print("DORA_DODGE complete=1 captures=12 ticks=625")','print("DORA_DODGE complete=1 captures=12 ticks=625")\n\t\tprint("DORA_WEB_NODE_DONE frames=625 aliases=0")')
lua=lua.replace('C:copy("GodotDodge.zip", archive)','C:copy("/game/GodotDodge.zip", archive)')
(stage/'init.lua').write_text('''-- DORA_WEB_NODE_DONE: completed by the audited Dodge controller.
local D = require("Dora")
local work = D.Path(D.Content.writablePath, "godot-release")
if not D.Content:exist(work) then assert(D.Content:mkdir(work)) end
'''+lua)
metadata['controller_source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
metadata['web_controller_sha256']=hashlib.sha256((stage/'init.lua').read_bytes()).hexdigest()
env=os.environ.copy();env.update(DORA_WEB_GAME_PROFILE='core',DORA_WEB_EAGER_GAME_ASSETS='1')
subprocess.run(['node',str(root/'Projects/xmake/tools/web/package_web_game.mjs'),str(stage),str(a.package.resolve()),'init.lua'],env=env,check=True)
runtime=a.runtime_package.resolve();m=json.loads((runtime/'manifest.json').read_text())
for name,digest in m['artifacts'].items():assert hashlib.sha256((runtime/name).read_bytes()).hexdigest()==digest,name
target=a.package/'godot';target.mkdir(exist_ok=True)
for f in runtime.iterdir():
    if f.is_file():shutil.copy2(f,target/f.name)
(a.package/'dodge-source.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Staged unchanged official project and its generated cache; runtime hashes verified.')
