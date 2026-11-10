"""Test-only transport to repository Lua tools; no build implementation lives here."""
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
from godot_paths import ENGINE_ROOT

class LuaToolError(ValueError):
    pass

def _encode(value):
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, bytes):
        return {'__lua_bytes': base64.b64encode(value).decode('ascii')}
    if isinstance(value, dict):
        return {key: _encode(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_encode(item) for item in value]
    return value

def call(module, method, *args, list_result=False, binary_values=False, multiple=False):
    with tempfile.TemporaryDirectory(prefix='dora-lua-test-') as temporary:
        request, result = Path(temporary)/'request.json', Path(temporary)/'result.json'
        request.write_text(json.dumps(dict(module=module, method=method, args=_encode(args), arg_count=len(args),
                                          list_result=list_result, binary_values=binary_values, multiple=multiple), ensure_ascii=False))
        command = [os.environ.get('DORA_XMAKE', 'xmake'), 'lua', str(Path(__file__).with_suffix('.lua')),
                   str(ENGINE_ROOT), str(request), str(result)]
        completed = subprocess.run(command, cwd=ENGINE_ROOT, text=True, capture_output=True)
        if completed.returncode or not result.is_file():
            raise LuaToolError(completed.stdout + completed.stderr)
        response = json.loads(result.read_text())
        if not response['ok']:
            raise LuaToolError(response['error'])
        value = response.get('value')
        if binary_values:
            value = {key: base64.b64decode(item['__lua_bytes']) for key, item in value.items()}
        return value

def cli(script, *args, **kwargs):
    return subprocess.run([os.environ.get('DORA_XMAKE', 'xmake'), 'lua', str(ENGINE_ROOT/script), *map(str, args)],
                          cwd=ENGINE_ROOT, **kwargs)

def bundle_verifier(output):
    """Keep offline acceptance bundles self-contained; xmake 3.x is a prerequisite."""
    import shutil
    output = Path(output)
    for relative in ('Tools/Godot/common.lua', 'Tools/Godot/ordered_json.lua',
                     'Tools/Godot/verify_nir_review.lua', 'Tools/Godot/verify_package.lua',
                     'Tools/Godot/package_manifest.lua',
                     'Projects/xmake/godot/macos_accesskit_sdk.json',
                     'Projects/xmake/godot/linux_accesskit_sdk.json',
                     'Tools/Godot/licenses/accesskit-0.22.3/GODOT-ACCESSKIT-NOTICES.txt'):
        destination = output/relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ENGINE_ROOT/relative, destination)
    support = Path(__file__).parent
    for relative in ('lua_tools.py', 'lua_tools.lua', 'lua_build_tools/verify_package.py', 'lua_build_tools/package_manifest.py'):
        destination = output/'Test/support'/relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(support/relative, destination)
    (output/'LUA-TOOLS.txt').write_text('Package verification requires xmake 3.x on PATH, or set DORA_XMAKE to its executable.\nProduction verification runs in Lua; Python files are test adapters only.\n')
