#!/usr/bin/env python3
"""Bind an Ogg object/map contribution to the exact accepted signed macOS host.

Allows only CodeSignature payload/length metadata differences. No signing,
loading, runtime-sharing, Release inference or removable-byte acceptance.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prefix(path):
    data = bytearray(path.read_bytes())
    assert struct.unpack_from('<II', data) == (0xfeedfacf, 0x100000c), 'Expected thin ARM64 Mach-O'
    assert struct.unpack_from('<I', data, 12)[0] == 2, 'Expected executable'
    offset = 32; ignored = []; signature = None; sections = {}; linkedit = False
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        cmd, size = struct.unpack_from('<II', data, offset)
        assert size >= 8 and offset + size <= len(data), 'Invalid load command'
        if cmd == 0x1d:
            assert signature is None and size == 16
            start, length = struct.unpack_from('<II', data, offset+8)
            signature = {'offset': start, 'bytes': length}
            ignored.append([offset+12, 4]); data[offset+12:offset+16] = b'\0'*4
        if cmd == 0x19:
            segment = bytes(data[offset+8:offset+24]).rstrip(b'\0').decode('ascii')
            count = struct.unpack_from('<I', data, offset+64)[0]; assert size == 72+80*count
            if segment == '__LINKEDIT':
                assert not linkedit; linkedit = True
                _, virtual_bytes, file_offset, file_bytes = struct.unpack_from('<QQQQ', data, offset+24)
                assert file_offset + file_bytes == len(data), 'Invalid LINKEDIT file extent'
                assert virtual_bytes == (file_bytes+16383) & ~16383, 'Invalid ARM64 LINKEDIT page extent'
                for field in [32, 48]:
                    ignored.append([offset+field, 8]); data[offset+field:offset+field+8] = b'\0'*8
            for i in range(count):
                p = offset+72+80*i; name = bytes(data[p:p+16]).rstrip(b'\0').decode('ascii')
                address, length = struct.unpack_from('<QQ', data, p+32)
                key = segment+','+name; assert key not in sections
                sections[key] = {'address': address, 'bytes': length}
        offset += size
    assert signature and linkedit and signature['offset'] >= offset
    assert signature['offset'] + signature['bytes'] == len(data), 'Unexpected signature extent/trailing data'
    return bytes(data[:signature['offset']]), ignored, signature, sections


def union(ranges):
    total = 0; end = -1
    for a, b in sorted(ranges):
        if b > end:total += b-max(a, end); end = b
    return total


def audit(production, mapped, link_map, control, inputs_path, accepted_run):
    original, ignored, signature, sections = prefix(production)
    inputs = json.loads(inputs_path.read_text())
    assert all(digest(Path(p)) == value for p, value in inputs.items()), 'Relink input changed'
    assert inputs[str(production.resolve())] == digest(production), 'Missing original identity in relink inputs'
    run = json.loads(accepted_run.read_text())
    assert run['returncode'] == 0 and run['inputs'][str(production.resolve())] == digest(production), 'Not the accepted host'
    matches = []
    for name, path in [('control', control), ('mapped', mapped)]:
        other, other_ignored, other_signature, other_sections = prefix(path)
        assert ignored == other_ignored and signature['offset'] == other_signature['offset']
        assert original == other and sections == other_sections, 'Signed host code/data/unsigned metadata differ'
        matches.append({'name': name, 'sha256': digest(path), 'prefix_equal': True, 'signature': other_signature})
    text = link_map.read_bytes().decode('utf-8', errors='surrogateescape')
    recorded = re.search(r'^# Path: (.+)$', text, re.M)
    assert recorded and Path(recorded[1]).resolve() == mapped.resolve() and '# Arch: arm64' in text
    objects = {int(i): name for i, name in re.findall(r'^\[\s*(\d+)\] (.+)$', text, re.M)}
    selected = {i: name for i, name in objects.items() if name.endswith('/Source/3rdParty/ogg/OggSources.c.o')}
    assert len(selected) == 1, 'Ambiguous Ogg object ownership'
    obj = Path(next(iter(selected.values())))
    assert str(obj) in inputs and digest(obj) == inputs[str(obj)], 'Ogg object is not the retained link input'
    live = text.split('# Symbols:\n', 1)[1].split('# Dead Stripped Symbols:', 1)[0]
    rows = [{'address': int(a, 16), 'bytes': int(n, 16), 'symbol': symbol} for a,n,i,symbol in re.findall(
        r'^(0x[0-9A-Fa-f]+)\s+(0x[0-9A-Fa-f]+)\s+\[\s*(\d+)\]\s+(.+)$', live, re.M) if int(i) in selected]
    assert rows
    spans = {}
    for name, section in sections.items():
        a = section['address']; b = a+section['bytes']
        ranges = [(max(a, r['address']), min(b, r['address']+r['bytes'])) for r in rows
                  if r['bytes'] and max(a, r['address']) < min(b, r['address']+r['bytes'])]
        if ranges:spans[name] = union(ranges)
    assert '__TEXT,__text' in spans
    assert all(digest(Path(p)) == value for p, value in inputs.items()), 'Input changed during audit'
    paths = [production, mapped, control, link_map, inputs_path, accepted_run, Path(__file__)]
    return {'passed': True, 'complete': False, 'scope': __doc__, 'artifacts_sha256': {str(p.resolve()): digest(p) for p in paths},
            'allowed_length_fields': ignored, 'production_signature': signature, 'comparison': matches,
            'production_sections': len(sections), 'ogg_object': str(obj), 'ogg_object_sha256': digest(obj),
            'live_symbols': rows, 'symbol_spans_by_section': spans, 'total_attributed_span_bytes': sum(spans.values()),
            'host_mode': 'accepted Debug host; no Release size claim', 'inputs_unchanged': True,
            'runtime_execution': False, 'removable_or_shared_bytes_accepted': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['production', 'mapped', 'link-map', 'control', 'inputs', 'accepted-run', 'output']:
        p.add_argument('--'+name, required=True, type=Path)
    a = p.parse_args(); assert not a.output.exists(), 'Use a fresh output path'
    r = audit(a.production, a.mapped, a.link_map, a.control, a.inputs, a.accepted_run)
    a.output.parent.mkdir(parents=True, exist_ok=True); a.output.write_text(json.dumps(r, indent=2)+'\n')
    print('PASS: signed-host prefix identity; Ogg symbol spans:', r['symbol_spans_by_section'])


if __name__ == '__main__':
    main()
