#!/usr/bin/env python3
"""Validate the audited Linux Godot xmake source manifest without compiling."""

from __future__ import annotations

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path

import re
from pathlib import Path
from native_variants import validate_native_variants


ROOT = ENGINE_ROOT
GODOT = ROOT / "Source/3rdParty/Godot"
TARGETS = ROOT / "Projects/xmake/godot/targets.lua"
BUILD_SCRIPT = ROOT / "Tools/Godot/build_linux_runtime.sh"


def validate_manifest(name: str, actions: int, variant_actions: int) -> tuple[str, set[str]]:
    manifest = ROOT / f"Projects/xmake/godot/{name}_sources.lua"
    text = manifest.read_text(encoding="utf-8")
    sources = re.findall(r'^\s+source\("([^"]+)"\),$', text, re.MULTILINE)
    assert len(sources) == actions, (name, len(sources))
    assert validate_native_variants(text) == variant_actions
    assert not any(Path(source).is_absolute() for source in sources)
    for source in sources:
        if ".gen." not in source:
            assert (GODOT / source).is_file(), source

    for define in (
        "LIBGODOT_ENABLED",
        "LINUXBSD_ENABLED",
        "UNIX_ENABLED",
        "GLES3_ENABLED",
        "EGL_ENABLED",
        "GLAD_GLES2",
    ):
        assert f'-D{define}' in text, define
    for forbidden in ("MONO_ENABLED", "X11_ENABLED", "WAYLAND_ENABLED", "VULKAN_ENABLED"):
        assert forbidden not in text, forbidden
    return text, set(sources)


def main() -> None:
    arm_text, arm_sources = validate_manifest("linux", 2362, 110)
    x86_text, x86_sources = validate_manifest("linux_x86_64", 2368, 110)
    targets = TARGETS.read_text(encoding="utf-8")
    build_script = BUILD_SCRIPT.read_text(encoding="utf-8")

    assert "thirdparty/zstd/decompress/huf_decompress_amd64.S" not in arm_sources
    assert "thirdparty/zstd/decompress/huf_decompress_amd64.S" in x86_sources
    assert "thirdparty/libpng/arm/arm_init.c" in arm_sources
    assert "thirdparty/libpng/arm/arm_init.c" not in x86_sources
    assert 'flag("-msse4.2")' in x86_text and 'flag("-mpopcnt")' in x86_text
    assert 'flag("-msse4.2")' not in arm_text

    assert 'path.join(output_root, "linux", get_config("arch"))' in targets
    assert 'local platform_depend_root = path.join(platform_output_root, "deps")' in targets
    assert targets.count("set_dependir(platform_depend_root)") == 2
    assert "os.mkdir(target:dependir())" in targets
    assert 'includes(path.join(os.projectdir(), "Projects/xmake/godot/linux_sources.lua"))' in targets
    assert 'includes(path.join(os.projectdir(), "Projects/xmake/godot/linux_x86_64_sources.lua"))' in targets
    assert '"-Wl,--no-undefined"' in targets
    assert '"-Wl,--version-script=" .. path.join(godot_root, "dora_bridge.map")' in targets
    assert 'XMAKE="${DORA_GODOT_XMAKE:-${DORA_XMAKE:-xmake}}"' in build_script
    assert "Godot xmake migration requires xmake 3.x or newer" in build_script
    assert '"--cross=$DORA_GODOT_LINUX_CROSS"' in build_script
    assert '"--bin=$DORA_GODOT_LINUX_BIN"' in build_script
    assert '"$XMAKE" f -P "$ROOT"' in build_script
    assert '"$XMAKE" build -P "$ROOT"' in build_script

    print(
        "validated Linux ARM64/x86_64 manifests: 2362/2368 compile actions, "
        "110 native variant actions each and architecture-isolated output"
    )


if __name__ == "__main__":
    main()
