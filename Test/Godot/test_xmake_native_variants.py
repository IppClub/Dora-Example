#!/usr/bin/env python3
"""Prove same-source object variants survive archive merging and incremental builds.

Uses the native macOS/Linux C toolchain. Does not build Godot or exercise a GPU.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--xmake', default=os.environ.get('DORA_GODOT_XMAKE', 'xmake'))
    a = p.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    (out / 'src').mkdir()
    cc = shutil.which('cc')
    assert cc and os.name == 'posix', 'This native fixture requires macOS/Linux cc'
    env = os.environ.copy()
    env['XMAKE_CONFIGDIR'] = str(out / 'config')
    (out / 'src/variant.c').write_text('int VARIANT_NAME(void) { return VARIANT_VALUE; }\n')
    (out / 'src/anchor.c').write_text('int native_variants_anchor;\n')
    (out / 'src/combined.c').write_text('int native_variants_combined;\n')
    project = '''set_project("native-codec-variants-proof")
set_languages("c11")
set_policy("build.fence", true)
set_objectdir(path.join(os.projectdir(), "objects"))
set_dependir(path.join(os.projectdir(), "deps"))
set_targetdir(path.join(os.projectdir(), "bin"))
for _, width in ipairs({16, 32}) do
    target("variant-" .. width)
        set_kind("object")
        add_files("src/variant.c")
        add_defines("VARIANT_NAME=variant_" .. width,
                    "VARIANT_VALUE=" .. (width == 16 and @VALUE@ or width))
    target_end()
end
target("core")
    set_kind("static")
    add_deps("variant-16", "variant-32")
    add_files("src/anchor.c")
target_end()
target("combined")
    set_kind("static")
    set_policy("build.merge_archive", true)
    add_deps("core")
    add_files("src/combined.c")
target_end()
'''
    for value in (16, 160):
        (out / 'xmake.lua').write_text(project.replace('@VALUE@', str(value)))
        (out / 'src/main.c').write_text('extern int variant_16(void);\nextern int variant_32(void);\n'
                                   f'int main(void) {{ return variant_16() == {value} && variant_32() == 32 ? 0 : 1; }}\n')
        with (out / f'build-{value}.log').open('w') as log:
            if value == 16:
                subprocess.run([a.xmake, 'f', '-P', str(out), '-c', '-m', 'release', '-y'],
                               env=env, cwd=out, stdout=log, stderr=subprocess.STDOUT, check=True)
            subprocess.run([a.xmake, 'build', '-P', str(out), '-j2', 'combined'],
                           env=env, cwd=out, stdout=log, stderr=subprocess.STDOUT, check=True)
            # Link only the merged archive. xmake's transitive dependencies must
            # not conceal a missing variant in either intermediate archive.
            subprocess.run([cc, str(out / 'src/main.c'), str(out / 'bin/libcombined.a'),
                            '-o', str(out / 'proof')], stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([str(out / 'proof')], check=True)
    result = {'passed': True, 'same_source_object_variants': True,
              'merged_archive_linked_without_transitive_libraries': True,
              'incremental_macro_change_executed': True,
              'scope': 'Native C/xmake/archive regression only; no Godot runtime or GPU acceptance'}
    (out / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Native xmake variants: compile, merged archive and incremental execution PASS')


if __name__ == '__main__':
    main()
