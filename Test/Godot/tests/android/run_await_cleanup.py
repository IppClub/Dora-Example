#!/usr/bin/env python3
"""Ordinary Release pending-await regression with real Activity.finish.

The separate, locally signed Android framework controller keeps the process
alive through onDestroy and native Logger destruction. Removing a root task
can end the process before those callbacks; it is not an exit acceptance gate.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
from pathlib import Path
import subprocess
import sys

p = argparse.ArgumentParser(description=__doc__)
for name in ('sdk', 'apk', 'runtime-package', 'output', 'lifecycle-apk'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--serial', required=True)
p.add_argument('--owned-avd', required=True)
a = p.parse_args()
command = [sys.executable, str(Path(__file__).with_name('run_ordinary_release.py')),
           '--serial', a.serial, '--owned-avd', a.owned_avd, '--await-cleanup']
for name in ('sdk', 'apk', 'runtime-package', 'output', 'lifecycle-apk'):
    command += ['--' + name, str(getattr(a, name.replace('-', '_')))]
subprocess.run(command, check=True)
