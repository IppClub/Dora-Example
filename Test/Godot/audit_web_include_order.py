#!/usr/bin/env python3
"""Audit Web include order, proving SCons's explicit SDK include is redundant.

Current compiler search and source/include multiplicity only; not complete
compiler-option equivalence, historical execution or browser acceptance.
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
import re
import shlex
import subprocess
import sys


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--xmake-db', required=True, type=Path, nargs='+')
    parser.add_argument('--compiler', required=True, type=Path, help='Exact emcc from the production SDK')
    parser.add_argument('--generated-root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence directory'
    folder = args.output.resolve()
    folder.mkdir(parents=True)
    compiler_dir = args.compiler.absolute().parent
    sdk_include = compiler_dir/'cache/sysroot/include'
    assert args.compiler.is_file() and sdk_include.is_dir(), 'Expected the actual production SDK include directory'
    inputs = [args.baseline, *args.xmake_db, args.compiler, compiler_dir/'em++', Path(__file__),
              Path(__file__).with_name('audit_compile_include_order.py')]
    clang = compiler_dir.parent/'bin/clang'
    assert clang.is_file()
    inputs.append(clang)
    before = {str(p.absolute()): digest(p) for p in inputs}
    groups, normalized = {}, []
    for entry in json.loads(args.baseline.read_text()):
        raw = entry.get('arguments') or shlex.split(entry['command'])
        name = Path(raw[0]).name
        assert name in ('emcc', 'em++'), ('Unsupported compiler', name)
        compiler = str(compiler_dir/name)
        argv, index = [compiler], 1
        while index < len(raw):
            arg = raw[index]
            assert not arg.startswith(('@', '-Wp,', '-save-temps'))
            if arg in ('-o', '-MF', '-MT', '-MQ', '-MJ'):
                index += 2
                continue
            if arg not in ('-c', '-MD', '-MMD', '-MP') and arg != entry['file']:
                argv.append(arg)
            index += 1
        invalid = '-I' + str(sdk_include)
        assert argv.count(invalid) == 1
        reduced = [arg for arg in argv if arg != invalid]
        language = 'c++' if name == 'em++' else 'c'
        key = hashlib.sha256(json.dumps([argv, entry['directory'], language]).encode()).hexdigest()
        if key not in groups:
            sub = folder/key
            sub.mkdir()
            searches, commands = {}, {}
            for mode, command in (('actual', argv), ('without-explicit-sdk-include', reduced)):
                command = command + ['-E', '-v', '-x', language, '/dev/null']
                p = subprocess.run(command, cwd=entry['directory'], capture_output=True, text=True)
                (sub/(mode+'.stderr')).write_text(p.stderr)
                assert p.returncode == 0, p.stderr
                match = re.search(r'#include <\.\.\.> search starts here:\n(.*?)End of search list\.', p.stderr, re.S)
                assert match, 'Compiler include search absent'
                searches[mode] = match[1].splitlines()
                commands[mode] = command
            assert searches['actual'] == searches['without-explicit-sdk-include']
            assert any(line.strip() == str(sdk_include) for line in searches['actual'])
            groups[key] = {'language': language, 'commands': commands, 'searches': searches, 'actions': 0}
        groups[key]['actions'] += 1
        normalized.append(dict(entry, arguments=[compiler, *[arg for arg in raw[1:] if arg != invalid]]))
        normalized[-1].pop('command', None)
    normalized_path = folder/'baseline-normalized.json'
    normalized_path.write_text(json.dumps(normalized, indent=2)+'\n')
    command = [sys.executable, str(Path(__file__).with_name('audit_compile_include_order.py').resolve()),
               '--baseline', str(normalized_path), '--xmake-db', *[str(p.resolve()) for p in args.xmake_db],
               '--generated-root', str(args.generated_root.resolve()), '--output', str(folder/'structural-verification.json')]
    with (folder/'structural.log').open('w') as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    structural = json.loads((folder/'structural-verification.json').read_text())
    assert all(digest(Path(p)) == value for p,value in before.items())
    report = {'passed': True, 'complete': False, 'scope': __doc__, 'inputs_sha256': before,
              'normalized_sdk_include': str(sdk_include), 'groups': groups,
              'compiler_version': subprocess.check_output([str(args.compiler), '--version'], text=True),
              'actions': structural['actions'], 'structural_command': command}
    (folder/'verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'PASS: {report["actions"]} Web include orders, {len(groups)} actual compiler flag/language groups')


if __name__ == '__main__':
    main()
