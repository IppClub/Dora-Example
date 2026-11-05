#!/usr/bin/env python3
"""Validate legacy and dual-backend release naming against the publisher schema."""
import argparse,copy,json
from pathlib import Path
import jsonschema
p=argparse.ArgumentParser();p.add_argument('--releases',type=Path,required=True);a=p.parse_args()
s=json.loads((a.releases/'schema/stable-v1.schema.json').read_text())
old=json.loads((a.releases/'stable.json').read_text());jsonschema.validate(old,s)
version='v1.10.0';platforms=['android','windows-x64','windows-x64-opengl','windows-x64-msi','windows-x64-opengl-msi','macos-arm64']
new=dict(old,version=version,packages={})
for platform in platforms:
    name='dora-ssr-'+version+'-'+(platform[:-4]+'.msi' if platform.endswith('-msi') else platform+'.zip')
    new['packages'][platform]={'ref':'refs/tags/'+version+'-0-'+platform,'commit':'a'*40,'file':name,'size':100,'sha256':'b'*64,'github':'https://github.com/IppClub/Dora-SSR/releases/download/'+version+'/'+name}
jsonschema.validate(new,s)
for name in ['dora-ssr-v1.10.0-windows-x64-msi.zip','dora-ssr-v1.10.0-windows-x64-dx12.zip','../dora-ssr-v1.10.0-windows-x64.zip']:
    altered=copy.deepcopy(new);altered['packages']['windows-x64']['file']=name
    try:jsonschema.validate(altered,s)
    except jsonschema.ValidationError:pass
    else:raise AssertionError(name)
print('PASS: legacy/new AtomGit schema and three noncanonical filenames rejected')
