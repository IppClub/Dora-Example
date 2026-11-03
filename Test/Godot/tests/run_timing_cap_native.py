#!/usr/bin/env python3
"""Exercise the capped-clock contract through an ordinary Dora native host."""

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
p.add_argument('--emulator', type=Path)
p.add_argument('--engine-readback', action='store_true', help='Exercise Godot ViewportTexture.get_image() instead of the host capture API')
p.add_argument('--buffers', type=int, choices=(2, 3, 4), default=3)
p.add_argument('--resize', action='store_true', help='Resize after the first Godot readback and verify the second image dimensions')
a = p.parse_args()
assert not a.resize or a.engine_readback
assert sys.platform in ('darwin', 'linux', 'win32')
assert not a.emulator or sys.platform == 'linux'
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
tests = Path(__file__).resolve().parent
shutil.copytree(tests / 'timing_cap_project', out / 'project')
cache = out / 'project/.godot'
cache.mkdir(exist_ok=True)
(cache / 'global_script_class_cache.cfg').write_text('list=[]\n', encoding='utf-8')
shutil.copytree(a.asset_root, out / 'assets')
code = (tests / 'timing_cap.lua').read_text(encoding='utf-8')
code = code.replace('@ENGINE_READBACK@', 'true' if a.engine_readback else 'false')
code = code.replace('@BUFFERS@', str(a.buffers)).replace('@RESIZE@', 'true' if a.resize else 'false')
for key, value in {'PROJECT': out / 'project', 'OUTPUT': out,
                   'RESULT': out / 'result.json'}.items():
    code = code.replace('@' + key + '@', json.dumps(str(value)))
(out / 'assets/Script/init.lua').write_text(code, encoding='utf-8')
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
binary, library = a.binary.resolve(), a.library.resolve()
assert b'dora_godot_node_test_main' not in binary.read_bytes()
paths = [binary, library]
if a.emulator:
    paths.append(a.emulator.resolve())
inputs = {str(path): sha(path) for path in paths}
fixture = {str(f.relative_to(out / 'project')): sha(f)
           for f in (out / 'project').rglob('*') if f.is_file()}
env = {k: v for k, v in os.environ.items()
       if not k.startswith(('DORA_GODOT_', 'DORA_BUILD_', 'DORA_TIMING_CAP_'))}
env.update(DORA_GODOT_LIBRARY=str(library), DORA_GODOT_GL_DIRECT='1',
           DORA_TIMING_CAP_HOST_CAPTURE='0' if a.engine_readback else '1', DORA_TIMING_CAP_OUTPUT=str(out),
           SDL_AUDIODRIVER='dummy')
if sys.platform == 'darwin':
    env['MTL_DEBUG_LAYER'] = '1'
elif sys.platform == 'win32':
    env['DORA_GODOT_WINDOWS_GL'] = '1'
command = ([str(a.emulator.resolve())] if a.emulator else []) + [str(binary), '--asset', str(out / 'assets')]
with (out / 'run.log').open('w', encoding='utf-8') as log:
    process = subprocess.run(command, cwd=binary.parent, env=env,
                             stdout=log, stderr=subprocess.STDOUT, timeout=90)
(out / 'process-result.json').write_text(json.dumps(dict(
    returncode=process.returncode, command=command, inputs=inputs, fixture=fixture,
    execution_mode='explicit userspace emulator' if a.emulator else 'direct execution',
    host_capture_pixel_exact=not a.engine_readback,
    graphics_backend='wgl' if sys.platform == 'win32' else 'metal' if sys.platform == 'darwin' else 'egl'), indent=2), encoding='utf-8')
assert process.returncode == 0
assert all(sha(Path(name)) == digest for name, digest in inputs.items())
if a.resize:
    metadata = json.loads((out / 'result.json').read_text(encoding='utf-8'))
    assert (metadata['clock-a']['width'], metadata['clock-a']['height']) == (640, 360)
    assert (metadata['clock-b']['width'], metadata['clock-b']['height']) == (800, 450)
subprocess.run([sys.executable, str(tests / 'verify_timing_cap.py'), str(out),
                '--engine-readback' if a.engine_readback else '--host-capture',
                '--buffers', str(a.buffers)], check=True)
