#!/usr/bin/env python3
"""Inventory local source overlap; this is not binary-sharing or ABI acceptance."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = ENGINE_ROOT
VENDOR = ROOT / 'Source/3rdParty'
GODOT = VENDOR / 'Godot/thirdparty'
MANIFESTS = {
    'macos_arm64': 'macos_arm64_sources.lua',
    'linux_arm64': 'linux_sources.lua',
    'linux_x86_64': 'linux_x86_64_sources.lua',
    'windows_x86_64_wgl': 'windows_x86_64_sources.lua',
    'windows_x86_64_d3d12': 'windows_d3d12_x86_64_sources.lua',
    'android_arm64': 'android_arm64_sources.lua',
    'web_wasm32': 'web_wasm32_sources.lua',
    'ios_simulator_arm64': 'ios_simulator_arm64_sources.lua',
    'ios_device_arm64': 'ios_device_arm64_sources.lua',
}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def metadata(name):
    text = (GODOT / 'README.md').read_text()
    match = re.search(r'^## ' + re.escape(name) + r'\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    assert match, name
    section = match[1]
    fields = {}
    for label in ('Upstream', 'Version', 'License'):
        value = re.search(r'^- ' + label + r': (.+)$', section, re.M)
        if value:
            fields[label.lower()] = value[1]
    fields['patches'] = re.findall(r'^- `([^`]+\.patch)`', section, re.M)
    return fields


def mapped_files(folder, layout):
    result = {}
    for file in sorted(folder.rglob('*')):
        if not file.is_file() or file.suffix not in ('.c', '.h', '.cpp', '.inl', '.hpp', '.mm'):
            continue
        relative = file.relative_to(folder).as_posix()
        if layout == 'ogg':
            relative = relative.removeprefix('src/') if relative.startswith('src/') else 'ogg/' + relative
        elif layout in ('theora', 'vorbis'):
            relative = relative.removeprefix('Source/').removeprefix('lib/').removeprefix('include/')
        elif layout == 'astc':
            relative = relative.removeprefix('source/').removeprefix('include/')
        elif layout == 'sdl':
            if relative.startswith('src/'):
                relative = relative.removeprefix('src/')
            elif relative.startswith('include/'):
                relative = 'include/SDL3/' + relative.removeprefix('include/')
        result[relative] = file
    return result


def manifest_actions(text):
    """Read only our generated literal DSL; do not evaluate arbitrary Lua.

    These are declared per-file flags, not final toolchain arguments. Reject
    unparsed source calls so a generator format change cannot silently omit data.
    """
    quoted = r'"(?:[^"\\]|\\.)*"'
    actions = []
    for match in re.finditer(
            r'target\(("[^"\n]+")\)\n    add_files\(\n(.*?)\n    \)\ntarget_end\(\)', text, re.S):
        target = json.loads(match[1])
        body = match[2]
        sources = [json.loads(value) for value in re.findall(r'source\((' + quoted + r')\)', body)]
        language = re.search(r'\{(cflags|cxxflags|asflags|mflags|mxxflags) = \{', body)
        assert sources and language, target
        flags = [json.loads(value) for value in re.findall(r'flag\((' + quoted + r')\)', body)]
        assert flags, target
        for source in sources:
            actions.append({'source': source, 'target': target,
                            'flag_kind': language[1], 'flags': flags})
    assert len(actions) == len(re.findall(r'source\("', text)), 'Unparsed manifest source calls'
    assert actions, 'Empty generated manifest'
    return actions


def dependency_profiles(actions, dependency):
    selected = [action for action in actions if action['source'].startswith('thirdparty/' + dependency + '/')]
    profiles = {}
    for action in selected:
        config = {key: action[key] for key in ('target', 'flag_kind', 'flags')}
        identity = hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()
        if identity not in profiles:
            profiles[identity] = dict(config, sources=[])
        profiles[identity]['sources'].append(action['source'])
    return {'actions': len(selected), 'profiles': profiles}


def dora_inputs(folder):
    engine = ROOT / 'Projects/xmake/manifests/engine.lua'
    entries = re.findall(r'"(Source/[^"\n]+)"', engine.read_text())
    direct = []
    included = []
    for entry in entries:
        path = ROOT / entry
        if path.is_relative_to(folder):
            direct.append(entry)
        if path.name.endswith(('Sources.c', 'Sources.cpp')) and path.is_file():
            for include in re.findall(r'^#include "([^"\n]+\.(?:c|cpp))"', path.read_text(), re.M):
                child = (path.parent / include).resolve()
                if child.is_relative_to(folder):
                    assert child.is_file(), child
                    included.append({'amalgamation': entry, 'source': str(child.relative_to(ROOT)),
                                     'amalgamation_sha256': digest(path)})
    # Theora is a separate target rather than an engine-manifest entry.
    if folder == VENDOR / 'theora':
        wrapper = folder / 'TheoraSources.c'
        for include in re.findall(r'^#include "([^"]+\.c)"', wrapper.read_text(), re.M):
            child = (wrapper.parent / include).resolve()
            assert child.is_file()
            included.append({'amalgamation': str(wrapper.relative_to(ROOT)),
                             'source': str(child.relative_to(ROOT)),
                             'amalgamation_sha256': digest(wrapper)})
    return {'scope': 'Current engine manifest and explicit source amalgamation declarations only; not per-platform final compile/link evidence',
            'engine_manifest_sha256': digest(engine), 'direct_engine_sources': direct,
            'amalgamated_sources': included}


def license_inventory(folder):
    files = []
    for path in sorted(folder.rglob('*')):
        if path.is_file() and path.name.upper().startswith(('COPYING', 'LICENSE')):
            files.append({'path': str(path.relative_to(ROOT)), 'sha256': digest(path),
                          'bytes': path.stat().st_size})
    embedded = []
    if not files:
        for path in sorted(folder.rglob('*.h')):
            if re.search(r'copyright|permission|licen[cs]e', path.read_text(errors='replace')[:16000], re.I):
                embedded.append({'path': str(path.relative_to(ROOT)), 'sha256': digest(path)})
    return {'scope': 'Local notice file inventory only; alternatives and actual linked component applicability require separate review',
            'files': files, 'embedded_notice_candidates': embedded}


def dora_version_evidence(name):
    declarations = {
        'theora': ('theora/README.dora.md', None),
        'ogg': ('ogg/UPSTREAM.json', None),
        'vorbis': ('vorbis/UPSTREAM.json', None),
        'bgfx/3rdparty/glslang': ('bgfx/3rdparty/glslang/UPSTREAM.json', None),
        'bgfx/3rdparty/spirv-cross': ('bgfx/3rdparty/spirv-cross/UPSTREAM.json', None),
        'Zip/zlib': ('Zip/zlib/UPSTREAM.json', None),
        'SDL2': ('SDL2/UPSTREAM.json', None),
        'JoltPhysics': ('JoltPhysics/UPSTREAM.json', None),
        'bimg/3rdparty/astc-encoder': ('bimg/3rdparty/astc-encoder/UPSTREAM.json', None),
        'bimg/3rdparty/tinyexr': ('bimg/3rdparty/tinyexr/UPSTREAM.json', None),
    }
    if name not in declarations:
        return {'status': 'exact upstream version/commit not established from a pinned local provenance manifest'}
    file, pattern = declarations[name]
    path = VENDOR / file
    text = path.read_text()
    return {'path': str(path.relative_to(ROOT)), 'sha256': digest(path),
            'declarations': re.findall(pattern, text, re.M) if pattern else text,
            'scope': 'Local version declaration only; not complete upstream patch provenance'}


def inventory():
    manifests = {name: (ROOT / 'Projects/xmake/godot' / file).read_text() for name, file in MANIFESTS.items()}
    actions = {name: manifest_actions(text) for name, text in manifests.items()}
    candidates = []
    for dora, godot, layout in (
        ('ogg', 'libogg', 'ogg'), ('theora', 'libtheora', 'theora'),
        ('vorbis', 'libvorbis', 'vorbis'), ('Zip/zlib', 'zlib', ''),
        ('JoltPhysics', 'jolt_physics', ''), ('SDL2', 'sdl', 'sdl'),
        ('bgfx/3rdparty/glslang', 'glslang', ''),
        ('bgfx/3rdparty/spirv-cross', 'spirv-cross', ''),
        ('bimg/3rdparty/astc-encoder', 'astcenc', 'astc'),
        ('bimg/3rdparty/tinyexr', 'tinyexr', ''),
    ):
        left = mapped_files(VENDOR / dora, layout)
        right = mapped_files(GODOT / godot, '')
        common = sorted(left.keys() & right.keys())
        assert common, f'Check source layout mapping for {dora} / {godot}'
        comparisons = [{'path': path, 'dora_sha256': digest(left[path]),
                        'godot_sha256': digest(right[path])} for path in common]
        profiles = {name: dependency_profiles(entries, godot) for name, entries in actions.items()}
        compiled = {name: profile['actions'] for name, profile in profiles.items()}
        candidates.append({
            'dora': str((VENDOR / dora).relative_to(ROOT)),
            'godot': str((GODOT / godot).relative_to(ROOT)),
            'godot_metadata': metadata(godot),
            'godot_version_header': ({
                'path': str((GODOT/godot/'glslang/build_info.h').relative_to(ROOT)),
                'sha256': digest(GODOT/godot/'glslang/build_info.h'),
                'declarations': re.findall(r'^#define GLSLANG_VERSION_(?:MAJOR|MINOR|PATCH|FLAVOR)[^\n]*', (GODOT/godot/'glslang/build_info.h').read_text(), re.M),
                'scope': 'Local header declaration, not complete patch provenance'
            } if godot == 'glslang' else None),
            'dora_declared_inputs': dora_inputs(VENDOR / dora),
            'dora_version_evidence': dora_version_evidence(dora),
            'local_notices': {'dora': license_inventory(VENDOR / dora),
                              'godot': license_inventory(GODOT / godot)},
            'godot_direct_compile_actions': compiled,
            'godot_declared_compile_profiles': profiles,
            'matched_relative_paths': len(common),
            'byte_identical_files': sum(p['dora_sha256'] == p['godot_sha256'] for p in comparisons),
            'comparisons': comparisons,
        })
    return {
        'scope': 'Selected local source overlaps and nine Release manifest per-file declarations only; not actual compiler/toolchain flags, ABI, symbols, ownership, final linking or package-size acceptance',
        'godot_metadata_sha256': digest(GODOT / 'README.md'),
        'manifest_sha256': {name: digest(ROOT / 'Projects/xmake/godot' / file) for name, file in MANIFESTS.items()},
        'manifest_compile_actions': {name: len(entries) for name, entries in actions.items()},
        'shared_build_configuration_sha256': {str(path.relative_to(ROOT)): digest(path) for path in [
            ROOT/'Projects/xmake/godot/targets.lua', ROOT/'Projects/xmake/options.lua',
            ROOT/'Projects/xmake/engine.lua', ROOT/'Projects/xmake/dependencies/vendor.lua',
            ROOT/'Source/3rdParty/bgfx/xmake.lua']},
        'candidates': candidates,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh output path to preserve previous evidence'
    report = inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for row in report['candidates']:
        print(f"{row['dora']}: {row['byte_identical_files']}/{row['matched_relative_paths']} matched files identical; Godot actions {row['godot_direct_compile_actions']}")


if __name__ == '__main__':
    main()
