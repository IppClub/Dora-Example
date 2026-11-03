#!/usr/bin/env python3
"""Mac native acceptance: clone/import/play, then export/archive/install/play.

Uses two sequential ordinary Dora processes. This does not test project switching
inside one Dora/LibGodot instance or claim other platforms have been accepted.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO
import argparse
from collections import Counter
import hashlib
import json
import re
import shutil
import struct
import subprocess
import zlib
from PIL import Image
import project_delivery as delivery

p=argparse.ArgumentParser(description=__doc__)
for name in ['godot','app','runtime-package','output']:p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args()
assert sys.platform=='darwin','This native acceptance driver currently covers macOS only'
out=a.output.resolve();assert not out.exists(),'Use a fresh output';out.mkdir(parents=True)
editor=a.godot.resolve();app=a.app.resolve();runtime=a.runtime_package.resolve()
repository=out/'author-repository';project=repository/'game'
shutil.copytree(TEST_REPO/'Test/Godot/tests/project_switch/b',project)
(project/'assets').mkdir()
def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',16,16,8,6,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+b'\xff\0\xff\xff'*16)*16))+chunk(b'IEND',b'')
(project/'assets/marker.png').write_bytes(png)
main=project/'main.gd';text=main.read_text().replace('func _ready() -> void:\n','''func _ready() -> void:
\tvar texture = preload("res://assets/marker.png")
\tassert(texture is CompressedTexture2D and texture.get_width() == 16)
\tvar marker := Sprite2D.new()
\tmarker.texture = texture
\tmarker.position = Vector2(500,80)
\tadd_child(marker)
''');main.write_text(text)
(repository/'LICENSE').write_text('MIT License\nCopyright (c) Dora SSR contributors\n')
(project/'.gitignore').write_text('.godot/\n')
subprocess.run(['git','init','-q',str(repository)],check=True)
subprocess.run(['git','-C',str(repository),'add','.'],check=True)
subprocess.run(['git','-C',str(repository),'-c','user.name=Dora test','-c','user.email=test@example.invalid',
                'commit','-qm','Create delivery fixture'],check=True)
original=delivery.fingerprint(repository)
cli=ENGINE_ROOT/'Tools/Godot/project.py'
def run(name,args):
    with (out/(name+'.log')).open('w') as log:
        subprocess.run([sys.executable,str(cli),*map(str,args)],cwd=ENGINE_ROOT,
                       stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
run('source-preview',['run',repository.as_uri(),'--project','game','--godot',editor,'--app',app,
    '--runtime-package',runtime,'--work-dir',out/'source-preview','--duration','2',
    '--capture',out/'source.png'])
assert delivery.fingerprint(repository)==original,'Author repository changed'
cloned=out/'source-preview/repository'
assert delivery.fingerprint(cloned)==original,'Clone differs from author inputs'
run('export',['export',cloned,'--project','game','--godot',editor,'--id','dora.delivery-fixture',
    '--platform','macOS','--work-dir',out/'export-work','--output',out/'game'])
run('archive',['archive',out/'game','--output',out/'game.dora-game'])
run('install',['install',out/'game.dora-game','--output',out/'installed'])
before=delivery.verify_game(out/'game');after=delivery.verify_game(out/'installed')
assert before['manifest_sha256']==after['manifest_sha256']
manifest=json.loads((out/'game/game.json').read_text())
assert 'licenses/LICENSE' in manifest['licenses'],'Repository-level license was lost'
# No editor argument: consumers of an exported game do not import source.
run('packed-preview',['run',out/'installed','--app',app,'--runtime-package',runtime,
    '--work-dir',out/'packed-preview','--duration','2','--capture',out/'packed.png'])
assert delivery.fingerprint(repository)==original
assert delivery.fingerprint(cloned)==original
cases=[]
for name in ['source','packed']:
    folder=out/(name+'-preview');record=json.loads((folder/'preview.json').read_text())
    assert record['played'] and record['player']['state']=='closed' and record['player']['captured']
    text=(folder/'run.log').read_text();assert 'DORA_GODOT_PROJECT_SWITCH loaded=B static=1 resource=B autoload=B' in text
    assert 'SCRIPT ERROR:' not in text and 'BGFX LEAK:' not in text and 'C++ objects leaks' not in text
    assert re.search(r'GodotRuntime readers:.*pending=0, completed=\d+, gpuErrors=0',text)
    frames=re.findall(r'DORA_GODOT_METAL_DIRECT completed frames=(\d+) blits=0',text)
    assert frames and int(frames[-1])>=30,frames
    image=Image.open(out/(name+'.png')).convert('RGB')
    pixels=image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata()
    colors=Counter(pixels);blue=sum(n for (r,g,b),n in colors.items() if r<50 and 40<=g<=90 and b>200)
    magenta=sum(n for (r,g,b),n in colors.items() if r>230 and g<30 and b>230)
    assert blue/(image.width*image.height)>0.85,(name,blue,image.size)
    assert magenta>400,(name,magenta)
    cases.append({'case':name,'size':list(image.size),'blue_pixels':blue,'imported_texture_pixels':magenta,
                  'frames':int(frames[-1]),'blits':0,'gpu_errors':0,'gpu_pending':0})
report={'passed':True,'scope':__doc__,'editor':delivery.editor_identity(str(editor)),
        'author_repository_unchanged':True,'clone_unchanged':True,'manifest_sha256':before['manifest_sha256'],
        'pck_sha256':before['pack']['sha256'],'cases':cases}
delivery.write_json(out/'verification.json',report)
print(json.dumps({'passed':True,'cases':cases,'report':str(out/'verification.json')},indent=2))
