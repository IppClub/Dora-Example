from lua_tools import call
def parse(entry): return call('Tools.Godot.import_compile_db', 'parse', entry, None, True, multiple=True)
def stage(source): return call('Tools.Godot.import_compile_db', 'stage', source)
