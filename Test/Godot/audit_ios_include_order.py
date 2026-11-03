#!/usr/bin/env python3
"""Compatibility entrypoint for the shared compiler include-order auditor."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
from audit_compile_include_order import main

if __name__ == '__main__':
    main()
