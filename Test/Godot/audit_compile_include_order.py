#!/usr/bin/env python3
"""Compare actual xmake per-file include search order with an audited SCons baseline.

Feed compile databases exported from all eleven Godot compilation targets (including the four codec object targets), excluding
only the final link anchor. This checks source multiplicity and include priority;
it does not claim complete compiler-option equivalence or runtime acceptance.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shlex

ROOT = ENGINE_ROOT


def arguments(entry):
    return entry.get('arguments') or shlex.split(entry['command'])


def includes(args):
    result = []
    index = 1
    while index < len(args):
        value = args[index]
        if value == '-I':
            index += 1
            result.append(args[index])
        elif value.startswith('-I'):
            result.append(value[2:])
        index += 1
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--xmake-db', type=Path, nargs='+', required=True)
    parser.add_argument('--generated-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    vendor = ROOT / 'Source/3rdParty/Godot'
    generated = args.generated_root.resolve()
    output = args.output.resolve()
    assert not output.exists(), 'Use a new report path to retain prior evidence'
    expected = Counter()
    for entry in json.loads(args.baseline.read_text()):
        file = Path(entry['file'])
        if file.is_absolute():
            file = file.relative_to(entry['directory'])
        source = file.as_posix()
        search = [os.path.normpath(p if Path(p).is_absolute() else str(vendor / p))
                  for p in includes(arguments(entry))]
        # Clang ignores subsequent copies of a directory. Do not let xmake's
        # reverse flag uniquing silently move a first include to a later slot.
        search = list(dict.fromkeys(search))
        if '.gen.' in source:
            search.append(str(vendor / file.parent))
        expected[(source, tuple(search))] += 1
    by_source = {}
    for key in expected:
        by_source.setdefault(key[0], []).append(key)
    actual = Counter()
    for db in args.xmake_db:
        for entry in json.loads(db.read_text()):
            file = Path(entry['file'])
            if not file.is_absolute():
                file = Path(entry['directory']) / file
            file = file.resolve()
            if file.is_relative_to(generated):
                source = file.relative_to(generated).as_posix()
            else:
                source = file.relative_to(vendor).as_posix()
            invocation = arguments(entry)
            assert all(not any(marker in flag for marker in ('@SDK@', '@CONFIG:', '@GODOT@')) for flag in invocation), ('Unexpanded SDK flag', file)
            search = [os.path.normpath(p if Path(p).is_absolute()
                                     else str(Path(entry['directory']) / p))
                      for p in includes(invocation)]
            matches = [key for key in by_source.get(source, [])
                       if search[-len(key[1]):] == list(key[1])]
            assert len(matches) == 1, ('Include order differs from SCons', source, search,
                                       by_source.get(source))
            key = matches[0]
            prefix = search[:-len(key[1])]
            assert all(Path(p) == vendor or Path(p).is_relative_to(generated) for p in prefix), (
                'Unaudited global include prefix', source, prefix)
            actual[key] += 1
    assert actual == expected, ('Source multiplicity differs', expected - actual, actual - expected)
    report = {
        'passed': True,
        'scope': 'Actual xmake compiler source multiplicity and per-source include suffix order '
                 'equal SCons after path normalization and first-occurrence deduplication. '
                 'Only vendor/codegen global prefixes allowed; full flags, header contents, '
                 'binary ABI and GPU acceptance require separate evidence.',
        'actions': sum(actual.values()),
        'baseline_sha256': digest(args.baseline),
        'compile_db_sha256': {str(p.resolve()): digest(p) for p in args.xmake_db},
        'auditor_sha256': digest(Path(__file__)),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print('Compiler include order: PASS;', report['actions'], 'actions')


if __name__ == '__main__':
    main()
