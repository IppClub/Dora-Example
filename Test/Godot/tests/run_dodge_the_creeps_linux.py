#!/usr/bin/env python3
"""Compatibility entrypoint for the Linux EGL upstream-project regression."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import sys

assert sys.platform == "linux"
import run_dodge_the_creeps_native  # noqa: E402,F401
