#!/usr/bin/env python3
"""Inspect final Linux ELF images and selected dependency code-symbol privacy.

Names identify candidates, not archive provenance, ABI compatibility, runtime
binding/global-state isolation, sharing or removable binary size. No ELF code
is executed. An unstripped symbol table is required to inspect private code.
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
from pathlib import Path
import re
import struct

from audit_macos_dependency_symbols import PATTERNS

ROOT = ENGINE_ROOT
MACHINES = {'arm64': 183, 'x86_64': 62}
BINDINGS = {0: 'LOCAL', 1: 'GLOBAL', 2: 'WEAK', 10: 'GNU_UNIQUE'}
VISIBILITY = {0: 'DEFAULT', 1: 'INTERNAL', 2: 'HIDDEN', 3: 'PROTECTED'}


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def cstring(data, start):
    assert 0 <= start < len(data), 'String offset outside table'
    return data[start:data.index(b'\0', start)].decode('utf-8', errors='surrogateescape')


def image(path, architecture, runtime, require_symbols=True):
    before = digest(path)
    data = path.read_bytes()
    assert data[:7] == b'\x7fELF\x02\x01\x01', 'Expected ELF64 little endian'
    kind, machine = struct.unpack_from('<HH', data, 16)
    assert machine == MACHINES[architecture], 'ELF architecture mismatch'
    assert kind in ((3,) if runtime else (2, 3)), 'Unexpected ELF image type'
    phoff, shoff = struct.unpack_from('<QQ', data, 32)
    phsize, phcount, shsize, shcount, strindex = struct.unpack_from('<HHHHH', data, 54)
    assert phsize == 56 and shsize == 64 and shcount and strindex < shcount
    assert phoff + phcount * phsize <= len(data) and shoff + shcount * shsize <= len(data)
    interpreter = None
    for i in range(phcount):
        ph = struct.unpack_from('<IIQQQQQQ', data, phoff + i * phsize)
        if ph[0] == 3:
            interpreter = cstring(data, ph[2])
    assert interpreter is None if runtime else interpreter is not None, 'ELF runtime/host role mismatch'
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + i * shsize) for i in range(shcount)]
    for section in sections:
        assert section[1] == 8 or section[4] + section[5] <= len(data), 'Truncated ELF section'
    names_section = sections[strindex]
    section_names = data[names_section[4]:names_section[4] + names_section[5]]
    names = [cstring(section_names, s[0]) for s in sections]
    if require_symbols:
        assert any(s[1] == 2 for s in sections), 'Retained symbol table missing; stripped images cannot prove private-code absence'
    allocated = {}
    for name, section in zip(names, sections):
        if not section[2] & 2:
            continue
        assert name not in allocated
        allocated[name] = {'type': section[1], 'flags': section[2], 'address': section[3],
                           'bytes': section[5], 'alignment': section[8],
                           'content_sha256': None if section[1] == 8 else hashlib.sha256(
                               data[section[4]:section[4] + section[5]]).hexdigest()}
    code, exports, imports = {}, set(), set()
    for section in sections:
        if section[1] not in (2, 11):
            continue
        assert section[9] == 24 and section[5] % 24 == 0 and section[6] < shcount
        strings_section = sections[section[6]]
        strings = data[strings_section[4]:strings_section[4] + strings_section[5]]
        for position in range(section[4], section[4] + section[5], 24):
            name_offset, info, other, index, value, size = struct.unpack_from('<IBBHQQ', data, position)
            if not name_offset:
                continue
            name = cstring(strings, name_offset)
            binding, symbol_type, visibility = info >> 4, info & 15, other & 3
            if section[1] == 11:
                if index == 0:
                    imports.add(name)
                elif index != 0xfff1 and binding in (1, 2, 10) and visibility in (0, 3):
                    exports.add(name)
            elif 0 < index < shcount and sections[index][2] & 4 and symbol_type in (0, 2, 10):
                code.setdefault(name, []).append({'address': value, 'bytes': size,
                    'binding': BINDINGS.get(binding, str(binding)),
                    'visibility': VISIBILITY[visibility], 'type': symbol_type,
                    'section': names[index]})
    assert code or not require_symbols, 'No retained code symbols'
    assert exports or not runtime, 'No runtime dynamic exports'
    needed, soname, flags, flags1 = [], None, 0, 0
    for section in sections:
        if section[1] != 6:
            continue
        assert section[9] == 16 and section[6] < shcount
        strings_section = sections[section[6]]
        strings = data[strings_section[4]:strings_section[4] + strings_section[5]]
        for position in range(section[4], section[4] + section[5], 16):
            tag, value = struct.unpack_from('<qQ', data, position)
            if tag == 0:
                break
            if tag == 1:
                needed.append(cstring(strings, value))
            elif tag == 14:
                soname = cstring(strings, value)
            elif tag == 30:
                flags = value
            elif tag == 0x6ffffffb:
                flags1 = value
    if runtime:
        allowed = set(re.findall(r'dora_godot_\w+(?=;)',
                                (ROOT / 'Source/3rdParty/Godot/dora_bridge.map').read_text()))
        expected = allowed - {'dora_godot_get_d3d12_targets_api'}
        assert len(expected) == 6 and exports == expected, 'Linux EGL bridge export contract mismatch'
    assert digest(path) == before
    return {'path': str(path), 'sha256': before, 'bytes': len(data), 'elf_type': kind,
            'machine': machine, 'interpreter': interpreter, 'soname': soname,
            'needed': needed, 'dynamic_flags': flags, 'dynamic_flags_1': flags1,
            'retained_code_names': len(code), 'dynamic_export_count': len(exports),
            'dynamic_import_count': len(imports), 'allocated_sections': allocated}, code, exports, imports


def allocated_equivalence(production, diagnostic):
    left, right = production['allocated_sections'], diagnostic['allocated_sections']
    assert left.keys() == right.keys(), 'Diagnostic allocated section set differs'
    ignored = []
    for name in left:
        if left[name] == right[name]:
            continue
        assert name == '.note.gnu.build-id', 'Diagnostic allocated section differs: ' + name
        assert {k:v for k,v in left[name].items() if k != 'content_sha256'} == {
            k:v for k,v in right[name].items() if k != 'content_sha256'}, 'Build ID section layout differs'
        ignored.append(name)
    return {'passed': True, 'sections': len(left), 'ignored_content_differences': ignored,
            'scope': 'All SHF_ALLOC section layout and bytes equal except GNU build ID contents; NOBITS metadata compared. Not whole-file or ELF-header identity.'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime', type=Path, required=True)
    p.add_argument('--runtime-symbols', type=Path, help='Unstripped diagnostic; all allocated code/data must match production')
    p.add_argument('--host', type=Path)
    p.add_argument('--architecture', choices=tuple(MACHINES), required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    runtime, code, exports, imports = image(args.runtime.resolve(), args.architecture, True,
                                          require_symbols=not args.runtime_symbols)
    diagnostic, equivalence = None, None
    if args.runtime_symbols:
        diagnostic, code, diagnostic_exports, diagnostic_imports = image(args.runtime_symbols.resolve(), args.architecture, True)
        equivalence = allocated_equivalence(runtime, diagnostic)
        assert exports == diagnostic_exports and imports == diagnostic_imports
    host, host_code, host_exports, host_imports = None, {}, set(), set()
    if args.host:
        host, host_code, host_exports, host_imports = image(args.host.resolve(), args.architecture, False)
    rows = {}
    for name, pattern in PATTERNS.items():
        matches = lambda symbol: re.search(pattern, '_' + symbol)
        own = {symbol: entries for symbol, entries in code.items() if matches(symbol)}
        clients = {symbol: entries for symbol, entries in host_code.items() if matches(symbol)}
        rows[name] = {'runtime_code': own, 'host_code': clients,
                      'common_defined_code_names': sorted(own.keys() & clients.keys()),
                      'runtime_binding_visibility': dict(Counter(entry['binding'] + '/' + entry['visibility']
                          for entries in own.values() for entry in entries)),
                      'runtime_exports': sorted(symbol for symbol in exports if matches(symbol)),
                      'runtime_imports': sorted(symbol for symbol in imports if matches(symbol)),
                      'host_exports': sorted(symbol for symbol in host_exports if matches(symbol)),
                      'host_imports': sorted(symbol for symbol in host_imports if matches(symbol))}
        assert not rows[name]['runtime_exports'], 'Private dependency escaped bridge export contract'
    report = {'passed': True, 'complete': False, 'scope': __doc__,
              'audit_script_sha256': digest(Path(__file__)),
              'classification_script_sha256': digest(Path(__file__).with_name('audit_macos_dependency_symbols.py')),
              'runtime': runtime, 'host': host,
              'unstripped_runtime': diagnostic, 'runtime_allocated_equivalence': equivalence,
              'dependencies': rows, 'runtime_execution': False,
              'runtime_global_state_isolation_proven': False, 'final_object_origin_proven': False}
    (args.output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({name: {'runtime': len(row['runtime_code']), 'host': len(row['host_code']),
                            'common': len(row['common_defined_code_names'])} for name, row in rows.items()}, indent=2))


if __name__ == '__main__':
    main()
