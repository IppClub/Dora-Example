#!/usr/bin/env python3
"""Audit exact AMD64 WGL PE import/export boundaries without loading the images.

Stripped internal code is unknown, not absent. Name-pattern matches do not prove
ABI compatibility, archive-member attribution, runtime ownership or size savings.
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

from audit_macos_dependency_symbols import PATTERNS
from verify_package import verify

# Cover both Itanium (MinGW) and MSVC C++ names. These remain discovery patterns,
# not exhaustive attribution of all dependency functions.
MSVC_PATTERNS = {
    'jolt': r'^\?.*@JPH@@',
    'glslang': r'^\?.*@glslang@@',
    'spirv_cross': r'^\?.*@spirv_cross@@',
    'astcenc': r'^\?astcenc_',
    'tinyexr': r'^\?(?:(?:Load|Save|Parse|Free|Init|Is|Set)[A-Za-z0-9_]*EXR|.*@tinyexr@@)',
}


def candidate(dependency, symbol):
    return bool(re.search(PATTERNS[dependency], '_' + symbol) or
                (dependency in MSVC_PATTERNS and re.search(MSVC_PATTERNS[dependency], symbol)))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def pe_header(path, dll):
    data = path.read_bytes()
    assert data[:2] == b'MZ', 'Expected DOS header'
    pe = struct.unpack_from('<I', data, 60)[0]
    assert data[pe:pe + 4] == b'PE\0\0', 'Expected PE signature'
    machine, sections, _, symbols_at, symbols, optional_size, flags = struct.unpack_from('<HHIIIHH', data, pe + 4)
    assert machine == 0x8664, 'Expected AMD64 image'
    assert bool(flags & 0x2000) == dll, 'Wrong executable/DLL kind'
    opt = pe + 24
    assert optional_size >= 240 and opt + optional_size + sections * 40 <= len(data)
    assert struct.unpack_from('<H', data, opt)[0] == 0x20b, 'Expected PE32+'
    count = struct.unpack_from('<I', data, opt + 108)[0]
    assert count >= 16, 'Incomplete PE data directory'
    directories = [struct.unpack_from('<II', data, opt + 112 + i * 8) for i in range(16)]
    assert directories[13] == (0, 0), 'Delay imports need a separate audit; refusing incomplete coverage'
    assert directories[14] == (0, 0), 'Unexpected managed image'
    return {'machine': 'AMD64', 'dll': dll, 'sections': sections,
            'coff_symbol_table_offset': symbols_at, 'coff_symbol_count': symbols,
            'internal_symbol_coverage': 'unknown' if symbols == 0 else 'not audited',
            'delay_import_directory': list(directories[13]), 'clr_directory': list(directories[14]),
            'export_directory': list(directories[0])}


def parse_tables(raw):
    imports = {}
    for block in re.findall(r'^Import \{\n(.*?)^\}', raw, re.M | re.S):
        names = re.findall(r'^  Name: (.+)$', block, re.M)
        assert len(names) == 1 and names[0].lower() not in imports, 'Ambiguous DLL import'
        symbols = re.findall(r'^  Symbol: (.*?) \((\d+)\)$', block, re.M)
        assert len(symbols) == len(re.findall(r'^  Symbol:', block, re.M)), 'Unparsed import symbol'
        assert symbols, 'Empty import block'
        # LLVM represents ordinal-only imports as an empty name plus ordinal.
        imports[names[0].lower()] = [{'name': name or None, 'hint_or_ordinal': int(hint)} for name, hint in symbols]
    exports = []
    for block in re.findall(r'^Export \{\n(.*?)^\}', raw, re.M | re.S):
        ordinal = re.findall(r'^  Ordinal: (\d+)$', block, re.M)
        name = re.findall(r'^  Name: (.*)$', block, re.M)
        rva = re.findall(r'^  RVA: (0x[0-9A-Fa-f]+)$', block, re.M)
        assert len(ordinal) == len(name) == len(rva) == 1, 'Unparsed export'
        exports.append({'ordinal': int(ordinal[0]), 'name': name[0] or None, 'rva': rva[0]})
    assert len(imports) == len(re.findall(r'^Import \{', raw, re.M)) and imports
    assert len(exports) == len(re.findall(r'^Export \{', raw, re.M))
    return imports, exports


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--dora', required=True, type=Path)
    p.add_argument('--package', required=True, type=Path)
    p.add_argument('--readobj', required=True, type=Path)
    p.add_argument('--accepted-inputs', required=True, type=Path, help='Retained WGL input-verification.json')
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    assert not a.output.exists(), 'Use a fresh evidence directory'
    verify(a.package)
    manifest = json.loads((a.package/'manifest.json').read_text())
    assert manifest['graphics_backend'] == 'wgl' and manifest['build_target'] == 'template_release'
    assert manifest['architectures'] == ['x86_64']
    runtime = a.package/manifest['library']
    receipt = json.loads(a.accepted_inputs.read_text())
    assert receipt['passed'] and receipt['runtime_sha256'] == digest(runtime), 'Runtime is not the accepted image'
    # Receipt keys retain the original Windows staging paths. Require the exact
    # ordinary-host entry, rather than matching arbitrary strings in the report.
    host_key = 'build\\windows\\x64\\debug\\Dora.exe'
    host_hashes = receipt.get('hosts', {})
    assert host_hashes.get(host_key) == digest(a.dora), 'Dora is not the accepted ordinary host'
    paths = [a.dora, runtime, a.package/'manifest.json', a.accepted_inputs, a.readobj,
             Path(__file__), Path(__file__).with_name('audit_macos_dependency_symbols.py')]
    before = {str(path.resolve()): digest(path) for path in paths}
    a.output.mkdir(parents=True)
    images = {}
    for name, path, dll in [('dora', a.dora, False), ('godot', runtime, True)]:
        header = pe_header(path, dll)
        command = [str(a.readobj), '--file-headers', '--coff-imports', '--coff-exports', str(path)]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        assert not result.stderr.strip(), result.stderr
        raw_path = a.output/(name+'-readobj.txt'); raw_path.write_text(result.stdout)
        imports, exports = parse_tables(result.stdout)
        start, size = header['export_directory']
        assert all(not start <= int(e['rva'], 16) < start + size for e in exports), 'Forwarded exports need separate provider audit'
        assert f'SymbolCount: {header["coff_symbol_count"]}' in result.stdout
        images[name] = {'sha256': digest(path), 'header': header, 'command': command,
                        'imports': imports, 'exports': exports, 'raw_sha256': digest(raw_path)}
    expected = {'AmdPowerXpressRequestHighPerformance', 'NoHotPatch', 'NvOptimusEnablement',
                'dora_godot_get_api', 'dora_godot_get_audio_api', 'dora_godot_get_gl_api',
                'dora_godot_get_gl_targets_api', 'dora_godot_get_ime_api', 'dora_godot_get_output_api',
                'libgodot_create_godot_instance', 'libgodot_destroy_godot_instance'}
    actual = [entry['name'] for entry in images['godot']['exports']]
    assert len(actual) == len(expected) and set(actual) == expected, 'Unexpected WGL export contract'
    # Optional LibGodot is dynamically loaded by the host, not a PE static import.
    assert runtime.name.lower() not in images['dora']['imports'], 'Godot became a mandatory PE import'
    rows = {}
    for dep, pattern in PATTERNS.items():
        rows[dep] = {}
        for name, image in images.items():
            rows[dep][name] = {
                'named_exports': [e['name'] for e in image['exports'] if e['name'] and candidate(dep, e['name'])],
                'named_imports': {dll: [s['name'] for s in symbols if s['name'] and candidate(dep, s['name'])]
                                  for dll, symbols in image['imports'].items()
                                  if any(s['name'] and candidate(dep, s['name']) for s in symbols)},
                'internal_definitions': 'unknown; stripped or unaudited COFF symbol table'}
    assert all(digest(Path(path)) == value for path, value in before.items()), 'Audit input changed'
    report = {'passed': True, 'complete': False, 'scope': __doc__, 'inputs_sha256': before,
              'host_configuration': 'exact accepted ordinary host from build/windows/x64/debug; not a Release host claim',
              'images': images, 'dependency_name_patterns': rows,
              'limitations': ['No internal symbol absence, link-map attribution, ABI, removable-byte or runtime-sharing claim',
                              'Ordinal imports retained without guessed names', 'No delay imports or forwarded exports present in either image',
                              'MSVC and Itanium patterns are candidate discovery, not exhaustive ownership attribution']}
    (a.output/'verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({name: {'import_dlls': len(image['imports']), 'exports': len(image['exports']),
                             'coff_symbols': image['header']['coff_symbol_count']} for name, image in images.items()}))


if __name__ == '__main__':
    main()
