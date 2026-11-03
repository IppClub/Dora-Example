#!/usr/bin/env python3
"""Inspect final Apple image topology and selected dependency symbol visibility.

Name patterns identify candidates, not object-file provenance. Static visibility
does not prove ABI compatibility, runtime global-state isolation or size savings.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

from audit_macos_dependency_symbols import PATTERNS

ROOT = ENGINE_ROOT


def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def capture(command, output, compressed=False):
    data = subprocess.check_output(list(map(str, command)))
    if compressed:
        output.write_bytes(gzip.compress(data, mtime=0))
    else:
        output.write_bytes(data)
    return data.decode(), hashlib.sha256(data).hexdigest()


def inspect(path, label, expected_platform, output, runtime):
    before = sha(path)
    header = struct.unpack('<8I', path.open('rb').read(32))
    assert header[0] == 0xfeedfacf and header[1] == 0x100000c, 'Expected thin ARM64 Mach-O'
    assert header[3] == (6 if runtime else 2), 'Expected dynamic runtime image or executable host'
    assert header[6] & 0x80, 'Expected two-level Mach-O namespace'
    build, _ = capture(['xcrun', 'vtool', '-show-build', path], output / (label + '-build.txt'))
    assert re.search(r'^\s*platform\s+' + expected_platform + r'\s*$', build, re.M), 'Unexpected Apple platform: ' + label
    symbols, symbols_hash = capture(['xcrun', 'nm', '-m', path], output / (label + '-symbols.txt.gz'), True)
    exports, _ = capture(['xcrun', 'nm', '-gU', path], output / (label + '-exports.txt.gz'), True)
    imports, _ = capture(['xcrun', 'nm', '-um', path], output / (label + '-imports.txt'))
    dependencies, _ = capture(['otool', '-L', path], output / (label + '-dependencies.txt'))
    code = {}
    for line in symbols.splitlines():
        match = re.match(r'^[0-9a-fA-F]+\s+\(__TEXT,__text\)\s+(.+?)\s+(\S+)$', line)
        if match:
            code[match[2]] = match[1]
    assert code, 'No defined code symbols'
    exported = {line.split()[-1] for line in exports.splitlines() if line.strip()}
    imported = set()
    import_bindings = {}
    for line in imports.splitlines():
        if not line.strip():
            continue
        match = re.search(r'\(undefined\)\s+.*?\bexternal\s+(\S+)', line)
        assert match, 'Unrecognized undefined-symbol record: ' + line
        imported.add(match[1])
        import_bindings[match[1]] = line.strip()
    if runtime:
        expected = set((ROOT / 'Source/3rdParty/Godot/dora_bridge.exports').read_text().split())
        assert exported == expected, 'Runtime exports differ from bridge-only contract'
        assert '@rpath/DoraGodot.framework/DoraGodot' in dependencies or expected_platform == 'MACOS'
    assert sha(path) == before, 'Image changed during audit'
    return {'path': str(path), 'sha256': before, 'file_type': 'MH_DYLIB' if runtime else 'MH_EXECUTE',
            'two_level_namespace': True, 'platform': expected_platform,
            'defined_code_symbols': len(code), 'export_count': len(exported),
            'undefined_symbol_count': len(imported),
            'nm_symbols_stdout_sha256': symbols_hash}, code, exported, import_bindings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--host', type=Path)
    parser.add_argument('--platform', choices=('MACOS', 'IOS', 'IOSSIMULATOR'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    library, code, exports, imports = inspect(args.runtime.resolve(), 'runtime', args.platform, args.output, True)
    host = None
    host_code = {}
    if args.host:
        host, host_code, _, _ = inspect(args.host.resolve(), 'host', args.platform, args.output, False)
    rows = {}
    for name, pattern in PATTERNS.items():
        own = {symbol for symbol in code if re.search(pattern, symbol)}
        clients = {symbol for symbol in host_code if re.search(pattern, symbol)}
        rows[name] = {'runtime_defined_code_names': sorted(own),
                      'host_defined_code_names': sorted(clients),
                      'common_defined_code_names': sorted(own & clients),
                      'runtime_visibility': dict(Counter(code[symbol] for symbol in own)),
                      'runtime_export_names': sorted(symbol for symbol in exports if re.search(pattern, symbol)),
                      'runtime_import_names': sorted(symbol for symbol in imports if re.search(pattern, symbol)),
                      'runtime_import_bindings': {symbol: imports[symbol] for symbol in imports if re.search(pattern, symbol)}}
        assert not rows[name]['runtime_export_names'], 'Private dependency escaped bridge export contract'
    nm = Path(subprocess.check_output(['xcrun', '--find', 'nm'], text=True).strip())
    report = {'passed': True, 'complete': False, 'scope': __doc__,
              'audit_script_sha256': sha(Path(__file__)), 'runtime': library, 'host': host,
              'nm_tool': {'path': str(nm), 'sha256': sha(nm)},
              'dependencies': rows, 'runtime_execution': False,
              'runtime_global_state_isolation_proven': False, 'final_object_origin_proven': False}
    (args.output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({name: {'runtime': len(row['runtime_defined_code_names']),
                            'host': len(row['host_defined_code_names']),
                            'common': len(row['common_defined_code_names'])}
                      for name, row in rows.items()}, indent=2))


if __name__ == '__main__':
    main()
