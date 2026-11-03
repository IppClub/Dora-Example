#!/usr/bin/env python3
"""Ordinary Windows WGL glTF/3D project runner; shares strict native acceptance."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import sys
from run_project_3d_native import main
if __name__=="__main__":
    assert sys.platform=='win32'
    main()
