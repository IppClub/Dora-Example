#!/usr/bin/env python3
"""Probe the production Lua version reader with a UTF-8 tool banner."""
import os, sys, shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
from lua_tools import call, LuaToolError
program = shutil.which(os.environ.get('DORA_XMAKE','xmake'))
version, banner = call('Tools.Godot.platform_build','probe_version',program,['lua','-c','print("xmake v3.1.2\\n🏗")'],multiple=True)
assert version == 3 and '🏗' in banner
try: call('Tools.Godot.platform_build','probe_version',program,['lua','-c','print("xmake v2.9.1")'],multiple=True)
except LuaToolError: pass
else: raise AssertionError('Old xmake was accepted')
print('PASS Lua version probe preserves UTF-8 and rejects unsupported tool versions')
