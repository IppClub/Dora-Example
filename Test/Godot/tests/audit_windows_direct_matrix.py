#!/usr/bin/env python3
"""Audit retained Windows WGL matrix reports and actual direct-target logs."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import re


def audit(results):
    aggregate = json.loads((results/'verification.json').read_text())
    assert aggregate['passed'] is True
    records = []
    runtime_hashes = set()
    for name, buffers, lifecycles in [('2',2,2), ('3',3,2), ('4',4,2), ('soak',3,2), ('timing',3,1)]:
        report_path = results/name/'verification.json'
        report = json.loads(report_path.read_text())
        assert report['passed'] is True, name
        abi_path = results/name/'abi-preboot/verification.json'
        abi = json.loads(abi_path.read_text())
        assert abi['passed'] is True and abi['backend'] == 'WGL' and abi['system'] == 'Windows', name
        assert abi['process_pointer_bits'] == 64, name
        runtime_hashes.add(abi['library_sha256'])
        if name != 'timing':
            assert report['runtime_architecture'] == 'x86_64', name
            assert report['runtime_environment'] == aggregate['environment'], name
            assert report['runtime_library_sha256'] == abi['library_sha256'], name
        log_path = results/name/'run.log'
        log = log_path.read_text(encoding='utf-8', errors='replace')
        bindings = re.findall(r'DORA_GODOT_GL_DIRECT enabled buffers=(\d+) size=(\d+)x(\d+) blits=(\d+)', log)
        completions = re.findall(r'DORA_GODOT_GL_DIRECT completed frames=(\d+) blits=(\d+)', log)
        assert len(bindings) >= lifecycles, (name, bindings)
        assert all(int(b)==buffers and int(w)>0 and int(h)>0 and int(blit)==0 for b,w,h,blit in bindings), name
        assert len(completions) == lifecycles, (name, completions)
        assert all(int(frames)>100 and int(blits)==0 for frames,blits in completions), name
        records.append({'scenario': name, 'bindings': len(bindings), 'completions': completions,
                        'report_sha256': hashlib.sha256(report_path.read_bytes()).hexdigest(),
                        'abi_report_sha256': hashlib.sha256(abi_path.read_bytes()).hexdigest(),
                        'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest()})
    assert len(runtime_hashes) == 1, runtime_hashes
    return {'passed': True, 'scope': 'Retained WGL direct-target logs and passed buffer/soak/timing reports',
            'environment': aggregate['environment'], 'runtime_sha256': next(iter(runtime_hashes)),
            'steady_state_blits': 0, 'scenarios': records}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve previous audit reports'
    report = audit(args.results)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
