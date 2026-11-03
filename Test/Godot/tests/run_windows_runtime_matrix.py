#!/usr/bin/env python3
"""Run Windows WGL or D3D12 buffer coverage and a separate clock-parity test."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = ENGINE_ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-package', required=True, type=Path)
    parser.add_argument('--results', required=True, type=Path)
    parser.add_argument('--environment', required=True, choices=['native', 'virtual-machine'])
    parser.add_argument('--backend', choices=['WGL', 'D3D12'], default='WGL')
    parser.add_argument('--warp', action='store_true', help='D3D12 software adapter only')
    args = parser.parse_args()
    if args.warp and args.backend != 'D3D12':
        parser.error('--warp requires --backend D3D12')
    assert sys.platform == 'win32', 'Actual Windows execution required'
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=False)
    base = [sys.executable, str(ROOT/str(test_path('Tools/Godot/test_windows.py'))), '--skip-build',
            '--backend', args.backend, '--runtime-package', str(args.runtime_package.resolve()),
            '--environment', args.environment]
    if args.warp:
        base.append('--warp')
    reports = []
    scenarios = [(str(buffers), ['--buffers', str(buffers), '--audio', '--resize',
                  '--cancel-resize', '--reservation', '--audio-stall', '--aliases',
                  '--ime', '--controller']) for buffers in (2, 3, 4)]
    scenarios.append(('soak', ['--buffers', '3', '--audio', '--soak-frames', '300']))
    # --timing selects a separate fixture/verifier, so it must not replace the
    # functional matrix's ordinary verify_macos.py acceptance.
    scenarios.append(('timing', ['--buffers', '3', '--timing', '--project',
                                str(ROOT/str(test_path('Tools/Godot/tests/timing_project')))]))
    for name, options in scenarios:
        output = results/name
        command = base + ['--results', str(output)] + options
        (results/(name+'-command.json')).write_text(json.dumps(command, indent=2))
        with (results/(name+'-driver.log')).open('w') as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        report = json.loads((output/'verification.json').read_text())
        assert report.get('passed') is True, (name, report)
        assert report.get('runtime_package_backend') == args.backend.lower(), (name, report)
        assert report.get('runtime_environment') == args.environment, (name, report)
        reports.append({'scenario': name, 'report': str(output/'verification.json'),
                        'runtime_library_sha256': report['runtime_library_sha256']})
    (results/'verification.json').write_text(json.dumps({
        'passed': True, 'environment': args.environment, 'reports': reports,
        'graphics_backend': args.backend.lower(),
        'adapter_scope': 'WARP software adapter' if args.warp else 'default adapter; physical hardware unverified',
        'synchronization_scope': 'CPU fence' if args.backend == 'D3D12' else 'GL transport',
        'scope': 'Functional 2/3/4 buffer matrix and separate timing; real-project acceptance recorded separately'
    }, indent=2)+'\n')


if __name__ == '__main__':
    main()
