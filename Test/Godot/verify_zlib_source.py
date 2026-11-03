#!/usr/bin/env python3
"""Reconstruct Dora's retained zlib subset from pinned official source.

Source/notice correspondence only; not compiler, ABI, runtime, sharing or
security acceptance. Does not execute upstream source or modify vendor files.
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
import subprocess
import tarfile
import tempfile

ROOT = ENGINE_ROOT
FOLDER = ROOT / 'Source/3rdParty/Zip/zlib'
COMMIT = '51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf'
ARCHIVE_SHA = 'd9e270d46252734aa49770fbc544125391617956266f220bd63216c834f3a522'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(archive_path, folder=FOLDER):
    metadata = folder / 'UPSTREAM.json'
    record = json.loads(metadata.read_text())
    assert record['schema_version'] == 1 and record['identified_equivalent_release'] == '1.3.1'
    assert record['identified_equivalent_commit'] == COMMIT
    assert sha(archive_path.read_bytes()) == record['archive_sha256'] == ARCHIVE_SHA, 'Unrecognized zlib archive'
    files = record['files']; names = {item['path'] for item in files}
    assert len(files) == len(names) == 26 and 'LICENSE' in names and 'zconf.h' in names
    patchname = record['patch']['path']
    for name in [*names, patchname]:
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts, 'Unsafe retained path'
        assert (folder / name).resolve().is_relative_to(folder.resolve()), 'Retained path escapes vendor'
    expected = names | {'UPSTREAM.json', 'README.dora.md', patchname}
    assert {str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file()} == expected, 'Retained inventory differs'
    patch = folder / patchname
    assert sha(patch.read_bytes()) == record['patch']['sha256'], 'Recorded patch differs'
    modified = [item['path'] for item in files if item['upstream_sha256'] != item['vendor_sha256']]
    assert modified == ['zconf.h'], 'Unexpected modified retained file set'
    assert next(item for item in files if item['path'] == 'LICENSE')['upstream_sha256'] == next(
        item for item in files if item['path'] == 'LICENSE')['vendor_sha256']
    with tempfile.TemporaryDirectory(prefix='dora-zlib-source-') as temporary:
        work = Path(temporary)
        with tarfile.open(archive_path) as archive:
            for entry in files:
                member = archive.getmember('zlib-' + COMMIT + '/' + entry['path'])
                assert member.isfile(), 'Expected regular upstream file'
                original = archive.extractfile(member).read()
                assert sha(original) == entry['upstream_sha256'], 'Upstream input differs'
                target = work / entry['path']; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(original)
        result = subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch.resolve())],
                                cwd=work, capture_output=True, text=True)
        assert result.returncode == 0, 'Recorded patch does not apply: ' + result.stdout + result.stderr
        for entry in files:
            assert sha((work / entry['path']).read_bytes()) == entry['vendor_sha256'], 'Reconstruction differs'
            assert sha((folder / entry['path']).read_bytes()) == entry['vendor_sha256'], 'Vendor input differs: ' + entry['path']
    return {'passed': True, 'scope': __doc__, 'release': '1.3.1', 'equivalent_commit': COMMIT,
            'archive_sha256': ARCHIVE_SHA, 'reconstructed_files': 26,
            'unmodified_upstream_files': 25, 'modified_files': modified,
            'metadata_sha256': sha(metadata.read_bytes()), 'patch_sha256': sha(patch.read_bytes()),
            'files': files, 'audit_sha256': sha(Path(__file__).read_bytes()),
            'runtime_execution': False, 'abi_or_sharing_accepted': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    assert not args.output.exists(), 'Preserve earlier evidence; choose a new output path'
    result = verify(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: all 26 retained zlib files reconstructed; one recorded local header patch')


if __name__ == '__main__':
    main()
