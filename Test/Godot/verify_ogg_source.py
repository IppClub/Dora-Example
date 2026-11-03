#!/usr/bin/env python3
"""Verify Dora's retained Ogg sources against the identified official release.

Reconstructs only six retained files in a temporary tree. Does not compile,
upgrade, or modify the source tree, and does not establish full ABI compatibility.
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
PINNED_ARCHIVE = '0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve prior evidence; choose a new output path'
    folder = ROOT / 'Source/3rdParty/ogg'
    metadata = folder / 'UPSTREAM.json'
    record = json.loads(metadata.read_text())
    assert record['schema_version'] == 1 and record['identified_equivalent_release'] == '1.3.5'
    assert sha(args.archive) == record['archive_sha256'] == PINNED_ARCHIVE, 'Ogg archive differs from pinned release'
    patch = folder / record['patch']['path']
    assert patch.resolve().is_relative_to(folder) and sha(patch) == record['patch']['sha256']
    with tempfile.TemporaryDirectory(prefix='dora-ogg-reconstruction-') as temporary:
        work = Path(temporary)
        with tarfile.open(args.archive) as archive:
            assert len(record['files']) == 6
            for entry in record['files']:
                for key in ('vendor_path', 'upstream_path'):
                    path = PurePosixPath(entry[key])
                    assert not path.is_absolute() and '..' not in path.parts
                data = archive.extractfile('libogg-1.3.5/' + entry['upstream_path']).read()
                assert hashlib.sha256(data).hexdigest() == entry['upstream_sha256']
                path = work / entry['vendor_path']
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch.resolve())],
                       cwd=work, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for entry in record['files']:
            assert sha(work / entry['vendor_path']) == sha(folder / entry['vendor_path']) == entry['vendor_sha256'], entry['vendor_path']
    for name, expected in record['local_files'].items():
        path = folder / name
        assert path.resolve().is_relative_to(folder) and sha(path) == expected, name
    result = {'passed': True, 'scope': __doc__, 'release': '1.3.5',
              'reconstructed_files': 6, 'archive_sha256': PINNED_ARCHIVE,
              'metadata_sha256': sha(metadata), 'patch_sha256': sha(patch),
              'local_file_sha256': record['local_files']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: six retained Ogg files reconstructed byte-for-byte; local configuration inventoried')


if __name__ == '__main__':
    main()
