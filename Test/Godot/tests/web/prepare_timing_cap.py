#!/usr/bin/env python3
"""Package the canonical capped-clock fixture with a Web-only startup adapter."""

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
p.add_argument('--buffers', type=int, choices=(2, 3, 4), required=True)
p.add_argument('--host-shutdown', action='store_true', help='Probe same-frame node removal followed by Lua App.shutdown')
a = p.parse_args()
stage = a.stage.resolve()
stage.mkdir(parents=True, exist_ok=False)
fixture = Path(__file__).resolve().parents[1] / 'timing_cap_project'
shutil.copytree(fixture, stage / 'godot')
cache = stage / 'godot/.godot'
cache.mkdir()
(cache / 'global_script_class_cache.cfg').write_text('list=[]\n', encoding='utf-8')
# Keep the canonical project/scene/script unchanged; set the native fixture's
# environment before its inherited _ready(), using the ordinary Godot OS API.
(stage / 'godot/web_timing_cap.gd').write_text('''extends "res://main.gd"
func _init() -> void:
    OS.set_environment("DORA_TIMING_CAP_OUTPUT", "/game/godot")
    OS.set_environment("DORA_TIMING_CAP_HOST_CAPTURE", "0")
''', encoding='utf-8')
(stage / 'godot/web_timing_cap.tscn').write_text('''[gd_scene load_steps=3 format=3]
[ext_resource type="PackedScene" path="res://main.tscn" id="1"]
[ext_resource type="Script" path="res://web_timing_cap.gd" id="2"]
[node name="Main" instance=ExtResource("1")]
script = ExtResource("2")
''', encoding='utf-8')
startup = '''local D = require("Dora")
D.App.devMode = false
local game = assert(D.GodotNode("/game/godot", "res://web_timing_cap.tscn", 640, 360, @BUFFERS@))
game:addTo(D.Director.ui)
local control = D.Node()
control:addTo(D.Director.ui)
local elapsed, resized, closing = 0, false, 0
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 45, "Web readback timeout")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if not resized and D.Content:exist("/user/cap-a.ready") then
  assert(game:resizeViewport(800, 450))
  resized = true
 end
 if D.Content:exist("/user/cap.done") then
  assert(resized)
  if game then game:removeFromParent(); game = nil end
  closing = closing + 1
  if closing == 30 then
   print("TIMING_CAP host complete DORA_WEB_CAP_DONE")
   return true
  end
 end
 return false
end)
'''.replace('@BUFFERS@', str(a.buffers))
if a.host_shutdown:
    startup = startup.replace('closing == 30', 'closing == 1').replace(
        'print("TIMING_CAP host complete DORA_WEB_CAP_DONE")',
        'print("TIMING_CAP host complete DORA_WEB_CAP_DONE")\n   D.App:shutdown()')
(stage / 'init.lua').write_text(startup, encoding='utf-8')
env = os.environ.copy()
env.update(DORA_WEB_GAME_PROFILE='core', DORA_WEB_EAGER_GAME_ASSETS='1', DORA_WEB_INCLUDE_GODOT_CACHE='1')
subprocess.run(['node', str(root / 'Projects/xmake/tools/web/package_web_game.mjs'),
                str(stage), str(a.package.resolve()), 'init.lua'], env=env, check=True)
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
metadata = dict(buffers=a.buffers, host_shutdown=a.host_shutdown, fixture={f.name: sha(f) for f in fixture.iterdir() if f.is_file()},
                adapters={f.name: sha(f) for f in (stage / 'godot').glob('web_timing_cap.*')},
                startup_sha256=sha(stage / 'init.lua'), runtime_manifest_sha256=sha(runtime / 'manifest.json'))
(a.package / 'timing-cap-source.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
