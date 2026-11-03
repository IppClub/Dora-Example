#!/usr/bin/env python3
"""Exercise dependency notice inclusion and rejection after a valid reseal.

The dummy DLL is a packaging fixture and is never loaded or GPU tested.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import hashlib,json
from pathlib import Path
import subprocess
import sys
import tempfile
from package_manifest import seal
from verify_package import verify

ROOT = ENGINE_ROOT
with tempfile.TemporaryDirectory(prefix='dora-nir-package-') as temporary:
    work = Path(temporary)
    dll = work / 'fixture.dll'
    dll.write_bytes(b'Packaging fixture only: not an executable DLL')
    package = work / 'package'
    subprocess.run([sys.executable, str(ROOT / 'Tools/Godot/package_runtime.py'),
                    '--source', str(ROOT / 'Source/3rdParty/Godot'),
                    '--library', str(dll), '--output', str(package),
                    '--graphics-backend', 'd3d12', '--architecture', 'x86_64'],
                   check=True, stdout=subprocess.PIPE)
    assert verify(package)['passed']
    manifest = json.loads((package / 'manifest.json').read_text())
    provenance = package / 'GODOT-NIR-PROVENANCE.json'
    original = provenance.read_bytes()
    assert json.loads(original)['schema'] == 2
    notice = package / 'GODOT-NIR-THIRD-PARTY-NOTICES.txt'
    original_notice = notice.read_bytes()
    for case in ('missing-history', 'changed-history', 'missing-historical-text'):
        altered = json.loads(original)
        if case == 'missing-history':
            altered.pop('historical_notice_sources')
        elif case == 'changed-history':
            altered['historical_notice_sources'][0]['notice_text'] += 'Changed attribution\n'
        else:
            text = altered['historical_notice_sources'][0]['notice_text'].encode()
            notice.write_bytes(original_notice.replace(text, b''))
            altered['notice_sha256'] = hashlib.sha256(notice.read_bytes()).hexdigest()
        provenance.write_text(json.dumps(altered))
        (package / 'manifest.json').write_text(json.dumps(seal(package, manifest)))
        try:
            verify(package)
        except ValueError as error:
            assert 'inherited notices missing or invalid' in str(error), (case, error)
        else:
            raise AssertionError('Resealed package accepted invalid historical notices: ' + case)
        notice.write_bytes(original_notice)
    altered = json.loads(original)
    altered['notice_sha256'] = '0' * 64
    provenance.write_text(json.dumps(altered))
    (package / 'manifest.json').write_text(json.dumps(seal(package, manifest)))
    try:
        verify(package)
    except ValueError as error:
        assert 'notice provenance mismatch' in str(error), error
    else:
        raise AssertionError('Resealed provenance/notice mismatch was accepted')
    provenance.write_bytes(original)
    provenance.unlink()
    (package / 'manifest.json').write_text(json.dumps(seal(package, manifest)))
    try:
        verify(package)
    except ValueError as error:
        assert 'dependency notices/provenance missing' in str(error), error
    else:
        raise AssertionError('Resealed package missing NIR provenance was accepted')
print('PASS: D3D12 packaging fixture includes inherited NIR notices; five resealed corrupt/missing evidence cases rejected')
