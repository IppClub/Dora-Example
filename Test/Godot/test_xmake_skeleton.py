#!/usr/bin/env python3
"""Validate the standalone Godot target graph without compiling Godot."""

from __future__ import annotations

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path

import re
import os
import subprocess
from pathlib import Path


ROOT = ENGINE_ROOT
TARGETS = ROOT / "Projects/xmake/godot/targets.lua"
EXPECTED = [
    "godot-codegen",
    "godot-jpeg-8",
    "godot-jpeg-12",
    "godot-pcre2-16",
    "godot-pcre2-32",
    "godot-core",
    "godot-drivers",
    "godot-servers",
    "godot-scene",
    "godot-modules",
    "godot-main-platform",
    "godot-dora-bridge",
    "godot-runtime",
]
EXPECTED_DEPS = {
    "godot-jpeg-8": "godot-codegen",
    "godot-jpeg-12": "godot-codegen",
    "godot-pcre2-16": "godot-codegen",
    "godot-pcre2-32": "godot-codegen",
    "godot-core": "godot-codegen",
    "godot-drivers": "godot-core",
    "godot-servers": "godot-drivers",
    "godot-scene": "godot-servers",
    "godot-modules": "godot-scene",
    "godot-main-platform": "godot-modules",
    "godot-dora-bridge": "godot-main-platform",
    "godot-runtime": "godot-dora-bridge",
}


def run(*args: str) -> str:
    env = os.environ.copy()
    env["XMAKE_CONFIGDIR"] = str(ROOT / "build/godot-xmake/skeleton-config")
    return subprocess.check_output(args, cwd=ROOT, env=env, text=True, stderr=subprocess.STDOUT)


def main() -> None:
    text = TARGETS.read_text(encoding="utf-8")
    declared = re.findall(r'name = "([^"]+)"', text)
    declared += re.findall(r'target\("([^"]+)"\)', text)
    # Platform blocks may reopen a target to append backend-specific link
    # settings; validate the logical target set rather than raw occurrences.
    assert set(declared) == set(EXPECTED), (declared, EXPECTED)
    assert 'path.join(os.projectdir(), "build/godot-xmake")' in text
    assert "Source/3rdParty/Godot" in text
    assert "has_config(\"dora_godot_runtime\")" in text

    before = run("git", "status", "--short", "--", "Source/3rdParty/Godot")
    run("xmake", "f", "-c", "-m", "release", "--dora_godot_runtime=y", "--dora_godot_standalone=y", "-y")
    listed = run("xmake", "show", "-l", "targets")
    after = run("git", "status", "--short", "--", "Source/3rdParty/Godot")
    assert before == after, (before, after)
    for target in EXPECTED:
        assert target in listed, target
        details = run("xmake", "show", "-t", target)
        if target != "godot-codegen" and not target.startswith(("godot-jpeg-", "godot-pcre2-")):
            assert "build/godot-xmake" in details, (target, details)
        dependency = EXPECTED_DEPS.get(target)
        if dependency:
            assert dependency in details, (target, dependency)

    print(f"validated {len(EXPECTED)} Godot xmake targets; vendor tree unchanged")


if __name__ == "__main__":
    main()
