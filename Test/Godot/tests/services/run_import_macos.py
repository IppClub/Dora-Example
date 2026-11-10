"""Exercise the real embedded import/check C APIs; never launch a Godot executable."""
import argparse,base64,json,os,pathlib,shutil,struct,subprocess,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[3]/'support'))
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--runtime',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True)
a=p.parse_args();out=a.output.resolve();assert not out.exists(),'Use a fresh output directory'
assert sys.platform=='darwin';out.mkdir(parents=True);project=out/'project';project.mkdir()
(project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n[autoload]\nSentinel="*res://sentinel.gd"\n')
(project/'main.tscn').write_text('[gd_scene format=3]\n[node name="Main" type="Node"]\n')
(project/'sentinel.gd').write_text('extends Node\nfunc _ready():\n\tFileAccess.open("res://AUTOLOAD_EXECUTED", FileAccess.WRITE).store_string("bad")\n')
(project/'tool.gd').write_text('@tool\nextends Node\nfunc _init():\n\tFileAccess.open("res://TOOL_EXECUTED", FileAccess.WRITE).store_string("bad")\n')
svg='<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="red"/></svg>'
for name in ('sprite.svg','managed.svg','broken.svg','blocked.svg'):(project/name).write_text(svg)
(project/'managed.svg.import').write_text('[remap]\nimporter="texture"\n')
(project/'broken.svg.import').write_text('[remap\nthis is broken')
(project/'bad.png').write_bytes(b'not png');(project/'unsupported.blend').write_bytes(b'no blender')
(project/'escape.png').symlink_to('/etc/hosts')
(project/'blocked.svg.import.pending').symlink_to('/etc/hosts')
vertices=struct.pack('<9f',0,0,0,1,0,0,0,1,0)
(project/'triangle.gltf').write_text(json.dumps({'asset':{'version':'2.0'},'buffers':[{'uri':'data:application/octet-stream;base64,'+base64.b64encode(vertices).decode(),'byteLength':len(vertices)}], 'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':len(vertices)}], 'accessors':[{'bufferView':0,'componentType':5126,'count':3,'type':'VEC3','min':[0,0,0],'max':[1,1,0]}], 'meshes':[{'primitives':[{'attributes':{'POSITION':0}}]}], 'nodes':[{'mesh':0}], 'scenes':[{'nodes':[0]}], 'scene':0}))
shutil.copyfile(ENGINE_ROOT/'Assets/Font/NotoEmoji.ttf',project/'font.ttf')
subprocess.run(['ffmpeg','-loglevel','error','-f','lavfi','-i','sine=frequency=440:duration=0.1',str(project/'sound.wav')],check=True)
subprocess.run(['ffmpeg','-loglevel','error','-i',str(project/'sound.wav'),'-ac','2','-c:a','vorbis','-strict','-2',str(project/'tone.ogg')],check=True)
subprocess.run(['ffmpeg','-loglevel','error','-i',str(project/'sound.wav'),str(project/'tone.mp3')],check=True)
binary=out/'import-test'
subprocess.run(['clang++','-std=c++17','-fobjc-arc','-I',str(ENGINE_ROOT/'Source/Godot'),str(pathlib.Path(__file__).with_name('import_macos.mm')),'-framework','Foundation','-framework','Metal','-o',str(binary)],check=True)
r=subprocess.run([str(binary),str(a.runtime.resolve()),str(project)],text=True,capture_output=True,timeout=90)
(out/'native.log').write_text(r.stdout+r.stderr)
assert r.returncode==0,(r.returncode,(r.stdout+r.stderr)[-4000:])
assert 'EMBEDDED_IMPORT_CHECK_PASS' in r.stdout
assert not (project/'TOOL_EXECUTED').exists()
assert (project/'managed.svg.import').read_text()=='[remap]\nimporter="texture"\n'
assert (project/'broken.svg.import').read_text()=='[remap\nthis is broken'
metadata=(project/'sprite.svg.import').read_text();assert '[dora]' in metadata and 'importer="texture"' in metadata
assert (project/'.godot/uid_cache.bin').exists()
print('PASS: six asset families, cache/force/edit/corruption, preload, path escape, metadata preservation, no script execution, check/run/import lifecycle and clean shutdown')
