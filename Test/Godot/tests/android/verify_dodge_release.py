"""Verify the unchanged official Dodge project inside an ordinary Android APK."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path, GODOT_ENGINE_BANNER
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path
from PIL import Image
from verify_ordinary_release import changed, pixels

NAMES = ['title', 'input-before', 'input-after', 'active-a', 'active-b',
         'paused-a', 'paused-b', 'resumed', 'removed', 'recreated-a', 'recreated-b', 'recreated-removed']


def audit_assets(apk, manifest):
    metadata = json.loads(manifest.read_text())
    assert metadata['upstream_repository'] == 'https://github.com/godotengine/godot-demo-projects'
    assert metadata['upstream_project'] == '2d/dodge_the_creeps'
    with zipfile.ZipFile(apk) as apk_zip:
        assert apk_zip.read('assets/GodotDodge.json') == manifest.read_bytes()
        assert apk_zip.read('assets/Script/GodotDodgeRelease.lua') == Path(__file__).with_name('dodge_release.lua').read_bytes()
        packed = apk_zip.read('assets/GodotDodge.zip')
        assert hashlib.sha256(packed).hexdigest() == metadata['archive_sha256']
        with zipfile.ZipFile(io.BytesIO(packed)) as archive:
            assert len(archive.namelist()) == len(set(archive.namelist()))
            hashes = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in archive.namelist()}
            assert hashes == metadata['packed_files']
            assert {n: h for n, h in hashes.items() if not n.startswith('.godot/')} == metadata['upstream_project_files']
    return metadata


def verify_case(case, buffers, metadata, controller, *, web_host=False):
    assert buffers == 3
    log = (case / 'run.log').read_text(errors='replace')
    result = json.loads((case / 'files/result.json').read_text())
    assert result == {'complete': True, 'dodge': True, 'full': False, 'captures': 12, 'buffers': 3, 'recreated': True}
    assert controller['dodge'] and controller['project_sha256'] == metadata['upstream_project_files']
    assert log.count(GODOT_ENGINE_BANNER) == 1 and 'DORA_DODGE complete=1 captures=12 ticks=625' in log
    assert 'DORA_DODGE recreated=1' in log
    assert not re.search(r'ERROR:|\[error\]|\[critical\]|FATAL EXCEPTION|Fatal signal|BGFX LEAK:|C\+\+ objects leaks', log)
    warnings = [line for line in log.splitlines() if 'WARNING:' in line or '[warning]' in line]
    for line in warnings:
        assert (line.endswith("[warning] failed to open a new controller! Couldn't find mapping for device (0)")
                or line == 'WARNING: Failed to load cached shader, recompiling.'), line
    assert [re.search(r'DORA_DODGE capture=(\S+)', l)[1] for l in log.splitlines() if 'DORA_DODGE capture=' in l] == NAMES
    images = {name: Image.open(case / 'files' / (name + '.png')).convert('RGB') for name in NAMES}
    assert len({im.size for im in images.values()}) == 1
    width, height = images['title'].size
    m = re.search(r'DORA_DODGE view=(\d+)x(\d+) scale=([\d.]+)', log); assert m
    vw, vh, scale = int(m[1]), int(m[2]), float(m[3])
    sx, sy = width / vw, height / vh
    box = (round(width/2-240*scale*sx), round(height/2-360*scale*sy),
           round(width/2+240*scale*sx), round(height/2+360*scale*sy))
    crops = {name: im.crop(box) for name, im in images.items()}
    checks = {label: changed(crops[a], crops[b]) for label, a, b in [
        ('started', 'title', 'input-before'), ('active', 'active-a', 'active-b'),
        ('paused', 'paused-a', 'paused-b'), ('resumed', 'paused-b', 'resumed'),
        ('removed', 'resumed', 'removed'), ('recreated_animation', 'recreated-a', 'recreated-b'),
        ('recreated_removal', 'recreated-b', 'recreated-removed')]}
    assert checks['started'] > 1000 and checks['active'] > 500, checks
    assert checks['paused'] < 500 and checks['resumed'] > 500 and checks['removed'] > 1000, checks
    assert checks['recreated_animation'] > 500 and checks['recreated_removal'] > 1000, checks
    def player_x(name):
        image = crops[name]
        points = [x for y in range(image.height) for x in range(image.width)
                  if all(abs(image.getpixel((x,y))[i] - value) < 18 for i, value in enumerate((148,127,124)))]
        assert len(points) > 40, (name,len(points))
        return sum(points)/len(points)
    movement = player_x('input-after') - player_x('input-before')
    assert movement > 40, movement
    for image in images.values():
        assert sum(g > 200 and r < 40 and b < 40 for r,g,b in pixels(image)) > 100, 'Dora marker missing'
    clients = re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)', log)
    readers = re.findall(r'GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)', log)
    audio = re.findall(r'GodotAudio drained: produced=(\d+), consumed=(\d+), nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)', log)
    direct = re.findall(r'DORA_GODOT_GL_DIRECT completed frames=(\d+) blits=(\d+)', log)
    assert len(clients) == len(readers) == len(audio) == len(direct) == 2
    for client in clients:
        produced, completed, errors = map(int, client)
        assert produced == completed and produced > 0 and errors == 0
    for reader in readers:
        b, frames, waits, signals, pending, complete, errors = map(int, reader)
        assert b == buffers and frames == complete and frames > 0 and pending == errors == 0
        assert 0 < waits <= signals and signals == frames * buffers
    for pcm in audio:
        produced, consumed, nzp, nzc, underrun = map(int, pcm)
        assert produced >= consumed > 48000 and nzp > 48000 and nzc > 48000 and underrun == 0
    for publication in direct:
        frames, blits = map(int,publication); assert frames > 0 and blits == 0
    if web_host:
        # Browser stop drains the embedded runtime and disposes page services;
        # it does not destroy the entire reusable Dora Wasm instance.
        assert 'DORA_WEB_DODGE_STOPPED' in log
    else:
        lifecycle = [n.strip() for group in re.findall(r'destroy: ([^\r\n]+)\.',log) for n in group.split(',')]
        for n in ('Director','BGFXDora','Logger'): assert lifecycle.count(n) == 1
        assert lifecycle.index('Director') < lifecycle.index('BGFXDora') < lifecycle.index('Logger')
        assert 'QA_ACTIVITY_DESTROYED' in log
    return {'passed':True,'full_acceptance':False,'buffers':buffers,'captures':12,'same_process_node_recreated':True,'libgodot_initializations':1,
            'upstream_project':metadata,'source_files_unchanged_after_runtime':True,
            'gpu_clients':clients,'gpu_readers':readers,'direct_blits':0,
            'metrics':{'image_changes':checks,'player_moved_pixels':movement,'pcm':audio},
            'allowed_environment_warnings':warnings,
            'images_sha256':{n:hashlib.sha256((case/'files'/(n+'.png')).read_bytes()).hexdigest() for n in NAMES},
            'scope':('Unmodified official Dodge project on Web; page stop and PCM only, not physical audio-device proof' if web_host else
                     'Unmodified official Dodge project on Android; PCM and emulator evidence are not physical-device proof')}
