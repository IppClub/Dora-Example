#!/usr/bin/env python3
"""Exercise SDK selection and compile metal-cpp with the production module flags."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import re

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
            result = subprocess.run([os.environ.get('DORA_XMAKE','xmake'), 'lua', str(root / 'Tools/Godot/build_ios_runtime.lua'),
                '--device', device, '--build-dir', str(build), '--xmake', str(fake)],
                env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert result.returncode != 0, result.stdout
            assert (build / 'compiler-started').exists() is not mismatch, result.stdout
            args = json.loads((build / 'configure-args.json').read_text())
            assert '--xcode=' + str(xcode) in args, args
            assert '--xcode_sdkver=' + version in args, args
            if mismatch:
                assert 'differs from active xcrun SDK' in result.stdout
    metalfx = 'source("servers/rendering/renderer_rd/effects/metal_fx.cpp")'
    assert metalfx in (root / 'Projects/xmake/godot/ios_device_arm64_sources.lua').read_text()
    assert metalfx not in (root / 'Projects/xmake/godot/ios_simulator_arm64_sources.lua').read_text()
    source = root / 'Source/3rdParty/Godot/thirdparty/metal-cpp/metal_cpp.cpp'
    for variant, sdk_name, triple in [
        ('ios_device_arm64', 'iphoneos', 'arm64-apple-ios14.0'),
        ('ios_simulator_arm64', 'iphonesimulator', 'arm64-apple-ios14.0-simulator'),
    ]:
        text = (root / 'Projects/xmake/godot' / (variant + '_sources.lua')).read_text()
        block = next(b for b in re.findall(r'target\("[^"\n]+"\).*?target_end\(\)', text, re.S)
                     if 'source("thirdparty/metal-cpp/metal_cpp.cpp")' in b)
        flags = [json.loads('"' + f + '"') for f in re.findall(r'flag\("((?:[^"\\]|\\.)*)"\)', block)]
        required = ['-std=gnu++20', '-fmodules', '-fcxx-modules', '-D_LIBCPP_REMOVE_TRANSITIVE_INCLUDES', '-includecstddef']
        assert all(flag in flags for flag in required), (variant, 'metal-cpp module/include flags drifted')
        sdk = subprocess.check_output(['xcrun', '--sdk', sdk_name, '--show-sdk-path'], text=True).strip()
        for mode in ['debug', 'release']:
            obj = base / (variant + '-' + mode + '.o')
            dylib = obj.with_suffix('.dylib')
            result = subprocess.run(['xcrun', '--sdk', sdk_name, 'clang++', '-target', triple,
                '-isysroot', sdk, *required, '-DDEBUG_ENABLED' if mode == 'debug' else '-DNDEBUG',
                '-fmodules-cache-path=' + str(base / (variant + '-modules')),
                '-I' + str(source.parent), *(['-DIOS_SIMULATOR'] if variant == 'ios_simulator_arm64' else []),
                '-c', str(source), '-o', str(obj)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert result.returncode == 0, (variant, mode, result.stdout)
            link = subprocess.run(['xcrun', '--sdk', sdk_name, 'clang++', '-target', triple,
                '-isysroot', sdk, '-dynamiclib', str(obj), '-framework', 'Foundation',
                '-framework', 'Metal', '-framework', 'QuartzCore', '-o', str(dylib)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert link.returncode == 0, (variant, mode, link.stdout)
print('PASS MetalFX source enabled for device, excluded for simulator render-buffer guards')
print('PASS active Xcode/SDK forwarded for device and simulator; wrong SDK rejected before compilation')
print('PASS actual metal-cpp compilation and framework link with Clang modules for device/simulator, Debug/Release; no GPU')
