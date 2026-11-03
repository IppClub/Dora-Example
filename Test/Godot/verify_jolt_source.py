#!/usr/bin/env python3
"""Verify all retained Dora Jolt files against a fixed official source archive.

Source and notice correspondence only. Does not execute upstream scripts,
change vendor files, or approve compiler, ABI, runtime or dependency sharing.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile

ROOT = ENGINE_ROOT
FOLDER = ROOT / 'Source/3rdParty/JoltPhysics'
COMMIT = '23dadd0e603f1b321142d4c74df07fce85064989'
ARCHIVE_SHA = 'e4a44a9bfdcdb1e47259b7a66a300d9f31daf1b28ec19617761c3aad7165b979'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(archive_path, folder=FOLDER):
    record = json.loads((folder / 'UPSTREAM.json').read_text())
    assert record['schema_version'] == 1 and record['identified_equivalent_release'] == '5.5.0'
    assert record['identified_equivalent_commit'] == COMMIT, 'Unexpected upstream commit'
    assert sha(archive_path.read_bytes()) == record['archive_sha256'] == ARCHIVE_SHA, 'Unrecognized Jolt archive'
    assert archive_path.stat().st_size == record['archive_bytes'] == 18854313
    files = record['files']
    names = {entry['path'] for entry in files}
    assert len(files) == len(names) == 444 and {'LICENSE', 'README.md', 'Jolt/Core/Core.h'} <= names
    assert record['patches'] == [], 'Unexpected Jolt patches'
    assert record['excluded_local_cache_directory'] == '.xmake'
    marker = (folder / 'JOLT_VERSION.txt').read_bytes()
    assert marker.decode().splitlines() == ['v5.5.0', COMMIT], 'Local Jolt version marker differs'
    assert record['local_files'] == [{'path': 'JOLT_VERSION.txt', 'sha256': sha(marker)}]
    expected = names | {'JOLT_VERSION.txt', 'UPSTREAM.json', 'README.dora.md'}
    actual = set()
    for path in folder.rglob('*'):
        relative = path.relative_to(folder)
        if relative.parts[0] == '.xmake':
            continue
        assert not path.is_symlink(), 'Symlink in retained source tree'
        if path.is_file():
            actual.add(relative.as_posix())
    assert actual == expected, 'Retained Jolt inventory differs'
    for name in names:
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts, 'Unsafe retained path'
        assert name in ('LICENSE', 'README.md') or path.parts[0] == 'Jolt', 'Unexpected upstream subtree'
        assert (folder / name).resolve().is_relative_to(folder.resolve()), 'Retained path escapes vendor'
    prefix = 'JoltPhysics-' + COMMIT + '/'
    with tarfile.open(archive_path) as archive:
        members = {}
        for member in archive:
            if not member.name.startswith(prefix):
                continue
            name = member.name[len(prefix):]
            if name in names:
                assert name not in members and member.isfile(), 'Duplicate or non-regular upstream input'
                members[name] = member
        assert set(members) == names, 'Missing retained upstream inputs'
        for entry in files:
            name = entry['path']
            original = archive.extractfile(members[name]).read()
            assert sha(original) == entry['upstream_sha256'] == entry['vendor_sha256'], 'Upstream digest differs: ' + name
            assert (folder / name).read_bytes() == original, 'Vendor Jolt input differs: ' + name
    return {'passed': True, 'complete': False, 'scope': __doc__,
            'equivalent_commit': COMMIT, 'release': '5.5.0', 'archive_sha256': ARCHIVE_SHA,
            'retained_upstream_files': len(files), 'unmodified_upstream_files': len(files),
            'modified_files': [], 'files': files, 'local_files': record['local_files'],
            'metadata_sha256': sha((folder / 'UPSTREAM.json').read_bytes()),
            'audit_sha256': sha(Path(__file__).read_bytes()),
            'excluded_local_cache_directory': '.xmake',
            'runtime_execution': False, 'abi_or_sharing_accepted': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve earlier evidence; choose a new output path'
    result = verify(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: all 444 retained Jolt upstream files match; no source or notice patches')


if __name__ == '__main__':
    main()
