#!/usr/bin/env python3
"""Compile real Embree units with a simulated AVX2 compiler default and the pinned baseline."""
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

root = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd()))
policy = (root / 'Projects/xmake/godot/targets.lua').read_text()
match = re.search(r'add_cxflags\("(-march=x86-64)", \{force = true\}\)', policy)
assert match, 'Godot x86_64 stages must pin the imported Embree ISA baseline'
baseline = match[1]
cc = shlex.split(os.environ.get('CXX', 'c++'))
if sys.platform == 'darwin':
    sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    cc = ['clang++', '-target', 'x86_64-apple-macos12.0', '-isysroot', sdk]
elif not (sys.platform.startswith('linux') and platform.machine() in ('x86_64', 'AMD64')):
    print('SKIP Embree ISA fixture requires an x86_64 compiler or macOS cross compiler')
    raise SystemExit(0)
source = root / 'Source/3rdParty/Godot/thirdparty/embree'
common = cc + ['-std=c++17', '-O0', '-g0', '-I' + str(source), '-I' + str(source / 'include'),
               '-DEMBREE_TARGET_SSE2', '-DEMBREE_LOWEST_ISA', '-DTASKING_INTERNAL']
for suffix in [[], [baseline], [baseline, '-msse4.2']]:
    flags = ['-march=x86-64-v3', '-msse4.2', '-mpopcnt'] + suffix
    macros = subprocess.check_output(cc + flags + ['-dM', '-E', '-x', 'c++', '-'], input='', text=True)
    assert ('#define __AVX2__' in macros) is (not suffix)
    assert '#define __SSE4_2__' in macros
with tempfile.TemporaryDirectory(prefix='dora-embree-isa-') as temporary:
    out = Path(temporary)
    for name, suffix in [('old', []), ('fixed', [baseline])]:
        flags = ['-march=x86-64-v3', '-msse4.2', '-mpopcnt'] + suffix
        obj = out / (name + '.o')
        result = subprocess.run(common + flags + ['-c', str(source / 'kernels/bvh/bvh.cpp'), '-o', str(obj)],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert result.returncode == 0, result.stdout
        nm_flags = ['-gU'] if sys.platform == 'darwin' else ['--defined-only', '-g']
        symbols = subprocess.check_output(['nm', *nm_flags, str(obj)], text=True)
        assert ('BVHNILi4EE' in symbols) is (name == 'fixed')
        assert ('BVHNILi8EE' in symbols) is (name == 'old')
print(json.dumps({'passed': True, 'scope': 'Compiler macros and actual Embree BVHN object definitions only; no full LibGodot link or GPU run',
                  'baseline': baseline, 'simulated_default': 'x86-64-v3', 'old_missing_BVHN4_reproduced': True,
                  'corrected_BVHN4_present': True}))
