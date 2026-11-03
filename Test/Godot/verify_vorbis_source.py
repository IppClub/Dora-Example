#!/usr/bin/env python3
"""Reconstruct retained Vorbis from fixed combined aoTuV/Lancer source and delta.

Equivalent source correspondence only. Original import/patch authorship, full
license applicability, ABI, behavior and sharing acceptance remain separate.
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
import re
import subprocess
import tarfile
import tempfile

ROOT = ENGINE_ROOT
FOLDER = ROOT/'Source/3rdParty/vorbis'
COMMIT = 'fbf05e8c7597065c371ff490c1c11e38c1bfec4b'
ARCHIVE_SHA = '1b20451b077744ceec467e785f6ce8176e1bc670d64099eac2551dbdde039697'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe(name):
    path = PurePosixPath(name)
    assert not path.is_absolute() and '..' not in path.parts and '\\' not in name and str(path) == name, 'Unsafe retained path'
    return name


def verify(archive_path, folder=FOLDER, root=ROOT):
    record = json.loads((folder/'UPSTREAM.json').read_text())
    assert record['schema_version'] == 1 and record['upstream_commit'] == COMMIT
    assert sha(archive_path) == record['archive_sha256'] == ARCHIVE_SHA, 'Unrecognized fixed archive'
    assert archive_path.stat().st_size == record['archive_bytes']
    rows = record['files'];names = {safe(r['path']) for r in rows}
    assert len(rows) == len(names) == 76 and {'COPYING', 'codec.h', 'lib/block.c'} <= names
    assert sum(row['identical'] for row in rows) == 33
    for row in rows:
        name = row['path']
        expected = 'include/vorbis/'+name if name in {'codec.h', 'vorbisenc.h', 'vorbisfile.h'} else name
        assert safe(row['upstream_path']) == expected, 'Unexpected upstream path mapping'
    patch_name = safe(record['patch']['path']); assert patch_name == 'patches/dora-retained.patch'
    patch = folder/patch_name;assert sha(patch) == record['patch']['sha256'], 'Patch digest differs'
    actual = set()
    for path in folder.rglob('*'):
        assert not path.is_symlink(), 'Symlink in retained source'
        if path.is_file():actual.add(path.relative_to(folder).as_posix())
    assert actual == names | {'UPSTREAM.json', 'README.dora.md', patch_name}, 'Unknown or missing retained file'
    amalgamation = record['local_amalgamation']
    assert amalgamation['path'] == 'Source/Audio/VorbisSources.c'
    source = root/amalgamation['path'];assert sha(source) == amalgamation['sha256'], 'Amalgamation changed'
    includes = re.findall(r'#include "\.\./3rdParty/vorbis/([^"]+\.c)"', source.read_text())
    assert len(includes) == len(set(includes)) == 23 and includes == amalgamation['retained_c_includes']
    assert set(includes) <= names
    before = {str(p.resolve()): sha(p) for p in [archive_path, patch, folder/'UPSTREAM.json', folder/'README.dora.md', source, *[folder/n for n in names]]}
    with tarfile.open(archive_path) as archive:
        prefix = 'vorbis-aotuv-lancer-'+COMMIT+'/'
        originals = {}
        wanted = {r['upstream_path'] for r in rows}
        for member in archive:
            if member.name.startswith(prefix) and member.name[len(prefix):] in wanted:
                name = member.name[len(prefix):]
                assert name not in originals and member.isfile(), 'Duplicate or non-regular archive input'
                originals[name] = archive.extractfile(member).read()
        assert originals.keys() == wanted, 'Missing upstream retained file'
    with tempfile.TemporaryDirectory(prefix='dora-vorbis-reconstruct-') as temp:
        work = Path(temp)
        for row in rows:
            original = originals[row['upstream_path']];target = folder/row['path']
            assert hashlib.sha256(original).hexdigest() == row['upstream_sha256'], 'Upstream digest differs'
            assert sha(target) == row['sha256'], 'Retained digest differs'
            assert row['identical'] == (target.read_bytes() == original), 'Incorrect unchanged-file classification'
            path = work/row['path'];path.parent.mkdir(parents=True, exist_ok=True);path.write_bytes(original)
        result = subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch.resolve())],
                                cwd=work, capture_output=True, text=True, check=True)
        assert 'offset' not in result.stdout.lower() and 'fuzz' not in result.stdout.lower(), 'Non-exact patch application'
        assert {p.relative_to(work).as_posix() for p in work.rglob('*') if p.is_file()} == names
        assert all((work/n).read_bytes() == (folder/n).read_bytes() for n in names), 'Reconstruction differs'
    assert originals['COPYING'] == (folder/'COPYING').read_bytes(), 'Original notice changed'
    assert all(sha(Path(path)) == value for path, value in before.items()), 'Input changed during verification'
    return {'passed': True, 'complete': False, 'scope': __doc__, 'upstream_commit': COMMIT,
            'retained_files': 76, 'unmodified_files': 33, 'modified_files': [r['path'] for r in rows if not r['identical']],
            'amalgamation_c_inputs': includes, 'inputs_sha256': before, 'patch_stdout': result.stdout,
            'audit_sha256': sha(Path(__file__)), 'runtime_execution': False, 'abi_or_sharing_accepted': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args();assert not a.output.exists(), 'Preserve evidence; use a fresh output'
    result = verify(a.archive)
    a.output.parent.mkdir(parents=True, exist_ok=True);a.output.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS: 76 retained Vorbis files reconstructed exactly; 23 amalgamation inputs recorded')


if __name__ == '__main__':
    main()
