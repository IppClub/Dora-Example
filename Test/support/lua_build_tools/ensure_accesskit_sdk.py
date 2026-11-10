from pathlib import Path
from lua_tools import call
def ensure(destination=None, archive=None, spec_path=None):
    return Path(call('Tools.Godot.ensure_accesskit_sdk','ensure',destination,archive,spec_path))
def verify(destination, spec): return call('Tools.Godot.ensure_accesskit_sdk','verify',destination,spec)
