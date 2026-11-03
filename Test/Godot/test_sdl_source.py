#!/usr/bin/env python3
"""Exercise source, archive, patch and path rejection with the real SDL inputs."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import json
from pathlib import Path
import shutil
import tempfile

from verify_sdl_source import FOLDER, sha, verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--official-archive', type=Path, required=True)
    parser.add_argument('--fork-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence path'
    baseline = verify(args.official_archive, args.fork_archive)
    cases = {
        'source-changed': 'SDL vendor source differs',
        'license-missing': 'Retained SDL inventory differs',
        'extra-source': 'Retained SDL inventory differs',
        'linux-config-changed': 'Added SDL vendor header differs',
        'local-build-input-changed': 'SDL local input differs',
        'patch-changed': 'SDL patch digest differs',
        'unsafe-path': 'Unsafe SDL retained path',
        'source-symlink': 'SDL retained path escapes vendor',
        'wrong-official-archive': 'Unrecognized SDL archive: official',
        'wrong-fork-archive': 'Unrecognized SDL archive: fork',
        'wrong-commit': 'Unexpected SDL commit',
        'metadata-and-source-changed': 'Official SDL digest differs',
        'resealed-unsafe-patch': 'Unsafe SDL patch target',
        'resealed-missing-hunk': 'SDL fork reconstruction differs',
        'newline-variant-content-changed': 'SDL newline variant content differs',
    }
    rejected = []
    with tempfile.TemporaryDirectory(prefix='dora-sdl-source-controls-') as temp:
        for case, expected in cases.items():
            folder = Path(temp) / case
            # Exclude only root build/artifact trees, exactly as the verifier.
            def ignore(directory, names):
                return set(names) & {'.xmake', 'build', 'Lib'} if Path(directory) == FOLDER else set()
            shutil.copytree(FOLDER, folder, ignore=ignore)
            official, fork = args.official_archive, args.fork_archive
            metadata = folder / 'UPSTREAM.json'
            record = json.loads(metadata.read_text())
            source = folder / 'src/video/cocoa/SDL_cocoaevents.m'
            if case == 'source-changed':
                source.write_bytes(source.read_bytes() + b'\n/* invalid fixture */\n')
            elif case == 'license-missing':
                (folder / 'LICENSE.txt').unlink()
            elif case == 'extra-source':
                (folder / 'src/unknown.c').write_text('int unknown;\n')
            elif case == 'linux-config-changed':
                path = folder / 'include/SDL_config_linux.h'
                path.write_bytes(path.read_bytes() + b'\n/* invalid fixture */\n')
            elif case == 'local-build-input-changed':
                path = folder / 'xmake.lua'
                path.write_bytes(path.read_bytes() + b'\n-- invalid fixture\n')
            elif case == 'patch-changed':
                (folder / record['patches'][0]['path']).write_text('invalid patch\n')
            elif case == 'unsafe-path':
                record['files'][0]['path'] = '../escape.c'
            elif case == 'source-symlink':
                source.unlink()
                source.symlink_to(FOLDER / 'src/video/cocoa/SDL_cocoaevents.m')
            elif case == 'wrong-official-archive':
                official = fork
            elif case == 'wrong-fork-archive':
                fork = official
            elif case == 'wrong-commit':
                record['fork']['commit'] = '0' * 40
            elif case == 'metadata-and-source-changed':
                source = folder / 'src/SDL.c'
                source.write_bytes(source.read_bytes() + b'\n/* invalid fixture */\n')
                entry = next(row for row in record['files'] if row['path'] == source.relative_to(folder).as_posix())
                for key in ('official_sha256', 'fork_sha256', 'vendor_sha256'):
                    entry[key] = sha(source.read_bytes())
            elif case == 'resealed-unsafe-patch':
                path = folder / record['patches'][0]['path']
                path.write_text('--- /tmp/escape.c\n+++ /tmp/escape.c\n')
                record['patches'][0]['sha256'] = sha(path.read_bytes())
            elif case == 'newline-variant-content-changed':
                path = folder / 'cmake/CheckCPUArchitecture.cmake'
                path.write_bytes(path.read_bytes().replace(b'\r\n', b'\n') + b'# invalid fixture\n')
            else:
                path = folder / record['patches'][0]['path']
                text = path.read_text()
                path.write_text(text[text.index('--- a/include/SDL_config_iphoneos.h'):])
                record['patches'][0]['sha256'] = sha(path.read_bytes())
            metadata.write_text(json.dumps(record))
            try:
                verify(official, fork, folder)
            except AssertionError as error:
                assert expected in str(error), (case, str(error))
                rejected.append({'case': case, 'reason': str(error)})
            else:
                raise AssertionError('Invalid SDL evidence accepted: ' + case)
        # Ordinary build state must neither become source evidence nor break checks.
        cached = Path(temp) / 'cache-control'
        shutil.copytree(FOLDER, cached, ignore=ignore)
        for name in ('.xmake', 'build', 'Lib'):
            (cached / name).mkdir()
            (cached / name / 'artifact').write_text('local build fixture\n')
        newline_path = cached / 'cmake/CheckCPUArchitecture.cmake'
        newline_path.write_bytes(newline_path.read_bytes().replace(b'\r\n', b'\n'))
        assert verify(args.official_archive, args.fork_archive, cached)['files'] == baseline['files']
    assert verify(args.official_archive, args.fork_archive)['files'] == baseline['files']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({
        'passed': True, 'scope': __doc__, 'rejected_cases': rejected,
        'retained_upstream_files': 1213, 'local_build_exclusion_positive_control': True,
        'lf_checkout_variant_positive_control': True,
        'original_tree_verified_after_controls': True,
        'validator_sha256': baseline['validator_sha256'],
        'test_sha256': sha(Path(__file__).read_bytes()), 'runtime_execution': False,
    }, indent=2) + '\n')
    print(f'PASS: {len(rejected)} invalid SDL inputs rejected; build exclusions and original tree verified')


if __name__ == '__main__':
    main()
