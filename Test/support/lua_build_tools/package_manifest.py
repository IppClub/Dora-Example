from lua_tools import call
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
def digest(path): return call('Tools.Godot.common', 'digest', path)
def seal(package, manifest):
    manifest.update(call('Tools.Godot.package_manifest', 'seal', package, manifest))
    return manifest
