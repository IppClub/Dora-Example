#!/usr/bin/env python3
"""Run a serial, input-driven community project smoke test in a prepared Dora host.

Input JSON contains an output directory, prepared host, runtime package and items.
Each item specifies path/name/width/height/buffers and timed public input events.
Source import and source-preservation evidence are recorded by the caller.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT
sys.path.insert(0, str(ENGINE_ROOT / 'Tools/Godot'))
import project_delivery as delivery
import project_switch_host as host
from PIL import Image, ImageChops

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('config', type=Path)
parser.add_argument('--verify-only', action='store_true', help='Recheck retained evidence without launching or changing the host')
args = parser.parse_args()
config = json.loads(args.config.read_text())
out = Path(config['output']).resolve()
out.mkdir(parents=True, exist_ok=True)
if not args.verify_only:
    assert not (out / 'run.log').exists(), 'Use a new output directory'

def lua(value):
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list): return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, dict): return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    raise TypeError(value)

startup = r'''
local D = Dora
D.Content:insertSearchPath(1, D.Content.assetPath .. "/Script/Lib")
local Player = require("GodotPlayer")
D.App.devMode = false
local output, items = @OUTPUT@, @ITEMS@
local player = Player()
local control = D.Node():addTo(D.Director.ui)
local index, current, closing, captures = 0, nil, false, 0
assert(D.Director:beginGameCapture())
local function finish(message)
    if closing then return end
    closing = true
    player:closeAsync(function(ok, error)
        D.Content:save(output .. "/player.json", string.format('{"passed":%s,"captures":%d}', tostring(not message and ok), captures))
        if message or not ok then D.Content:save(output .. "/failure.txt", tostring(message or error)) end
        D.Director:endGameCapture()
        D.App:shutdown()
    end)
end
local function nextProject()
    index = index + 1
    if index > #items then finish(); return end
    local item = items[index]
    assert(player:switchAsync(item.path, {scene=item.scene or "",width=item.width,height=item.height,buffers=item.buffers}, function(ok, game, message)
        if not ok then finish(message); return end
        current = {game=game,item=item,elapsed=0,event=1,capture=1,pending=false,ticks=0}
        print("DORA_COMMUNITY ready=" .. index .. " name=" .. item.name)
    end))
end
nextProject()
control:schedule(function(dt)
    local ok, message = pcall(function()
        if closing or not current then return end
        local s = current
        -- Shader compilation may stall the first frame. Do not collapse a
        -- press and release into the same frame after such a stall.
        s.elapsed, s.ticks = s.elapsed + math.min(dt, 1 / 30), s.ticks + 1
        assert(s.game.lastError == "", s.game.lastError)
        local size, view = s.game.viewportSize, D.View.size
        s.game.scaleX, s.game.scaleY = view.width / size.width, view.height / size.height
        while s.item.events[s.event] and s.elapsed >= s.item.events[s.event].time do
            local e = s.item.events[s.event]
            if e.key then s.game:sendKey(e.key,e.pressed)
            else s.game:sendPointer(e.x,e.y,1,e.pressed) end
            print("DORA_COMMUNITY input=" .. index .. " event=" .. s.event)
            s.event = s.event + 1
        end
        local times = s.item.captureTimes or {1,3,5,8}
        if not s.pending and times[s.capture] and s.elapsed >= times[s.capture] then
            s.pending = true
            assert(D.Director:captureGameAsync(output .. "/" .. index .. "-" .. s.capture .. ".png", function(saved)
                if not saved then finish("Capture failed"); return end
                s.pending, s.capture, captures = false, s.capture + 1, captures + 1
            end))
        end
        if s.capture == 5 and not s.pending and s.ticks >= 300 then
            print("DORA_COMMUNITY complete=" .. index .. " ticks=" .. s.ticks)
            current = nil
            nextProject()
        end
    end)
    if not ok then finish(message) end
    return false
end)
'''.replace('@OUTPUT@', lua(str(out))).replace('@ITEMS@', lua(config['items']))
if args.verify_only:
    record = json.loads((Path(config['host']) / 'preview.json').read_text())
    command = record['command']
    binary = Path(command[0])
else:
    command, binary, assets = host.install(Path(config['host']), startup)
runtime = Path(config['runtime'])
manifest = json.loads((runtime / 'manifest.json').read_text())
library = runtime / manifest['library']
env = {k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_', 'DORA_BUILD_'))}
env.update(DORA_GODOT_LIBRARY=str(library), MTL_DEBUG_LAYER='1')
execution_error = None
if args.verify_only:
    previous = json.loads((out / 'verification.json').read_text())
    assert previous['host_sha256'] == delivery.digest(binary), 'Host changed since execution'
    assert previous['runtime_sha256'] == delivery.digest(library), 'Runtime changed since execution'
    execution_error = previous.get('execution_error')
else:
    try:
        delivery.run_command(command, out / 'run.log', 180, env=env, cwd=binary.parent)
    except delivery.ProjectError as error:
        # Preserve a machine-readable failure report when a game reports errors at
        # shutdown instead of discarding its captured frames and lifecycle evidence.
        execution_error = str(error)
state = json.loads((out / 'player.json').read_text())
log = (out / 'run.log').read_text()
ids = re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)', log)
clean = re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)', log)
frames = re.findall(r'DORA_GODOT_METAL_DIRECT completed frames=(\d+) blits=(\d+)', log)
readers = re.findall(r'GodotRuntime readers:.*pending=(\d+), completed=\d+, gpuErrors=(\d+)', log)
audio = re.findall(r'GodotAudio drained:.*nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)', log)
errors = re.findall(r'(?m)^.*(?:SCRIPT ERROR:|ERROR:|\[error\]|BGFX LEAK:|C\+\+ objects leaks|ObjectDB instances were leaked|RIDs of type).*$', log)
cases = []
for i, item in enumerate(config['items'], 1):
    images = [Image.open(out / f'{i}-{j}.png').convert('RGB') for j in range(1,5)]
    colors = [len(im.getcolors(im.width * im.height) or []) for im in images]
    changes = [sum(n for v,n in enumerate(ImageChops.difference(a,b).convert('L').histogram()) if v>10) for a,b in zip(images,images[1:])]
    minimum_colors = item.get('minColors', 50)
    assert minimum_colors >= 16, 'Blank/flat frames must still be rejected'
    cases.append(dict(name=item['name'],buffers=item['buffers'],colors=colors,minimum_colors=minimum_colors,changed_pixels=changes))
count = len(config['items'])
passed = (state.get('passed') and state['captures']==4*count and len(ids)==count
          and len({i for i,t in ids})==1 and len({t for i,t in ids})==count
          and len(clean)==count and all(int(n)==0 for o,r,n in clean)
          and len(frames)==count and all(int(f)>=300 and int(b)==0 for f,b in frames)
          and len(readers)==count and all(p=='0' and e=='0' for p,e in readers)
          and not execution_error and not errors and all(min(c['colors'])>c['minimum_colors'] and max(c['changed_pixels'])>100 for c in cases))
report = dict(passed=bool(passed),scope='Community game smoke and serial project switching; not full gameplay completion',
              host_sha256=delivery.digest(binary),runtime_sha256=delivery.digest(library),
              cases=cases,instance_and_trees=ids,post_unload_counts=clean,frames_and_blits=frames,
              pending_and_gpu_errors=readers,audio=audio,errors=errors,execution_error=execution_error,captures=state['captures'])
delivery.write_json(out / 'verification.json', report)
print(json.dumps(report,indent=2,ensure_ascii=False))
sys.exit(0 if passed else 1)
