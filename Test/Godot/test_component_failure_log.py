#!/usr/bin/env python3
"""Failed production component builders expose bounded compiler diagnostics."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

root = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd()))
sys.path.insert(0, str(root / 'Tools/Godot'))
spec = importlib.util.spec_from_file_location('production_component', root / 'Tools/Godot/build_component.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory(prefix='dora-component-error-') as temporary:
    build = Path(temporary)
    (build / 'build.log').write_text('\n'.join(f'old line {i}' for i in range(250))
                                  + '\ncompiler fatal error: fixture \U0001f3d7\n')
    (build / 'link.log').write_bytes((build / 'build.log').read_bytes())
    error = subprocess.CalledProcessError(17, ['fixture-builder'])
    for script, arguments, env in [
        ('build_linux_runtime.sh', (), {'DORA_GODOT_BUILD_DIR': str(build)}),
        ('build_windows_runtime.py', ('--build-dir', build), {}),
        ('build_android_runtime.py', ('--build-dir', build), {'DORA_GODOT_BUILD_DIR': '/unused'}),
        ('link_ios_runtime.py', ('--build-dir', build), {}),
    ]:
        output = io.StringIO()
        with patch.object(module.subprocess, 'run', side_effect=error), contextlib.redirect_stderr(output):
            try:
                module.run(script, *arguments, env=env)
            except subprocess.CalledProcessError as caught:
                assert caught is error
            else:
                raise AssertionError('Failure must remain a failure')
        text = output.getvalue()
        assert 'compiler fatal error: fixture \U0001f3d7' in text
        assert 'old line 0\n' not in text
        assert len(text.splitlines()) == 181
    raw = io.BytesIO()
    legacy_stderr = io.TextIOWrapper(raw, encoding='cp1252')
    with patch.object(module.subprocess, 'run', side_effect=error), contextlib.redirect_stderr(legacy_stderr):
        try:
            module.run('build_windows_runtime.py', '--build-dir', build)
        except subprocess.CalledProcessError as caught:
            assert caught is error
        else:
            raise AssertionError('Legacy stderr must preserve the compiler failure')
    assert 'compiler fatal error: fixture \U0001f3d7' in raw.getvalue().decode('utf-8')
    output = io.StringIO()
    with patch.object(module.subprocess, 'run', side_effect=error), contextlib.redirect_stderr(output):
        try:
            module.run('build_web_runtime.py', '--build-dir', build / 'missing')
        except subprocess.CalledProcessError as caught:
            assert caught is error
        else:
            raise AssertionError('Missing log must not hide the original failure')
    assert output.getvalue() == ''
print('PASS component failure log tails, output limit, platform paths and original exit status')
