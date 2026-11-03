#!/usr/bin/env python3
"""Check rejection of altered real Jolt source, notices and provenance inputs."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import json
from pathlib import Path
import shutil
import tempfile

from verify_jolt_source import FOLDER, sha, verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence path'
    baseline = verify(args.archive)
    rejected = []
    cases = {
        'source-changed': 'Vendor Jolt input differs',
        'license-missing': 'Retained Jolt inventory differs',
        'extra-source': 'Retained Jolt inventory differs',
        'marker-changed': 'Local Jolt version marker differs',
        'upstream-commit-changed': 'Unexpected upstream commit',
        'metadata-and-source-changed': 'Upstream digest differs',
        'source-symlink': 'Symlink in retained source tree',
        'wrong-archive': 'Unrecognized Jolt archive',
    }
    with tempfile.TemporaryDirectory(prefix='dora-jolt-source-') as temp:
        for case, expected in cases.items():
            folder = Path(temp) / case
            shutil.copytree(FOLDER, folder, ignore=shutil.ignore_patterns('.xmake'))
            archive = args.archive
            source = folder / 'Jolt/Core/Core.h'
            if case == 'source-changed':
                source.write_bytes(source.read_bytes() + b'\n/* invalid fixture */\n')
            elif case == 'license-missing':
                (folder / 'LICENSE').unlink()
            elif case == 'extra-source':
                (folder / 'Jolt/unknown.cpp').write_text('int unknown;\n')
            elif case == 'marker-changed':
                (folder / 'JOLT_VERSION.txt').write_text('v5.4.0\nwrong\n')
            elif case in ('upstream-commit-changed', 'metadata-and-source-changed'):
                metadata = folder / 'UPSTREAM.json'
                record = json.loads(metadata.read_text())
                if case == 'upstream-commit-changed':
                    record['identified_equivalent_commit'] = '0' * 40
                else:
                    source.write_bytes(source.read_bytes() + b'\n/* invalid fixture */\n')
                    entry = next(row for row in record['files'] if row['path'] == 'Jolt/Core/Core.h')
                    entry['vendor_sha256'] = entry['upstream_sha256'] = sha(source.read_bytes())
                metadata.write_text(json.dumps(record))
            elif case == 'source-symlink':
                source.unlink()
                source.symlink_to(FOLDER / 'Jolt/Core/Core.h')
            else:
                archive = Path(temp) / 'wrong.tar.gz'
                archive.write_bytes(b'not the fixed official archive')
            try:
                verify(archive, folder)
            except AssertionError as error:
                assert expected in str(error), (case, str(error))
                rejected.append({'case': case, 'reason': str(error)})
            else:
                raise AssertionError('Invalid Jolt evidence accepted: ' + case)
        cached = Path(temp) / 'cache-control'
        shutil.copytree(FOLDER, cached, ignore=shutil.ignore_patterns('.xmake'))
        (cached / '.xmake').mkdir()
        (cached / '.xmake/config').write_text('local cache fixture\n')
        assert verify(args.archive, cached)['files'] == baseline['files']
    assert verify(args.archive)['files'] == baseline['files']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({
        'passed': True, 'scope': __doc__, 'rejected_cases': rejected,
        'retained_upstream_files': baseline['retained_upstream_files'],
        'local_cache_exclusion_positive_control': True,
        'original_tree_verified_after_controls': True,
        'test_sha256': sha(Path(__file__).read_bytes()),
        'validator_sha256': baseline['audit_sha256'],
        'runtime_execution': False,
    }, indent=2) + '\n')
    print(f'PASS: {len(rejected)} altered inputs rejected; cache exclusion and original tree verified')


if __name__ == '__main__':
    main()
