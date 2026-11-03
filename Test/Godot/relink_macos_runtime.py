#!/usr/bin/env python3
"""Reproduce an accepted macOS runtime exactly before accepting its link map.

Relinks retained inputs in a fresh directory only. Does not compile source,
load Godot, change an accepted package, or approve ABI or dependency sharing.
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
import subprocess
import sys


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--receipt', required=True, type=Path, help='JSON from export_macos_link_receipt.lua')
    p.add_argument('--production', required=True, type=Path, help='Exact accepted dylib; never overwritten')
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    assert sys.platform == 'darwin', 'macOS linker required'
    assert not a.output.exists(), 'Preserve evidence; use a fresh output directory'
    receipt = json.loads(a.receipt.read_text())
    flags = receipt['flags']; files = [Path(n).resolve() for n in receipt['files']]
    assert all(isinstance(s, str) for s in flags) and all(p.is_file() for p in files)
    assert len(files) == len(set(files)), 'Ambiguous input inventory'
    assert flags[:3] == ['-shared', '-target', 'arm64-apple-macos11.0'], 'Expected accepted ARM64 macOS Release link flags'
    assert '-o' not in flags and '-install_name' not in flags and not any(s.startswith('-Wl,-map') for s in flags)
    assert all(s in flags for s in ['-Wl,-S', '-Wl,-x', '-Wl,-dead_strip'])
    objects = [str(path) for path in files if path.suffix == '.o']
    assert len(objects) == 1 and len([path for path in files if path.suffix == '.a']) == 6, 'Unexpected runtime link shape'
    directories = [Path(s[2:]).resolve() for s in flags if s.startswith('-L')]
    library_flags = [s for s in flags if s.startswith('-lgodot-')]
    assert len(library_flags) == 6
    linked = []
    for flag in library_flags:
        matches = [folder/('lib'+flag[2:]+'.a') for folder in directories if (folder/('lib'+flag[2:]+'.a')).is_file()]
        assert len(matches) == 1, 'Ambiguous archive resolution'
        linked.append(matches[0])
    assert set(linked) == {path for path in files if path.suffix == '.a'}, 'Receipt files differ from ordered link flags'
    # argv[0] selects Clang's C++ driver mode; resolving clang++ to clang
    # changes implicit runtime libraries even when both names share bytes.
    program = Path(receipt['program']).absolute()
    exports = [s.split(',', 2)[2] for s in flags if s.startswith('-Wl,-exported_symbols_list,')]
    assert len(exports) == 1
    sdk = Path(flags[flags.index('-isysroot')+1])
    tracked = [a.receipt.resolve(), Path(receipt['source']).resolve(), Path(receipt['exporter']).resolve(),
               a.production.resolve(), program, program.parent/'ld', Path(exports[0]), sdk/'SDKSettings.plist',
               Path(__file__).resolve(), *files]
    before = {str(path): digest(path) for path in tracked}
    production = a.production.read_bytes()
    assert production[:8] == bytes.fromhex('cffaedfe0c000001'), 'Expected thin ARM64 Mach-O'
    install = subprocess.check_output(['xcrun', 'otool', '-D', str(a.production.resolve())], text=True).splitlines()
    assert install[1:] == ['@rpath/libdora_godot.dylib'], 'Unexpected production install name'
    a.output.mkdir(parents=True)
    (a.output/'inputs.json').write_text(json.dumps(before, indent=2)+'\n')
    runs = []
    for name in ['control', 'mapped']:
        output = (a.output/(name+'.dylib')).resolve()
        command = [str(program), '-o', str(output), *objects, *flags, '-install_name', install[1]]
        if name == 'mapped':command += ['-Wl,-map,'+str((a.output/'link.map').resolve())]
        (a.output/(name+'-command.json')).write_text(json.dumps(command, indent=2)+'\n')
        with (a.output/(name+'-link.log')).open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        run = {'name': name, 'returncode': result.returncode,
               'sha256': digest(output) if output.is_file() else None,
               'whole_file_equal': output.is_file() and output.read_bytes() == production}
        runs.append(run)
        (a.output/(name+'-result.json')).write_text(json.dumps(run, indent=2)+'\n')
        assert result.returncode == 0 and run['whole_file_equal'], 'Relink is not the exact production image; map not accepted'
    text = (a.output/'link.map').read_bytes().decode('utf-8', errors='surrogateescape')
    assert '# Path: '+str((a.output/'mapped.dylib').resolve()) in text and '# Arch: arm64' in text
    assert all(digest(Path(path)) == expected for path, expected in before.items()), 'Original input changed'
    report = {'passed': True, 'complete': False, 'scope': __doc__, 'inputs_sha256': before,
              'production_sha256': before[str(a.production.resolve())], 'runs': runs,
              'link_map_sha256': digest(a.output/'link.map'), 'inputs_unchanged': True,
              'production_map_identity': 'Both relinks equal the accepted image in every byte, including load commands and linkedit',
              'compile_or_runtime_performed': False}
    (a.output/'verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PASS: control and mapped relinks reproduce the production dylib byte-for-byte')


if __name__ == '__main__':
    main()
