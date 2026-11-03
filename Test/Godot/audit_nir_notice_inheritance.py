#!/usr/bin/env python3
"""Audit pinned NIR inputs without inline notices against original source evidence.

This records evidence and unresolved questions, never assigns a blanket Mesa
license or treats source/object mapping as final-link contribution evidence.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import difflib
import hashlib
import json
import re
from pathlib import Path

from generate_nir_notices import MESA_COMMIT, MESA_SHA, NIR_SHA, comments, read_archive

ROOT = ENGINE_ROOT
BLAKE3_COMMIT = 'df610ddc3b93841ffc59a87e3da659a15910eb46'
BLAKE3_SHA = '3b5aab142e171a166eb530876d37eb70c4112ee3a0c9e18562f9c7401048dc2b'
BLAKE3_FILES = ('blake3.c', 'blake3.h', 'blake3_dispatch.c',
                'blake3_impl.h', 'blake3_portable.c')
LINEAGE = ROOT / 'Tools/Godot/licenses/nir-25.3.1-1/SOURCE_LINEAGE.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def history_reviews(history_root, notice):
    registry = json.loads(LINEAGE.read_text())
    assert registry['schema'] == 1 and registry['mesa_commit'] == MESA_COMMIT
    evidence = {}
    for entry in registry['evidence']:
        name = entry['file']
        assert Path(name).name == name, 'Invalid history filename'
        data = (history_root / name).read_bytes()
        assert digest(data) == entry['sha256'], 'Historical input changed: ' + name
        evidence[name] = data
    verified = {}
    for review in registry['reviews']:
        diff = json.loads(evidence['commit-' + review['commit'] + '-diff.json'])
        target = review['path'].removeprefix('mesa/')
        added = next(row for row in diff if row['new_path'] == target)
        assert added['new_file'] and not added.get('too_large') and not added.get('collapsed')
        plus = '\n'.join(line[1:] for line in added['diff'].splitlines() if line.startswith('+'))
        retained = []
        for parent in review['parents']:
            original = evidence[parent['file']].decode()
            blocks = [block for block in comments(original) if 'Copyright' in block and
                      ('Permission is hereby granted' in block or 'SPDX-License-Identifier: MIT' in block)]
            assert blocks, 'Historical parent has no applicable notice'
            assert all(block in notice for block in blocks), 'Historical notice absent from bundle'
            retained.extend({'path': parent['path'], 'notice_sha256': digest(block.encode())}
                            for block in blocks)
        if review['rule'] == 'gl-config-struct-extraction':
            parent = review['parents'][0]
            original = evidence[parent['file']].decode()
            structure = re.search(r'struct gl_config\s*\{[\s\S]*?\n\};', plus).group()
            assert structure in original, 'Struct extraction differs from licensed parent'
            removed = next(row for row in diff if row['old_path'] == parent['path'])
            minus = '\n'.join(line[1:] for line in removed['diff'].splitlines() if line.startswith('-'))
            assert structure in minus, 'Licensed source was not moved in this commit'
        elif review['rule'] == 'nir-inline-extraction':
            removed = next(row for row in diff if row['old_path'] == 'src/compiler/nir/nir.c')
            minus = '\n'.join(line[1:] for line in removed['diff'].splitlines() if line.startswith('-'))
            original = evidence['nir-c-parent.raw'].decode()
            for symbol in ('nir_foreach_src(', 'nir_foreach_dest('):
                assert symbol in minus and symbol in plus and symbol in original
            header = next(row for row in diff if row['old_path'] == 'src/compiler/nir/nir.h')
            assert '#include "nir_inline_helpers.h"' in header['diff']
        elif review['rule'] == 'nouveau-helper-extraction':
            parent = review['parents'][0]
            original = evidence[parent['file']].decode()
            removed = next(row for row in diff if row['old_path'] == parent['path'])
            minus = '\n'.join(line[1:] for line in removed['diff'].splitlines() if line.startswith('-'))
            for line in ('drmVersionPtr ver = drmGetVersion(fd);',
                         'const bool is_nouveau = !strncmp("nouveau", ver->name, ver->name_len);',
                         'drmFreeVersion(ver);'):
                assert line in original and line in minus and line in plus
            assert 'drm_fd_is_nouveau(fd)' in removed['diff']
        elif review['rule'] == 'format-table-conversion':
            parent = review['parents'][0]
            removed = next(row for row in diff if row['old_path'] == parent['path'])
            assert removed['deleted_file'] and not removed.get('too_large')
            original = evidence[parent['file']].decode()
            old_names = set(re.findall(r'^PIPE_FORMAT_(\w+)\s*,', original, re.M))
            new_names = set(re.findall(r'^- name: (\w+)$', plus, re.M))
            assert len(old_names) > 100 and old_names == new_names, 'Format conversion input mismatch'
        elif review['rule'] == 'extensions-table-extraction':
            parent = review['parents'][0]
            original = evidence[parent['file']].decode()
            removed = next(row for row in diff if row['old_path'] == parent['path'])
            minus = '\n'.join(line[1:] for line in removed['diff'].splitlines() if line.startswith('-'))
            entries = lambda text: re.findall(r'^\s*EXT\(([^\n]+)\)\s*$', text, re.M)
            extracted = entries(plus)
            assert len(extracted) > 100 and extracted == entries(minus)
            assert all(item in entries(original) for item in extracted)
            assert '#include "extensions_table.h"' in removed['diff']
        else:
            raise AssertionError('Unreviewed lineage rule')
        verified[review['path']] = {'commit': review['commit'], 'rule': review['rule'],
                                   'retained_parent_notices': retained}
    assert len(verified) == 5
    return verified


def fetch_history(destination):
    import urllib.request
    destination.mkdir(parents=True, exist_ok=False)
    for entry in json.loads(LINEAGE.read_text())['evidence']:
        assert entry['url'].startswith('https://gitlab.freedesktop.org/api/v4/')
        with urllib.request.urlopen(entry['url'], timeout=30) as response:
            data = response.read()
        assert digest(data) == entry['sha256'], 'Fetched history differs from pinned review'
        (destination / entry['file']).write_bytes(data)


def audit(mesa_archive, blake3_archive, provenance_path, history_root=None):
    mesa = read_archive(mesa_archive, MESA_SHA, 'mesa-' + MESA_COMMIT)
    upstream = read_archive(blake3_archive, BLAKE3_SHA, 'BLAKE3-' + BLAKE3_COMMIT)
    provenance = json.loads(provenance_path.read_text())
    assert provenance['mesa_commit'] == MESA_COMMIT
    assert provenance['mesa_source_sha256'] == MESA_SHA
    assert provenance['nir_source_sha256'] == NIR_SHA
    sdk_inventory_path = ROOT / 'Projects/xmake/godot/windows_d3d12_sdk.json'
    sdk_inventory = json.loads(sdk_inventory_path.read_text())
    assert sdk_inventory['godot_nir_tag'] == provenance['godot_nir_tag'] == '25.3.1-1'
    records = {r['path']: r for r in provenance['files']}
    assert len(records) == len(provenance['files']), 'Duplicate provenance input'
    missing = provenance['files_without_notice_blocks']
    assert len(missing) == len(set(missing)) == 19
    assert set(missing) == {r['path'] for r in records.values() if not r['notice_blocks']}
    notice_dir = ROOT / 'Tools/Godot/licenses/nir-25.3.1-1/blake3-1.8.2'
    licenses = []
    for item in json.loads((notice_dir / 'sources.json').read_text()):
        data = upstream[item['file']]
        assert digest(data) == item['sha256']
        assert data == (notice_dir / item['file']).read_bytes()
        licenses.append({'path': 'BLAKE3/' + item['file'], 'sha256': digest(data),
                         'packaged_notice_source': str((notice_dir / item['file']).relative_to(ROOT))})
    # The README defines choices for upstream code; it does not establish the
    # licensing of later Mesa-only additions or modifications.
    choice = upstream['README.md'].decode().split('## Licenses', 1)[1].split('## ', 1)[0]
    assert all(term in choice for term in ('CC0 1.0', 'Apache 2.0', 'LLVM'))
    objects = provenance['object_sources']
    notice = provenance_path.with_name('GODOT-NIR-THIRD-PARTY-NOTICES.txt')
    # Modified-provenance fixtures may live elsewhere; always use the checked
    # source notice, and bind it to this provenance's expected payload hash.
    notice = ROOT / 'Tools/Godot/licenses/nir-25.3.1-1' / notice.name
    assert digest(notice.read_bytes()) == provenance['notice_sha256']
    lineage = history_reviews(history_root, notice.read_text()) if history_root else {}
    rows = []
    for name in missing:
        record = records[name]
        row = {'path': name, 'sha256': record['sha256'],
               'archive_objects_by_source_or_generator': [
                   obj['object'] for obj in objects
                   if obj.get('source') == name or obj.get('generator') == name],
               'notice_inheritance_verified': False}
        if name.startswith('mesa/'):
            data = mesa[name.removeprefix('mesa/')]
            assert digest(data) == record['sha256'], 'Notice-free source changed: ' + name
        else:
            assert name.startswith('sdk-generated/'), 'Unrecognized input namespace: ' + name
            sdk_name = 'godot-mesa/' + name.removeprefix('sdk-generated/')
            assert sdk_inventory['files'][sdk_name] == record['sha256'], 'Generated metadata differs from pinned SDK: ' + name
        if name.startswith('mesa/src/util/blake3/') and Path(name).name in BLAKE3_FILES:
            source = 'c/' + Path(name).name
            original = upstream[source]
            same = original == data
            row.update(upstream_path='BLAKE3/' + source,
                       upstream_sha256=digest(original),
                       upstream_license_choices=['CC0-1.0', 'Apache-2.0', 'Apache-2.0 WITH LLVM-exception'],
                       status='identical-upstream-license-evidence' if same else 'modified-upstream-review-required',
                       notice_inheritance_verified=same,
                       source_diff=''.join(difflib.unified_diff(
                           original.decode().splitlines(True), data.decode().splitlines(True),
                           fromfile='BLAKE3/' + source, tofile=name)),
                       remaining_review=None if same else 'Confirm licensing/attribution of Mesa changes; upstream base alone is insufficient.')
        else:
            row.update(status='review-required', remaining_review=(
                'Generated version metadata; confirm generator/source relationship.' if name.startswith('sdk-generated/') else
                'Confirm applicable component or file history; Mesa majority-MIT overview alone is insufficient.'))
        if name in lineage:
            row.update(status='historical-extraction-retained-notices',
                       notice_inheritance_verified=True, source_lineage=lineage[name],
                       remaining_review=None)
        rows.append(row)
    mapped = [row for row in rows if 'upstream_path' in row]
    assert len(mapped) == 5
    assert sum(row['notice_inheritance_verified'] for row in rows) == 2 + len(lineage)
    return {'schema': 1, 'evidence_verified': True, 'inheritance_review_complete': False,
            'scope': 'Pinned-source and original-license evidence for all 19 notice-free inventory entries; unresolved entries remain explicit. Not legal advice, final-link or runtime acceptance.',
            'mesa_commit': MESA_COMMIT, 'mesa_source_sha256': MESA_SHA,
            'blake3_commit': BLAKE3_COMMIT, 'blake3_source_sha256': BLAKE3_SHA,
            'provenance_sha256': digest(provenance_path.read_bytes()),
            'sdk_inventory_sha256': digest(sdk_inventory_path.read_bytes()),
            'source_lineage_registry_sha256': digest(LINEAGE.read_bytes()) if history_root else None,
            'historical_extraction_files': len(lineage),
            'upstream_license_sources': licenses, 'upstream_license_choice_text': choice.strip(),
            'notice_free_files': len(rows), 'upstream_base_verified_files': len(mapped),
            'identical_upstream_files': 2, 'modified_upstream_files': 3,
            'unresolved_files': [row['path'] for row in rows if not row['notice_inheritance_verified']],
            'files': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mesa-source', type=Path, required=True)
    parser.add_argument('--blake3-source', type=Path, required=True)
    parser.add_argument('--provenance', type=Path, default=ROOT / 'Tools/Godot/licenses/nir-25.3.1-1/GODOT-NIR-PROVENANCE.json')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--history-root', type=Path)
    parser.add_argument('--fetch-history', action='store_true',
                        help='Fetch pinned official evidence files into a fresh history-root')
    args = parser.parse_args()
    assert not args.output.exists(), 'Preserve earlier evidence; use a fresh output path'
    if args.fetch_history:
        assert args.history_root, '--fetch-history requires --history-root'
        fetch_history(args.history_root)
    result = audit(args.mesa_source, args.blake3_source, args.provenance, args.history_root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(f"Source evidence verified: {result['upstream_base_verified_files']} BLAKE3 bases, "
          f"{result['identical_upstream_files']} identical; {len(result['unresolved_files'])} inheritance reviews remain")


if __name__ == '__main__':
    main()
