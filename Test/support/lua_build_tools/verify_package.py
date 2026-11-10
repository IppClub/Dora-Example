from lua_tools import call
def verify(package): return call('Tools.Godot.verify_package', 'verify', package)
