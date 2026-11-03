#!/usr/bin/env python3
"""Exercise project discovery and game-package corruption/extraction boundaries."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT
import json
import struct
import tempfile
import unittest
import zipfile
import project_delivery as delivery
from project import require_ordinary_host, lua_string


def pck(path, version=3, name='project.binary'):
    encoded = name.encode() + b'\0'
    encoded += b'\0' * (-len(encoded) % 4)
    start = 96 + 4 + 4 + len(encoded) + 36
    header = b'GDPC' + struct.pack('<IIIIIQ', version, 4, 6, 0, 0, 0)
    header += struct.pack('<Q', 96) if version == 3 else b''
    header += bytes(96 - len(header))
    body = struct.pack('<II', 1, len(encoded)) + encoded
    body += struct.pack('<QQ', start, 4) + bytes(16) + struct.pack('<I', 0)
    path.write_bytes(header + body + b'fake')


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()

    def project(self, relative='project'):
        project = self.root / relative
        project.mkdir(parents=True)
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Delivery"\nrun/main_scene="res://main.tscn"\n')
        return project

    def game(self):
        package = self.root/'game'
        package.mkdir()
        pck(package/'game.pck')
        manifest = {'format':delivery.GAME_FORMAT, 'format_version':1, 'id':'dora.fixture',
                    'title':'Fixture', 'version':'1.0', 'runtime':{'godot':'4.6','mono':False},
                    'entry':'game.pck', 'platform':'macOS', 'licenses':[],
                    'artifacts':{'game.pck':{'sha256':delivery.digest(package/'game.pck'),
                                           'bytes':(package/'game.pck').stat().st_size}}}
        delivery.write_json(package/'game.json', manifest)
        return package

    def test_project_file_and_nested_repository(self):
        project = self.project('repo/games/demo')
        self.assertEqual(delivery.find_project(self.root/'repo'), project)
        self.assertEqual(delivery.find_project(project/'project.godot'), project)

    def test_multiple_projects_require_selection(self):
        self.project('repo/first'); second = self.project('repo/second')
        with self.assertRaises(delivery.ProjectError):delivery.find_project(self.root/'repo')
        self.assertEqual(delivery.find_project(self.root/'repo','second'),second)

    def test_selection_cannot_escape_repository(self):
        project = self.project()
        with self.assertRaises(delivery.ProjectError):delivery.find_project(project,'../')

    def test_import_cache_and_git_data_are_not_sources(self):
        project = self.project()
        (project/'.godot').mkdir();(project/'.godot/cache').write_text('cache')
        (project/'.git').mkdir();(project/'.git/config').write_text('local credentials stay outside staging')
        self.assertEqual(set(delivery.fingerprint(project)),{'project.godot'})

    def test_symlinked_source_requires_materialization(self):
        project = self.project()
        try:(project/'outside').symlink_to(self.root/'missing')
        except OSError:self.skipTest('Symlinks unavailable')
        with self.assertRaises(delivery.ProjectError):delivery.inspect_project(project)

    def test_csharp_feature_blocks_preparation(self):
        project = self.project()
        with (project/'project.godot').open('a') as f:f.write('config/features=PackedStringArray(\n"4.6", "C#")\n')
        with self.assertRaises(delivery.ProjectError):delivery.require_supported(delivery.inspect_project(project))

    def test_native_extension_requires_platform_sidecars(self):
        project = self.project();(project/'plugin.gdextension').write_text('[configuration]\n')
        with self.assertRaises(delivery.ProjectError):delivery.require_supported(delivery.inspect_project(project))

    def test_existing_output_is_preserved(self):
        project = self.project();output=self.root/'out';output.mkdir();sentinel=output/'keep';sentinel.write_text('keep')
        with self.assertRaises(delivery.ProjectError):delivery.prepare(project,output,'not-an-editor')
        self.assertEqual(sentinel.read_text(),'keep')

    def test_preparation_cannot_write_into_repository(self):
        project = self.project('repo/nested')
        with self.assertRaises(delivery.ProjectError):delivery.prepare(self.root/'repo',self.root/'repo/work','not-an-editor')
        self.assertFalse((self.root/'repo/work').exists())

    def test_godot3_project_is_rejected(self):
        project=self.project();(project/'project.godot').write_text('config_version=4\n')
        with self.assertRaises(delivery.ProjectError):delivery.inspect_project(project)

    def test_both_pck_index_versions(self):
        for version in [2,3]:
            path=self.root/f'{version}.pck';pck(path,version)
            self.assertEqual(delivery.inspect_pck(path)['resource_count'],1)

    def test_pack_traversal_and_truncation(self):
        path=self.root/'bad.pck';pck(path,name='../project.binary')
        with self.assertRaises(delivery.ProjectError):delivery.inspect_pck(path)
        path.write_bytes(b'GDPC')
        with self.assertRaises(delivery.ProjectError):delivery.inspect_pck(path)

    def test_corrupt_game_is_rejected(self):
        package=self.game();self.assertTrue(delivery.verify_game(package)['verified'])
        with (package/'game.pck').open('ab') as f:f.write(b'corrupt')
        with self.assertRaises(delivery.ProjectError):delivery.verify_game(package)

    def test_unlisted_game_files_are_rejected(self):
        package=self.game();(package/'extra.dll').write_bytes(b'extra')
        with self.assertRaises(delivery.ProjectError):delivery.verify_game(package)

    def test_unsupported_runtime_is_rejected(self):
        package=self.game();path=package/'game.json';manifest=json.loads(path.read_text());manifest['runtime']['mono']=True;delivery.write_json(path,manifest)
        with self.assertRaises(delivery.ProjectError):delivery.verify_game(package)

    def test_artifact_path_escape_is_rejected(self):
        package=self.game();path=package/'game.json';manifest=json.loads(path.read_text());manifest['artifacts']['../outside']={'sha256':'0'*64,'bytes':0};delivery.write_json(path,manifest)
        with self.assertRaises(delivery.ProjectError):delivery.verify_game(package)

    def test_archive_roundtrip(self):
        package=self.game();archive=self.root/'game.dora-game';delivery.archive_game(package,archive)
        original=delivery.verify_game(package);installed=delivery.install_game(archive,self.root/'installed')
        self.assertEqual(original['manifest_sha256'],installed['manifest_sha256'])
        self.assertEqual(original['pack']['sha256'],installed['pack']['sha256'])

    def test_archive_traversal_and_duplicate_rejected_before_write(self):
        for index,names in enumerate([['../escape'],['game.json','game.json'],['C:/escape'],['C:escape']]):
            archive=self.root/f'bad{index}.zip'
            with zipfile.ZipFile(archive,'w') as zip:
                for name in names:zip.writestr(name,'x')
            output=self.root/f'bad{index}'
            with self.assertRaises(delivery.ProjectError):delivery.install_game(archive,output)
            self.assertFalse(output.exists())
        self.assertFalse((self.root/'escape').exists())

    def test_archive_expanded_size_limit(self):
        archive=self.root/'big.zip'
        with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as zip:zip.writestr('large',b'a'*1000)
        with self.assertRaises(delivery.ProjectError):delivery.install_game(archive,self.root/'installed',max_bytes=100)
        self.assertFalse((self.root/'installed').exists())

    def test_test_host_is_rejected_even_across_read_blocks(self):
        binary=self.root/'Dora'
        binary.write_bytes(b'x'*(1024*1024-5)+b'GODOT_NODE_TEST')
        with self.assertRaises(delivery.ProjectError):require_ordinary_host(binary)

    def test_lua_path_literal_preserves_delimiters(self):
        value='/project/with]]and]=]/main.pck'
        self.assertEqual(lua_string(value),'[==['+value+']==]')

    def test_source_zip_import_strips_host_wrapper_and_caches(self):
        archive=self.root/'source.zip'
        with zipfile.ZipFile(archive,'w') as zip:
            zip.writestr('repo-main/project.godot','config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n')
            zip.writestr('repo-main/main.tscn','fixture')
            zip.writestr('repo-main/.git/config','not imported')
            zip.writestr('repo-main/.godot/imported/cache','not imported')
        output=self.root/'imported';delivery.import_repository(archive,output)
        self.assertTrue((output/'project.godot').is_file())
        self.assertFalse((output/'.git').exists());self.assertFalse((output/'.godot').exists())
        self.assertEqual(delivery.find_project(output),output)


if __name__ == '__main__':unittest.main()
