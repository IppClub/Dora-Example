#!/usr/bin/env python3
"""Exercise source/provenance rejection against the real pinned NIR inputs."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import copy
import json
from pathlib import Path
import tempfile

from audit_nir_notice_inheritance import LINEAGE, ROOT, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mesa-source', type=Path, required=True)
    parser.add_argument('--blake3-source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--history-root', type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence path'
    provenance = ROOT / 'Tools/Godot/licenses/nir-25.3.1-1/GODOT-NIR-PROVENANCE.json'
    original = json.loads(provenance.read_text())
    result = audit(args.mesa_source, args.blake3_source, provenance, args.history_root)
    assert result['evidence_verified'] and not result['inheritance_review_complete']
    assert len(result['unresolved_files']) == (12 if args.history_root else 17)
    rejected = []
    with tempfile.TemporaryDirectory(prefix='dora-nir-inheritance-') as temporary:
        modified = Path(temporary) / 'provenance.json'
        for case in ('unrecognized-archive', 'missing-input', 'source-hash', 'generated-hash'):
            document = copy.deepcopy(original)
            if case == 'missing-input':
                document['files_without_notice_blocks'].pop()
            elif case in ('source-hash', 'generated-hash'):
                target = ('mesa/src/util/blake3/blake3_dispatch.c' if case == 'source-hash'
                          else 'sdk-generated/bin/git_sha1.h')
                next(row for row in document['files'] if row['path'] == target)['sha256'] = '0' * 64
            modified.write_text(json.dumps(document))
            try:
                audit(args.blake3_source if case == 'unrecognized-archive' else args.mesa_source,
                      args.blake3_source, modified, args.history_root)
            except AssertionError as error:
                expected = {'unrecognized-archive': 'Unrecognized source archive',
                            'missing-input': '', 'source-hash': 'Notice-free source changed',
                            'generated-hash': 'Generated metadata differs from pinned SDK'}[case]
                assert expected in str(error), (case, str(error))
                rejected.append(case)
            else:
                raise AssertionError('Invalid evidence accepted: ' + case)
        if args.history_root:
            history = Path(temporary) / 'history'
            history.mkdir()
            entries = json.loads(LINEAGE.read_text())['evidence']
            for case in ('changed-history', 'missing-history'):
                for entry in entries:
                    (history / entry['file']).write_bytes((args.history_root / entry['file']).read_bytes())
                target = history / entries[0]['file']
                if case == 'changed-history':
                    target.write_bytes(target.read_bytes() + b'\n')
                else:
                    target.unlink()
                try:
                    audit(args.mesa_source, args.blake3_source, provenance, history)
                except AssertionError as error:
                    assert case == 'changed-history' and 'Historical input changed' in str(error)
                    rejected.append(case)
                except FileNotFoundError as error:
                    assert case == 'missing-history' and Path(error.filename) == target
                    rejected.append(case)
                else:
                    raise AssertionError('Invalid history accepted: ' + case)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({
        'passed': True, 'scope': 'Real pinned-source positive and negative evidence checks; no runtime execution or complete license acceptance',
        'rejected_cases': rejected, 'unresolved_files': len(result['unresolved_files']),
    }, indent=2) + '\n')
    print(f"PASS: real source evidence; {len(rejected)} altered/missing inputs rejected; "
          f"{len(result['unresolved_files'])} reviews remain")


if __name__ == '__main__':
    main()
