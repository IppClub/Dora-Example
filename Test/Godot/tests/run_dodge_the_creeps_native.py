#!/usr/bin/env python3
"""Run the unchanged upstream Dodge the Creeps project on Linux EGL or Windows WGL/D3D12."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageChops


root = ENGINE_ROOT
parser = argparse.ArgumentParser(description=__doc__)
for name in ("binary", "library", "project", "output"):
    parser.add_argument("--" + name, type=Path, required=True)
parser.add_argument("--upstream-commit", required=True)
parser.add_argument("--environment", choices=("unspecified", "native", "virtual-machine"), default="unspecified")
parser.add_argument(
    "--allow-legacy-host",
    action="store_true",
    help="Accept an ordinary host predating reader/audio/direct diagnostics; the report keeps that boundary explicit",
)
parser.add_argument('--backend', choices=('EGL', 'WGL', 'D3D12'), help='Default: EGL on Linux, WGL on Windows')
parser.add_argument('--warp', action='store_true', help='Windows D3D12 software adapter only')
parser.add_argument('--d3d12-cpu-readers', action='store_true', help='Diagnostic: also wait for the Dora consumer queue before producing')
parser.add_argument('--warp-shader-cache', choices=('on','off'), help='Diagnostic WARP shader-cache override; project files remain unchanged')
parser.add_argument('--emulator', type=Path, help='Linux only: explicitly launch the real host through a userspace emulator')
parser.add_argument('--abi-python', type=Path, help='Target-architecture Python used with --emulator for ctypes ABI checks')
parser.add_argument('--abi-python-home', type=Path, help='PYTHONHOME only for the target-architecture ABI subprocess')
parser.add_argument('--restart-before-pause', action='store_true', help='Refresh ended games via public Start input before animation and pause/resume checks; verify Start disappeared')
parser.add_argument('--real-time-input', action='store_true', help='Measure public movement input before the first mob spawn using elapsed seconds; retains all controller ticks, captures and pixel thresholds')
args = parser.parse_args()
assert sys.platform in ("linux", "win32")
backend = args.backend or ("WGL" if sys.platform == "win32" else "EGL")
assert backend in (("WGL", "D3D12") if sys.platform == "win32" else ("EGL",))
assert not args.warp or backend == "D3D12", "--warp requires Windows D3D12"
assert not args.d3d12_cpu_readers or backend == "D3D12", "--d3d12-cpu-readers requires Windows D3D12"
assert not args.warp_shader_cache or args.warp, "--warp-shader-cache requires --warp"
assert not (backend == "D3D12" and args.allow_legacy_host), "D3D12 acceptance requires full CPU-fence/audio diagnostics"
assert not args.emulator or sys.platform == 'linux', 'Explicit emulation is Linux only'
assert bool(args.emulator) == bool(args.abi_python) == bool(args.abi_python_home), 'Emulation requires target ABI Python and its home'
emulator = args.emulator.resolve() if args.emulator else None
prefix = [str(emulator)] if emulator else []
abi_python = args.abi_python.resolve() if args.abi_python else Path(sys.executable)

binary = args.binary.resolve()
library = args.library.resolve()
source_project = args.project.resolve()
output = args.output.resolve()
assert binary.is_file() and library.is_file()
assert (source_project / "project.godot").is_file()
assert (source_project / ".godot/imported").is_dir(), "Import the upstream project before running"
assert not output.exists(), "Use a fresh output directory to preserve prior evidence"
output.mkdir(parents=True)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def tree_hashes(path: Path) -> dict[str, str]:
    return {
        str(file.relative_to(path)): digest(file)
        for file in sorted(path.rglob("*"))
        if file.is_file() and ".godot" not in file.relative_to(path).parts
    }


try:
    source_hashes = tree_hashes(source_project)
    project = output / "project"
    shutil.copytree(source_project, project, ignore=shutil.ignore_patterns(".git"))
    assert tree_hashes(project) == source_hashes

    assets = output / "assets"
    shutil.copytree(root / "Assets", assets)
    template = Path(__file__).with_name("dodge_the_creeps_macos.lua")
    startup = (
        template.read_text()
        .replace(
            'assert(D.GodotNode.getUnsupportedReason() == "")',
            'if D.GodotNode.getUnsupportedReason then assert(D.GodotNode.getUnsupportedReason() == "") end',
        )
        .replace("@PROJECT@", json.dumps(str(project)))
        .replace("@OUTPUT@", json.dumps(str(output)))
    )
    # QEMU is functional coverage, not a native throughput benchmark. Keep all
    # controller ticks and assertions; only extend its wall-clock watchdog.
    watchdog_seconds = 180 if emulator else 45
    if emulator:
        assert startup.count('elapsed < 45') == 1
        startup = startup.replace('elapsed < 45', 'elapsed < 180')
    expected_captures = 10 if args.restart_before_pause else 9
    if args.real_time_input:
        start = '\tif ticks == 60 then capture("input-before") end'
        end = '\tif ticks == 105 then capture("input-after") end'
        first = startup.index(start)
        last = startup.index(end, first) + len(end)
        startup = startup[:first] + '''\tif ticks == 49 then capture("input-before") end
\tif ticks == 50 then
\t\tgame:sendKey("D", true)
\t\trealInputStarted = elapsed
\tend
\tif realInputStarted and elapsed - realInputStarted >= 0.35 then
\t\tgame:sendKey("D", false)
\t\tprint("DORA_DODGE real_input_seconds=" .. (elapsed - realInputStarted))
\t\trealInputStarted = nil
\t\tcapture("input-after")
\tend''' + startup[last:]
        startup = 'local realInputStarted = nil\n' + startup
    if args.restart_before_pause:
        point = '\tif ticks == 255 then game:pause();'
        assert startup.count(point) == 1
        startup = startup.replace(point, '''\tif ticks == 245 then
\t\tgame:sendPointer(240, 570, 1, true)
\t\tgame:sendPointer(240, 570, 1, false)
\t\tprint("DORA_DODGE restart_before_pause=1")
\tend
\tif ticks == 250 then capture("before-pause") end
''' + point)
        point = '\tif ticks == 180 then capture("active-a") end'
        assert startup.count(point) == 1
        startup = startup.replace(point, '''\tif ticks == 170 then
\t\tgame:sendPointer(240, 570, 1, true)
\t\tgame:sendPointer(240, 570, 1, false)
\t\tprint("DORA_DODGE restart_before_active=1")
\tend
''' + point)
        startup = startup.replace('assert(captures == 9)', 'assert(captures == 10)')
        startup = startup.replace('complete=1 captures=9 ticks=455', 'complete=1 captures=10 ticks=455')
    (assets / "Script/init.lua").write_text(startup)
    (output / "startup.lua").write_text(startup)

    abi_environment = os.environ.copy()
    if args.abi_python_home:
        abi_environment['PYTHONHOME'] = str(args.abi_python_home.resolve())
    subprocess.run(
        prefix + [
            str(abi_python),
            str(Path(__file__).with_name("runtime_abi.py")),
            "--library",
            str(library),
            "--backend",
            backend,
            "--require-audio",
            "--output",
            str(output / "abi-preboot"),
        ],
        check=True,
        env=abi_environment,
    )

    artifacts = {
        "upstream_repository": "https://github.com/godotengine/godot-demo-projects",
        "upstream_project": "2d/dodge_the_creeps",
        "upstream_commit": args.upstream_commit,
        "host_sha256": digest(binary),
        "runtime_sha256": digest(library),
        "controller_sha256": digest(template),
        "upstream_project_files": source_hashes,
        "execution_mode": "explicit userspace emulator" if emulator else "direct execution",
        "emulator_sha256": digest(emulator) if emulator else None,
        "abi_python_sha256": digest(abi_python),
        "executed_startup_sha256": digest(assets / 'Script/init.lua'),
        "controller_watchdog_seconds": watchdog_seconds,
        "restart_before_pause": args.restart_before_pause,
        "real_time_input": args.real_time_input,
    }
    (output / "artifacts.json").write_text(json.dumps(artifacts, indent=2) + "\n")

    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith(("DORA_GODOT_", "DORA_BUILD_"))
    }
    environment.update(
        DORA_GODOT_LIBRARY=str(library),
        SDL_AUDIODRIVER="dummy",
        GODOT_SILENCE_ROOT_WARNING="1",
    )
    if backend != "D3D12":
        environment["DORA_GODOT_GL_DIRECT"] = "1"
    if args.warp:
        environment["DORA_GODOT_D3D12_WARP"] = "1"
    if args.d3d12_cpu_readers:
        environment["DORA_GODOT_D3D12_CPU_READERS"] = "1"
    if args.warp_shader_cache:
        environment["DORA_GODOT_D3D12_WARP_SHADER_CACHE"] = "1" if args.warp_shader_cache == "on" else "0"
    command = prefix + [str(binary), "--asset", str(assets)]
    if sys.platform == "linux":
        command = [sys.executable, str(Path(__file__).with_name("with_weston.py")),
                   "--logs", str(output / "weston"), "--"] + command
    else:
        environment["DORA_GODOT_WINDOWS_D3D12" if backend == "D3D12" else "DORA_GODOT_WINDOWS_GL"] = "1"
    started = time.monotonic()
    with (output / "run.log").open("w") as log:
        result = subprocess.run(
            command,
            cwd=root,
            env=environment,
            stdout=log,
            stderr=subprocess.STDOUT,
            # Linux's compositor wrapper has its own shorter command guard;
            # on Windows subprocess.run kills and waits for the direct child.
            timeout=360,
        )
    runtime_seconds = time.monotonic() - started
    (output / "process-result.json").write_text(json.dumps({
        "returncode": result.returncode,
        "returncode_hex": hex(result.returncode & 0xffffffff),
        "runtime_seconds": runtime_seconds,
        "command": command,
        "host_sha256": artifacts["host_sha256"],
        "runtime_sha256": artifacts["runtime_sha256"],
    }, indent=2) + "\n", encoding="utf-8")
    assert result.returncode == 0, f"Dora exited with {result.returncode} ({result.returncode & 0xffffffff:#010x})"
    assert tree_hashes(source_project) == source_hashes, "Upstream project source changed"
    assert tree_hashes(project) == source_hashes, "Staged upstream project source changed"
    assert digest(binary) == artifacts["host_sha256"]
    assert digest(library) == artifacts["runtime_sha256"]
    if emulator:
        assert digest(emulator) == artifacts['emulator_sha256']
    assert digest(abi_python) == artifacts['abi_python_sha256']

    log_text = (output / "run.log").read_text()
    assert "DORA_DODGE running=1" in log_text
    assert "DORA_DODGE start_click=1" in log_text
    assert f"DORA_DODGE complete=1 captures={expected_captures} ticks=455" in log_text
    rejected = re.findall(
        r"ERROR:|WARNING:|BGFX LEAK:|C\+\+ objects leaks|AddressSanitizer|runtime error:",
        log_text,
    )
    assert not rejected, rejected

    names = [
        "title",
        "input-before",
        "input-after",
        "active-a",
        "active-b",
        "paused-a",
        "paused-b",
        "resumed",
        "removed",
    ]
    if args.restart_before_pause:
        assert 'DORA_DODGE restart_before_pause=1' in log_text
        names.append('before-pause')
    images = {name: Image.open(output / f"{name}.png").convert("RGB") for name in names}
    assert len({image.size for image in images.values()}) == 1
    width, height = images["title"].size
    box = (round(width * 0.32), round(height * 0.08), round(width * 0.68), round(height * 0.92))
    crops = {name: image.crop(box) for name, image in images.items()}

    def pixels(image: Image.Image):
        return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()

    def changed(first: str, second: str) -> int:
        difference = ImageChops.difference(crops[first], crops[second])
        return sum(pixel != (0, 0, 0) for pixel in pixels(difference))

    image_checks = {
        "title_to_started_changed_pixels": changed("title", "input-before"),
        "active_changed_pixels": changed("active-a", "active-b"),
        "paused_changed_pixels": changed("paused-a", "paused-b"),
        "resumed_changed_pixels": changed("paused-b", "resumed"),
        "removal_changed_pixels": changed("resumed", "removed"),
    }
    if args.restart_before_pause:
        # The public Start button spans viewport (150,520)..(330,620).
        # Require its region to change before pausing, so an ended game on
        # the title screen cannot masquerade as a pause/resume test.
        origin_x, origin_y = (width - 480 * .85) / 2, (height - 720 * .85) / 2
        button = tuple(round(v) for v in (origin_x + 150 * .85, origin_y + 520 * .85,
                                          origin_x + 330 * .85, origin_y + 620 * .85))
        difference = ImageChops.difference(images['title'].crop(button), images['before-pause'].crop(button))
        image_checks['start_button_changed_before_pause'] = sum(pixel != (0,0,0) for pixel in pixels(difference))
        assert image_checks['start_button_changed_before_pause'] > 1000, image_checks
        difference = ImageChops.difference(images['title'].crop(button), images['active-a'].crop(button))
        image_checks['start_button_changed_before_active'] = sum(pixel != (0,0,0) for pixel in pixels(difference))
        assert image_checks['start_button_changed_before_active'] > 1000, image_checks
    (output / "image-checks.json").write_text(json.dumps(image_checks, indent=2) + "\n")
    assert image_checks["title_to_started_changed_pixels"] > 1000, image_checks
    assert image_checks["active_changed_pixels"] > 500, image_checks
    # Godot may advance one AnimatedSprite2D image while SceneTree pause has
    # already frozen physics and transforms. Keep the tolerance below one
    # small sprite (and far below active motion) instead of requiring bytewise
    # identity from two independently captured composited frames.
    assert image_checks["paused_changed_pixels"] < 500, image_checks
    assert image_checks["resumed_changed_pixels"] > 500, image_checks
    assert image_checks["removal_changed_pixels"] > 1000, image_checks

    def player_center(name: str) -> tuple[float, int]:
        points = [
            (x, y)
            for y in range(height)
            for x in range(width)
            if (lambda color: abs(color[0] - 148) < 18 and abs(color[1] - 127) < 18 and abs(color[2] - 124) < 18)(
                images[name].getpixel((x, y))
            )
        ]
        assert len(points) > 40, (name, len(points))
        return sum(x for x, _ in points) / len(points), len(points)

    player_before, before_pixels = player_center("input-before")
    player_after, after_pixels = player_center("input-after")
    player_movement = player_after - player_before
    assert player_movement > 40, (player_before, player_after, player_movement)

    clients = re.findall(
        r"GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)", log_text
    )
    readers = re.findall(
        r"GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)",
        log_text,
    )
    audio = re.findall(
        r"GodotAudio drained: produced=(\d+), consumed=(\d+), nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)",
        log_text,
    )
    direct = re.findall(r"DORA_GODOT_GL_DIRECT completed frames=(\d+) blits=(\d+)", log_text)
    renderer = re.findall(r"Godot Renderer: (.+)", log_text)
    if not renderer:
        renderer = re.findall(r"OpenGL API (.+)", log_text)
    cpu_fences = re.findall(
        r"GodotRuntime D3D12 CPU fence: buffers=(\d+), waits=(\d+), produced=(\d+), completed=(\d+), gpuErrors=(\d+)", log_text)
    assert len(clients) == 1
    if backend == "D3D12":
        assert 'DORA_GODOT_D3D12_CPU enabled' in log_text
        if args.d3d12_cpu_readers:
            assert 'DORA_GODOT_D3D12_CPU_READERS enabled' in log_text
            host_waits = re.findall(r'DORA_GODOT_D3D12_CPU_READERS completed waits=(\d+)', log_text)
            assert len(host_waits) == 1 and int(host_waits[0]) == int(clients[0][0])
        if args.warp_shader_cache:
            assert 'DORA_GODOT_D3D12_WARP shader_cache=' + ('1' if args.warp_shader_cache == 'on' else '0') in log_text
        assert len(cpu_fences) == len(audio) == 1 and not readers and not direct
        buffers, waits, produced, completed, errors = map(int, cpu_fences[0])
        assert buffers == 3 and waits > 0 and produced == completed > 0 and errors == 0
        assert produced == int(clients[0][0])
        if args.warp:
            assert 'DORA_GODOT_D3D12_WARP compat=shadows force_disable_shadows=1 force_vertex_shading=0' in log_text
        renderer = ['D3D12 WARP software adapter' if args.warp else 'D3D12 default adapter; physical GPU unverified']
    elif args.allow_legacy_host:
        assert len(readers) <= 1 and len(audio) <= 1 and len(direct) <= 1
    else:
        assert len(readers) == len(audio) == len(direct) == 1
    produced, completed, errors = map(int, clients[0])
    assert produced == completed and produced > 0 and errors == 0
    if readers:
        buffers, frames, waits, signals, pending, completed_reads, read_errors = map(int, readers[0])
        assert buffers == 3 and frames == completed_reads and frames > 0 and pending == read_errors == 0
    if audio:
        audio_produced, consumed, nonzero_produced, nonzero_consumed, underruns = map(int, audio[0])
        assert audio_produced >= consumed > 0
        assert nonzero_produced > 0 and nonzero_consumed > 0 and underruns == 0
    if direct:
        direct_frames, blits = map(int, direct[0])
        assert direct_frames > 0 and blits == 0

    report = {
        "passed": True,
        "diagnostic_configuration": {"d3d12_cpu_readers": args.d3d12_cpu_readers, "warp_shader_cache_override": args.warp_shader_cache},
        "scope": f"Unchanged official open-source Godot project with LibGodot on {backend}; renderer and dummy audio are not physical-device proof",
        "environment": args.environment,
        "system": platform.platform(),
        "machine": platform.machine(),
        "project": {
            "name": "Dodge the Creeps",
            "upstream_repository": artifacts["upstream_repository"],
            "path": artifacts["upstream_project"],
            "commit": args.upstream_commit,
            "source_files_unchanged": True,
            "generated_import_cache_used": True,
        },
        "runtime_seconds": runtime_seconds,
        "captures": len(names),
        "renderer": renderer[-1] if renderer else "recorded in run.log",
        "legacy_host_diagnostics_allowed": args.allow_legacy_host,
        "input": {
            "pointer_start_button": True,
            "held_key_D": True,
            "physical_key_action_moved_player_pixels": player_movement,
            "player_centers_x": [player_before, player_after],
            "player_color_pixels": [before_pixels, after_pixels],
        },
        "image_checks": image_checks,
        "gpu": {
            "client": clients[0],
            "readers": readers[0] if readers else None,
            "direct": direct[0] if direct else None,
            "steady_state_blits": 0 if direct else None,
            "host_metrics_available": bool(cpu_fences) if backend == "D3D12" else bool(readers and direct),
            "cpu_fences": cpu_fences,
            "synchronization_scope": "CPU fence; GPU reader fences untested" if backend == "D3D12" else "GL reader fences",
        },
        "audio": {
            "accounting": audio[0] if audio else None,
            "decoded_project_ogg_nonzero": True if audio else None,
            "physical_device_audibility_tested": False,
            "host_metrics_available": bool(audio),
        },
        "artifacts": {key: value for key, value in artifacts.items() if key != "upstream_project_files"},
        "abi_preboot_sha256": digest(output / "abi-preboot/verification.json"),
        "images_sha256": {name: digest(output / f"{name}.png") for name in names},
        "log_sha256": digest(output / "run.log"),
    }
    (output / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
except BaseException as error:
    (output / "verification.json").unlink(missing_ok=True)
    (output / "failure.json").write_text(
        json.dumps({"passed": False, "type": type(error).__name__, "error": repr(error)}, indent=2) + "\n"
    )
    raise
