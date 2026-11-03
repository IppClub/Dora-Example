#!/usr/bin/env python3
"""Probe selected C dependency translation units with exported build flags.

Current compile databases are build-graph evidence, not historical compiler
execution or complete ABI approval. Only compile-only probes run here.
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
import plistlib
import re
import shlex
import shutil
import subprocess
import struct

from probe_dependency_layouts import STRUCTS

SELECTION = {
    'ogg': ('Source/3rdParty/ogg/OggSources.c', 'thirdparty/libogg/framing.c', 'ogg'),
    'theora': ('Source/3rdParty/theora/TheoraSources.c', 'thirdparty/libtheora/decinfo.c', 'th_'),
    'vorbis': ('Source/Audio/VorbisSources.c', 'thirdparty/libvorbis/block.c', 'vorbis_'),
    'zlib': ('Source/3rdParty/Zip/zlib/adler32.c', 'thirdparty/zlib/adler32.c', 'z_stream'),
}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load(paths):
    return [entry for path in paths for entry in json.loads(path.read_text())]


def base_command(entry, platform='android', ios_device=None):
    cwd = Path(entry['directory'])
    source = Path(entry['file'])
    source = source if source.is_absolute() else cwd/source
    source = source.resolve()
    raw = entry.get('arguments') or shlex.split(entry['command'])
    result, removed = [], []
    i = 0
    while i < len(raw):
        arg = raw[i]
        assert not arg.startswith(('@', '-Wp,', '-save-temps', '-ftime-trace')), 'Unsupported side-effect/response flags'
        if arg in ('-o', '-MF', '-MT', '-MQ', '-MJ', '-serialize-diagnostics', '--serialize-diagnostics'):
            removed += raw[i:i+2]
            assert i+1 < len(raw)
            i += 2
            continue
        if arg in ('-c', '-S', '-emit-llvm', '-MD', '-MMD', '-MP', '-MG'):
            removed.append(arg)
        elif i > 0 and not arg.startswith('-') and (cwd/arg).resolve() == source:
            removed.append(arg)
        else:
            result.append(arg)
        i += 1
    assert sum((cwd/value).resolve() == source for value in raw[1:] if not value.startswith('-')) == 1
    if platform == 'android':
        assert any('android28' in arg for arg in result), 'Expected actual Android API28 flags'
    elif platform == 'ios':
        assert ios_device in ('device', 'simulator'), 'Explicit iOS platform required'
        assert result.count('-target') == 1 and result.count('-isysroot') == 1, 'Expected explicit iOS target and SDK'
        target = result[result.index('-target')+1]
        simulator = ios_device == 'simulator'
        assert re.fullmatch(r'arm64-apple-ios[0-9.]+(?:-simulator)?', target), 'Expected actual iOS ARM64 target'
        assert target.endswith('-simulator') == simulator, 'iOS device/simulator target mismatch'
        sdk = Path(result[result.index('-isysroot')+1])
        assert sdk.is_dir() and sdk.resolve().name.startswith('iPhoneSimulator' if simulator else 'iPhoneOS'), 'iOS SDK platform mismatch'
        settings = plistlib.loads((sdk/'SDKSettings.plist').read_bytes())
        assert settings['CanonicalName'].startswith('iphonesimulator' if simulator else 'iphoneos'), 'iOS SDK metadata platform mismatch'
    elif platform == 'web':
        assert Path(result[0]).name in ('emcc', 'emcc.py'), 'Expected exported Emscripten C compiler'
    elif platform == 'linux':
        targets = [result[i+1] for i, arg in enumerate(result[:-1]) if arg in ('-target', '--target')]
        targets += [arg.split('=', 1)[1] for arg in result if arg.startswith('--target=')]
        assert all('linux' in target and 'android' not in target for target in targets), 'Non-Linux compiler target'
    else:
        assert platform == 'macos'
        assert '-target' in result and result[result.index('-target')+1].startswith('arm64-apple-macos'), 'Expected actual macOS ARM64 target'
        assert '-isysroot' in result and Path(result[result.index('-isysroot')+1]).is_dir(), 'Missing actual macOS SDK'
    return result, cwd, source, removed


def invoke(command, cwd, destination):
    with destination.open('w') as stdout, destination.with_suffix(destination.suffix+'.stderr').open('w') as stderr:
        subprocess.run(command, cwd=cwd, check=True, stdout=stdout, stderr=stderr)



def elf_layout_constants(path, count, architecture):
    """Read an emitted GCC ELF object's constant array, without executing it."""
    data = path.read_bytes()
    assert data[:7] == b'\x7fELF\x02\x01\x01', 'Expected ELF64 little endian probe object'
    kind, machine = struct.unpack_from('<HH', data, 16)
    assert kind == 1 and machine == {'arm64': 183, 'x86_64': 62}[architecture], 'Probe object target mismatch'
    shoff = struct.unpack_from('<Q', data, 40)[0]
    shsize, shcount = struct.unpack_from('<HH', data, 58)
    assert shsize == 64 and shcount > 0 and shoff + shsize * shcount <= len(data)
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + i * shsize) for i in range(shcount)]
    matches = []
    for symbols in sections:
        if symbols[1] != 2:
            continue
        assert symbols[9] == 24 and symbols[5] % 24 == 0 and symbols[6] < shcount
        strings = sections[symbols[6]]
        assert symbols[4] + symbols[5] <= len(data) and strings[4] + strings[5] <= len(data)
        names = data[strings[4]:strings[4] + strings[5]]
        for offset in range(symbols[4], symbols[4] + symbols[5], 24):
            name, info, other, index, value, size = struct.unpack_from('<IBBHQQ', data, offset)
            assert name < len(names)
            if names[name:names.index(b'\0', name)] != b'dora_dependency_layout':
                continue
            assert info & 15 == 1 and 0 < index < shcount and size == count * 8, 'Invalid layout array symbol'
            section = sections[index]
            assert section[1] == 1 and section[2] & 2 and value + size <= section[5]
            start = section[4] + value
            assert start + size <= len(data)
            for relocation in sections:
                if relocation[1] not in (4, 9) or relocation[7] != index:
                    continue
                stride = 24 if relocation[1] == 4 else 16
                assert relocation[9] == stride and relocation[5] % stride == 0
                assert relocation[4] + relocation[5] <= len(data)
                for position in range(relocation[4], relocation[4] + relocation[5], stride):
                    relative = struct.unpack_from('<Q', data, position)[0]
                    assert not value <= relative < value + size, 'Layout constants require relocation'
            matches.append(list(struct.unpack_from('<' + 'Q' * count, data, start)))
    assert len(matches) == 1, 'Missing or ambiguous layout constants'
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dora-db', type=Path, required=True)
    parser.add_argument('--godot-db', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--platform', choices=('android', 'macos', 'linux', 'web', 'ios'), default='android')
    parser.add_argument('--architecture', choices=('arm64', 'x86_64'), help='Required for Linux GCC object probes')
    parser.add_argument('--ios-device', choices=('device', 'simulator'), help='Required for iOS platform/SDK verification')
    args = parser.parse_args()
    if args.platform == 'ios' and not args.ios_device:
        parser.error('--ios-device is required for iOS probes')
    if args.platform == 'linux' and not args.architecture:
        parser.error('--architecture is required for Linux probes')
    assert not args.output.exists(), 'Use a fresh evidence directory'
    inputs = [args.dora_db, *args.godot_db, Path(__file__), Path(__file__).with_name('probe_dependency_layouts.py')]
    before = {str(path.resolve()): digest(path) for path in inputs}
    args.output.mkdir(parents=True)
    databases = {'dora': load([args.dora_db]), 'godot': load(args.godot_db)}
    rows, compilers = {}, {}
    for dependency, (dora_suffix, godot_suffix, prefix) in SELECTION.items():
        metrics = [('sizeof.void *', 'sizeof(void *)'), ('sizeof.long', 'sizeof(long)')]
        for name, fields in STRUCTS.items():
            if name.startswith(prefix):
                metrics += [(f'sizeof.{name}', f'sizeof({name})'), (f'alignof.{name}', f'_Alignof({name})')]
                metrics += [(f'offsetof.{name}.{field}', f'offsetof({name}, {field})') for field in fields]
        providers = {}
        for provider, suffix in (('dora', dora_suffix), ('godot', godot_suffix)):
            candidates = [entry for entry in databases[provider] if entry['file'].replace('\\', '/').endswith(suffix)]
            assert len(candidates) == 1, (dependency, provider, len(candidates))
            entry = candidates[0]
            command, cwd, source, removed = base_command(entry, args.platform, args.ios_device)
            folder = args.output/dependency/provider
            folder.mkdir(parents=True)
            source_sha = digest(source)
            ios_sdk = None
            if args.platform == 'ios':
                sdk = Path(command[command.index('-isysroot')+1]).resolve()
                ios_sdk = {'path': str(sdk), 'canonical_name': plistlib.loads((sdk/'SDKSettings.plist').read_bytes())['CanonicalName'],
                           'settings_sha256': digest(sdk/'SDKSettings.plist')}
            probe = (folder/'probe.c').resolve()
            probe.write_text('#include '+json.dumps(str(source))+'\n#include <stddef.h>\nconst unsigned long long dora_dependency_layout[] = {\n'+',\n'.join(value for _,value in metrics)+'\n};\n')
            macro_command = command + ['-dM', '-E', str(source)]
            invoke(macro_command, cwd, folder/'macros.txt')
            macros = dict(re.findall(r'^#define (\w+)(.*)$', (folder/'macros.txt').read_text(), re.M))
            if args.platform == 'macos':
                assert all(key in macros for key in ('__APPLE__', '__MACH__', '__aarch64__'))
            if args.platform == 'ios':
                assert all(key in macros for key in ('__APPLE__', '__MACH__', '__aarch64__', '__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__')), 'Expected Apple iOS ARM64 predefined macros'
            if args.platform == 'web':
                assert '__EMSCRIPTEN__' in macros and '__wasm32__' in macros and macros.get('__SIZEOF_POINTER__', '').strip() == '4', 'Expected Emscripten wasm32 target'
            if args.platform == 'linux':
                assert '__linux__' in macros and '__ANDROID__' not in macros and ('__aarch64__' if args.architecture == 'arm64' else '__x86_64__') in macros, 'Wrong Linux predefined target'
            dependency_command = command + ['-M', '-MT', 'probe', str(probe)]
            invoke(dependency_command, cwd, folder/'headers.txt')
            names = shlex.split((folder/'headers.txt').read_text().replace('\\\n', ' ').split(':', 1)[1])
            headers = {str((cwd/name).resolve()): digest((cwd/name).resolve()) for name in names}
            ir = (folder/('probe.o' if args.platform == 'linux' else 'probe.ll')).resolve()
            layout_command = command + (['-c'] if args.platform == 'linux' else ['-S', '-emit-llvm']) + [str(probe), '-o', str(ir)]
            invoke(layout_command, cwd, folder/'layout.log')
            if args.platform == 'linux':
                values = elf_layout_constants(ir, len(metrics), args.architecture)
            else:
                match = re.search(r'@dora_dependency_layout\s*=.*?\[(\d+) x i64\]\s+\[(.*?)\]', ir.read_text(), re.S)
                if args.platform == 'web':
                    assert re.search(r'^target triple = \"wasm32[^\"]*emscripten\"', ir.read_text(), re.M), 'Unexpected LLVM Web target'
                assert match and int(match[1]) == len(metrics), 'Missing LLVM layout constants'
                values = [int(value) for value in re.findall(r'i64 (\d+)', match[2])]
            assert len(values) == len(metrics)
            assert digest(source) == source_sha
            assert all(digest(Path(name)) == value for name,value in headers.items())
            executable = str((cwd/command[0]).resolve()) if '/' in command[0] else shutil.which(command[0])
            assert executable, 'Compiler executable not found in PATH'
            compiler = str(Path(executable).resolve())
            if compiler not in compilers:
                compilers[compiler] = {'sha256': digest(Path(compiler)), 'version': subprocess.check_output([compiler, '--version'], text=True)}
                if args.platform == 'web':
                    clang = Path(compiler).parent.parent/'bin/clang'
                    assert clang.is_file(), 'Emscripten underlying Clang not found'
                    compilers[compiler]['underlying_clang'] = str(clang.resolve())
                    compilers[compiler]['underlying_clang_sha256'] = digest(clang.resolve())
                    compilers[compiler]['underlying_clang_version'] = subprocess.check_output([str(clang), '--version'], text=True)
            detail = {'compile_db_entry': entry, 'removed_output_flags': removed,
                      'commands': {'macros': macro_command, 'headers': dependency_command, 'layout': layout_command},
                      'source_sha256': source_sha, 'headers_sha256': headers, 'macros': macros,
                      'layout': {key: value for (key,_),value in zip(metrics,values)}, 'ir_sha256': digest(ir),
                      'artifact_kind': 'ELF relocatable constant array' if args.platform == 'linux' else 'LLVM IR'}
            if ios_sdk:
                assert digest(Path(ios_sdk['path'])/'SDKSettings.plist') == ios_sdk['settings_sha256'], 'SDK metadata changed during probe'
                detail['ios_sdk'] = ios_sdk
            (folder/'result.json').write_text(json.dumps(detail, indent=2)+'\n')
            providers[provider] = detail
        left,right = (providers[name]['layout'] for name in ('dora','godot'))
        keys = providers['dora']['macros'].keys() | providers['godot']['macros'].keys()
        macro_differences = {key: {name: providers[name]['macros'].get(key) for name in providers}
                             for key in sorted(keys) if providers['dora']['macros'].get(key) != providers['godot']['macros'].get(key)}
        rows[dependency] = {'metrics_per_provider':len(metrics), 'layout_differences': {k:{'dora':left[k],'godot':right[k]} for k in left if left[k]!=right[k]},
                            'macro_differences':macro_differences,
                            'providers':{name:{'source_sha256':d['source_sha256'],'header_count':len(d['headers_sha256']),
                                               'language_standard':d['macros'].get('__STDC_VERSION__'),'android_api':d['macros'].get('__ANDROID_API__'),
                                               'macos_min_version':d['macros'].get('__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__')} for name,d in providers.items()}}
    assert all(digest(Path(path)) == value for path,value in before.items())
    report = {'passed': True, 'complete': False, 'scope': __doc__, 'platform':args.platform, 'architecture':args.architecture, 'ios_device':args.ios_device, 'inputs_sha256':before, 'compilers':compilers, 'dependencies':rows,
              'runtime_execution':False,'input_flag_changes':'Only source/output/dependency-generation flags replaced; language/optimization/macros/target/sysroot/includes preserved'}
    (args.output/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:{'metrics':v['metrics_per_provider'],'layout_differences':len(v['layout_differences']),'macro_differences':len(v['macro_differences'])} for k,v in rows.items()},indent=2))


if __name__ == '__main__':
    main()
