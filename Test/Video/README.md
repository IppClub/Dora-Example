Run the video regressions against the engine being edited:

```sh
xmake dora-test --repo=/path/to/Dora-Example --suite=engine --case=test_video_playback
```

The runner isolates CMake build directories by test source path so local overrides
and immutable remote snapshots can be used successively.

The focused CMake/CTest project is independent of the broader Love test harness:

```sh
cmake -S Test/Video -B build/video -DDORA_SSR_ROOT=/path/to/Dora-SSR -DCMAKE_BUILD_TYPE=Release
cmake --build build/video --config Release --parallel 4
ctest --test-dir build/video -C Release --output-on-failure --no-tests=error
```

`VideoPlaybackTests.cpp` compares every displayed YUV frame with a sequentially
decoded reference, including duplicate frames, forward/backward and paused seeks,
seeks after EOF, keyframes across page boundaries, missing EOS, truncated headers
and data, and decoder-worker teardown. CTest kills a stalled decoder after 15 s.
`VideoBufferTests.cpp` checks the same production buffer policy used by VideoNode,
including 1080p/4K, frame-rate limits, oversized single frames and integer overflow.
CMake extracts the private policy from `VideoNode.cpp` for this focused test;
changes to that source automatically regenerate the test include.

The decoded-frame queue budget is 32 MiB, with one frame allowed when that frame
alone exceeds the budget. Decoder reference images and pending GPU uploads are
not part of the queue budget.

`VideoQueueTests.cpp` compiles the complete private `VideoData` implementation
from `VideoNode.cpp` with a file-only Content adapter. It fills the actual 1080p
RGBA queue, verifies producer backpressure and stop/join, and decodes two loops
while checking all 600 frame timestamps, including repeated images.
`AudioPlaybackTests.cpp` compiles the Vorbis extraction function from `Audio.cpp`
and the real SoLoud WavStream decoder. It covers both BOS orders, byte-identical
audio extraction, plain/silent/truncated/random inputs, and EOF/rewind/seek with
a granule/PCM sample-count mismatch. CTest bounds each decoder test to 15 s.

These focused tests do not open an audio device or GPU. Actual native rendered
frames, pause/resume, scene detach, and audio/video loop alignment additionally
require running a Dora/Love application with a multiplexed OGV.

`VideoControlsTests.cpp` compiles the production VideoNode control methods with
its real decoder, adapting only the renderer and device clock. It checks exact
RGBA frames for paused/forward/backward/superseded seeks (including packets
spanning pages), synchronized audio seeks and clocks, rewind, finite/clamped
positions, EOF replay, unequal track lengths, loops and scene lifecycle.

For real SoLoud and GPU verification, load `NativeVideoControls.lua` in Dora and
call its returned function with an original multiplexed OGV and an existing
output directory. Use a video at least one second long with embedded Vorbis:

```lua
local run = dofile("/path/to/Dora-Example/Test/Video/NativeVideoControls.lua")
run("/path/to/original.ogv", "/path/to/existing/output")
```

This creates `result.json` and 16 PNGs for independent frame comparison. The
script records `VideoNode.currentTime`, waits for asynchronous readback before
resuming, and tests paused seeks, audio-driven resume, rapid and playing seeks, end state,
replay, rewind, clamped positions and loop restart near EOF. Audio is muted;
physical speaker/display latency is outside the test.

Compare the native captures with an independent FFmpeg decode (requires Python 3,
FFmpeg and FFprobe):

```sh
python3 Test/Video/compare_native_frames.py /path/to/original.ogv /path/to/output
```

The comparison checks all 16 images against the corresponding video timestamp,
clamps audio-only tails to the final video frame, and requires at most one frame
of difference and a mean absolute RGB error below one. It writes
`native-frame-comparison.json` beside the captures.

## Web OGV acceptance

The Love playback target links the production `common/StringMap.cpp` as well:
`StringMap.h` declares an extern `std::vector<std::string>` instantiation, whose
definition must be present for GCC/libstdc++ exception cleanup paths. Clang
optimization can hide this missing dependency. To check the GNU toolchain,
use a separate CMake build directory so a previous Clang compiler cache is not
reused:

```sh
cmake -S Test/Video -B /tmp/ogv-gcc -DDORA_SSR_ROOT=/path/to/Dora-SSR \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
cmake --build /tmp/ogv-gcc --parallel 4
ctest --test-dir /tmp/ogv-gcc --output-on-failure
```

The CMake suite also builds `dora_web_video_controls_tests`: the production
VideoData and VideoNode control code is compiled with DORA_EMSCRIPTEN and runs
without a video worker, covering keyframe seeks, paused preview, audio tails,
EOF replay and loop restart. The AudioWorklet DSP test additionally checks that
a muted 2D Source advances, holds while paused, seeks/resumes and reaches EOF:

```sh
node Test/BuildScripts/test_web_audio_worklet.mjs /path/to/web-build
```

For actual browser/audio/GPU acceptance, build a Release Web Player with VIDEO
and LOVE enabled. Supply an original Ogg/Theora video with embedded Vorbis,
at least 52 seconds long; the script does not transcode it. Stage and serve it:

```sh
python3 Test/Video/stage_web_ogv.py /path/to/Dora-SSR /path/to/sintel.ogv /tmp/ogv-web \
  --engine-files /path/to/web-build --port 8880
```

Open the printed URL. Select each of the three cases and click **Start test /
resume audio** after loading. Keep the tab visible. Controls takes about six
seconds; each full-duration case takes the clip duration plus about 15 seconds.
Results, PNGs and browser/audio metadata are collected under `results/<case>`.
Use a new output directory for each build. For pthread builds add `--isolate`;
leave it off to verify that single-thread video works without COOP/COEP or
SharedArrayBuffer. LOVE remains opt-in; the VideoNode cases also run with LOVE
disabled.

```sh
python3 Test/Video/compare_native_frames.py /path/to/sintel.ogv /tmp/ogv-web/results/controls --web
python3 Test/Video/compare_native_frames.py /path/to/sintel.ogv /tmp/ogv-web/results/continuous --web
python3 Test/Video/compare_native_frames.py /path/to/sintel.ogv /tmp/ogv-web/results/lovefull --web
```

The full tests check natural EOF timing, replay through a non-static scene and
loop continuation after crossing EOF. Love also checks paused and playing
seeks. The VideoNode full test continuously moves its muted audio child to
exercise per-frame configuration updates without blocking the Worklet clock.
The Love EOF screenshot uses the final video timestamp for comparison:
its ended Source's `tell()` resets to zero. Audio is muted but decoded by the
real AudioWorklet mixer; speaker/display latency is not measured. Acceptance
requires at most one frame of image error and mean RGB error below one.

The contract suite runs `test_web_ogv_harness`: it verifies startup readiness,
discarding saved results, screenshot upload retries, and publishing the new
result only after every capture has been collected. `test_web_audio_state`
also feeds delayed Worklet cursors while moving/fading a Source and confirms
that configuration changes cannot starve its clock or undo seek/pause ordering.
