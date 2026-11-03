#!/usr/bin/env python3
"""Measure C-header layouts by native execution or compile-only LLVM constants.

No third-party runtime is linked. Matching measured fields are not full ABI
acceptance. Mismatched public layouts rule out directly exchanging those structs.
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
import platform
import re
import shlex
import subprocess
import sys

ROOT = ENGINE_ROOT
STRUCTS = {
    'oggpack_buffer': ['endbyte', 'endbit', 'buffer', 'ptr', 'storage'],
    'ogg_page': ['header', 'header_len', 'body', 'body_len'],
    'ogg_packet': ['packet', 'bytes', 'b_o_s', 'e_o_s', 'granulepos', 'packetno'],
    'ogg_stream_state': ['body_data', 'lacing_vals', 'granule_vals', 'header', 'serialno', 'pageno', 'packetno', 'granulepos'],
    'ogg_sync_state': ['data', 'storage', 'fill', 'returned', 'unsynced', 'headerbytes', 'bodybytes'],
    'th_info': ['version_major', 'frame_width', 'frame_height', 'pic_width', 'pic_height', 'fps_numerator', 'colorspace', 'pixel_fmt', 'keyframe_granule_shift'],
    'th_comment': ['user_comments', 'comment_lengths', 'comments', 'vendor'],
    'vorbis_info': ['version', 'channels', 'rate', 'bitrate_upper', 'codec_setup'],
    'vorbis_dsp_state': ['analysisp', 'vi', 'pcm', 'pcmret', 'pcm_storage', 'pcm_current', 'pcm_returned', 'eofflag', 'lW', 'W', 'nW', 'centerW', 'granulepos', 'sequence', 'backend_state'],
    'vorbis_block': ['pcm', 'opb', 'lW', 'W', 'nW', 'pcmend', 'granulepos', 'sequence', 'vd', 'localstore', 'internal'],
    'vorbis_comment': ['user_comments', 'comment_lengths', 'comments', 'vendor'],
    'z_stream': ['next_in', 'avail_in', 'total_in', 'next_out', 'avail_out', 'total_out', 'msg', 'state', 'zalloc', 'zfree', 'opaque', 'data_type', 'adler', 'reserved'],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--compile-target', choices=[
        'arm64-apple-macos11.0', 'aarch64-unknown-linux-gnu', 'x86_64-unknown-linux-gnu',
        'aarch64-linux-android23', 'wasm32-unknown-emscripten', 'x86_64-pc-windows-msvc',
        'arm64-apple-ios14.0', 'arm64-apple-ios14.0-simulator'],
        help='Static default-ABI layout only; never executes target code or loads a runtime')
    p.add_argument('--sysroot', type=Path, help='Real target SDK/sysroot for non-Apple static probes')
    p.add_argument('--compiler', type=Path, help='Clang executable from the target toolchain; defaults to Xcode clang')
    args = p.parse_args()
    if args.compile_target and '-apple-' not in args.compile_target and not args.sysroot:
        p.error('A real target --sysroot is required for non-Apple header dependencies')
    if args.sysroot and not args.sysroot.is_dir():
        p.error('Target sysroot directory does not exist')
    if args.compiler and not args.compiler.is_file():
        p.error('Compiler executable does not exist')
    assert sys.platform == 'darwin', 'This probe driver uses the installed Xcode clang'
    assert args.compile_target or platform.machine() == 'arm64', 'Native mode requires macOS ARM64'
    assert not args.output.exists(), 'Use a fresh evidence directory'
    compiler = [str(args.compiler.resolve())] if args.compiler else ['xcrun', 'clang']
    args.output.mkdir(parents=True)
    metrics = []
    for name in ('void *', 'long', 'ogg_int16_t', 'ogg_int32_t', 'ogg_int64_t', 'alloc_func', 'free_func'):
        metrics.append((f'sizeof.{name}', f'sizeof({name})'))
    for name, fields in STRUCTS.items():
        metrics += [(f'sizeof.{name}', f'sizeof({name})'), (f'alignof.{name}', f'_Alignof({name})')]
        metrics += [(f'offsetof.{name}.{field}', f'offsetof({name}, {field})') for field in fields]
    source = ['#include <stddef.h>', '#include "ogg/ogg.h"', '#include "theora/codec.h"',
              '#include "vorbis/codec.h"', '#include "zlib.h"']
    if args.compile_target:
        source += ['const unsigned long long dora_dependency_layout[] = {']
        source += [expression + ',' for _, expression in metrics]
        source += ['};']
    else:
        source += ['#include <stdio.h>', 'int main(void) {']
        for key, expression in metrics:
            source.append('printf("{\\"key\\":\\"' + key + '\\",\\"value\\":%zu}\\n", (size_t)(' + expression + '));')
        source += ['return 0;', '}']
    code = args.output / 'probe.c'
    code.write_text('\n'.join(source) + '\n')
    vendor = ROOT / 'Source/3rdParty'
    godot = vendor / 'Godot/thirdparty'
    roots = {'dora': [vendor, vendor/'theora/include', vendor/'Zip/zlib'],
             'godot': [godot/'libogg', godot/'libtheora', godot/'libvorbis', godot/'zlib']}
    reports = {}
    for name, includes in roots.items():
        binary = args.output / ('probe-' + name)
        target = args.compile_target or 'arm64-apple-macos11.0'
        if args.compile_target:
            binary = binary.with_suffix('.ll')
        command = compiler + ['-std=c11', '-target', target, '-Wall', '-Wextra', '-Werror', str(code.resolve()), '-o', str(binary.resolve())]
        if args.compile_target:
            command += ['-ffreestanding', '-S', '-emit-llvm']
            if args.sysroot:
                command += ['--sysroot=' + str(args.sysroot.resolve())]
                if 'android' in target:
                    arch_include = args.sysroot / 'usr/include/aarch64-linux-android'
                    if arch_include.is_dir():command += ['-isystem', str(arch_include.resolve())]
            elif '-apple-ios' in target:
                sdk = 'iphonesimulator' if target.endswith('-simulator') else 'iphoneos'
                command += ['-isysroot', subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()]
        for folder in includes:
            command += ['-I', str(folder)]
        (args.output / (name + '-command.json')).write_text(json.dumps(command, indent=2) + '\n')
        # Capture transitive user and SDK headers using the same target flags.
        output_index = command.index('-o')
        dependency_command = [arg for arg in command[:output_index] + command[output_index+2:] if arg not in ('-S', '-emit-llvm')] + ['-M', '-MT', 'probe']
        deps = subprocess.check_output(dependency_command, text=True)
        (args.output / (name + '-headers.txt')).write_text(deps)
        header_names = shlex.split(deps.replace('\\\n', ' ').split(':', 1)[1])
        headers = {str(Path(path).resolve()): digest(Path(path)) for path in header_names}
        with (args.output / (name + '-compile.log')).open('w') as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
        if args.compile_target:
            ir = binary.read_text()
            match = re.search(r'@dora_dependency_layout\s*=.*?\[(\d+) x i64\]\s+\[(.*?)\]', ir, re.S)
            assert match and int(match[1]) == len(metrics), 'Layout constants missing from LLVM IR'
            values = [int(value) for value in re.findall(r'i64 (\d+)', match[2])]
            assert len(values) == len(metrics)
            measurements = {key: value for (key, _), value in zip(metrics, values)}
            raw = ''.join(json.dumps({'key': key, 'value': value}) + '\n' for key, value in measurements.items())
        else:
            raw = subprocess.check_output([str(binary.resolve())], text=True)
            measurements = {row['key']: row['value'] for row in map(json.loads, raw.splitlines())}
        (args.output / (name + '-raw.jsonl')).write_text(raw)
        assert len(measurements) == len(metrics), 'Metric count mismatch'
        assert all(digest(Path(path)) == value for path, value in headers.items())
        reports[name] = {'measurements': measurements, 'headers_sha256': headers,
                         'artifact_sha256': digest(binary),
                         'artifact_kind': 'LLVM IR' if args.compile_target else 'native executable',
                         'executed': not bool(args.compile_target)}
    left, right = (reports[n]['measurements'] for n in ('dora', 'godot'))
    assert left.keys() == right.keys()
    differences = {name: {'dora': left[name], 'godot': right[name]} for name in left if left[name] != right[name]}
    report = {'passed': True, 'scope': __doc__, 'target': args.compile_target or 'native macOS ARM64',
              'mode': 'compile-only default ABI, not production flags or runtime execution' if args.compile_target else 'native C11 header-layout execution',
              'compiler': subprocess.check_output(compiler + ['--version'], text=True),
              'compiler_command': compiler,
              'compiler_sha256': digest(args.compiler.resolve()) if args.compiler else None,
              'probe_sha256': digest(code), 'sysroot_argument': str(args.sysroot.resolve()) if args.sysroot else None, 'providers': reports, 'differences': differences,
              'direct_struct_exchange_compatible_for_measured_fields': not differences}
    (args.output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'measured_fields': len(left), 'differences': differences}, indent=2))


if __name__ == '__main__':
    main()
