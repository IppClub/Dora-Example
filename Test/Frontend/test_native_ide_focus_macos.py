#!/usr/bin/env python3
"""Verify Cocoa focus handoff using the actual DoraIDEHost in an ordinary host."""
import argparse,json,pathlib,subprocess,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);add_engine_argument(p);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
assert sys.platform=='darwin';out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);module=out/'focus-test.dylib'
subprocess.run(['clang++','-std=c++17','-fobjc-arc','-dynamiclib',str(pathlib.Path(__file__).with_name('native_ide_focus_macos.mm')),'-framework','Cocoa','-framework','WebKit','-o',str(module)],check=True)
service=NativeAgent(a.engine,ENGINE_ROOT);service.environment['DORA_NATIVE_IDE_FOCUS_OUTPUT']=str(out/'result.json')
with service as engine:
 try:
  engine.command(out,'assert(package.loadlib('+json.dumps(str(module))+',"luaopen_native_ide_focus"))()',timeout_seconds=20)
  result=json.loads((out/'result.json').read_text());assert result['success'],result
  print('PASS: hidden IDE relinquishes focus, native input survives, visible IDE regains focus')
 finally:(out/'engine.log').write_text(engine.log_path.read_text(errors='replace'))
