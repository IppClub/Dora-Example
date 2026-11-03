"""Deterministic local fixtures for real native sync/async importer failures."""
import copy,json,struct,zlib
from pathlib import Path
root=Path(__file__).resolve().parent/'Fixtures/Diagnostics';root.mkdir(parents=True,exist_ok=True)
base=(root.parents[3]/'Example/Creation3D/assets/cube.glb').read_bytes()
length=struct.unpack_from('<I',base,12)[0];document=json.loads(base[20:20+length]);binary=base[28+length:]
def glb(name,doc,data=binary):
    doc=copy.deepcopy(doc);js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*(-len(js)%4);data+=b'\0'*(-len(data)%4)
    (root/name).write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data)
def textured(uri):
    doc=copy.deepcopy(document);doc['images']=[{'uri':uri}];doc['textures']=[{'source':0}]
    doc['materials'][0]['pbrMetallicRoughness']['baseColorTexture']={'index':0}
    return doc
(root/'valid.glb').write_bytes(base)
(root/'parse.glb').write_bytes(b'glTF bad container')
glb('missing-image.glb',textured('missing.png'))
(root/'corrupt.png').write_bytes(b'not an encoded image')
glb('decode-image.glb',textured('corrupt.png'))
doc=textured('missing.png');doc['materials'][0]['normalTexture']={'index':0};glb('shared-image.glb',doc)
doc=textured('https://example.invalid/never-fetch.png');glb('uri.glb',doc)
doc=textured('unused');doc['images']=[{'bufferView':len(doc['bufferViews']),'mimeType':'image/png'}]
bad=b'not-a-png';doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(bad)});doc['buffers'][0]['byteLength']=len(binary)+len(bad);glb('embedded-decode.glb',doc,binary+bad)
doc=copy.deepcopy(document);doc['buffers'][0]['uri']='missing.bin';glb('missing-buffer.glb',doc)
doc=copy.deepcopy(document);doc['buffers'][0]['byteLength']+=100;glb('short-buffer.glb',doc)
doc=copy.deepcopy(document);doc['meshes'][0]['primitives'][0]['attributes']['POSITION']=999;glb('invalid-index.glb',doc)
doc=copy.deepcopy(document);doc['extensionsUsed']=['DORA_test_extension'];doc['extensionsRequired']=['DORA_test_extension'];glb('warning.glb',doc)
glb('empty.glb',{'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[]}]},b'')
# Oversized texture stays embedded, so it cannot enter the external Texture2D loader.
def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',65536,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0'+b'\xff'*65536*4))+chunk(b'IEND',b'')
doc=textured('unused');doc['images']=[{'bufferView':len(doc['bufferViews']),'mimeType':'image/png'}];doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(png)});doc['buffers'][0]['byteLength']=len(binary)+len(png);glb('wide-texture.glb',doc,binary+png)
(root/'retry.glb').write_bytes((root/'parse.glb').read_bytes())
(root/'cancel.glb').write_bytes((root.parents[3]/'Example/Creation3D/assets/Fox.glb').read_bytes())
print('diagnostic fixtures generated in',root)
