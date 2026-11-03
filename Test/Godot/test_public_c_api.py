#!/usr/bin/env python3
"""Validate libclang extraction against known C contracts and rejected inputs."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import json
from pathlib import Path
import tempfile

from probe_public_c_api import Clang, contracts, digest

LIBRARY = Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libclang.dylib')
BASELINE = '''enum Mode { NEGATIVE = -1, SEVEN = 7 };
typedef struct Contract { int x; long y; int (*callback)(int); } Contract;
int api(const Contract *, long, ...);
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--libclang', type=Path, default=LIBRARY)
    parser.add_argument('--target', default='arm64-apple-macos12.0')
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence path'
    clang = Clang(args.libclang)
    flags = ['-target', args.target, '-std=c11']
    controls = []
    with tempfile.TemporaryDirectory(prefix='dora-public-c-api-') as temp:
        header = Path(temp) / 'contract.h'
        source = Path(temp) / 'probe.c'
        source.write_text('#include "contract.h"\n')
        def parse(text):
            header.write_text(text)
            rows, diagnostics = clang.parse(source, flags, {str(header)})
            return contracts(rows)
        original = parse(BASELINE)
        record = original['StructDecl:Contract:complete']
        assert record['size'] == 24 and record['alignment'] == 8
        assert [field['offset_bits'] for field in record['fields']] == [0, 64, 128]
        assert record['fields'][2]['type'] == 'int (*)(int)'
        assert original['FunctionDecl:api']['arguments'] == ['const struct Contract *', 'long']
        assert original['FunctionDecl:api']['variadic']
        assert original['FunctionDecl:api']['link_name'] == ('_api' if '-apple-' in args.target else 'api')
        assert original['EnumDecl:Mode']['values']['NEGATIVE']['signed'] == -1
        assert original['EnumDecl:Mode']['values']['SEVEN']['unsigned'] == 7
        for name, text, changed in (
            ('field-order', BASELINE.replace('int x; long y;', 'long y; int x;'), 'StructDecl:Contract:complete'),
            ('packing', '#pragma pack(push,1)\n' + BASELINE + '#pragma pack(pop)\n', 'StructDecl:Contract:complete'),
            ('function-argument', BASELINE.replace('*, long,', '*, double,'), 'FunctionDecl:api'),
            ('callback-argument', BASELINE.replace('(*callback)(int)', '(*callback)(float)'), 'StructDecl:Contract:complete'),
            ('enum-value', BASELINE.replace('SEVEN = 7', 'SEVEN = 8'), 'EnumDecl:Mode'),
            ('asm-link-name', BASELINE.replace('long, ...);', 'long, ...) __asm__("renamed_api");'), 'FunctionDecl:api'),
        ):
            altered = parse(text)
            assert altered[changed] != original[changed], 'Contract change missed: ' + name
            controls.append({'case': name, 'contract_difference_detected': True})
        for name, text, expected in (
            ('unprototyped-function', BASELINE + 'int legacy();\n', 'Unprototyped public function'),
            ('syntax-error', 'struct Invalid { missing_type member; };\n', None),
            ('empty-header', '/* no declarations */\n', 'No declarations found'),
        ):
            try:
                parse(text)
            except AssertionError as error:
                if expected:
                    assert expected in str(error), (name, str(error))
                controls.append({'case': name, 'invalid_input_rejected': True})
            else:
                raise AssertionError('Invalid contract accepted: ' + name)
        assert parse(BASELINE) == original
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'passed': True, 'scope': __doc__, 'known_contract': original,
        'controls': controls, 'libclang_sha256': digest(args.libclang), 'target': args.target,
        'probe_sha256': digest(Path(__file__).with_name('probe_public_c_api.py')),
        'test_sha256': digest(Path(__file__)), 'target_code_executed': False}, indent=2) + '\n')
    print('PASS: known layout/enum/function contract; 6 mutations detected and 3 invalid inputs rejected')


if __name__ == '__main__':
    main()
