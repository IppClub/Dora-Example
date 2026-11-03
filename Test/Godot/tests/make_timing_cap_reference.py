#!/usr/bin/env python3
"""Seal the pinned upstream and three native-host capped-clock GPU references."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import os
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
for name in ('official-results', 'official-project', 'official-version-file',
             'official-archive', 'metal-results', 'egl-arm64-results',
             'egl-x64-results', 'output'):
    p.add_argument('--' + name, required=True, type=Path)
a = p.parse_args()
root = ENGINE_ROOT
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
version = a.official_version_file.read_text().strip()
assert version == '4.6.stable.official.89cea1439'
assert sha(a.official_archive) == 'fc15ceb6280420f117ab4ef62332654db0088078faeeb9025dd814276185ed3b'
upstream = json.loads((root / 'Source/3rdParty/Godot/UPSTREAM.json').read_text())
assert upstream['upstream_commit'].startswith('89cea1439')
fixture = {f.name: sha(f) for f in Path(__file__).with_name('timing_cap_project').iterdir() if f.is_file()}
components = {}
for name, folder, project in (
    ('official-godot-4.6', a.official_results, a.official_project),
    ('dora-metal', a.metal_results, a.metal_results / 'project'),
    ('dora-egl-arm64', a.egl_arm64_results, a.egl_arm64_results / 'project'),
    ('dora-egl-x64', a.egl_x64_results, a.egl_x64_results / 'project'),
):
    report = folder / 'verification.json'
    data = json.loads(report.read_text())
    assert data['passed'] and data['host_capture'] == (name != 'official-godot-4.6')
    assert abs(data['shader_delta_ticks'] - data['independent_raw_delta_ticks']) <= 2
    assert data['shader_delta_ticks'] > 4 * data['script_delta_ticks']
    assert sha(folder / 'result.json') == data['metadata_sha256']
    assert sha(folder / 'run.log') == data['log_sha256']
    assert all(sha(project / f) == digest for f, digest in fixture.items())
    for image, record in data['clocks'].items():
        assert sha(folder / (image + '.png')) == record['image_sha256']
    components[name] = dict(report=os.path.relpath(report.resolve(), a.output.resolve().parent),
        sha256=sha(report), shader_delta_ticks=data['shader_delta_ticks'],
        script_delta_ticks=data['script_delta_ticks'],
        independent_raw_delta_ticks=data['independent_raw_delta_ticks'])
main = root / 'Source/3rdParty/Godot/main/main.cpp'
code = main.read_text()
assert code.index('DoraGodotRenderTiming::enqueue(scaled_step)') < code.index('advance.physics_steps > max_physics_steps')
assert 'get_main_loop()->process(process_step * time_scale)' in code
assert 'draw(wants_present, scaled_step)' in code
assert not a.output.exists(), 'Preserve earlier reference evidence'
a.output.write_text(json.dumps(dict(passed=True,
    contract='upstream_uncapped_render_step_before_physics_catchup_cap',
    official_version=version, reference_commit=upstream['upstream_commit'],
    fixture=fixture, components=components, source_main_sha256=sha(main),
    scope='Stock Godot 4.6 and Dora Metal/EGL ARM64/x64 actual GPU clocks under catch-up cap; independent wall-clock reference within two 64Hz ticks'), indent=2) + '\n')
print(str(a.output))
