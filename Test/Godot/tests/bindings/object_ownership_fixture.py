"""Portable Wasm binary for testing exported Object cleanup on a real trap."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path

def uint(value):
    result=bytearray()
    while True:
        byte=value&127;value>>=7;result.append(byte|(128 if value else 0))
        if not value:return bytes(result)


def name(text):
    data=text.encode();return uint(len(data))+data


def vector(items):return uint(len(items))+b''.join(items)
def section(kind,data):return bytes([kind])+uint(len(data))+data


def fixture():
    # (func _start (local i64) call node_new local.tee 0 call object_retain
    #  local.get 0 call object_retain local.get 0 call object_release unreachable)
    # Two owned references remain on trap. Exports match the real Dora Wasm ABI.
    types=[b'\x60\x00\x01\x7e',b'\x60\x01\x7e\x00',b'\x60\x00\x01\x7f',b'\x60\x01\x7f\x00',b'\x60\x00\x00']
    imports=[name('dora')+name(n)+b'\x00'+uint(t) for n,t in [('node_new',0),('object_retain',1),('object_release',1)]]
    exports=[name(n)+b'\x00'+uint(i) for i,n in enumerate(['dora_wasm_version','call_function','deref_function','_start'],3)]
    bodies=[b'\x00\x41'+uint((0<<16)|(5<<8)|11)+b'\x0b',b'\x00\x0b',b'\x00\x0b',b'\x01\x01\x7e\x10\x00\x22\x00\x10\x01\x20\x00\x10\x01\x20\x00\x10\x02\x00\x0b']
    return b'\x00asm\x01\x00\x00\x00'+section(1,vector(types))+section(2,vector(imports))+section(3,vector([uint(t) for t in [2,3,3,4]]))+section(7,vector(exports))+section(10,vector([uint(len(b))+b for b in bodies]))
