#!/usr/bin/env python3
"""Exercise the actual iOS framework's preboot ABI inside an explicit simulator."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = ENGINE_ROOT


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--udid', required=True)
    p.add_argument('--framework', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    framework = a.framework.resolve()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    manifest_path = framework.parent / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    assert manifest['passed'] and manifest['device'] == 'simulator', manifest
    library = framework / 'DoraGodot'
    library_hash = digest(library)
    assert library_hash == manifest['library_sha256']
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j'], text=True))
    device = next(d for group in devices['devices'].values() for d in group if d['udid'] == a.udid)
    assert device['state'] == 'Booted', 'Boot the explicit simulator first; this runner never starts or stops devices'
    source = Path(__file__).with_name('runtime_abi.cpp')
    binary = out / 'runtime_abi'
    command = ['xcrun', '--sdk', 'iphonesimulator', 'clang++', '-target', 'arm64-apple-ios14.0-simulator',
               '-std=c++17', '-Wall', '-Wextra', '-I' + str(ROOT / 'Source/Godot'), str(source), '-o', str(binary)]
    with (out / 'build.log').open('w') as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none', str(binary)],
                   check=True, capture_output=True)
    subprocess.run(['codesign', '--verify', '--strict', str(framework)], check=True, capture_output=True)
    spawn = ['xcrun', 'simctl', 'spawn', a.udid, str(binary), str(library)]
    result = subprocess.run(spawn, capture_output=True, text=True, timeout=60)
    (out / 'stdout.log').write_text(result.stdout)
    (out / 'stderr.log').write_text(result.stderr)
    assert result.returncode == 0, 'Native preboot ABI probe failed; inspect stdout.log/stderr.log'
    marker = 'DORA_IOS_ABI_JSON '
    records = [json.loads(line[len(marker):]) for line in result.stdout.splitlines() if line.startswith(marker)]
    assert len(records) == 1, 'Missing or ambiguous native result'
    report = records[0]
    assert report['passed'] and report['pointer_bits'] == 64 and report['gpu_tested'] is False
    assert len(report['checks']) >= 214, 'Incomplete native ABI guard coverage'
    assert digest(library) == library_hash, 'Runtime changed during acceptance'
    report.update(scope='Actual iOS simulator framework preboot C ABI/version/size/canary/invalid-handle/shutdown guards only; no Godot boot, GPU or physical-device acceptance',
                  udid=a.udid, device=device['name'], library_sha256=library_hash,
                  manifest_sha256=digest(manifest_path), source_sha256=digest(source),
                  probe_sha256=digest(binary), command=command, spawn=spawn)
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('iOS native ABI guards: PASS;', len(report['checks']), 'checks')


if __name__ == '__main__':
    main()
