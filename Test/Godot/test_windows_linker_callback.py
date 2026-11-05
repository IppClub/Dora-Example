#!/usr/bin/env python3
"""Run the actual Windows runtime linker callback in a small native xmake target.

No Windows SDK or GPU is used: this checks xmake lifecycle/API timing and that
its selected C++ runtime can link, not a complete Windows runtime build.
"""
import os,re,shutil,subprocess,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT
text=(ENGINE_ROOT/'Projects/xmake/godot/targets.lua').read_text()
callback=re.search(r'        (?:after_load|on_config)\(function \(target\)\n            -- The stage archives[\s\S]*?        end\)',text).group()
xmake=os.environ.get('DORA_XMAKE') or shutil.which('xmake')
assert xmake,'xmake is required'
with tempfile.TemporaryDirectory(prefix='godot-linker-callback-') as temp:
    for label,body in [('actual',callback),('early-control',callback.replace('on_config(', 'after_load(',1))]:
        root=Path(temp)/label;root.mkdir()
        (root/'runtime.cpp').write_text('#include <string>\nextern "C" const char *probe() { static std::string value="runtime"; return value.c_str(); }\n')
        (root/'xmake.lua').write_text('set_project("callback-probe")\ntarget("probe")\nset_kind("shared")\nadd_files("runtime.cpp")\n'+body+'\ntarget_end()\n')
        env=os.environ.copy();env['XMAKE_CONFIGDIR']=str(root/'config')
        result=subprocess.run([xmake,'f','-P',str(root),'-y','--ccache=n','--builddir='+str(root/'build')],capture_output=True,text=True,env=env,cwd=root)
        if label=='actual':
            assert result.returncode==0,result.stdout+result.stderr
            result=subprocess.run([xmake,'build','-P',str(root)],capture_output=True,text=True,env=env,cwd=root)
            assert result.returncode==0,result.stdout+result.stderr
        else:
            assert result.returncode!=0 and 'before target' in result.stdout+result.stderr,result.stdout+result.stderr
print('PASS: actual linker callback configures/links; early target-tool query rejected')
