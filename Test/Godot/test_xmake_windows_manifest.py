#!/usr/bin/env python3
"""Audit the Windows x64 MinGW migration input independently of compilation."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import re
from pathlib import Path
from native_variants import validate_native_variants

ROOT = ENGINE_ROOT


def main():
    text = (ROOT / "Projects/xmake/godot/windows_x86_64_sources.lua").read_text()
    sources = re.findall(r'^\s+source\("([^"]+)"\),$', text, re.MULTILINE)
    assert len(sources) == 2385
    assert validate_native_variants(text) == 110
    for source in sources:
        assert not Path(source).is_absolute(), source
        if ".gen." not in source:
            assert (ROOT / "Source/3rdParty/Godot" / source).is_file(), source
    for macro in ("LIBGODOT_ENABLED", "WINDOWS_ENABLED", "GLES3_ENABLED", "WASAPI_ENABLED"):
        assert f'-D{macro}' in text, macro
    for macro in ("D3D12_ENABLED", "VULKAN_ENABLED", "MONO_ENABLED", "LINUXBSD_ENABLED"):
        assert f'-D{macro}' not in text, macro
    for source in ("platform/windows/os_windows.cpp", "platform/windows/display_server_windows.cpp"):
        assert source in sources, source
    print("validated Windows x64 WGL manifest: 2385 actions, 110 native codec-variant actions; manifest audit only")


if __name__ == "__main__":
    main()
