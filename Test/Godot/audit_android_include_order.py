#!/usr/bin/env python3
"""Check Android include order after proving a duplicate NDK include is inert.

This compares current exported compiler inputs, not historical execution,
complete option equivalence, binary ABI, or runtime acceptance.
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
import subprocess
import sys

from probe_dependency_compile_inputs import base_command


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def without_ndk_include(argv, directory):
    result = []
    index = 0
    removed = 0
    while index < len(argv):
        if argv[index] == '-I' and index+1 < len(argv) and argv[index+1] == directory:
            index += 2
            removed += 1
        elif argv[index] == '-I' + directory:
            index += 1
            removed += 1
        else:
            result.append(argv[index])
            index += 1
    assert removed == 1, ('Expected exactly one explicit NDK architecture include', removed)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--xmake-db', required=True, type=Path, nargs='+')
    parser.add_argument('--generated-root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve old reports; use a fresh directory'
    folder = args.output.resolve()
    folder.mkdir(parents=True)
    inputs = [args.baseline, *args.xmake_db, Path(__file__),
              Path(__file__).with_name('probe_dependency_compile_inputs.py'),
              Path(__file__).with_name('audit_compile_include_order.py')]
    before = {str(p.resolve()): digest(p) for p in inputs}
    groups, derived, tools = {}, [], {}
    for db_index, db in enumerate(args.xmake_db):
        entries = json.loads(db.read_text())
        normalized = []
        for entry in entries:
            argv, cwd, source, _ = base_command(entry)
            assert source.suffix in ('.c', '.cc', '.cpp'), ('Unaudited language', source)
            language = 'c' if source.suffix == '.c' else 'c++'
            sdk = [arg.split('=', 1)[1] for arg in argv if arg.startswith('--sysroot=')]
            assert len(sdk) == 1
            include = str(Path(sdk[0])/'usr/include/aarch64-linux-android')
            assert Path(include).is_dir()
            reduced = without_ndk_include(argv, include)
            key = hashlib.sha256(json.dumps([argv, str(cwd), language]).encode()).hexdigest()
            if key not in groups:
                group_folder = folder/key
                group_folder.mkdir()
                searches = {}
                commands = {}
                for name, command in (('actual', argv), ('without-explicit-ndk-include', reduced)):
                    command = command + ['-E', '-v', '-x', language, '/dev/null']
                    process = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
                    (group_folder/(name+'.stderr')).write_text(process.stderr)
                    assert process.returncode == 0, process.stderr
                    match = re.search(r'#include <\.\.\.> search starts here:\n(.*?)End of search list\.', process.stderr, re.S)
                    assert match, 'Compiler search list absent'
                    searches[name] = match[1].splitlines()
                    commands[name] = command
                assert searches['actual'] == searches['without-explicit-ndk-include'], ('NDK -I changes actual priority', source)
                assert any(line.strip() == include for line in searches['actual'])
                groups[key] = {'language': language, 'cwd': str(cwd), 'explicit_ndk_include': include,
                               'searches': searches, 'commands': commands, 'actions': 0}
                compiler = Path(argv[0]).resolve()
                tools[str(compiler)] = digest(compiler)
            groups[key]['actions'] += 1
            raw = entry.get('arguments')
            assert raw is not None, 'Expected xmake argument arrays'
            updated = dict(entry, arguments=without_ndk_include(raw, include))
            updated.pop('command', None)
            normalized.append(updated)
        target = folder/f'normalized-{db_index}.json'
        target.write_text(json.dumps(normalized, indent=2)+'\n')
        derived.append(target)
    command = [sys.executable, str(Path(__file__).with_name('audit_compile_include_order.py').resolve()),
               '--baseline', str(args.baseline.resolve()), '--xmake-db', *map(str, derived),
               '--generated-root', str(args.generated_root.resolve()), '--output', str(folder/'structural-verification.json')]
    with (folder/'structural.log').open('w') as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    structural = json.loads((folder/'structural-verification.json').read_text())
    assert all(digest(Path(p)) == value for p,value in before.items())
    assert all(digest(Path(p)) == value for p,value in tools.items())
    result = {'passed': True, 'complete': False, 'scope': __doc__, 'inputs_sha256': before,
              'compiler_sha256': tools, 'groups': groups, 'actions': structural['actions'],
              'normalization': 'Only remove the exact NDK architecture -I after actual compiler search equality is proven for every flag/language group',
              'structural_command': command}
    (folder/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(f'PASS: {result["actions"]} include orders, {len(groups)} effective compiler flag/language groups')


if __name__ == '__main__':
    main()
