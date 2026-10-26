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
