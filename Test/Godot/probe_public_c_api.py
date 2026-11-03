#!/usr/bin/env python3
"""Inventory declared public C contracts using exported flags and matching libclang.

Includes every declaration in the explicitly listed headers, all fields of their
complete top-level records, typedefs and enum values. Not binary ABI, exported
implementation, ownership, behavior, or actual dependency-sharing acceptance.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess

from probe_dependency_compile_inputs import base_command

ROOT = ENGINE_ROOT
HEADERS = {
    'ogg': ('ogg/ogg.h', 'Godot/thirdparty/libogg/ogg/ogg.h'),
    'theora': ('theora/include/theora', 'Godot/thirdparty/libtheora/theora'),
    'vorbis': ('vorbis', 'Godot/thirdparty/libvorbis/vorbis'),
    'zlib': ('Zip/zlib', 'Godot/thirdparty/zlib'),
}
PUBLIC = {'theora': ('codec.h', 'theoradec.h', 'theoraenc.h', 'theora.h'),
          'vorbis': ('codec.h', 'vorbisenc.h', 'vorbisfile.h'),
          'zlib': ('zlib.h', 'zconf.h')}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contracts(rows):
    """Retain forward declarations separately from definitions; reject collisions."""
    result = {}
    for row in rows:
        value = row['contract']
        key = value['kind'] + ':' + value['name']
        if 'complete' in value:
            key += ':complete' if value['complete'] else ':forward'
        assert key not in result, 'Ambiguous public declaration: ' + key
        result[key] = value
    return result


def layout_expressions(rows):
    result = []
    for key, value in contracts(rows).items():
        if value['kind'] not in ('StructDecl', 'UnionDecl', 'TypedefDecl'):
            continue
        if value.get('size', -1) < 0:
            continue
        name = value['name'] if value['kind'] == 'TypedefDecl' else value['type']
        result.extend([(key + '.size', 'sizeof(' + name + ')', value['size']),
                       (key + '.alignment', '_Alignof(' + name + ')', value['alignment'])])
        for field in value.get('fields', []):
            assert field['bit_width'] == -1, 'Independent offsetof does not support bit fields'
            result.append((key + '.' + field['name'],
                           '8 * offsetof(' + name + ', ' + field['name'] + ')', field['offset_bits']))
    assert result
    return result


class Cursor(C.Structure):
    _fields_ = [('kind', C.c_uint), ('xdata', C.c_int), ('data', C.c_void_p * 3)]


class Type(C.Structure):
    _fields_ = [('kind', C.c_uint), ('data', C.c_void_p * 2)]


class String(C.Structure):
    _fields_ = [('data', C.c_void_p), ('private_flags', C.c_uint)]


class Location(C.Structure):
    _fields_ = [('ptr_data', C.c_void_p * 2), ('int_data', C.c_uint)]


Visitor = C.CFUNCTYPE(C.c_uint, Cursor, Cursor, C.c_void_p)
InclusionVisitor = C.CFUNCTYPE(None, C.c_void_p, C.POINTER(Location), C.c_uint, C.c_void_p)


class Clang:
    def __init__(self, library):
        self.lib = C.CDLL(str(library))
        signatures = {
            'createIndex': (C.c_void_p, [C.c_int, C.c_int]),
            'disposeIndex': (None, [C.c_void_p]),
            'parseTranslationUnit2': (C.c_int, [C.c_void_p, C.c_char_p, C.POINTER(C.c_char_p), C.c_int, C.c_void_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]),
            'disposeTranslationUnit': (None, [C.c_void_p]),
            'getTranslationUnitCursor': (Cursor, [C.c_void_p]),
            'visitChildren': (C.c_uint, [Cursor, Visitor, C.c_void_p]),
            'getInclusions': (None, [C.c_void_p, InclusionVisitor, C.c_void_p]),
            'getCursorSpelling': (String, [Cursor]),
            'getCursorKindSpelling': (String, [C.c_uint]),
            'getCursorLocation': (Location, [Cursor]),
            'getExpansionLocation': (None, [Location, C.POINTER(C.c_void_p), C.POINTER(C.c_uint), C.POINTER(C.c_uint), C.POINTER(C.c_uint)]),
            'getFileName': (String, [C.c_void_p]),
            'getCString': (C.c_char_p, [String]),
            'disposeString': (None, [String]),
            'getCursorType': (Type, [Cursor]),
            'Cursor_getMangling': (String, [Cursor]),
            'Cursor_getStorageClass': (C.c_uint, [Cursor]),
            'getCursorLinkage': (C.c_uint, [Cursor]),
            'getCanonicalType': (Type, [Type]),
            'getTypeSpelling': (String, [Type]),
            'getTypedefDeclUnderlyingType': (Type, [Cursor]),
            'getEnumDeclIntegerType': (Type, [Cursor]),
            'getEnumConstantDeclValue': (C.c_longlong, [Cursor]),
            'getEnumConstantDeclUnsignedValue': (C.c_ulonglong, [Cursor]),
            'isCursorDefinition': (C.c_uint, [Cursor]),
            'getFunctionTypeCallingConv': (C.c_uint, [Type]),
            'getResultType': (Type, [Type]),
            'getNumArgTypes': (C.c_int, [Type]),
            'getArgType': (Type, [Type, C.c_uint]),
            'isFunctionTypeVariadic': (C.c_uint, [Type]),
            'getFieldDeclBitWidth': (C.c_int, [Cursor]),
            'Type_getOffsetOf': (C.c_longlong, [Type, C.c_char_p]),
            'Type_getSizeOf': (C.c_longlong, [Type]),
            'Type_getAlignOf': (C.c_longlong, [Type]),
            'getNumDiagnostics': (C.c_uint, [C.c_void_p]),
            'getDiagnostic': (C.c_void_p, [C.c_void_p, C.c_uint]),
            'getDiagnosticSeverity': (C.c_uint, [C.c_void_p]),
            'getDiagnosticSpelling': (String, [C.c_void_p]),
            'disposeDiagnostic': (None, [C.c_void_p]),
            'getClangVersion': (String, []),
        }
        for name, (result, arguments) in signatures.items():
            function = getattr(self.lib, 'clang_' + name)
            function.restype = result
            function.argtypes = arguments
            setattr(self, name, function)

    def text(self, value):
        try:
            return (self.getCString(value) or b'').decode()
        finally:
            self.disposeString(value)

    def children(self, cursor):
        result = []
        @Visitor
        def collect(child, parent, data):
            result.append(child)
            return 1
        self.visitChildren(cursor, collect, None)
        return result

    def location(self, cursor):
        file, line, column, offset = C.c_void_p(), C.c_uint(), C.c_uint(), C.c_uint()
        self.getExpansionLocation(self.getCursorLocation(cursor), C.byref(file), C.byref(line), C.byref(column), C.byref(offset))
        return {'path': str(Path(self.text(self.getFileName(file))).resolve()), 'line': line.value} if file.value else None

    def typename(self, value):
        return self.text(self.getTypeSpelling(self.getCanonicalType(value)))

    def describe(self, cursor):
        kind = self.text(self.getCursorKindSpelling(cursor.kind))
        name = self.text(self.getCursorSpelling(cursor))
        value = self.getCursorType(cursor)
        row = {'kind': kind, 'name': name, 'type': self.typename(value)}
        if kind in ('FunctionDecl', 'VarDecl'):
            row.update(storage_class=self.Cursor_getStorageClass(cursor), linkage=self.getCursorLinkage(cursor))
        if kind == 'FunctionDecl':
            count = self.getNumArgTypes(value)
            assert self.getCanonicalType(value).kind == 111 and count >= 0, 'Unprototyped public function: ' + name
            row.update(result=self.typename(self.getResultType(value)),
                       link_name=self.text(self.Cursor_getMangling(cursor)),
                       header_definition=bool(self.isCursorDefinition(cursor)),
                       arguments=[self.typename(self.getArgType(value, i)) for i in range(count)],
                       calling_convention=self.getFunctionTypeCallingConv(value),
                       variadic=bool(self.isFunctionTypeVariadic(value)))
        elif kind in ('StructDecl', 'UnionDecl'):
            row['complete'] = bool(self.isCursorDefinition(cursor))
            if row['complete']:
                row.update(size=self.Type_getSizeOf(value), alignment=self.Type_getAlignOf(value), fields=[], nested_declarations=[])
                assert row['size'] >= 0 and row['alignment'] > 0, 'Invalid public record layout'
                for child in self.children(cursor):
                    childkind = self.text(self.getCursorKindSpelling(child.kind))
                    if childkind in ('StructDecl', 'UnionDecl', 'EnumDecl'):
                        row['nested_declarations'].append(self.describe(child))
                        continue
                    assert childkind in ('FieldDecl', 'attribute(packed)'), 'Unsupported record child: ' + childkind
                    if childkind != 'FieldDecl':
                        continue
                    field = self.text(self.getCursorSpelling(child))
                    assert field, 'Unnamed public field needs explicit support'
                    bitoffset = self.Type_getOffsetOf(value, field.encode())
                    assert bitoffset >= 0
                    row['fields'].append({'name': field, 'type': self.typename(self.getCursorType(child)),
                                          'offset_bits': bitoffset, 'bit_width': self.getFieldDeclBitWidth(child)})
        elif kind == 'TypedefDecl':
            value = self.getTypedefDeclUnderlyingType(cursor)
            row.update(underlying_type=self.typename(value), size=self.Type_getSizeOf(value), alignment=self.Type_getAlignOf(value))
        elif kind == 'EnumDecl':
            row['integer_type'] = self.typename(self.getEnumDeclIntegerType(cursor))
            row['values'] = {self.text(self.getCursorSpelling(c)): {
                'signed': self.getEnumConstantDeclValue(c), 'unsigned': self.getEnumConstantDeclUnsignedValue(c)}
                for c in self.children(cursor)}
        elif kind != 'VarDecl':
            raise AssertionError('Unsupported public declaration: ' + kind)
        return row

    def parse(self, source, arguments, public_headers):
        public_headers = {str(Path(name).resolve()) for name in public_headers}
        index, unit = self.createIndex(0, 0), C.c_void_p()
        args = (C.c_char_p * len(arguments))(*(arg.encode() for arg in arguments))
        diagnostics = []
        try:
            error = self.parseTranslationUnit2(index, str(source).encode(), args, len(args), None, 0, 0, C.byref(unit))
            assert error == 0 and unit.value, 'libclang parse failed: ' + str(error)
            for i in range(self.getNumDiagnostics(unit)):
                diagnostic = self.getDiagnostic(unit, i)
                diagnostics.append({'severity': self.getDiagnosticSeverity(diagnostic), 'message': self.text(self.getDiagnosticSpelling(diagnostic))})
                self.disposeDiagnostic(diagnostic)
            assert all(row['severity'] < 3 for row in diagnostics), diagnostics
            included = set()
            @InclusionVisitor
            def include(file, stack, length, data):
                if file:
                    included.add(str(Path(self.text(self.getFileName(file))).resolve()))
            self.getInclusions(unit, include, None)
            self.last_inclusions = included
            rows = []
            for cursor in self.children(self.getTranslationUnitCursor(unit)):
                location = self.location(cursor)
                if location and location['path'] in public_headers:
                    rows.append({'location': location, 'contract': self.describe(cursor)})
            assert rows, 'No declarations found in explicit public headers'
            assert set(public_headers) <= {r['location']['path'] for r in rows}, 'Public header produced no declarations'
            return rows, diagnostics
        finally:
            if unit.value:
                self.disposeTranslationUnit(unit)
            self.disposeIndex(index)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compile-probes', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--platform', choices=('macos', 'ios', 'android'), default='macos')
    parser.add_argument('--ios-device', choices=('device', 'simulator'))
    args = parser.parse_args()
    if args.platform == 'ios' and not args.ios_device:
        parser.error('--ios-device is required for iOS public-header probes')
    if args.platform != 'ios' and args.ios_device:
        parser.error('--ios-device applies only to iOS probes')
    assert not args.output.exists(), 'Use a fresh evidence directory'
    base = json.loads((args.compile_probes / 'verification.json').read_text())
    assert base['passed'] and base['platform'] == args.platform, 'Compile-probe platform mismatch'
    if args.platform == 'ios':
        assert base['ios_device'] == args.ios_device, 'Compile-probe iOS device/simulator mismatch'
    args.output.mkdir(parents=True)
    assert len(base['compilers']) == 1, 'Expected one verified compiler toolchain'
    primary_compiler = Path(next(iter(base['compilers']))).resolve()
    library = primary_compiler.parent.parent / 'lib/libclang.dylib'
    assert library.is_file(), 'Matching compiler libclang unavailable'
    clang = Clang(library)
    inputs = {str(library): digest(library), str(Path(__file__).resolve()): digest(Path(__file__)),
              str((args.compile_probes / 'verification.json').resolve()): digest(args.compile_probes / 'verification.json')}
    for helper in ('probe_dependency_compile_inputs.py', 'probe_dependency_layouts.py'):
        path = Path(__file__).with_name(helper).resolve()
        inputs[str(path)] = digest(path)
    exported_entries = []
    for filename, expected in base['inputs_sha256'].items():
        path = Path(filename)
        if path.name.endswith('compile_commands.json'):
            assert digest(path) == expected, 'Exported compile database changed'
            inputs[filename] = expected
            exported_entries.extend(json.loads(path.read_text()))
    assert exported_entries, 'No verified exported compile database'
    dependencies = {}
    for dependency, paths in HEADERS.items():
        providers = {}
        for provider, relative in zip(('dora', 'godot'), paths):
            previous = args.compile_probes / dependency / provider / 'result.json'
            detail = json.loads(previous.read_text())
            assert detail['compile_db_entry'] in exported_entries, 'Selected TU not in verified exported database'
            command, cwd, original_source, removed = base_command(detail['compile_db_entry'], args.platform, args.ios_device)
            sdk_metadata = None
            android_sdk = None
            if args.platform == 'ios':
                sdk = Path(command[command.index('-isysroot') + 1]).resolve()
                sdk_metadata = {'path': str(sdk),
                                'canonical_name': plistlib.loads((sdk / 'SDKSettings.plist').read_bytes())['CanonicalName'],
                                'settings_sha256': digest(sdk / 'SDKSettings.plist')}
                assert sdk_metadata == detail['ios_sdk'], 'iOS SDK changed since exported-flags probe'
                inputs[str(sdk / 'SDKSettings.plist')] = sdk_metadata['settings_sha256']
            assert all(digest(Path(name)) == value for name, value in detail['headers_sha256'].items()), 'Selected TU headers changed since exported-flags probe'
            compiler = Path(shutil.which(command[0]) or command[0]).resolve()
            assert digest(compiler) == base['compilers'][str(compiler)]['sha256'], 'Compiler changed since flags probe'
            assert compiler.parent.parent / 'lib/libclang.dylib' == library, 'Compiler/libclang toolchain mismatch'
            if args.platform == 'android':
                targets = [command[i + 1] for i, flag in enumerate(command[:-1]) if flag in ('-target', '--target')]
                targets += [flag.split('=', 1)[1] for flag in command if flag.startswith('--target=')]
                assert len(targets) == 1 and re.fullmatch(r'aarch64-(?:none-)?linux-android28', targets[0]), 'Expected Android ARM64 API28 compiler target'
                sysroots = [command[i + 1] for i, flag in enumerate(command[:-1]) if flag in ('--sysroot', '-isysroot')]
                sysroots += [flag.split('=', 1)[1] for flag in command if flag.startswith('--sysroot=')]
                assert len(sysroots) == 1 and Path(sysroots[0]).resolve() == compiler.parent.parent / 'sysroot', 'Android sysroot does not belong to compiler toolchain'
                ndk = next((parent for parent in compiler.parents if (parent / 'source.properties').is_file()), None)
                assert ndk, 'Missing NDK package identity'
                properties = ndk / 'source.properties'
                revision = re.search(r'^Pkg.Revision\s*=\s*([^\n]+)', properties.read_text(), re.M)
                assert revision and revision[1].strip() == '28.1.13356709', 'Unexpected Android NDK revision'
                inputs[str(properties)] = digest(properties)
                android_sdk = {'sysroot': str(Path(sysroots[0]).resolve()), 'ndk_root': str(ndk),
                               'revision': revision[1].strip(), 'properties_sha256': digest(properties)}
            folder = args.output / dependency / provider
            folder.mkdir(parents=True)
            header_root = ROOT / 'Source/3rdParty' / relative
            headers = [header_root] if dependency == 'ogg' else [header_root / name for name in PUBLIC[dependency]]
            before = {str(header.resolve()): digest(header) for header in headers}
            inputs[str(previous.resolve())] = digest(previous)
            source = (folder / 'public.c').resolve()
            source.write_text(''.join('#include ' + json.dumps(str(h.resolve())) + '\n' for h in headers))
            dependency_command = command + ['-M', '-MT', 'public', str(source)]
            dependency_text = subprocess.check_output(dependency_command, cwd=cwd, text=True)
            (folder / 'headers.txt').write_text(dependency_text)
            names = shlex.split(dependency_text.replace('\\\n', ' ').split(':', 1)[1])
            transitive = {str((cwd / name).resolve()): digest((cwd / name).resolve()) for name in names}
            assert set(before) <= transitive.keys(), 'Public headers absent from dependency graph'
            # -M also lists SDK metadata and __has_include candidates. Compare
            # actual entered headers with -H while retaining every -M digest.
            trace_command = command + ['-E', '-H', str(source)]
            with (folder / 'preprocessed.c').open('w') as stdout, (folder / 'header-trace.log').open('w') as stderr:
                subprocess.run(trace_command, cwd=cwd, stdout=stdout, stderr=stderr, check=True)
            traced = {str(source)} | {str((cwd / name).resolve()) for name in re.findall(
                r'^\.+ (.+)$', (folder / 'header-trace.log').read_text(), re.M)}
            assert traced <= transitive.keys(), 'Entered header missing from compiler dependency graph'
            driver_metadata = {}
            if args.platform in ('macos', 'ios'):
                sdk = Path(command[command.index('-isysroot') + 1]).resolve()
                metadata = sdk / 'SDKSettings.json'
                canonical = json.loads(metadata.read_text())['CanonicalName']
                prefix = 'macosx' if args.platform == 'macos' else ('iphonesimulator' if args.ios_device == 'simulator' else 'iphoneos')
                assert canonical.startswith(prefix), 'Apple driver metadata platform mismatch'
                if str(metadata) in traced:
                    driver_metadata[str(metadata)] = digest(metadata)
                    traced.remove(str(metadata))
            # Preserve working-directory semantics without changing global cwd.
            flags = command[1:] + ['-working-directory', str(cwd), '-fsyntax-only']
            if args.platform == 'android':
                resource = Path(subprocess.check_output(command + ['-print-resource-dir'], cwd=cwd, text=True).strip()).resolve()
                assert resource.is_relative_to(compiler.parent.parent) and (resource / 'include/stddef.h').is_file(), 'Invalid Android compiler resource directory'
                assert not any(flag.startswith('-resource-dir') for flag in command), 'Explicit resource-dir needs separate validation'
                flags += ['-resource-dir', str(resource)]
                android_sdk['compiler_resource_dir'] = str(resource)
            rows, diagnostics = clang.parse(source, flags, before)
            (folder / 'header-graph-check.json').write_text(json.dumps({
                'libclang': sorted(clang.last_inclusions), 'compiler_entered_headers': sorted(traced),
                'compiler_additional_dependencies': sorted(transitive.keys() - traced),
                'driver_metadata_sha256': driver_metadata,
                'only_libclang': sorted(clang.last_inclusions - traced),
                'only_compiler': sorted(traced - clang.last_inclusions)}, indent=2) + '\n')
            assert clang.last_inclusions == traced, 'libclang and actual compiler entered headers differ'
            expressions = layout_expressions(rows)
            functions = [row['contract'] for row in rows if row['contract']['kind'] == 'FunctionDecl']
            layout_source = (folder / 'layout.c').resolve()
            layout_source.write_text(source.read_text() + '#include <stddef.h>\nconst unsigned long long public_api_layout[] = {\n' +
                                     ',\n'.join(expression for _, expression, _ in expressions) + '\n};\n' +
                                     'void (*const public_api_functions[])(void) = {\n' +
                                     ',\n'.join('(void (*)(void)) &' + row['name'] for row in functions) + '\n};\n')
            ir = (folder / 'layout.ll').resolve()
            ir_command = command + ['-S', '-emit-llvm', str(layout_source), '-o', str(ir)]
            with (folder / 'layout.log').open('w') as log:
                subprocess.run(ir_command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, check=True)
            text = ir.read_text()
            triple = re.search(r'^target triple = "([^"]+)"', text, re.M)
            assert triple, 'Missing LLVM target'
            if args.platform == 'macos':
                assert re.fullmatch(r'arm64-apple-macosx[0-9.]+', triple[1]), 'Unexpected layout LLVM target'
            elif args.platform == 'ios':
                assert re.fullmatch(r'arm64-apple-ios[0-9.]+(?:-simulator)?', triple[1]), 'Unexpected iOS LLVM target'
                assert triple[1].endswith('-simulator') == (args.ios_device == 'simulator'), 'iOS LLVM device/simulator mismatch'
            else:
                assert re.fullmatch(r'aarch64-(?:unknown|none)-linux-android28', triple[1]), 'Unexpected Android LLVM target'
            match = re.search(r'@public_api_layout\s*=.*?\[(\d+) x i64\]\s+\[(.*?)\]', text, re.S)
            assert match and int(match[1]) == len(expressions), 'Missing independent layout array'
            values = [int(value) for value in re.findall(r'i64 (\d+)', match[2])]
            assert values == [expected for _, _, expected in expressions], 'libclang/actual compiler layout mismatch'
            refs = re.search(r'@public_api_functions\s*=.*?\[(\d+) x ptr\]\s+\[(.*?)\]', text, re.S)
            assert refs and int(refs[1]) == len(functions), 'Missing public function reference array'
            identifiers = re.findall(r'ptr @("(?:[^"\\]|\\.)*"|[-a-zA-Z$._0-9]+)', refs[2])
            names = [re.sub(r'\\([0-9A-Fa-f]{2})', lambda m: chr(int(m[1], 16)), name[1:-1])
                     if name.startswith('"') else name for name in identifiers]
            apple = args.platform in ('macos', 'ios')
            assert ('-m:o-' if apple else '-m:e-') in text.split('target datalayout = "', 1)[1].split('"', 1)[0], 'Unexpected object mangling layout'
            link_names = [name[1:] if name.startswith('\x01') else ('_' if apple else '') + name for name in names]
            assert link_names == [row['link_name'] for row in functions], 'libclang/actual compiler public link names differ'
            obj = (folder / 'public.o').resolve()
            object_command = command + ['-c', str(layout_source), '-o', str(obj)]
            with (folder / 'object.log').open('w') as log:
                subprocess.run(object_command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, check=True)
            nm = compiler.parent / 'llvm-nm'
            if not nm.is_file():
                assert apple, 'Matching LLVM nm unavailable'
                nm = Path(subprocess.check_output(['xcrun', '--find', 'nm'], text=True).strip())
            undefined = subprocess.check_output([str(nm), '-u', '-j', str(obj)], text=True)
            (folder / 'undefined-symbols.txt').write_text(undefined)
            required = {row['link_name'] for row in functions if row['linkage'] == 4 and not row['header_definition']}
            assert required <= set(undefined.splitlines()), 'Actual probe object is missing public symbol references'
            inputs[str(nm.resolve())] = digest(nm.resolve())
            assert all(digest(Path(name)) == value for name, value in transitive.items()), 'Public header input changed during probe'
            assert all(digest(Path(name)) == value for name, value in before.items())
            payload = {'headers_sha256': before, 'compile_db_entry': detail['compile_db_entry'],
                       'flags': flags, 'declarations': rows, 'diagnostics': diagnostics,
                       'transitive_headers_sha256': transitive,
                       'independent_layout_command': ir_command, 'independent_layout_ir_sha256': digest(ir),
                       'independently_checked_function_link_names': link_names,
                       'probe_object_sha256': digest(obj), 'probe_object_command': object_command,
                       'probe_object_undefined_public_symbols': sorted(required),
                       'layout_constants': {key: expected for key, _, expected in expressions}}
            if sdk_metadata:
                payload['ios_sdk'] = sdk_metadata
            if android_sdk:
                payload['android_sdk'] = android_sdk
            (folder / 'result.json').write_text(json.dumps(payload, indent=2) + '\n')
            providers[provider] = payload
        dependencies[dependency] = {name: {'declarations': len(row['declarations']),
            'independently_checked_layout_metrics': len(row['layout_constants']),
            'by_kind': {kind: sum(d['contract']['kind'] == kind for d in row['declarations'])
                        for kind in sorted({d['contract']['kind'] for d in row['declarations']})}}
            for name, row in providers.items()}
        left, right = (contracts(providers[name]['declarations']) for name in ('dora', 'godot'))
        dependencies[dependency]['comparison'] = {
            'only_dora': sorted(left.keys() - right.keys()), 'only_godot': sorted(right.keys() - left.keys()),
            'changed': {key: {'dora': left[key], 'godot': right[key]} for key in sorted(left.keys() & right.keys()) if left[key] != right[key]}}
    assert all(digest(Path(name)) == value for name, value in inputs.items())
    (args.output / 'verification.json').write_text(json.dumps({'passed': True, 'complete': False,
        'scope': __doc__, 'platform': args.platform, 'ios_device': args.ios_device,
        'libclang_version': clang.text(clang.getClangVersion()),
        'inputs_sha256': inputs, 'dependencies': dependencies, 'runtime_execution': False}, indent=2) + '\n')
    print(json.dumps(dependencies, indent=2))


if __name__ == '__main__':
    main()
