"""Ordinary native host staging shared by serial project-lifecycle acceptance."""
import json
import subprocess
import sys
from pathlib import Path

def add_arguments(parser):
    host=parser.add_mutually_exclusive_group(required=True)
    host.add_argument('--app',type=Path,help='macOS ordinary application')
    host.add_argument('--binary',type=Path,help='Linux ordinary host executable')
    parser.add_argument('--asset-source',type=Path,help='Required with --binary')

def arguments(args):
    assert sys.platform in ('darwin','linux')
    if args.app:
        assert sys.platform=='darwin'
        return ['--app',str(args.app.resolve())]
    assert sys.platform=='linux' and args.asset_source and args.asset_source.is_dir()
    return ['--binary',str(args.binary.resolve()),'--asset-source',str(args.asset_source.resolve())]

def install(work,startup):
    record=json.loads((work/'preview.json').read_text())
    command=record['command']
    binary=Path(command[0])
    assets=work/'Dora.app/Contents/Resources' if sys.platform=='darwin' else work/'assets'
    (assets/'Script/init.lua').write_text(startup)
    if sys.platform=='darwin':
        subprocess.run(['codesign','--force','--deep','--timestamp=none','--sign','-',str(work/'Dora.app')],capture_output=True,check=True)
    return command,binary,assets

def verify_gl_transport(log,expected):
    if sys.platform!='linux':return
    import re
    rows=re.findall(r'DORA_GODOT_GL_TRANSPORT phase=close mode=(\S+).*?buffers=(\d+) size=(\d+x\d+) blits=(\d+) direct_publications=(\d+)',log)
    assert len(rows)==expected and all(mode=='direct' and int(blits)==0 and int(publications)>0
        for mode,buffers,size,blits,publications in rows),rows
