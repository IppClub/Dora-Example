#!/usr/bin/env python3
"""Find C-family basename/content overlap across all non-Godot vendor trees.

Candidate discovery only: equal basenames do not prove common upstream origin,
and equal source files do not prove final binary duplication or ABI compatibility.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

from audit_dependency_sources import MANIFESTS, manifest_actions

ROOT = ENGINE_ROOT
VENDOR = ROOT / 'Source/3rdParty'
GODOT = VENDOR / 'Godot/thirdparty'
SUFFIXES = {'.c', '.h', '.cpp', '.hpp', '.inl', '.mm', '.m', '.S', '.cxx', '.hxx', '.cc', '.ipp', '.tpp', '.s'}


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def component(path):
    parts = path.relative_to(VENDOR).parts
    for marker in ('3rdparty', 'libraries'):
        lowered = [part.lower() for part in parts]
        if marker in lowered:
            index = lowered.index(marker)
            if index + 2 < len(parts):
                return '/'.join(parts[:index + 2])
    return parts[0] + ('/zlib' if parts[0] == 'Zip' and len(parts) > 2 and parts[1] == 'zlib' else '')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a new evidence path'
    dora_by_name = defaultdict(list)
    dora_count = 0
    for top in sorted(VENDOR.iterdir()):
        if not top.is_dir() or top.name.startswith('.') or top.name == 'Godot':
            continue
        for path in sorted(top.rglob('*')):
            if path.is_file() and not path.is_symlink() and path.suffix in SUFFIXES:
                if any(part in ('.git', '.xmake', 'build') for part in path.relative_to(top).parts):
                    continue
                dora_count += 1
                dora_by_name[path.name].append(path)
    godot_files = [path for path in sorted(GODOT.rglob('*')) if path.is_file() and not path.is_symlink() and path.suffix in SUFFIXES]
    hashes = {}

    def cached_hash(path):
        if path not in hashes:
            hashes[path] = digest(path)
        return hashes[path]

    groups = {}
    for godot in godot_files:
        relative = godot.relative_to(GODOT)
        library = relative.parts[0]
        for dora in dora_by_name.get(godot.name, []):
            key = (library, component(dora))
            group = groups.setdefault(key, {'godot_component': library, 'dora_component': key[1], 'pairs': []})
            left, right = cached_hash(dora), cached_hash(godot)
            group['pairs'].append({'dora': str(dora.relative_to(ROOT)), 'godot': str(godot.relative_to(ROOT)),
                                   'dora_sha256': left, 'godot_sha256': right, 'byte_identical': left == right})
    manifests = {}
    for name, file in MANIFESTS.items():
        path = ROOT / 'Projects/xmake/godot' / file
        actions = manifest_actions(path.read_text())
        counts = defaultdict(int)
        for action in actions:
            parts = action['source'].split('/')
            if parts[0] == 'thirdparty':
                counts[parts[1]] += 1
        manifests[name] = {'sha256': digest(path), 'direct_component_actions': dict(counts)}
    rows = []
    for key, group in sorted(groups.items()):
        group['same_basename_pairs'] = len(group['pairs'])
        group['byte_identical_pairs'] = sum(pair['byte_identical'] for pair in group['pairs'])
        group['godot_direct_compile_actions'] = {name: meta['direct_component_actions'].get(key[0], 0) for name, meta in manifests.items()}
        rows.append(group)
    result = {'scope': __doc__, 'audit_script_sha256': digest(Path(__file__)),
              'considered_suffixes': sorted(SUFFIXES),
              'dora_source_files_considered': dora_count, 'godot_source_files_considered': len(godot_files),
              'matched_file_sha256': {str(path.relative_to(ROOT)): value for path, value in sorted(hashes.items())},
              'manifest_profiles': manifests, 'groups': rows,
              'limitations': ['Basename matching can yield unrelated code; each group needs origin review',
                              'Renamed files with different basenames are outside this discovery pass',
                              'Headers and tools may not be retained by either runtime; final linkage is separate']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'dora_files': dora_count, 'godot_files': len(godot_files), 'groups': len(rows),
                      'largest_exact_groups': [{'godot': row['godot_component'], 'dora': row['dora_component'],
                                               'identical': row['byte_identical_pairs'], 'basename_pairs': row['same_basename_pairs']}
                                              for row in sorted(rows, key=lambda row: row['byte_identical_pairs'], reverse=True)[:18]]}, indent=2))


if __name__ == '__main__':
    main()
