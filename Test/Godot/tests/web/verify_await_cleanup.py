#!/usr/bin/env python3
"""Verify real Web pending-await cleanup, source identity and GPU drain."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('output', type=Path)
a = p.parse_args()
out = a.output.resolve()
d = json.loads((out / 'execution.json').read_text())
assert d['passed'] and d['await_cleanup'] and d['controller_frames'] == 150
assert d['pending_awaits'] == 2
logs = '\n'.join(d['logs'])
assert logs.count('AWAIT_CLEANUP armed') == 2
assert 'AWAIT_CLEANUP child freed; root pending until shutdown' in logs
assert 'GodotInstance::stop()' in logs
for token in ('WARNING:', 'ERROR:', '[error]', 'Leaked instance:', 'Orphan StringName:', 'AWAIT_CLEANUP unexpectedly resumed'):
    assert token not in logs, token
metrics = d['audio_metrics']
assert not metrics['protocol_errors'] and not metrics['underruns']
assert len(metrics['sessions']) == 1
session = metrics['sessions'][0]
produced, completed, errors, reuse_waits = session['close_stats']
assert produced > 0 and produced == completed and errors == 0 and reuse_waits >= 0
assert re.search(r'DORA_GODOT_GL_DIRECT completed frames=\d+ blits=0', logs)
blits = 0
assert session['pending_at_close'] == 0 and all(value == 0 for value in session['pending'].values())
e = json.loads((out / 'await-evidence.json').read_text())
fixture = Path(__file__).resolve().parents[1] / 'await_cleanup'
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
expected = {f.name: sha(f) for f in fixture.iterdir() if f.is_file()}
assert e['metadata']['fixture'] == e['host'] == e['godot'] == expected
report = {'passed': True, 'browser': d['browser'], 'browser_engine': d['browser_engine'],
          'renderer': d['renderer'], 'artifacts': d['artifacts'], 'pending_awaits': 2,
          'produced': produced, 'completed': completed, 'blits': blits,
          'reuse_waits': reuse_waits,
          'execution_sha256': sha(out / 'execution.json'), 'fixture': expected,
          'scope': 'Actual browser WebGL2, canonical await cancellation and normal LibGodot shutdown; no physical mobile or audio-device claim'}
(out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
