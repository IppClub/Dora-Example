#!/usr/bin/env python3
"""Exercise active-Xcode forwarding and reject a mismatched SDK before compilation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

if sys.platform != 'darwin':
    print('SKIP iOS SDK selection requires macOS/Xcode')
    raise SystemExit(0)
root = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd()))
with tempfile.TemporaryDirectory(prefix='dora-ios-sdk-') as temporary:
    base = Path(temporary)
    fake = base / 'xmake-probe'
    fake.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
args=sys.argv[1:];out=Path(os.environ['PROBE_BUILD'])
if args==['--version']:print('xmake v3.1.2');sys.exit(0)
if args[0]=='f':(out/'configure-args.json').write_text(json.dumps(args));sys.exit(0)
if args[0]=='l':
 Path(args[-1]).write_text(json.dumps({'plat':'iphoneos','arch':'arm64','appledev':os.environ['PROBE_DEVICE'],'target_minver':'14.0','sdk':os.environ['PROBE_SDK'],'targetfile':'unused.a'}));sys.exit(0)
if args[0]=='build':(out/'compiler-started').touch();sys.exit(23)
raise SystemExit(99)
''')
    fake.chmod(0o755)
    for device, sdk_name, appledev in [('device', 'iphoneos', 'iphoneos'), ('simulator', 'iphonesimulator', 'simulator')]:
        sdk = subprocess.check_output(['xcrun', '--sdk', sdk_name, '--show-sdk-path'], text=True).strip()
        version = subprocess.check_output(['xcrun', '--sdk', sdk_name, '--show-sdk-version'], text=True).strip()
        xcode = next(p for p in Path(sdk).parents if p.suffix == '.app')
        for mismatch in (False, True):
            build = base / f'{device}-{mismatch}'
            build.mkdir()
            env = os.environ.copy()
            env.update(PROBE_BUILD=str(build), PROBE_DEVICE=appledev,
                       PROBE_SDK='/different/Xcode.app/Contents/Developer/Other.sdk' if mismatch else sdk)
            result = subprocess.run([sys.executable, str(root / 'Tools/Godot/build_ios_runtime.py'),
                '--device', device, '--build-dir', str(build), '--xmake', str(fake)],
                env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert result.returncode == (1 if mismatch else 23), result.stdout
            assert (build / 'compiler-started').exists() is not mismatch, result.stdout
            args = json.loads((build / 'configure-args.json').read_text())
            assert '--xcode=' + str(xcode) in args, args
            assert '--xcode_sdkver=' + version in args, args
            if mismatch:
                assert 'AssertionError' in result.stdout
print('PASS active Xcode/SDK forwarded for device and simulator; wrong SDK rejected before compilation')
