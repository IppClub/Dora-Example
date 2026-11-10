from lua_tools import call
def parse(entry, include_roots=None): return call('Tools.Godot.import_compile_db', 'parse', entry, include_roots, multiple=True)
def stage(source): return call('Tools.Godot.import_compile_db', 'stage', source)
