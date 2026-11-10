#!/usr/bin/env python3
"""Validate native Godot startup transitions in an isolated asset tree/window."""
from pathlib import Path
import argparse,json,subprocess,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
root=ENGINE_ROOT.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
assets=output/'Assets';assets.mkdir()
for source in (root/'Assets').iterdir():
 if source.name!='Script':(assets/source.name).symlink_to(source,target_is_directory=source.is_dir())
(assets/'Script').mkdir()
for name,main in [('valid','main.tscn'),('invalid','absent.tscn')]:
 project=output/name;project.mkdir()
 (project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://'+main+'"\n[rendering]\nrenderer/rendering_method="mobile"\n')
 (project/'main.tscn').write_text('[gd_scene format=3]\n[node name="Main" type="Node2D"]\n')
source='''local D = require("Dora")
D.Content.searchPaths = {SOURCE .. "/Assets", SOURCE .. "/Assets/Script", SOURCE .. "/Assets/Script/Lib", SOURCE .. "/Assets/Script/Lib/Dora/en"}
D.Director.systemScheduler:schedule(D.once(function()
 local ok, err = pcall(function()
  local transition = require("Script.Dev.RunTransition")
  local status = {running=true, runId=1}
  local entry = {getCurrentEntryStatus=function() return status end}
  local game = assert(D.GodotNode(OUTPUT .. "/valid", "", 64, 64, 3))
  game:addTo(D.Director.ui)
  local readyFrame
  game:onUpdate(function()
   if game.running then readyFrame=D.App.frame; return true end
   return false
  end)
  local passed, reason = transition.waitForFrameAsync(entry, 1, true)
  assert(passed, reason)
  assert(readyFrame and D.App.frame-readyFrame>=2, "returned before first-frame submission")
  print("TRANSITION_NATIVE_SUCCESS frames=" .. (D.App.frame-readyFrame))
  local closed
  game:unloadAsync(function(success, message) assert(success, message);closed=true end)
  while not closed do D.sleep() end
  game:removeFromParent()
  local failed=assert(D.GodotNode(OUTPUT .. "/invalid", "", 64, 64, 3))
  failed:addTo(D.Director.ui)
  failed:onUpdate(function()
   if failed.lastError~="" then failed:removeFromParent();return true end
   return false
  end)
  local passedFailure, failureReason=transition.waitForFrameAsync(entry, 1, true)
  assert(not passedFailure and failureReason and failureReason~="")
  print("TRANSITION_NATIVE_FAILURE " .. failureReason)
 end)
 D.Content:save(OUTPUT .. "/result.json", require("json").encode({success=ok, error=err}))
 D.App:shutdown()
end))
'''
source='local SOURCE='+json.dumps(str(root))+'\nlocal OUTPUT='+json.dumps(str(output))+'\n'+source
(assets/'Script/init.lua').write_text(source)
with (output/'native.log').open('w') as log:
 process=subprocess.run([str(args.host.resolve()),'--asset',str(assets)],stdout=log,stderr=subprocess.STDOUT,timeout=90)
assert process.returncode==0,process.returncode
result=json.loads((output/'result.json').read_text());assert result['success'],result
print('PASS: isolated native Metal runtime cold startup waits for actual Godot readiness plus two Dora frame submissions; invalid main scene returns failure even after its node is removed')
