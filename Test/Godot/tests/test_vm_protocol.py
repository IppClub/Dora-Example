#!/usr/bin/env python3
"""Run the portable ownership/ABI tests in an existing Linux Parallels VM.
Only writes to /tmp/dora-godot-integration; it does not alter guest packages.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
from pathlib import Path
import argparse, base64, json, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument('--vm',default='Ubuntu ARM64')
parser.add_argument('--output',default='build/godot-runtime/protocol-linux-arm64.json')
args=parser.parse_args()
root=ENGINE_ROOT
prl='/Applications/Parallels Desktop.app/Contents/MacOS/prlctl'
prefix='/tmp/dora-godot-integration'
def python(code):
    # prlctl constructs a guest command line. The outer double quotes must be
    # preserved as part of its argv; payloads are base64 and contain no quotes.
    for attempt in range(3):
        result=subprocess.run([prl,'exec',args.vm,'/usr/bin/python3','-c','"'+code+'"'],capture_output=True,text=True)
        if result.returncode == 0:
            time.sleep(0.05)
            return result.stdout
        time.sleep(0.2 * (attempt+1))
    raise RuntimeError(result.stderr+result.stdout)
production = [
    'xmake.lua',
    'Source/3rdParty/Godot/UPSTREAM.json',
    'Source/3rdParty/Godot/modules/dora_bridge/runtime_project.h',
    'Source/3rdParty/Godot/modules/dora_bridge/register_types_gl.cpp',
    *['Source/Godot/'+name for name in ('GodotBridge.h', 'GodotBridgeGL.h',
      'GodotBridgeMetalTargets.h', 'GodotBridgeAudio.h', 'GodotBridgeViewport.h', 'GodotBridgeGLTargets.h', 'GodotAudioQueue.h',
      'GodotFrameRing.h', 'GodotRenderBootQueue.h', 'GodotGpuReads.h')],
    'Source/Web/WebTaskQueue.h', 'Source/Web/WebTaskQueue.cpp',
    'Source/3rdParty/Godot/modules/dora_bridge/runtime_timing.h',
    'Source/3rdParty/Godot/modules/dora_bridge/gl/target_policy.h',
    'Source/3rdParty/bgfx/dora/BgfxEmbeddedShaders.hpp',
    'Source/3rdParty/bgfx/src/bgfx_shader.sh', 'Source/3rdParty/bgfx/src/bgfx_compute.sh',
]
fixtures = ['Test/Godot/tests/'+name for name in ('frame_ring.cpp', 'render_boot.cpp',
    'render_timing.cpp', 'audio_queue.cpp', 'gpu_reads.cpp', 'bridge_abi.c',
    'gl/target_policy.cpp', 'protocol.sh', 'embedded_shader.py', 'web/task_queue_stop.py')]
fixtures += ['Test/Godot/'+name for name in ('test_project_orphan_cleanup.py', 'test_runtime_version_guards.py')]
fixtures += ['Test/Godot/tests/'+name for name in ('check_library.py', 'verify_timing.py',
    'ios/run_node.py', 'android/verify_dodge_release.py', 'android/verify_ordinary_release.py',
    'android/run_ordinary_release.py', 'android/lifecycle/app/src/main/java/org/dora/godotrc1/ReleaseLifecycle.java')]
for name in production + fixtures + ['Test/support/godot_paths.py',
                                    'Test/support/godot-paths.sh', 'Test/Godot/paths.json']:
    path=prefix+'/'+name
    python("import pathlib; p=pathlib.Path('"+path+"'); p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(b'')")
    data=base64.b64encode(test_path(name).read_bytes()).decode()
    for i in range(0,len(data),512):
        python("import base64; f=open('"+path+"','r+b'); f.seek("+str(i//4*3)+"); f.write(base64.b64decode('"+data[i:i+512]+"')); f.close()")
print(python("import os,subprocess; os.chdir('"+prefix+"'); os.environ.update(DORA_ENGINE_ROOT='"+prefix+"',DORA_TEST_REPO='"+prefix+"'); raise SystemExit(subprocess.run(['/bin/bash','"+prefix+"/Test/Godot/tests/protocol.sh']).returncode)"))
report=json.loads(python("import pathlib; print(pathlib.Path('"+prefix+"/build/godot-runtime/protocol/verification.json').read_text())"))
assert report['passed'] and report['system']=='Linux'
output=root/args.output; output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n')
