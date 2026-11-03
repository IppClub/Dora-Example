"""Local fixture integrity and geometry inventory; not a runtime performance test."""
import hashlib,json,struct
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'Example/Creation3D'
records=[]
for path in sorted((root/'assets').glob('*.glb')):
    raw=path.read_bytes(); magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw),path
    length,kind=struct.unpack_from('<II',raw,12); assert kind==0x4e4f534a
    doc=json.loads(raw[20:20+length]); triangles=0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            count=doc['accessors'][primitive['indices'] if 'indices' in primitive else primitive['attributes']['POSITION']]['count']
            assert count%3==0; triangles+=count//3
    for view in doc.get('bufferViews',[]):
        assert view.get('byteOffset',0)+view['byteLength']<=doc['buffers'][view.get('buffer',0)]['byteLength']
    records.append(dict(file=path.name,sha256=hashlib.sha256(raw).hexdigest(),triangles=triangles,animations=[a.get('name') for a in doc.get('animations',[])],images=len(doc.get('images',[])),copyright=doc['asset'].get('copyright','Original primitive, MIT')))
fox=root.parents[1]/'Test/Model3D/Assets/Model/Fox.glb'
assert fox.read_bytes()==(root/'assets/Fox.glb').read_bytes(),'Fox changed from source fixture'
out=Path(__file__).resolve().parent/'evidence/assets.json'; out.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('ASSET_AUDIT PASS',len(records),'local GLBs')
