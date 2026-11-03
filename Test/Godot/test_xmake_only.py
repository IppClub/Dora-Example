#!/usr/bin/env python3
"""Guard the standalone build entrypoints and native same-source variants.

This checks dispatch/source inventory, not a platform compiler or GPU result.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import ast
import json
from pathlib import Path
import re
import subprocess
import sys

from native_variants import validate_native_variants

ROOT = ENGINE_ROOT


def main():
    tools = ROOT / 'Tools/Godot'
    manifests = sorted((ROOT / 'Projects/xmake/godot').glob('*_sources.lua'))
    assert len(manifests) == 13, [p.name for p in manifests]
    assert not list((ROOT / 'Projects/xmake/godot/wrappers').rglob('*.c'))
    for path in manifests:
        text = path.read_text()
        assert validate_native_variants(text) == 110, path
        assert '/wrappers/' not in text, path
        assert 'DORA_GODOT_GENERATED_ROOT' in text, path
        assert 'always_added = true' in text, path
        assert 'if is_mode("debug") and value == "-DNDEBUG"' in text, path
        assert '-DMONO_ENABLED' not in text, path
        assert 'source("modules/mono/' not in text, path

    for profile in (ROOT / 'Projects/xmake/godot').glob('template_release*.json'):
        assert 'mono' not in json.loads(profile.read_text())['enabled_modules'], profile

    x86 = (ROOT / 'Projects/xmake/godot/android_x86_64_sources.lua').read_text()
    arm32 = (ROOT / 'Projects/xmake/godot/android_arm32_sources.lua').read_text()
    assert '-mfix-cortex-a53' not in x86 + arm32
    assert '-msse4.2' in x86 and '-mpopcnt' in x86
    assert 'source("thirdparty/zstd/decompress/huf_decompress_amd64.S")' in x86
    assert 'source("thirdparty/zstd/decompress/huf_decompress_amd64.S")' not in arm32
    assert '-march=armv7-a' in arm32 and '-mfloat-abi=softfp' in arm32
    for name in ('windows_arm64', 'windows_d3d12_arm64'):
        text = (ROOT / f'Projects/xmake/godot/{name}_sources.lua').read_text()
        for block in re.findall(r'target\("[^"\n]+"\).*?target_end\(\)', text, re.S):
            if '-D__SSE2__' in block:
                sources = re.findall(r'source\("([^"]+)"\)', block)
                assert sources and all(s.startswith('thirdparty/embree/') for s in sources), name

    scripts = [tools / ('build_' + platform + '_runtime.py')
               for platform in ('windows', 'android', 'ios', 'web')]
    scripts += [tools / 'build_runtime.sh', tools / 'build_linux_runtime.sh']
    for path in scripts:
        text = path.read_text()
        assert '--dora_godot_standalone=y' in text, path
        assert not re.search(r'\b(?:pip\S*\s+install[^\n]*scons|SCons\b|venv\b)', text), path
        if path.suffix == '.py':
            for node in ast.walk(ast.parse(text)):
                if isinstance(node, (ast.Import, ast.ImportFrom)):
                    names = [node.module or ''] if isinstance(node, ast.ImportFrom) else [n.name for n in node.names]
                    assert not any(n.lower().startswith('scons') for n in names), path
            rejected = subprocess.run([sys.executable, str(path), '--builder', 'scons'],
                                      text=True, capture_output=True)
            assert rejected.returncode == 2 and 'invalid choice' in rejected.stderr, path
    assert (ROOT / 'Source/3rdParty/Godot/SConstruct').is_file()
    assert len(list((ROOT / 'Source/3rdParty/Godot').rglob('SCsub'))) == 208
    probe = (ROOT / str(test_path('Tools/LibGodotMetalProbe/run.sh'))).read_text()
    assert 'test_macos.sh' in probe and 'scons' not in probe.lower()
    print(json.dumps({'passed': True, 'source_manifests': len(manifests),
                      'native_variant_actions_per_manifest': 110,
                      'scons_selectors_rejected': 4,
                      'upstream_build_files_preserved': True,
                      'scope': 'Build dispatch and source inventory only; no compiler or GPU acceptance'}))


if __name__ == '__main__':
    main()
