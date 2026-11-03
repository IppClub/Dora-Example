#!/usr/bin/env python3
"""Verify selected pinned NIR source derivations without assigning licenses.

The three reviewed BLAKE3 transformations are compared as C preprocessing
lexemes (comments/whitespace excluded), not compiled or tested for behavior.
The pinned Mesa version-header generator is executed in an isolated directory
with an explicit version override. No SDK, vendor or production output changes.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from audit_nir_notice_inheritance import BLAKE3_COMMIT, BLAKE3_SHA
from generate_nir_notices import MESA_COMMIT, MESA_SHA, NIR_SHA, read_archive
from verify_d3d12_sdk import ROOT, verify


def digest(data):
    return hashlib.sha256(data).hexdigest()


def lexemes(text):
    pattern = r'/\*[\s\S]*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\s+|[A-Za-z_][A-Za-z_0-9]*|\S'
    return [token for token in re.findall(pattern, text)
            if not token.isspace() and not token.startswith(('/*', '//'))]


def replace_once(text, old, new):
    assert text.count(old) == 1, 'Reviewed transformation anchor changed'
    return text.replace(old, new, 1)


def transform(name, text):
    if name == 'blake3.c':
        text = replace_once(text, 'size_t blake3_compress_subtree_wide(',
                            'static size_t blake3_compress_subtree_wide(')
        changes = ['Make blake3_compress_subtree_wide file-local; whitespace differs']
    elif name == 'blake3.h':
        start = text.index('#if !defined(BLAKE3_API)')
        end = text.index('#ifdef __cplusplus', start)
        block = text[start:end]
        assert len(re.findall(r'#[ \t]*endif', block)) == 4 and 'BLAKE3_PRIVATE' in block
        text = text[:start] + text[end:]
        start = text.index('#if defined(BLAKE3_USE_TBB)')
        end = text.index('#endif // BLAKE3_USE_TBB', start) + len('#endif // BLAKE3_USE_TBB')
        assert 'blake3_hasher_update_tbb' in text[start:end]
        text = text[:start] + text[end:]
        text = text.replace('BLAKE3_API ', '')
        text = replace_once(text, 'typedef struct {\n  uint32_t key[8];',
                            'typedef struct blake3_hasher {\n  uint32_t key[8];')
        changes = ['Remove DLL/default visibility macro block and API annotations',
                   'Give blake3_hasher its struct tag',
                   'Remove optional TBB update declaration; whitespace differs']
    elif name == 'blake3_impl.h':
        text = replace_once(text, 'BLAKE3_PRIVATE size_t blake3_compress_subtree_wide(',
                            'static size_t blake3_compress_subtree_wide(')
        text = replace_once(text, 'BLAKE3_PRIVATE void blake3_compress_subtree_wide_join_tbb(',
                            'void blake3_compress_subtree_wide_join_tbb(')
        changes = ['Make subtree declaration file-local',
                   'Remove private visibility annotation from optional TBB declaration; whitespace differs']
    else:
        raise AssertionError('Unreviewed source transformation')
    return text, changes


def check_derivation(name, upstream, mesa):
    transformed, changes = transform(name, upstream.decode())
    actual = lexemes(mesa.decode())
    assert lexemes(transformed) == actual, 'Unreviewed BLAKE3 token difference: ' + name
    return {'file': name, 'upstream_sha256': digest(upstream), 'mesa_sha256': digest(mesa),
            'reviewed_changes': changes, 'lexemes': len(actual),
            'transformed_lexemes_sha256': digest(json.dumps(actual).encode()),
            'reviewed_lexemes_equal': True, 'byte_identical': upstream == mesa,
            'license_inheritance_verified': False, 'behavior_equivalence_verified': False}


def check_generated_header(generated, sdk_output):
    assert sdk_output == generated, 'Generated header differs from SDK'


def audit(mesa_path, blake3_path, nir_path, sdk, output):
    output.mkdir(parents=True, exist_ok=False)
    mesa = read_archive(mesa_path, MESA_SHA, 'mesa-' + MESA_COMMIT)
    upstream = read_archive(blake3_path, BLAKE3_SHA, 'BLAKE3-' + BLAKE3_COMMIT)
    nir = read_archive(nir_path, NIR_SHA, 'godot-nir-static-25.3.1-1')
    sdk_check = verify(sdk, ROOT / 'Projects/xmake/godot/windows_d3d12_sdk.json')
    update = nir['update_mesa.sh'].decode()
    assert "run_step bin 'git_sha1_gen.py --output $OUTDIR/git_sha1.h'" in update
    assert b'25.3.1\n' == mesa['VERSION']
    assert (sdk / 'godot-mesa/VERSION.info').read_bytes().replace(b'\r\n', b'\n') == mesa['VERSION']
    rows = [check_derivation(name, upstream['c/' + name], mesa['src/util/blake3/' + name])
            for name in ('blake3.c', 'blake3.h', 'blake3_impl.h')]
    for name in ('blake3.h', 'blake3_impl.h'):
        assert (sdk / ('godot-mesa/src/util/blake3/' + name)).read_bytes().replace(
            b'\r\n', b'\n') == mesa['src/util/blake3/' + name]
    work = output / 'generator'; (work / 'bin').mkdir(parents=True)
    script = work / 'bin/git_sha1_gen.py'; script.write_bytes(mesa['bin/git_sha1_gen.py'])
    generated = []
    for label, override in [('empty', ''), ('pinned-commit', MESA_COMMIT)]:
        target = work / (label + '.h')
        command = [sys.executable, str(script.resolve()), '--output', str(target.resolve())]
        env = {'PATH': '/usr/bin:/bin', 'MESA_GIT_SHA1_OVERRIDE': override,
               'PYTHONDONTWRITEBYTECODE': '1'}
        result = subprocess.run(command, cwd=work, env=env, capture_output=True, text=True, timeout=30)
        (work / (label + '.log')).write_text(result.stdout + result.stderr)
        assert result.returncode == 0, 'Pinned generator failed'
        expected = ('#define MESA_GIT_SHA1 "' + (' (git-' + override[:10] + ')' if override else '') + '"').encode()
        assert target.read_bytes() == expected
        # Re-running equal generation must preserve the existing output's mtime.
        os.utime(target, ns=(1_000_000_000, 1_000_000_000))
        subprocess.run(command, cwd=work, env=env, capture_output=True, check=True, timeout=30)
        assert target.stat().st_mtime_ns == 1_000_000_000
        generated.append({'case': label, 'override': override, 'command': command,
                          'output_sha256': digest(expected), 'output': expected.decode(),
                          'repeat_preserved_mtime': True})
    actual = (sdk / 'godot-mesa/bin/git_sha1.h').read_bytes()
    check_generated_header((work / 'empty.h').read_bytes(), actual)
    # Meaningful negative controls use an unreviewed source token and real SDK
    # output corruption; these must not be absorbed by whitespace normalization.
    rejected = []
    for row in rows:
        name = row['file']
        try:
            check_derivation(name, upstream['c/' + name], mesa['src/util/blake3/' + name] + b'\nint unreviewed_change;\n')
        except AssertionError as error:
            assert 'Unreviewed BLAKE3 token difference' in str(error)
            rejected.append(name)
        else:
            raise AssertionError('Unreviewed source accepted')
    try:
        check_generated_header((work / 'empty.h').read_bytes(), actual + b'\n#define unreviewed_change 1\n')
    except AssertionError as error:
        assert 'Generated header differs from SDK' in str(error)
    else:
        raise AssertionError('Modified generated SDK header accepted')
    result = {'passed': True, 'license_review_complete': False, 'scope': __doc__,
              'audit_sha256': digest(Path(__file__).read_bytes()),
              'mesa_commit': MESA_COMMIT, 'blake3_commit': BLAKE3_COMMIT,
              'archive_sha256': {'mesa': MESA_SHA, 'blake3': BLAKE3_SHA, 'nir': NIR_SHA},
              'sdk': sdk_check, 'source_derivations': rows,
              'version_data': {'source_sha256': digest(mesa['VERSION']), 'sdk_equal': True},
              'generator_source_sha256': digest(script.read_bytes()),
              'upstream_invocation': "run_step bin 'git_sha1_gen.py --output $OUTDIR/git_sha1.h'",
              'generated_header_matches_sdk': True, 'generated_header_sha256': digest(actual),
              'generator_cases': generated, 'negative_source_controls': rejected,
              'modified_generated_header_rejected': True,
              'runtime_execution': False}
    (output / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: three reviewed source transformations, version data, pinned generator and SDK output; licenses remain open')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mesa-source', type=Path, required=True)
    p.add_argument('--blake3-source', type=Path, required=True)
    p.add_argument('--nir-source', type=Path, required=True)
    p.add_argument('--sdk-root', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    audit(args.mesa_source, args.blake3_source, args.nir_source, args.sdk_root, args.output)


if __name__ == '__main__':
    main()
