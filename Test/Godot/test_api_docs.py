"""External test-runner adapter; the generator and regression are xmake Lua."""
from pathlib import Path
import os
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
subprocess.run([os.environ.get('DORA_XMAKE','xmake'),'lua',str(Path(__file__).with_suffix('.lua')),str(ENGINE_ROOT)],check=True)
