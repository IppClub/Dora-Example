#!/usr/bin/env python3
"""Decode upstream shader/script clock behavior when physics catch-up is capped."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import re
from PIL import Image, ImageChops

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('results', type=Path)
p.add_argument('--host-capture', action='store_true')
p.add_argument('--engine-readback', action='store_true')
p.add_argument('--web-execution', action='store_true', help='Require actual browser execution/normal shutdown evidence instead of a native process result')
p.add_argument('--android-execution', action='store_true', help='Require ordinary APK Activity/LibGodot shutdown evidence')
p.add_argument('--diagnose-android-shader-cache', type=Path, metavar='PROBE_JSON', help='Produce a failing diagnostic report with pixel results for the independently reproduced Android binary-cache warning; never passes acceptance')
p.add_argument('--cabi-observer', action='store_true', help='For Web, verify observed production close/reader calls when immediate host exit does not flush native Info logs')
p.add_argument('--buffers', type=int, choices=(2, 3, 4), default=3)
a = p.parse_args()
assert not (a.host_capture and a.engine_readback)
assert not a.web_execution or a.engine_readback
assert not a.android_execution or (a.engine_readback and not a.web_execution)
assert not a.cabi_observer or a.web_execution
assert not a.diagnose_android_shader_cache or a.android_execution
out = a.results.resolve()
metadata = json.loads((out / 'result.json').read_text(encoding='utf-8'))
log = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
assert 'TIMING_CAP ready max_steps=1 delay_ms=80' in log
assert 'TIMING_CAP complete captures=2 frames=24' in log
diagnostics = re.findall(r'^.*(?:ERROR:|WARNING:|SCRIPT ERROR|Leaked instance:|BGFX LEAK:).*$', log, re.MULTILINE)
if a.diagnose_android_shader_cache:
    assert diagnostics == ['WARNING: Failed to load cached shader, recompiling.'], diagnostics
    probe = json.loads(a.diagnose_android_shader_cache.read_text())
    assert probe['complete'] and not probe['libgodot_mapped'] and not probe['libgodot_started']
    assert probe['renderer'] in log and probe['version'] in log
    assert probe['queried_bytes'] == probe['returned_bytes'] > 0 and probe['capture_error'] == 0
    assert not probe['same_context']['linked'] and not probe['new_context']['linked']
    assert probe['same_context']['gl_error'] == probe['new_context']['gl_error'] == 0
    assert probe['source_pixels'] == probe['source_recompile_pixels'] == [32, 96, 191, 255]
else:
    assert not diagnostics, diagnostics
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
clocks = {}
for name in ('clock-a', 'clock-b'):
    rgba = Image.open(out / (name + '.png')).convert('RGBA')
    if a.engine_readback:
        assert rgba.size == (metadata[name]['width'], metadata[name]['height']), name
    if a.host_capture and json.loads((out / 'process-result.json').read_text()).get('host_capture_pixel_exact'):
        source = json.loads((out / (name + '.source.json')).read_text())
        assert rgba.size == (source['width'], source['height']) and max(rgba.size) <= 1280, 'Host clock capture was resampled'
    image = rgba.convert('RGB')
    r, g, b = image.split()
    high = ImageChops.lighter(ImageChops.lighter(r, g), b)
    low = ImageChops.darker(ImageChops.darker(r, g), b)
    mask = ImageChops.lighter(high.point(lambda x: 255 if x < 5 else 0),
                             low.point(lambda x: 255 if x > 250 else 0))
    mask = ImageChops.multiply(mask, rgba.getchannel('A').point(lambda x: 255 if x > 250 else 0))
    bounds = mask.getbbox()
    assert bounds, name
    x, y, right, bottom = bounds
    sx, sy = (right - x) / 384, (bottom - y) / 64
    assert abs(sx - sy) < .01, (name, bounds)
    codes = []
    for row in (16, 48):
        value = 0
        for bit in range(16):
            pixel = image.getpixel((int(x + (bit + .5) * 24 * sx), int(y + row * sy)))
            assert max(pixel) - min(pixel) < 8 and (max(pixel) < 40 or min(pixel) > 210), pixel
            if min(pixel) > 210:
                value |= 1 << bit
        codes.append(value)
    assert abs(codes[1] - int(metadata[name]['script_clock'] * 64)) <= 1
    clocks[name] = dict(shader=codes[0], script=codes[1], bounds=bounds,
                        image_sha256=sha(out / (name + '.png')))
first, last = metadata['clock-a'], metadata['clock-b']
assert first['frames'] == 8 and last['frames'] == 24
physics = last['physics_frames'] - first['physics_frames']
assert 14 <= physics <= 16, physics
gpu = (clocks['clock-b']['shader'] - clocks['clock-a']['shader']) % 65536
script = (clocks['clock-b']['script'] - clocks['clock-a']['script']) % 65536
assert abs(script - physics / 60 * 64) <= 2, (script, physics)
assert gpu >= physics * .08 * 64 - 2 and gpu > script * 4, (gpu, script)
raw = (last['raw_clock'] - first['raw_clock']) * 64
assert abs(gpu - raw) <= 2, ('Shader TIME / independent uncapped wall clock', gpu, raw)
if a.host_capture or a.engine_readback:
    if a.web_execution:
        execution = json.loads((out / 'execution.json').read_text(encoding='utf-8'))
        assert execution['passed'] and execution['source_hashes_verified']
        assert execution['teardown']['state'] == 'stopped'
        assert not execution['teardown']['platform']['active']
        assert execution['metadata']['buffers'] == a.buffers
        assert execution['teardown']['libgodot_shutdown'] == dict(calls=1, completed=1)
    elif a.android_execution:
        execution = json.loads((out / 'execution.json').read_text(encoding='utf-8'))
        assert execution['passed'] and execution['activity_destroyed_normally'] and execution['full_native_shutdown']
        assert execution['controller']['buffers'] == a.buffers
        assert 'GodotInstance::stop()' in log and 'destroy: Logger.' in log
    else:
        process = json.loads((out / 'process-result.json').read_text(encoding='utf-8'))
        assert process['returncode'] == 0
    assert 'TIMING_CAP host complete' in log
    if a.cabi_observer:
        metrics = execution['teardown']['gpu_lifecycle']
        assert not metrics['protocol_errors'] and len(metrics['sessions']) == 1
        session = metrics['sessions'][0]
        produced, completed, errors, reuse_waits = session['close_stats']
        assert produced > 0 and produced == completed and errors == 0 and reuse_waits >= 0
        assert session['buffers'] == a.buffers and session['pending_at_close'] == 0
        assert session['begins'] > 0 and session['max_pending'] > 0 and session['bindings'] >= 2
        assert session['begins'] + session['empty_ends'] == session['ends']
        assert session['ends'] % a.buffers == 0 and all(value == 0 for value in session['pending'].values())
    else:
        clients = re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)', log)
        assert len(clients) == 1 and clients[0][0] == clients[0][1] and clients[0][2] == '0'
        readers = re.findall(r'GodotRuntime readers: buffers=' + str(a.buffers) + r', frames=(\d+), waits=\d+, signals=\d+, pending=(\d+), completed=(\d+), gpuErrors=(\d+)', log)
        assert len(readers) == 1 and readers[0][0] == readers[0][2] and readers[0][1] == readers[0][3] == '0'
    assert re.search(r'DORA_GODOT_(?:METAL|GL)_DIRECT completed frames=\d+ blits=0', log)
report = dict(passed=True, clocks=clocks, shader_delta_ticks=gpu, script_delta_ticks=script,
              physics_steps=physics, independent_raw_delta_ticks=raw, host_capture=a.host_capture,
              engine_readback=a.engine_readback,
              web_execution=a.web_execution,
              android_execution=a.android_execution,
              stats_evidence='Observed production C ABI' if a.cabi_observer else 'Native diagnostics',
              buffers=a.buffers,
              metadata_sha256=sha(out / 'result.json'), log_sha256=sha(out / 'run.log'),
              scope='Forced one-step physics catch-up cap; uncapped shader clock and capped script delta, actual GPU pixels')
if a.diagnose_android_shader_cache:
    report.update(passed=False, pixel_contract_passed=True, strict_acceptance_passed=False,
                  diagnostics=diagnostics, independent_probe_sha256=sha(a.diagnose_android_shader_cache),
                  scope='Diagnostic only: pixel/clock/GPU/lifecycle checks passed but original strict warning gate remains failed')
    (out / 'shader-cache-diagnostic.json').write_text(json.dumps(report, indent=2) + '\n')
else:
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
if a.diagnose_android_shader_cache:
    raise SystemExit(1)
