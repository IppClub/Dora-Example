from lua_tools import call, LuaToolError
from urllib.parse import unquote
import json
import base64
def chunk_script(url, data): return 'DoraHtmlPackage.deliver('+json.dumps(url)+',"'+base64.b64encode(data).decode()+'");\n'
def sha256_bytes(data): return call('Tools.Godot.common', 'data_digest', data)
def build(args):
    values = {name.replace('_','-'): value for name, value in vars(args).items()}
    try: return call('Tools.WebBuilder.webbuild', 'build', values, binary_values=True)
    except LuaToolError as error: raise SystemExit(str(error))
def verify(path, quiet=False): return call('Tools.WebBuilder.webbuild', 'verify', path, quiet, list_result=True)
def apply_compat_patches(html): return call('Tools.WebBuilder.webbuild', 'apply_compat_patches', html)
def validate_path(path):
    from lua_tools import LuaToolError
    try: return call('Tools.Godot.common', 'safe_relative', path)
    except LuaToolError as error: raise SystemExit(str(error))
