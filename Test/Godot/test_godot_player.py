#!/usr/bin/env python3
"""Run the production Lua player contract using Lua or Dora's bundled Lua host."""
import os,shutil,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
lua=os.getenv('DORA_GODOT_PLAYER_LUA') or shutil.which('lua')
if not lua:
    candidates=sorted((p for p in (ENGINE_ROOT/'build/host').glob('**/bin/dora-tolua*') if p.name in ('dora-tolua','dora-tolua.exe') and p.is_file()),key=lambda p:p.stat().st_mtime,reverse=True)
    assert candidates,'Build dora-tolua first or set DORA_GODOT_PLAYER_LUA'
    lua=str(candidates[0])
script=TEST_REPO/'Test/Godot/tests/project_switch/controller_contract.lua'
module=ENGINE_ROOT/'Assets/Script/Lib/GodotPlayer.lua'
env=os.environ.copy();env['DORA_GODOT_PLAYER_SOURCE']=str(module)
command=[lua,str(script)]
if Path(lua).stem!='dora-tolua':command.append(str(module))
subprocess.run(command,check=True,env=env,cwd=ENGINE_ROOT,timeout=30)
