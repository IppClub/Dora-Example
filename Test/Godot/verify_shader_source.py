#!/usr/bin/env python3
"""Verify retained glslang/SPIRV-Cross source against fixed bgfx and Khronos.

Reconstructs a retained subset only, without running upstream code. Not original
import history, complete license applicability, ABI or binary-sharing approval.
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
import stat
import subprocess
import tarfile
import tempfile

ROOT = ENGINE_ROOT
BGFX = 'f1e0ba4b0bf9eaccf25889392c112ee98aeda272'
BGFX_TREE = '012a5e6a5ec269e592f0002b9dcfe9240738cfdf'
PINS = {
    'glslang': ('9d764997360b202d2ba7aaad9a401e57d8df56b3',
                '6119649d365791062cd8c6973a820e4d58cff63cd212962508c84048367a3a43', 131, 'LICENSE.txt'),
    'spirv-cross': ('b26ac3fa8bcfe76c361b56e3284b5276b23453ce',
                    'bd1e51025da2bee394f3c0ac0f15e755728f59a0167cc6eea35757b0dfded10b', 36, 'LICENSE'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe(name):
    p = PurePosixPath(name)
    assert not p.is_absolute() and '..' not in p.parts and '\\' not in name and str(p) == name, 'Unsafe retained path'
    return name


def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()



def verify_git_tree(entries, root_sha):
    """Rebuild every recursive Git tree object, including root, from API entries."""
    children = {}
    directories = {''}
    for path, entry in entries.items():
        safe(path)
        parent, _, name = path.rpartition('/')
        assert re.fullmatch('[0-9a-f]{40}', entry['sha']), 'Invalid Git object name'
        assert (entry['mode'], entry['type']) in {
            ('040000', 'tree'), ('100644', 'blob'), ('100755', 'blob'),
            ('120000', 'blob'), ('160000', 'commit')}, 'Unsupported Git tree mode/type'
        children.setdefault(parent, []).append((name.encode(), entry))
        if entry['type'] == 'tree':directories.add(path)
    assert set(children) <= directories, 'Orphan Git tree child'
    for directory in directories:
        rows = sorted(children.get(directory, []),
                      key=lambda item: item[0] + (b'/' if item[1]['type'] == 'tree' else b'\0'))
        payload = b''.join(format(int(e['mode'], 8), 'o').encode() + b' ' + name + b'\0' +
                           bytes.fromhex(e['sha']) for name, e in rows)
        calculated = hashlib.sha1(b'tree ' + str(len(payload)).encode() + b'\0' + payload).hexdigest()
        expected = root_sha if directory == '' else entries[directory]['sha']
        assert calculated == expected, 'Git tree object hash differs: ' + directory


def verify(component, archive_path, evidence, folder=None):
    folder = folder or ROOT/'Source/3rdParty/bgfx/3rdparty'/component
    record = json.loads((folder/'UPSTREAM.json').read_text())
    commit, archive_sha, count, license_name = PINS[component]
    assert record['schema_version'] == 1 and record['bgfx_commit'] == BGFX and record['bgfx_tree'] == BGFX_TREE
    assert record['upstream_commit'] == commit
    assert sha(archive_path.read_bytes()) == record['upstream_archive_sha256'] == archive_sha, 'Unrecognized upstream archive'
    assert archive_path.stat().st_size == record['upstream_archive_bytes']
    for name in ['commit', 'tree']:
        assert sha((evidence/('bgfx-'+name+'.json')).read_bytes()) == record['bgfx_'+name+'_evidence_sha256'], 'Changed bgfx evidence'
    bgfx_commit = json.loads((evidence/'bgfx-commit.json').read_text())
    tree = json.loads((evidence/'bgfx-tree.json').read_text())
    assert bgfx_commit['sha'] == BGFX and bgfx_commit['tree']['sha'] == BGFX_TREE
    assert tree['sha'] == BGFX_TREE and not tree['truncated'], 'Wrong or incomplete bgfx tree'
    entries = {e['path']: e for e in tree['tree']}
    assert len(entries) == len(tree['tree']), 'Duplicate tree path'
    verify_git_tree(entries, BGFX_TREE)
    rows = record['files']; names = {safe(r['path']) for r in rows}
    assert len(rows) == len(names) == count and license_name in names, 'Retained inventory differs'
    patch_name = safe(record['patch']['path']); assert patch_name == 'patches/bgfx-retained.patch'
    patch = folder/patch_name
    assert sha(patch.read_bytes()) == record['patch']['sha256'], 'Patch digest differs'
    actual = set()
    for path in folder.rglob('*'):
        assert not path.is_symlink(), 'Symlink in retained tree'
        if path.is_file():actual.add(path.relative_to(folder).as_posix())
    assert actual == names | {'UPSTREAM.json', 'README.dora.md', patch_name}, 'Unknown or missing retained source'
    input_paths = [archive_path, patch, folder/'UPSTREAM.json', folder/'README.dora.md',
                   evidence/'bgfx-commit.json', evidence/'bgfx-tree.json', *[folder/n for n in names]]
    before = {str(p.resolve()): sha(p.read_bytes()) for p in input_paths}
    needed = names - ({'build_info.h'} if component == 'glslang' else set())
    if component == 'glslang':needed |= {'build_info.h.tmpl', 'CHANGES.md'}
    with tarfile.open(archive_path) as archive:
        prefix = ('glslang-' if component == 'glslang' else 'SPIRV-Cross-')+commit+'/'
        files = {}
        for member in archive:
            if member.name.startswith(prefix) and member.name[len(prefix):] in needed:
                rel = member.name[len(prefix):]
                assert rel not in files and member.isfile(), 'Duplicate or non-regular upstream input'
                files[rel] = archive.extractfile(member).read()
        assert files.keys() == needed, 'Missing upstream retained input'
    if component == 'glslang':
        match = re.search(r'^#* +(\d+)\.(\d+)\.(\d+)(-\w+)?(?: .*)?$', files['CHANGES.md'].decode(), re.M)
        assert match and match.groups() == ('15', '4', '0', None), 'Unexpected glslang version'
        generated = record['generated_build_info']
        assert generated['path'] == 'build_info.h' and generated['template'] == 'build_info.h.tmpl' and generated['version_source'] == 'CHANGES.md'
        values = {'major': '15', 'minor': '4', 'patch': '0', 'flavor': ''}
        assert generated['replacements'] == values
        data = files['build_info.h.tmpl']
        for key, value in values.items():data = data.replace(('@'+key+'@').encode(), value.encode())
        files['build_info.h'] = data
    with tempfile.TemporaryDirectory(prefix='dora-shader-source-') as temp:
        work = Path(temp)
        for row in rows:
            name = row['path']; data = (folder/name).read_bytes();e = entries['3rdparty/'+component+'/'+name]
            assert e['type'] == 'blob' and e['mode'] == row['mode'] and e['sha'] == row['bgfx_blob_sha1'] == blob(data), 'Fixed bgfx source correspondence differs'
            assert stat.S_IMODE((folder/name).stat().st_mode) == int(row['mode'], 8) & 0o777, 'Source mode differs'
            assert sha(data) == row['sha256'], 'Retained digest differs'
            if component == 'glslang' and name == 'build_info.h':
                assert not row['upstream_present'] and row['upstream_sha256'] is None and not row['identical']
                assert files[name] == data, 'Generated version header differs'
            else:
                assert row['upstream_present'] and sha(files[name]) == row['upstream_sha256']
                assert row['identical'] == (files[name] == data), 'Wrong unchanged-file classification'
            target = work/name;target.parent.mkdir(parents=True, exist_ok=True);target.write_bytes(files[name])
        result = subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch.resolve())], cwd=work,
                                capture_output=True, text=True, check=True)
        assert 'offset' not in result.stdout.lower() and 'fuzz' not in result.stdout.lower(), 'Non-exact patch application'
        assert {p.relative_to(work).as_posix() for p in work.rglob('*') if p.is_file()} == names
        assert all((work/n).read_bytes() == (folder/n).read_bytes() for n in names), 'Reconstruction differs'
    assert all(sha(Path(p).read_bytes()) == value for p, value in before.items()), 'Input changed during audit'
    return {'passed': True, 'complete': False, 'scope': __doc__, 'component': component,
            'bgfx_commit': BGFX, 'bgfx_tree': BGFX_TREE, 'upstream_commit': commit, 'retained_files': count,
            'unmodified_files': sum(r['identical'] for r in rows),
            'modified_files': [r['path'] for r in rows if r['upstream_present'] and not r['identical']],
            'generated_files': [r['path'] for r in rows if not r['upstream_present']],
            'inputs_sha256': before, 'patch_stdout': result.stdout,
            'audit_sha256': sha(Path(__file__).read_bytes()), 'runtime_execution': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--component', required=True, choices=PINS)
    p.add_argument('--archive', required=True, type=Path)
    p.add_argument('--bgfx-evidence', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args();assert not a.output.exists(), 'Preserve evidence; choose a fresh path'
    result = verify(a.component, a.archive, a.bgfx_evidence)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS:', a.component, result['retained_files'], 'fixed bgfx files and exact upstream reconstruction')


if __name__ == '__main__':
    main()
