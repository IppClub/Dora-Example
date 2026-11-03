"""Read unencrypted standalone PCK v2/v3 directory entries for test evidence.
Layout: pinned Godot core/io/file_access_pack.cpp (PackedSourcePCK::try_open_pack).
This is a test inspector, not the production resource loader.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import struct
from pathlib import Path
def files(path):
    data=Path(path).read_bytes()
    assert len(data)>=100 and data[:4]==b'GDPC', 'Not a standalone PCK'
    version,=struct.unpack_from('<I',data,4)
    flags,=struct.unpack_from('<I',data,20)
    assert version in (2,3) and not flags&1, 'Unsupported/encrypted directory'
    pos=96 if version==2 else struct.unpack_from('<Q',data,32)[0]
    count,=struct.unpack_from('<I',data,pos); pos+=4
    assert 0<=count<=len(data)//40
    result=[]
    for _ in range(count):
        length,=struct.unpack_from('<I',data,pos); pos+=4
        assert pos+length+36<=len(data)
        name=data[pos:pos+length].split(b'\0',1)[0].decode('utf8'); pos+=length+36
        result.append(name.removeprefix('res://'))
    return result
