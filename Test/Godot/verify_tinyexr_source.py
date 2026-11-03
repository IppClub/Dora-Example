#!/usr/bin/env python3
"""Verify two retained TinyEXR files against fixed syoyo and bimg sources.

Only retained-source correspondence, not original import history, complete
backend licensing, ABI, binary compatibility or runtime-sharing approval.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import tarfile

ROOT = ENGINE_ROOT
FOLDER = ROOT/'Source/3rdParty/bimg/3rdparty/tinyexr'
COMMIT = '834c4ce7955f2ae61edc802c697332baae2488c3'
TREE = '2725bd2abc0d0e9a593f8e1093dbee95144f1dc9'
BIMG = '98a40e85334721446bbc2efe7bd4576d37952136'
BIMG_SHA = '86436cc057405031ae5bd4ed092f666f9f79341c5288fddf95a702fb71e51b75'
BLOBS = {'README.md': 'b570c4567ffc2231b957d3b183ea0b31898c6a00',
         'tinyexr.h': 'b8ecad20ec58b6cdd0d7af03aa6df4df59486eb9'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()


def verify(upstream, bimg_archive, folder=FOLDER):
    record = json.loads((folder/'UPSTREAM.json').read_text())
    assert record['schema_version'] == 1 and record['upstream_commit'] == COMMIT and record['upstream_tree'] == TREE
    assert record['bimg_commit'] == BIMG and record['bimg_subtree'] == '3rdparty/tinyexr'
    assert record['patches'] == [], 'Unexpected retained TinyEXR patch'
    assert digest(bimg_archive) == record['bimg_archive_sha256'] == BIMG_SHA, 'Unrecognized bimg archive'
    assert digest(upstream/'commit.json') == record['upstream_commit_response_sha256'], 'Commit evidence changed'
    assert digest(upstream/'tree.json') == record['upstream_tree_response_sha256'], 'Tree evidence changed'
    commit = json.loads((upstream/'commit.json').read_text())
    tree = json.loads((upstream/'tree.json').read_text())
    assert commit['sha'] == COMMIT and commit['tree']['sha'] == TREE
    assert tree['sha'] == TREE and not tree['truncated'], 'Incomplete upstream tree'
    names = [r['path'] for r in record['files']]
    assert len(names) == 2 and set(names) == set(BLOBS), 'Unexpected retained files'
    actual = set()
    for path in folder.rglob('*'):
        assert not path.is_symlink(), 'Symlink in retained tree'
        if path.is_file():actual.add(path.relative_to(folder).as_posix())
    assert actual == set(BLOBS) | {'UPSTREAM.json', 'README.dora.md'}, 'Unknown or missing retained input'
    before = {str(p.resolve()): digest(p) for p in [folder/'UPSTREAM.json', folder/'README.dora.md',
              upstream/'commit.json', upstream/'tree.json', bimg_archive, *[folder/n for n in BLOBS], *[upstream/n for n in BLOBS]]}
    prefix = 'bimg-'+BIMG+'/3rdparty/tinyexr/'
    with tarfile.open(bimg_archive) as archive:
        members = [m for m in archive if m.name.startswith(prefix) and m.name[len(prefix):] in BLOBS]
        assert len(members) == 2 and {m.name[len(prefix):] for m in members} == set(BLOBS)
        assert all(m.isfile() for m in members), 'Non-regular bimg input'
        for row in record['files']:
            name = row['path']; data = (upstream/name).read_bytes()
            assert hashlib.sha256(data).hexdigest() == row['sha256'] == digest(folder/name), 'Source digest differs'
            assert git_blob(data) == row['git_blob_sha1'] == BLOBS[name], 'Unrecognized upstream source blob'
            entries = [e for e in tree['tree'] if e['path'] == name]
            assert len(entries) == 1 and entries[0]['type'] == 'blob' and entries[0]['mode'] == '100644' and entries[0]['sha'] == BLOBS[name]
            member = next(m for m in members if m.name == prefix+name)
            assert archive.extractfile(member).read() == data == (folder/name).read_bytes(), 'Retained source is not fixed bimg source'
    assert all(digest(Path(p)) == value for p, value in before.items()), 'Input changed during audit'
    return {'passed': True, 'complete': False, 'scope': __doc__, 'upstream_commit': COMMIT,
            'upstream_tree': TREE, 'bimg_commit': BIMG, 'retained_files': 2, 'patches': [],
            'inputs_sha256': before, 'git_blob_sha1': BLOBS, 'audit_sha256': digest(Path(__file__)),
            'runtime_execution': False, 'complete_backend_licensing_accepted': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--upstream-dir', required=True, type=Path)
    p.add_argument('--bimg-archive', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    assert not a.output.exists(), 'Preserve evidence; use a fresh output'
    result = verify(a.upstream_dir, a.bimg_archive)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS: both retained TinyEXR files match fixed upstream Git blobs and bimg')


if __name__ == '__main__':
    main()
