from lua_tools import call
from godot_paths import ENGINE_ROOT as ROOT
def verify(sdk, metadata_path): return call('Tools.Godot.verify_d3d12_sdk', 'verify', sdk, metadata_path)
