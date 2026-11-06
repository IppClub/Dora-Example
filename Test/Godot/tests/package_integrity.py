#!/usr/bin/env python3
"""Negative deployment checks; no runtime or GPU execution."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import json,sys,tempfile,unittest,subprocess,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from package_manifest import seal,digest
from verify_package import verify

class PackageIntegrity(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        (self.root/'runtime.so').write_bytes(b'fixture library')
        (self.root/'LICENSE.txt').write_text('fixture license')
        self.manifest=seal(self.root,{'library':'runtime.so','library_sha256':digest(self.root/'runtime.so'),'licenses':['LICENSE.txt']})
        self.save()
    def save(self):
        (self.root/'manifest.json').write_text(json.dumps(self.manifest))
    def rejects(self):
        with self.assertRaises((ValueError,FileNotFoundError)):verify(self.root)
    def test_valid(self):self.assertTrue(verify(self.root)['passed'])
    def test_corrupt_library(self):
        (self.root/'runtime.so').write_bytes(b'corrupt');self.rejects()
    def test_missing_license(self):
        (self.root/'LICENSE.txt').unlink();self.rejects()
    def test_changed_license(self):
        (self.root/'LICENSE.txt').write_text('different');self.rejects()
    def test_extra_library(self):
        (self.root/'stale.so').write_bytes(b'old');self.rejects()
    def test_bad_abi(self):
        self.manifest['bridge_abi']=99;self.save();self.rejects()
    def test_bad_source(self):
        self.manifest['source_archive_sha256']='0'*64;self.save();self.rejects()
    def test_valid_architectures(self):
        self.manifest['architectures']=['arm64','x86_64'];self.save();self.assertTrue(verify(self.root)['passed'])
    def test_empty_architectures(self):
        self.manifest['architectures']=[];self.save();self.rejects()
    def test_duplicate_architectures(self):
        self.manifest['architectures']=['arm64','arm64'];self.save();self.rejects()
    def test_unknown_architecture(self):
        self.manifest['architectures']=['mips64'];self.save();self.rejects()
    def test_valid_graphics_backend(self):
        # A valid D3D12 package also carries the production NIR notices.
        notices = ('GODOT-NIR-THIRD-PARTY-NOTICES.txt', 'GODOT-NIR-PROVENANCE.json')
        for name in notices:
            (self.root/name).write_bytes((ENGINE_ROOT/'Tools/Godot/licenses/nir-25.3.1-1'/name).read_bytes())
        self.manifest['licenses'].append(notices[0])
        self.manifest['graphics_backend']='d3d12';self.save()
        self.manifest=seal(self.root,self.manifest);self.save()
        self.assertEqual(verify(self.root)['graphics_backend'],'d3d12')
    def test_metal_static_sdk_notices_and_repeated_packaging(self):
        library=self.root/'fixture.dylib';library.write_bytes(b'fixture, no runtime execution')
        package=self.root/'metal'
        command=[sys.executable,str(ENGINE_ROOT/'Tools/Godot/package_runtime.py'),
                 '--source',str(ENGINE_ROOT/'Source/3rdParty/Godot'),'--library',str(library),
                 '--output',str(package),'--architecture','arm64','--graphics-backend','metal']
        for _ in range(2): subprocess.run(command,check=True,capture_output=True)
        self.assertTrue(verify(package)['passed'])
        # Reseal to exercise semantic checks, beyond the existing digest guards.
        manifest=json.loads((package/'manifest.json').read_text())
        notice='GODOT-ACCESSKIT-NOTICES.txt'
        manifest['licenses'].remove(notice);(package/notice).unlink()
        (package/'manifest.json').write_text(json.dumps(seal(package,manifest)))
        with self.assertRaisesRegex(ValueError,'notices/provenance missing'): verify(package)

    def test_linux_static_accesskit_inventory(self):
        library=self.root/'fixture.so';library.write_bytes(b'fixture, no runtime execution')
        package=self.root/'linux'
        command=[sys.executable,str(ENGINE_ROOT/'Tools/Godot/package_runtime.py'),
                 '--source',str(ENGINE_ROOT/'Source/3rdParty/Godot'),'--library',str(library),
                 '--output',str(package),'--architecture','arm64','--graphics-backend','egl',
                 '--static-accesskit-sdk','linux']
        subprocess.run(command,check=True,capture_output=True)
        self.assertTrue(verify(package)['passed'])
        manifest=json.loads((package/'manifest.json').read_text())
        provenance=package/'GODOT-ACCESSKIT-PROVENANCE.json'
        data=json.loads(provenance.read_text());data['source_archive_sha256']='0'*64
        provenance.write_text(json.dumps(data))
        (package/'manifest.json').write_text(json.dumps(seal(package,manifest)))
        with self.assertRaisesRegex(ValueError,'provenance mismatch'): verify(package)

    def test_accesskit_rejects_untrusted_archive(self):
        from ensure_accesskit_sdk import ensure
        archive=self.root/'bad.zip';archive.write_bytes(b'untrusted download')
        with self.assertRaisesRegex(ValueError,'archive hash mismatch'):
            ensure(self.root/'sdk',archive)

    def test_accesskit_rejects_bad_cached_library(self):
        from ensure_accesskit_sdk import ensure
        sdk=self.root/'sdk';(sdk/'include').mkdir(parents=True)
        shutil.copy2(ENGINE_ROOT/'Source/3rdParty/Godot/thirdparty/accesskit/include/accesskit.h',sdk/'include/accesskit.h')
        library=sdk/'lib/macos/arm64/static/libaccesskit.a';library.parent.mkdir(parents=True);library.write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError,'SDK hash mismatch'): ensure(sdk)

    def test_unknown_graphics_backend(self):
        self.manifest['graphics_backend']='d3d11';self.save();self.rejects()
    def test_seal_preserves_identity(self):
        with self.assertRaises(ValueError):seal(self.root,{'source_archive_sha256':'0'*64})
    def test_missing_payload(self):
        self.manifest.pop('library');self.manifest.pop('library_sha256');self.save();self.rejects()
    def test_path_escape(self):
        self.manifest['artifacts']['../outside']='0'*64;self.save();self.rejects()
    def test_symlink(self):
        (self.root/'alias.so').symlink_to(self.root/'runtime.so')
        self.manifest['artifacts']['alias.so']=digest(self.root/'runtime.so');self.save();self.rejects()

if __name__=='__main__':unittest.main()
