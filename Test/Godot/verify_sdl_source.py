#!/usr/bin/env python3
"""Reconstruct the retained SDL2 subset through official, fork and vendor layers.

Source/notice correspondence only, not full component licensing, ABI or sharing
acceptance. Upstream code is never executed and vendor files are not changed.
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
FOLDER = ROOT / 'Source/3rdParty/SDL2'
PINS = {
    'official': ('e924f12a7b33678bc71dc96acf3c44142c72c553',
                 '89eab220f0096d0ebd695d1d678f86fbe0981ba5605fea9e66413c37254f2805'),
    'fork': ('05210686fc98508b2b7794721e42402231229092',
             '01adab1394e0c4e93eddc167e894275dd2f6d60560aa99e9d33b97bc56903aaf'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(name):
    path = PurePosixPath(name)
    assert name and not path.is_absolute() and '..' not in path.parts and '\\' not in name, 'Unsafe SDL retained path'
    assert path.as_posix() == name, 'Non-canonical SDL retained path'


def read_retained(archive_path, layer, metadata, names):
    commit, expected = PINS[layer]
    assert metadata['commit'] == commit, 'Unexpected SDL commit: ' + layer
    assert sha(archive_path.read_bytes()) == metadata['archive_sha256'] == expected, 'Unrecognized SDL archive: ' + layer
    assert archive_path.stat().st_size == metadata['archive_bytes']
    prefix = 'SDL-' + commit + '/'
    result = {}
    with tarfile.open(archive_path) as archive:
        for member in archive:
            if not member.name.startswith(prefix):
                continue
            name = member.name[len(prefix):]
            if name not in names:
                continue
            assert name not in result and member.isfile(), 'Duplicate/non-regular SDL archive input'
            result[name] = archive.extractfile(member).read()
    assert result.keys() == names, 'Missing SDL archive inputs'
    return result


def verify(official_archive, fork_archive, folder=FOLDER):
    record = json.loads((folder / 'UPSTREAM.json').read_text())
    assert record['schema_version'] == 1 and record['declared_version'] == '2.31.0'
    files = record['files']
    names = {entry['path'] for entry in files}
    assert len(files) == len(names) == 1213 and {'LICENSE.txt', 'include/SDL_version.h'} <= names
    additions = record['vendor_added_files']
    assert [row['path'] for row in additions] == ['include/SDL_config_linux.h']
    assert [row['path'] for row in record['local_files']] == ['DORA_SOURCE.md', 'xmake.lua']
    assert [row['path'] for row in record['patches']] == [
        'patches/official-to-dora-fork.patch', 'patches/fork-to-dora-vendor.patch']
    assert record['excluded_build_directories'] == ['.xmake', 'build', 'Lib']
    variants = record['checkout_line_ending_variants']
    assert len(variants) == 1 and variants[0]['path'] == 'cmake/CheckCPUArchitecture.cmake', 'Unexpected SDL newline exception'
    expected = names | {row['path'] for key in ('vendor_added_files', 'local_files', 'patches') for row in record[key]}
    expected |= {'UPSTREAM.json', 'README.dora.md'}
    for name in expected:
        safe_path(name)
        assert (folder / name).resolve().is_relative_to(folder.resolve()), 'SDL retained path escapes vendor'
    actual = set()
    # Prune artifact trees rather than walking their potentially large contents.
    import os
    for directory, dirs, filenames in os.walk(folder, followlinks=False):
        parent = Path(directory)
        if parent == folder:
            dirs[:] = [name for name in dirs if name not in record['excluded_build_directories']]
        for name in dirs + filenames:
            path = parent / name
            assert not path.is_symlink(), 'Symlink in SDL source tree'
        actual.update((parent / name).relative_to(folder).as_posix() for name in filenames)
    assert actual == expected, 'Retained SDL inventory differs'
    official = read_retained(official_archive, 'official', record['official'], names)
    fork = read_retained(fork_archive, 'fork', record['fork'], names)
    changed_fork = sorted(name for name in names if official[name] != fork[name])
    changed_vendor = sorted(row['path'] for row in files if row['fork_sha256'] != row['vendor_sha256'])
    assert changed_fork == record['fork_modified_files'] and len(changed_fork) == 4, 'SDL fork change set differs'
    assert changed_vendor == record['vendor_modified_files'] and len(changed_vendor) == 9, 'SDL vendor change set differs'
    for entry in files:
        name = entry['path']
        assert sha(official[name]) == entry['official_sha256'], 'Official SDL digest differs: ' + name
        assert sha(fork[name]) == entry['fork_sha256'], 'Fork SDL digest differs: ' + name
    assert official['LICENSE.txt'] == fork['LICENSE.txt'] == (folder / 'LICENSE.txt').read_bytes(), 'SDL license differs'
    logs = []
    with tempfile.TemporaryDirectory(prefix='dora-sdl-source-') as temporary:
        work = Path(temporary)
        for name, data in official.items():
            target = work / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        for index, patch in enumerate(record['patches']):
            path = folder / patch['path']
            text = path.read_text()
            assert sha(path.read_bytes()) == patch['sha256'], 'SDL patch digest differs'
            for line in text.splitlines():
                if line.startswith(('--- ', '+++ ')):
                    target = line[4:]
                    if target != '/dev/null':
                        assert target.startswith(('a/', 'b/')), 'Unsafe SDL patch target'
                        safe_path(target[2:])
                        assert target[2:] in names | {'include/SDL_config_linux.h'}, 'Unknown SDL patch target'
            result = subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(path.resolve())],
                                    cwd=work, capture_output=True, text=True)
            assert result.returncode == 0 and 'offset' not in result.stdout and 'fuzz' not in result.stdout, 'SDL patch failed: ' + result.stdout + result.stderr
            logs.append(result.stdout)
            if index == 0:
                assert all((work / name).read_bytes() == data for name, data in fork.items()), 'SDL fork reconstruction differs'
        for entry in files:
            name = entry['path']
            assert sha((work / name).read_bytes()) == entry['vendor_sha256'], 'SDL vendor reconstruction differs: ' + name
            expected_bytes = (work / name).read_bytes()
            current_bytes = (folder / name).read_bytes()
            if name == variants[0]['path']:
                lf_bytes = expected_bytes.replace(b'\r\n', b'\n')
                assert sha(lf_bytes) == variants[0]['lf_sha256'], 'SDL newline variant digest differs'
                assert current_bytes in (expected_bytes, lf_bytes), 'SDL newline variant content differs'
            else:
                assert current_bytes == expected_bytes, 'SDL vendor source differs: ' + name
        for entry in additions:
            name = entry['path']
            assert sha((work / name).read_bytes()) == entry['sha256'], 'Added SDL header reconstruction differs'
            assert (folder / name).read_bytes() == (work / name).read_bytes(), 'Added SDL vendor header differs'
        rebuilt = {path.relative_to(work).as_posix() for path in work.rglob('*') if path.is_file()}
        assert rebuilt == names | {'include/SDL_config_linux.h'}, 'Unexpected reconstructed SDL file'
    for entry in record['local_files']:
        assert sha((folder / entry['path']).read_bytes()) == entry['sha256'], 'SDL local input differs: ' + entry['path']
    return {'passed': True, 'complete': False, 'scope': __doc__, 'retained_upstream_files': len(files),
            'official': record['official'], 'fork': record['fork'], 'files': files,
            'fork_modified_files': changed_fork, 'vendor_modified_files': changed_vendor,
            'vendor_added_files': additions, 'local_files': record['local_files'],
            'patches': record['patches'], 'patch_logs': logs,
            'checkout_line_ending_variants': variants,
            'metadata_sha256': sha((folder / 'UPSTREAM.json').read_bytes()),
            'validator_sha256': sha(Path(__file__).read_bytes()),
            'runtime_execution': False, 'abi_or_sharing_accepted': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--official-archive', type=Path, required=True)
    parser.add_argument('--fork-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence path'
    result = verify(args.official_archive, args.fork_archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: 1213 retained SDL files and added Linux config reconstructed through both patch layers')


if __name__ == '__main__':
    main()
