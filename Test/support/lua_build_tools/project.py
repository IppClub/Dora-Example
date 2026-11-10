from lua_tools import call
def lua_string(value): return call('Tools.Godot.project', 'lua_string', value)
def require_ordinary_host(binary): return call('Tools.Godot.project', 'require_ordinary_host', binary)
def clone(repository, output, timeout): return call('Tools.Godot.project', 'clone', repository, output, timeout)
