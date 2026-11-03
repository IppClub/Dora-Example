#!/usr/bin/env python3
"""Exercise cancellation of pending GDScript awaits through an ordinary WGL host."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

p = argparse.ArgumentParser(description=__doc__)
for name in ('binary', 'library', 'asset-root', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
a = p.parse_args()
assert sys.platform == 'win32'
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
binary, library = a.binary.resolve(), a.library.resolve()
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
inputs = {str(path): digest(path) for path in (binary, library)}
assert b'dora_godot_node_test_main' not in binary.read_bytes(), 'Use an ordinary host'
shutil.copytree(a.asset_root, out / 'assets')
shutil.copytree(Path(__file__).with_name('await_cleanup'), out / 'project')
(out / 'project/.godot').mkdir()
(out / 'project/.godot/global_script_class_cache.cfg').write_text('list=[]\n', encoding='utf-8')
code = '''local D = Dora
D.App.devMode = false
local game = assert(D.GodotNode(@PROJECT@, "", 320, 240, 3))
game:addTo(D.Director.ui)
local control = D.Node()
control:addTo(D.Director.ui)
local ticks, elapsed = 0, 0
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 30, "Pending await cleanup timed out")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if game and not game.running then return false end
 ticks = ticks + 1
 if ticks == 120 then game:removeFromParent(); game = nil end
 if ticks == 150 then
  print("AWAIT_CLEANUP host complete")
  D.App:shutdown()
  return true
 end
 return false
end)
'''.replace('@PROJECT@', json.dumps(str(out / 'project')))
(out / 'assets/Script/init.lua').write_text(code, encoding='utf-8')
fixture = {str(path.relative_to(out)): digest(path) for path in (out / 'project').rglob('*') if path.is_file()}
env = {k: v for k, v in os.environ.items() if not k.startswith(('DORA_GODOT_', 'DORA_BUILD_'))}
env.update(DORA_GODOT_WINDOWS_GL='1', DORA_GODOT_GL_DIRECT='1',
           DORA_GODOT_LIBRARY=str(library), SDL_AUDIODRIVER='dummy', GODOT_SILENCE_ROOT_WARNING='1')
with (out / 'run.log').open('w', encoding='utf-8') as log:
    result = subprocess.run([str(binary), '--asset', str(out / 'assets')],
                            cwd=binary.parent, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60)
(out / 'process-result.json').write_text(json.dumps({'returncode': result.returncode, 'inputs': inputs,
                                                    'fixture': fixture}, indent=2), encoding='utf-8')
assert result.returncode == 0, result.returncode
assert all(digest(Path(path)) == value for path, value in inputs.items()), 'Inputs changed'
log = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
assert log.count('AWAIT_CLEANUP armed') == 2
assert 'AWAIT_CLEANUP child freed; root pending until shutdown' in log
assert 'AWAIT_CLEANUP host complete' in log
for token in ('WARNING:', 'ERROR:', '[error]', 'Leaked instance:', 'Orphan StringName:', 'BGFX LEAK:'):
    assert token not in log, token
assert 'AWAIT_CLEANUP unexpectedly resumed' not in log
(out / 'verification.json').write_text(json.dumps({'passed': True, 'inputs': inputs,
    'pending_awaits': 2, 'scope': 'Instance cancellation and scene shutdown with pending 600-second timers; WGL ordinary host'}, indent=2), encoding='utf-8')
print('Pending await cleanup passed')
