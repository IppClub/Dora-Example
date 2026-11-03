#!/usr/bin/env python3
"""Verify astcenc's retained bimg correspondence and mapped Arm reconstruction.

No upstream code executes. This is equivalent source provenance, not original
import history, licensing reassignment, ABI or runtime-sharing acceptance.
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
FOLDER = ROOT/'Source/3rdParty/bimg/3rdparty/astc-encoder'
ARM = '234c8a48483a74892a0e6c49d1e100ad42fbdde4'
BIMG = '98a40e85334721446bbc2efe7bd4576d37952136'
ARM_SHA = 'e80ad180ae9ed3dc23f2ea6404e3044fe20183b26e547894abb48c0ed9dec0e4'
BIMG_SHA = '86436cc057405031ae5bd4ed092f666f9f79341c5288fddf95a702fb71e51b75'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe(name):
    path = PurePosixPath(name)
    assert not path.is_absolute() and '..' not in path.parts and '\\' not in name and str(path) == name, 'Unsafe retained path'
    return name


def selected_archive(archive_path, prefix, names):
    result = {}
    with tarfile.open(archive_path) as archive:
        for member in archive:
            if member.name.startswith(prefix) and member.name[len(prefix):] in names:
                name = member.name[len(prefix):]
                assert name not in result and member.isfile(), 'Duplicate or non-regular archive input'
                result[name] = archive.extractfile(member).read()
    assert set(result) == names, 'Missing upstream files'
    return result


def verify(arm_archive, bimg_archive, folder=FOLDER):
    record = json.loads((folder/'UPSTREAM.json').read_text())
    assert record['schema_version'] == 1
    assert record['arm_baseline']['commit'] == ARM and record['bimg']['commit'] == BIMG
    for path, key, pinned in [(arm_archive, 'arm_baseline', ARM_SHA), (bimg_archive, 'bimg', BIMG_SHA)]:
        assert sha(path.read_bytes()) == record[key]['archive_sha256'] == pinned, 'Unrecognized fixed archive'
        assert path.stat().st_size == record[key]['archive_bytes']
    rows = record['files']; names = {safe(row['path']) for row in rows}
    assert len(rows) == len(names) == 34 and {'LICENSE.txt', 'include/astcenc.h'} <= names
    for row in rows:
        expected = 'Source/'+PurePosixPath(row['path']).name if row['path'].startswith(('source/', 'include/')) else row['path']
        assert safe(row['upstream_path']) == expected, 'Unexpected Arm path mapping'
    patch_path = safe(record['patch']['path'])
    assert patch_path == 'patches/bimg-4.8-baseline.patch'
    patch = folder/patch_path
    assert sha(patch.read_bytes()) == record['patch']['sha256'], 'Patch digest differs'
    actual = set()
    for path in folder.rglob('*'):
        assert not path.is_symlink(), 'Symlink in source tree'
        if path.is_file():actual.add(path.relative_to(folder).as_posix())
    assert actual == names | {'UPSTREAM.json', 'README.dora.md', patch_path}, 'Unknown or missing local input'
    bimg = selected_archive(bimg_archive, 'bimg-'+BIMG+'/3rdparty/astc-encoder/', names)
    arm = selected_archive(arm_archive, 'astc-encoder-'+ARM+'/', {r['upstream_path'] for r in rows} | {'CMakeLists.txt'})
    assert b'project(astcencoder VERSION 4.8.0)' in arm['CMakeLists.txt']
    assert record['arm_baseline']['declared_cmake_version'] == '4.8.0'
    original = {}
    with tempfile.TemporaryDirectory(prefix='dora-astc-reconstruct-') as temp:
        work = Path(temp)
        for row in rows:
            name = row['path']; data = arm[row['upstream_path']]
            assert sha(data) == row['upstream_sha256'], 'Arm digest differs'
            assert sha(bimg[name]) == row['sha256'] and (folder/name).read_bytes() == bimg[name], 'Retained bimg correspondence differs'
            assert row['identical'] == (data == bimg[name]), 'Incorrect unchanged-file classification'
            original[name] = sha((folder/name).read_bytes())
            target = work/name; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
        command = ['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch.resolve())]
        result = subprocess.run(command, cwd=work, capture_output=True, text=True, check=True)
        assert 'offset' not in result.stdout.lower() and 'fuzz' not in result.stdout.lower(), 'Non-exact patch application'
        assert {str(p.relative_to(work)) for p in work.rglob('*') if p.is_file()} == names, 'Patch changed file inventory'
        assert all((work/name).read_bytes() == bimg[name] for name in names), 'Reconstruction differs'
    assert all(sha((folder/name).read_bytes()) == value for name, value in original.items())
    return {'passed': True, 'complete': False, 'scope': __doc__, 'bimg_commit': BIMG, 'arm_equivalent_baseline': ARM,
            'declared_version': '4.8.0', 'retained_files': 34, 'unmodified_arm_files': sum(r['identical'] for r in rows),
            'modified_arm_files': [r['path'] for r in rows if not r['identical']],
            'arm_archive_sha256': ARM_SHA, 'bimg_archive_sha256': BIMG_SHA,
            'metadata_sha256': sha((folder/'UPSTREAM.json').read_bytes()), 'patch_sha256': sha(patch.read_bytes()),
            'readme_sha256': sha((folder/'README.dora.md').read_bytes()), 'audit_sha256': sha(Path(__file__).read_bytes()),
            'patch_stdout': result.stdout, 'original_sources_unchanged': original, 'runtime_execution': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--arm-archive', required=True, type=Path)
    p.add_argument('--bimg-archive', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    assert not a.output.exists(), 'Preserve evidence; use a fresh path'
    result = verify(a.arm_archive, a.bimg_archive)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS: 34 bimg files match; Arm baseline + exact patch reconstructs all retained bytes')


if __name__ == '__main__':
    main()
