#!/usr/bin/env python3
"""Linux EGL functional buffer matrix and clock parity, with explicit emulation support."""

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
import subprocess
import sys

root = ENGINE_ROOT
p = argparse.ArgumentParser(description=__doc__)
for name in ('binary', 'runtime-package', 'results'):
    p.add_argument('--' + name, required=True, type=Path)
p.add_argument('--environment', required=True, choices=('native', 'virtual-machine'))
p.add_argument('--emulator', type=Path)
p.add_argument('--abi-python', type=Path)
p.add_argument('--abi-python-home', type=Path)
p.add_argument('--physics-catchup-reference', type=Path, help='Audited upstream capped-clock contract; strict clock parity remains the default')
p.add_argument('--scenarios', nargs='+', choices=('2', '3', '4', 'soak', 'timing'),
               default=('2', '3', '4', 'soak', 'timing'), help='Explicit cases for a retained-evidence follow-up; omitted cases remain unverified by this invocation')
a = p.parse_args()
assert len(set(a.scenarios)) == len(a.scenarios), 'Duplicate scenarios'
assert sys.platform == 'linux'
assert bool(a.emulator) == bool(a.abi_python) == bool(a.abi_python_home)
binary, package, out = a.binary.resolve(), a.runtime_package.resolve(), a.results.resolve()
out.mkdir(parents=True, exist_ok=False)
manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
assert manifest['graphics_backend'] == 'egl'
library = package / manifest['library']
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
inputs = {str(path): digest(path) for path in (binary, library)}
for path in (a.emulator, a.abi_python):
    if path:
        inputs[str(path.resolve())] = digest(path)
assert b'dora_godot_node_test_main' in binary.read_bytes(), 'Use a test host'
subprocess.run([os.environ.get('DORA_XMAKE','xmake'), 'lua', str(root / 'Tools/Godot/verify_package.lua'), str(package),
                '--output', str(out / 'package-integrity.json')], check=True)
reports = []
for scenario in a.scenarios:
    env = {k: v for k, v in os.environ.items() if not k.startswith(('DORA_GODOT_', 'DORA_BUILD_'))}
    case = out / scenario
    env.update(DORA_GODOT_GL_DIRECT='1', DORA_GODOT_SKIP_BUILD='1',
               DORA_GODOT_DORA_BINARY=str(binary), DORA_GODOT_LIBRARY=str(library),
               DORA_GODOT_NODE_RESULTS=str(case), DORA_GODOT_TEST_BUFFERS=scenario if scenario.isdigit() else '3',
               DORA_GODOT_RESOURCE_METRICS=str(case / 'resource-metrics.json'))
    if a.emulator:
        env.update(DORA_GODOT_TEST_EMULATOR=str(a.emulator.resolve()),
                   DORA_GODOT_ABI_PYTHON=str(a.abi_python.resolve()),
                   DORA_GODOT_ABI_PYTHONHOME=str(a.abi_python_home.resolve()))
    if scenario == 'timing':
        env.update(DORA_GODOT_TEST_TIMING='1', DORA_GODOT_TEST_PROJECT=str(root / str(test_path('Tools/Godot/tests/timing_project'))))
        if a.physics_catchup_reference:
            env['DORA_GODOT_TIMING_CATCHUP_REFERENCE'] = str(a.physics_catchup_reference.resolve())
    elif scenario == 'soak':
        env.update(DORA_GODOT_TEST_AUDIO='1', DORA_GODOT_TEST_SOAK_FRAMES='300')
    else:
        env.update({f'DORA_GODOT_TEST_{flag}': '1' for flag in
                    ('AUDIO', 'RESIZE', 'CANCEL_RESIZE', 'RESERVATION', 'AUDIO_STALL', 'ALIASES', 'CONTROLLER')})
    command = [sys.executable, str(root / str(test_path('Tools/Godot/tests/with_weston.py'))),
               '--logs', str(out / (scenario + '-weston'))]
    if a.emulator:
        command += ['--timeout', '660']
    command += ['--', '/bin/bash', str(root / str(test_path('Tools/Godot/test_linux.sh')))]
    (out / (scenario + '-command.json')).write_text(json.dumps({'command': command,
        'environment': {k: v for k, v in env.items() if k.startswith('DORA_GODOT_')}}, indent=2), encoding='utf-8')
    with (out / (scenario + '-driver.log')).open('w', encoding='utf-8') as log:
        subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=700)
    report_path = case / 'verification.json'
    report = json.loads(report_path.read_text(encoding='utf-8'))
    abi = json.loads((case / 'abi-preboot/verification.json').read_text(encoding='utf-8'))
    assert report['passed'] and abi['passed'] and abi['library_sha256'] == inputs[str(library)]
    assert all(digest(Path(path)) == value for path, value in inputs.items()), 'Inputs changed'
    report.update(runtime_library_sha256=inputs[str(library)], host_executable_sha256=inputs[str(binary)],
                  runtime_environment=a.environment, runtime_package_backend='egl',
                  execution_mode='explicit userspace emulator' if a.emulator else 'direct execution')
    report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    reports.append({'scenario': scenario, 'report_sha256': digest(report_path), 'abi_checks': len(abi['checks'])})
(out / 'verification.json').write_text(json.dumps({'passed': True, 'reports': reports, 'inputs': inputs,
    'scenarios': list(a.scenarios),
    'environment': a.environment, 'execution_mode': 'explicit userspace emulator' if a.emulator else 'direct execution',
    'scope': 'Only the explicitly listed functional/timing cases; renderer in raw logs; real project and ordinary fallback separate'}, indent=2), encoding='utf-8')
print('Linux EGL matrix passed')
