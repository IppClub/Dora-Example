#!/usr/bin/env python3
"""Audit retained ELF symbols against the exact native libraries in an Android APK.

Matching names are candidate overlap, not ABI compatibility, symbol binding,
archive-member provenance, runtime sharing, or removable binary size.
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
import struct
import subprocess
import zipfile

from audit_macos_dependency_symbols import PATTERNS


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def allocated_sections(path):
    """Read bytes mapped by SHF_ALLOC, excluding NOBITS contents, from ELF64 LE."""
    data = path.read_bytes()
    assert data[:6] == b'\x7fELF\x02\x01', 'Expected ELF64 little endian'
    assert struct.unpack_from('<H', data, 18)[0] == 183, 'Expected AArch64'
    offset = struct.unpack_from('<Q', data, 40)[0]
    entry_size, count, names_index = struct.unpack_from('<HHH', data, 58)
    assert entry_size == 64 and count and names_index < count
    assert offset + count * entry_size <= len(data)
    headers = [struct.unpack_from('<IIQQQQIIQQ', data, offset + i * entry_size) for i in range(count)]
    names_header = headers[names_index]
    names = data[names_header[4]:names_header[4] + names_header[5]]
    result = {}
    for name_offset, kind, flags, address, file_offset, size, _, _, alignment, _ in headers:
        if not flags & 2:
            continue
        end = names.index(b'\0', name_offset)
        name = names[name_offset:end].decode('ascii')
        assert name not in result, 'Duplicate allocated section name'
        if kind != 8:
            assert file_offset + size <= len(data)
        result[name] = {'type': kind, 'flags': flags, 'address': address,
                        'bytes': size, 'alignment': alignment,
                        'content_sha256': None if kind == 8 else hashlib.sha256(data[file_offset:file_offset + size]).hexdigest()}
    assert '.text' in result
    return result


def run(tool, arguments, output):
    with output.open('w') as stream:
        subprocess.run([str(tool), *map(str, arguments)], check=True, stdout=stream, stderr=subprocess.PIPE, text=True)
    return output.read_text()


def defined_names(raw):
    result = {}
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] in {'T', 't', 'W', 'w'}:
            result.setdefault(fields[0], []).append({'kind': fields[1], 'address': fields[2], 'bytes': int(fields[3], 16)})
    assert result, 'No retained function symbols; a stripped file cannot prove absence'
    return result


def dynamic_names(raw):
    defined, undefined = set(), set()
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) >= 8 and re.fullmatch(r'\d+:', fields[0]):
            # Drop symbol-version suffixes; retain the original readelf output.
            name = fields[7].split('@', 1)[0]
            (undefined if fields[6] == 'UND' else defined).add(name)
    assert defined, 'No defined dynamic symbols'
    return defined, undefined


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--dora', required=True, type=Path, help='Retained unstripped libmain.so')
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--tool-dir', required=True, type=Path, help='Actual NDK LLVM bin directory')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve evidence; use a fresh directory'
    paths = [args.apk, args.dora, args.godot, args.tool_dir/'llvm-nm', args.tool_dir/'llvm-readelf',
             Path(__file__), Path(__file__).with_name('audit_macos_dependency_symbols.py')]
    before = {str(p.resolve()): digest(p) for p in paths}
    args.output.mkdir(parents=True)
    with zipfile.ZipFile(args.apk) as apk:
        for name in ('libmain.so', 'libgodot_android.so'):
            member = 'lib/arm64-v8a/' + name
            assert apk.namelist().count(member) == 1
            (args.output / ('apk-' + name)).write_bytes(apk.read(member))
    providers = {}
    symbols = {}
    dynamic_symbols = {}
    for name, retained, packaged in [('dora', args.dora, args.output/'apk-libmain.so'),
                                     ('godot', args.godot, args.output/'apk-libgodot_android.so')]:
        sections = allocated_sections(retained)
        packaged_sections = allocated_sections(packaged)
        comparison = {'retained': sections, 'apk': packaged_sections,
                      'identical': sections == packaged_sections}
        (args.output/(name+'-allocated-sections.json')).write_text(json.dumps(comparison, indent=2)+'\n')
        assert comparison['identical'], name + ' retained code/data is not the APK image'
        raw = run(args.tool_dir/'llvm-nm', ['--defined-only', '--format=posix', retained], args.output/(name+'-nm.txt'))
        symbols[name] = defined_names(raw)
        dynamic = run(args.tool_dir/'llvm-readelf', ['--dynamic', '--dyn-syms', '--wide', retained], args.output/(name+'-dynamic.txt'))
        dynamic_symbols[name] = dynamic_names(dynamic)
        providers[name] = {'retained_sha256': digest(retained), 'apk_library_sha256': digest(packaged),
                           'all_allocated_sections_identical': True, 'allocated_sections': len(sections),
                           'needed': re.findall(r'\(NEEDED\).*?\[(.*?)\]', dynamic),
                           'raw_nm_sha256': digest(args.output/(name+'-nm.txt'))}
    rows = {}
    for dependency, pattern in PATTERNS.items():
        # Shared patterns use Mach-O's leading underscore, which ELF omits.
        selected = {provider: {symbol: entries for symbol, entries in table.items()
                               if re.search(pattern, '_' + symbol)} for provider, table in symbols.items()}
        rows[dependency] = {'dora_functions': selected['dora'], 'godot_functions': selected['godot'],
                            'common_defined_names': sorted(selected['dora'].keys() & selected['godot'].keys())}
        rows[dependency]['dynamic_symbols'] = {
            provider: {
                'defined': sorted(symbol for symbol in defined if re.search(pattern, '_' + symbol)),
                'undefined': sorted(symbol for symbol in undefined if re.search(pattern, '_' + symbol)),
                'local_function_names': sorted(symbol for symbol, entries in selected[provider].items()
                                               if all(entry['kind'] == 't' for entry in entries))}
            for provider, (defined, undefined) in dynamic_symbols.items()}
    assert all(digest(Path(path)) == value for path, value in before.items()), 'Audit input changed'
    result = {'passed': True, 'complete': False, 'scope': __doc__, 'inputs_sha256': before,
              'production_identity': 'All SHF_ALLOC section metadata and bytes match the exact APK; NOBITS metadata compared without file bytes',
              'symbol_attribution': 'Name-pattern candidates only; no exact archive-member provenance or dynamic binding proof',
              'providers': providers, 'dependencies': rows}
    (args.output/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: {'dora': len(v['dora_functions']), 'godot': len(v['godot_functions']),
                           'common': len(v['common_defined_names'])} for k,v in rows.items()}, indent=2))


if __name__ == '__main__':
    main()
