#!/usr/bin/env python3
"""Stage the shared pending-await fixture in an owned Dora Web Player."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

root = ENGINE_ROOT
p = argparse.ArgumentParser(description=__doc__)
for name in ('package', 'runtime-package', 'stage'):
    p.add_argument('--' + name, required=True, type=Path)
a = p.parse_args()
stage = a.stage.resolve()
stage.mkdir(parents=True, exist_ok=False)
fixture = Path(__file__).resolve().parents[1] / 'await_cleanup'
shutil.copytree(fixture, stage / 'godot')
cache = stage / 'godot/.godot'
cache.mkdir()
(cache / 'global_script_class_cache.cfg').write_text('list=[]\n')
(stage / 'init.lua').write_text('''local D = require("Dora")
D.App.devMode = false
local game = assert(D.GodotNode("/game/godot", "", 320, 240, 3))
game:addTo(D.Director.ui)
local control = D.Node()
control:addTo(D.Director.ui)
local ticks, elapsed = 0, 0
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 40, "Web await cleanup timed out")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if game and not game.running then return false end
 ticks = ticks + 1
 if ticks == 120 then game:removeFromParent(); game = nil end
 if ticks == 150 then
  print("AWAIT_CLEANUP host complete")
  print("DORA_WEB_AWAIT_DONE")
  D.App:shutdown()
  return true
 end
 return false
end)
''')
env = os.environ.copy()
env.update(DORA_WEB_GAME_PROFILE='core', DORA_WEB_EAGER_GAME_ASSETS='0', DORA_WEB_INCLUDE_GODOT_CACHE='1')
subprocess.run(['node', str(root / 'Projects/xmake/tools/web/package_web_game.mjs'), str(stage), str(a.package.resolve()), 'init.lua'], env=env, check=True)
runtime = a.runtime_package.resolve()
manifest = json.loads((runtime / 'manifest.json').read_text())
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
for name, digest in manifest['artifacts'].items():
    assert sha(runtime / name) == digest, name
target = a.package / 'godot'
target.mkdir(exist_ok=True)
for f in runtime.iterdir():
    if f.is_file():
        shutil.copy2(f, target / f.name)
metadata = {'fixture': {f.name: sha(f) for f in fixture.iterdir() if f.is_file()},
            'startup_sha256': sha(stage / 'init.lua'), 'runtime_manifest_sha256': sha(runtime / 'manifest.json')}
(a.package / 'await-source.json').write_text(json.dumps(metadata, indent=2) + '\n')
print('Staged canonical await cleanup fixture and sealed Web runtime')
