from lua_tools import call
def variant_target(source, flags): return call('Tools.Godot.native_variants', 'variant_target', source, flags)
def manifest_actions(text): return call('Tools.Godot.native_variants', 'manifest_actions', text, list_result=True)
def validate_native_variants(text): return call('Tools.Godot.native_variants', 'validate_native_variants', text)
