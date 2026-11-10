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
        sources = re.findall(r'source\("([^"\n]+)"\)', text)
        for name in sources:
            if '.gen.' not in name:
                assert (ROOT / 'Source/3rdParty/Godot' / name).is_file(), (path, name)
        for name in ('core/object/callable_mp.cpp', 'modules/gdscript/gdscript_resource_format.cpp',
                     'modules/visual_shader/register_types.cpp'):
            assert name in sources, (path, name)

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

    scripts = [tools / ('build_' + platform + '_runtime.lua') for platform in ('windows','android','ios','web')]
    scripts += [tools/'build_runtime.sh', tools/'build_linux_runtime.sh']
    shared = (tools/'platform_build.lua').read_text()
    assert '--dora_godot_standalone=y' in shared
    assert not list(tools.glob('*.py')), 'Production tools must be Lua'
    for path in scripts:
        text = path.read_text()
        assert not re.search(r'\\b(?:pip\\S*\\s+install[^\\n]*scons|venv\\b)', text), path
        if path.suffix == '.lua':
            rejected = subprocess.run(['xmake','lua',str(path),'--builder','scons'],text=True,capture_output=True)
            assert rejected.returncode != 0 and 'Unsupported value' in rejected.stdout+rejected.stderr, path
        else:
            assert '--dora_godot_standalone=y' in text, path
    # A source upgrade must advance Java/host/CI SDK inputs together.
    upstream = ROOT / 'Source/3rdParty/Godot'
    android = (upstream / 'platform/android/java/app/config.gradle').read_text()
    ndk = re.search(r"ndkVersion\s*:\s*'([^']+)'", android)[1]
    compile_sdk = re.search(r'compileSdk\s*:\s*(\d+)', android)[1]
    build_tools = re.search(r"buildTools\s*:\s*'([^']+)'", android)[1]
    version_ns = {}
    exec(compile((upstream / 'version.py').read_text(), 'version.py', 'exec'), version_ns)
    java_version = '.'.join(str(version_ns[k]) for k in ('major', 'minor', 'patch', 'status'))
    assert java_version in (tools / 'build_android_java.lua').read_text()
    assert java_version in (tools / 'prepare_android_aar.lua').read_text()
    gradle = (ROOT / 'Projects/Android/Dora/app/build.gradle').read_text()
    assert 'godot-java-' + java_version + '.aar' in gradle
    assert ndk in gradle and build_tools in gradle
    agp = re.search(r"androidGradlePlugin\s*:\s*'([^']+)'", android)[1]
    kotlin = re.search(r"kotlinVersion\s*:\s*'([^']+)'", android)[1]
    assert agp in (ROOT / 'Projects/Android/Dora/build.gradle').read_text()
    assert 'kotlin-stdlib:' + kotlin in gradle
    wrapper = 'platform/android/java/gradle/wrapper/gradle-wrapper.properties'
    expected_gradle = re.search(r'gradle-[0-9.]+-bin.zip', (upstream / wrapper).read_text())[0]
    assert expected_gradle in (ROOT / 'Projects/Android/Dora/gradle/wrapper/gradle-wrapper.properties').read_text()
    assert 'godotEnabled ? ' + compile_sdk in gradle
    for name in ('Tools/Godot/platform_build.lua', 'Projects/xmake/tasks/android.lua',
                 'Projects/xmake/tasks/doctor.lua', '.github/workflows/android.yml', '.github/workflows/release.yml'):
        assert ndk in (ROOT / name).read_text(), name
    for name in ('.github/workflows/android.yml', '.github/workflows/release.yml'):
        text = (ROOT / name).read_text()
        assert 'platforms;android-' + compile_sdk in text and 'build-tools;' + build_tools in text, name
    assert json.loads((ROOT / 'Projects/xmake/godot/web_link.json').read_text())['upstream_commit'] == json.loads((upstream / 'UPSTREAM.json').read_text())['upstream_commit']
    assert (ROOT / 'Source/3rdParty/Godot/SConstruct').is_file()
    assert len(list((ROOT / 'Source/3rdParty/Godot').rglob('SCsub'))) == 210
    probe = (ROOT / str(test_path('Tools/LibGodotMetalProbe/run.sh'))).read_text()
    assert 'test_macos.sh' in probe and 'scons' not in probe.lower()
    print(json.dumps({'passed': True, 'source_manifests': len(manifests),
                      'native_variant_actions_per_manifest': 110,
                      'scons_selectors_rejected': 4,
                      'upstream_build_files_preserved': True,
                      'scope': 'Build dispatch and source inventory only; no compiler or GPU acceptance'}))


if __name__ == '__main__':
    main()
