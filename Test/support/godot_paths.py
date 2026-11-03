"""Resolve relocated Godot tests against an explicit engine checkout."""
import json
import os
import sys
from pathlib import Path

TEST_REPO = Path(__file__).resolve().parents[2]
_explicit = os.environ.get('DORA_ENGINE_ROOT') or os.environ.get('DORA_SSR_ROOT')
if _explicit:
    ENGINE_ROOT = Path(_explicit).resolve()
else:
    _candidates = [Path.cwd(), TEST_REPO.parent / 'Dora-SSR']
    ENGINE_ROOT = next((p.resolve() for p in _candidates if (p / 'xmake.lua').is_file()), None)
    if ENGINE_ROOT is None:
        raise RuntimeError('Set DORA_ENGINE_ROOT to the Dora-SSR checkout')
sys.path.insert(0, str(ENGINE_ROOT / 'Tools/Godot'))
os.environ.setdefault('DORA_ENGINE_ROOT', str(ENGINE_ROOT))
os.environ.setdefault('DORA_TEST_REPO', str(TEST_REPO))
_PATHS = json.loads((TEST_REPO / 'Test/Godot/paths.json').read_text())

def test_path(relative):
    """Resolve an original engine test path; production paths stay in the engine."""
    relative = str(relative).replace('\\', '/')
    if relative in _PATHS:
        return TEST_REPO / _PATHS[relative]
    for old, new in [('Tools/Godot/tests', 'Test/Godot/tests'),
                     ('Tools/LibGodotMetalProbe', 'Test/LibGodotMetalProbe')]:
        if relative == old or relative.startswith(old + '/'):
            return TEST_REPO / new / relative[len(old):].lstrip('/')
    if relative.startswith(('Test/Godot/', 'Test/LibGodotMetalProbe/', 'Test/support/')):
        return TEST_REPO / relative
    return ENGINE_ROOT / relative
