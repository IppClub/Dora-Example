#!/usr/bin/env python3
"""Compare defined Dora symbols with live symbols in a diagnostic Godot link map.

A map must describe its exact library. This does not infer equivalence to another
stripped production binary or establish ABI compatibility or size savings.
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
import struct

PATTERNS = {
    'ogg': r'^_ogg_',
    'theora': r'^_(?:th_|theora_|oc_)',
    'zlib': r'^_(?:inflate|deflate|adler32|crc32|compress|uncompress|zlib|gz)[A-Za-z0-9_]*$',
    'sdl': r'^_SDL_',
    'vorbis': r'^_(?:ov_|vorbis_)',
    'stb_vorbis': r'^_stb_vorbis_',
    'jolt': r'^__Z.*3JPH',
    'glslang': r'^(?:__Z.*7glslang|_glslang_)',
    'spirv_cross': r'^__Z.*11spirv_cross',
    'astcenc': r'^(?:_astcenc_|__Z[0-9]+astcenc_)',
    'tinyexr': r'^(?:__Z.*7tinyexr|_(?:Load|Save|Parse|Free|Init|Is|Set)[A-Za-z0-9_]*EXR[A-Za-z0-9_]*$)',
}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def macho_text(path):
    data = path.read_bytes()
    assert struct.unpack_from('<II', data) == (0xfeedfacf, 0x100000c), 'Expected thin ARM64 Mach-O'
    offset = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, length = struct.unpack_from('<II', data, offset)
        if command == 0x19:
            for index in range(struct.unpack_from('<I', data, offset + 64)[0]):
                section = offset + 72 + 80 * index
                name = data[section:section + 16].rstrip(b'\0')
                segment = data[section + 16:section + 32].rstrip(b'\0')
                if name == b'__text' and segment == b'__TEXT':
                    address, size, file_offset = struct.unpack_from('<QQI', data, section + 32)
                    assert file_offset + size <= len(data)
                    return address, data[file_offset:file_offset + size]
        offset += length
    raise ValueError('Mach-O text section missing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dora', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--link-map', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--production-runtime', type=Path, help='Compare exact code ranges at matching text addresses, without asserting whole-map equivalence')
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve prior evidence; use a fresh output directory'
    text = args.link_map.read_bytes().decode('utf-8', errors='surrogateescape')
    recorded = re.search(r'^# Path: (.+)$', text, re.M)
    assert recorded and Path(recorded[1]).resolve() == args.godot.resolve(), 'Link map describes another library'
    assert '# Arch: arm64' in text
    profile_path = ENGINE_ROOT / 'Projects/xmake/godot/macos_arm64_sources.lua'
    from audit_dependency_sources import manifest_actions
    actions = manifest_actions(profile_path.read_text())
    dependency_names = {'ogg':'libogg', 'theora':'libtheora', 'zlib':'zlib',
                        'sdl':'sdl', 'vorbis':'libvorbis', 'jolt':'jolt_physics',
                        'glslang':'glslang', 'spirv_cross':'spirv-cross',
                        'astcenc':'astcenc', 'tinyexr':'tinyexr'}
    owners = {name: {Path(action['source']).name + '.o' for action in actions
                     if action['source'].startswith('thirdparty/' + dependency + '/')}
              for name, dependency in dependency_names.items()}
    paths = (args.dora, args.godot, args.link_map, profile_path)
    if args.production_runtime:
        paths += (args.production_runtime,)
    before = {str(path.resolve()): digest(path) for path in paths}
    args.output.mkdir(parents=True)
    symbols = subprocess.check_output(['xcrun', 'nm', '-P', str(args.dora.resolve())], text=True)
    (args.output / 'dora-nm.txt').write_text(symbols)
    defined = set()
    for line in symbols.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[1] in 'TtDdSsBbAaCc':
            defined.add(fields[0])
    objects = {int(index): name for index, name in re.findall(r'^\[\s*(\d+)\] (.+)$', text, re.M)}
    live = text.split('# Symbols:\n', 1)[1].split('# Dead Stripped Symbols:', 1)[0]
    live_symbols = re.findall(r'^(0x[0-9A-Fa-f]+)\s+(0x[0-9A-Fa-f]+)\s+\[\s*(\d+)\]\s+(.+)$', live, re.M)
    assert live_symbols and defined
    rows = {}
    for name, pattern in PATTERNS.items():
        dora = sorted(symbol for symbol in defined if re.search(pattern, symbol))
        godot = [{'symbol': symbol, 'address': address, 'bytes': int(size, 16),
                  'object': objects[int(index)]} for address, size, index, symbol in live_symbols
                 if re.search(pattern, symbol) and (name not in owners or
                     objects[int(index)].rsplit('(',1)[-1].removesuffix(')') in owners[name])]
        rows[name] = {'dora_defined_names': dora, 'godot_live_symbols': godot,
                      'common_defined_names': sorted(set(dora) & {entry['symbol'] for entry in godot})}
    production = None
    if args.production_runtime:
        address, diagnostic_code = macho_text(args.godot)
        other_address, production_code = macho_text(args.production_runtime)
        assert address == other_address and len(diagnostic_code) == len(production_code), 'Text layout differs; exact range comparison unavailable'
        production = {'scope': 'Only selected mapped code ranges compared at identical text addresses; no complete production-map or runtime equivalence',
                      'text_address': address, 'text_bytes': len(diagnostic_code), 'dependencies': {}}
        for dependency, row in rows.items():
            checked, skipped, mismatches = [], [], []
            for entry in row['godot_live_symbols']:
                start = int(entry['address'], 16) - address
                size = entry['bytes']
                if size <= 0 or start < 0 or start + size > len(diagnostic_code):
                    skipped.append(entry['symbol'])
                    continue
                identical = diagnostic_code[start:start + size] == production_code[start:start + size]
                (checked if identical else mismatches).append(entry['symbol'])
            production['dependencies'][dependency] = {
                'matching_code_symbols': checked, 'mismatched_code_symbols': mismatches,
                'uncompared_noncode_or_zero_symbols': skipped,
                'common_dora_names_with_matching_production_code': sorted(set(row['dora_defined_names']) & set(checked))}
    dependencies = {}
    for name, path in [('dora', args.dora), ('godot', args.godot)]:
        raw = subprocess.check_output(['xcrun', 'otool', '-L', str(path.resolve())], text=True)
        (args.output / (name + '-otool.txt')).write_text(raw)
        dependencies[name] = raw.splitlines()[1:]
    assert all(digest(Path(path)) == expected for path, expected in before.items()), 'Inputs changed during audit'
    report = {'passed': True, 'scope': 'Defined symbol overlap in this exact Dora executable and diagnostic Godot dylib/map only; no ABI compatibility, production equivalence, runtime sharing or package-size acceptance',
              'audit_script_sha256': digest(Path(__file__)),
              'artifacts_sha256': before, 'symbols': rows, 'production_code_ranges': production, 'dynamic_dependencies': dependencies,
              'godot_owner_filter': 'Archive member basename must occur in this dependency macOS source manifest; same-name members can remain ambiguous',
              'raw_nm_sha256': digest(args.output / 'dora-nm.txt')}
    (args.output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({name: {'dora': len(row['dora_defined_names']), 'godot': len(row['godot_live_symbols']),
                             'common': len(row['common_defined_names'])} for name, row in rows.items()}))


if __name__ == '__main__':
    main()
