#!/usr/bin/env python3
"""Exercise the production Lua failure handler and staging implementation."""
import os, sys, subprocess, tempfile
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
from lua_tools import call
module = SimpleNamespace(stage=lambda *args: call('Tools.Godot.build_component','stage',*args))
with tempfile.TemporaryDirectory(prefix='dora-component-error-') as temporary:
    directory = Path(temporary)
    text = '\n'.join(f'old line {i}' for i in range(250))+'\ncompiler fatal error: fixture 🏗\n'
    for name in ('build.log','link.log'): (directory/name).write_text(text, encoding='utf-8')
    result = subprocess.run([os.environ.get('DORA_XMAKE','xmake'),'lua',str(Path(__file__).with_suffix('.lua')),str(ENGINE_ROOT),str(directory)],capture_output=True)
    assert result.returncode == 0, result.stdout+result.stderr
    output = result.stdout.decode('utf-8')
    assert output.count('compiler fatal error: fixture 🏗') == 2
    assert 'old line 0\n' not in output and 'old line 249\n' in output
    assert output.count('Godot compiler log:') == 2
print('PASS bounded UTF-8 Lua compiler log tails, link/build paths, missing logs and preserved failures')

# Exercise production staging: SDK provenance is not necessarily a license.
with tempfile.TemporaryDirectory(prefix='dora-component-sidecars-') as temporary:
    base = Path(temporary)
    package = base / 'package'; package.mkdir()
    (package / 'libdora_godot.so').write_bytes(b'fixture native library')
    (package / 'LICENSE.txt').write_text('fixture license')
    (package / 'SDK-PROVENANCE.json').write_text('{"version":"fixture"}')
    (package / 'manifest.json').write_text('{"fixture":true}')
    metadata = {'library': 'libdora_godot.so', 'licenses': ['LICENSE.txt'],
                'dependency_provenance': ['SDK-PROVENANCE.json'],
                'artifacts': {'libdora_godot.so': '', 'LICENSE.txt': '', 'SDK-PROVENANCE.json': ''}}
    for platform in ('linux', 'macosx', 'windows'):
        target = base / platform
        assert module.stage(package, target, platform, metadata)
        assert (target / 'GodotRuntimeNotices/SDK-PROVENANCE.json').read_bytes() == (package / 'SDK-PROVENANCE.json').read_bytes()
        assert not (target / 'GodotRuntimeNotices/libdora_godot.so').exists()
        assert not module.stage(package, target, platform, metadata), 'Unchanged inputs must remain incremental'
    jni = package / 'jni/arm64-v8a'; jni.mkdir(parents=True)
    (jni / 'libdora_godot.so').write_bytes(b'fixture JNI payload')
    metadata['artifacts']['jni/arm64-v8a/libdora_godot.so'] = ''
    target = base / 'android'
    assert module.stage(package, target, 'android', metadata)
    assert (target / 'GodotRuntimeNotices/SDK-PROVENANCE.json').is_file()
    assert not (target / 'GodotRuntimeNotices/jni').exists()
print('PASS production component sidecars, incremental staging and JNI payload isolation')
