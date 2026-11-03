#!/usr/bin/env python3
"""Stage opt-in APK test assets without editing the application's source assets."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
from pathlib import Path
import shutil
root=ENGINE_ROOT
out=root/'build/godot-android/test-assets'
shutil.copytree(root/'Assets',out,dirs_exist_ok=True)
(out/'Script/init.lua').write_text('return true\n')
print(out)
