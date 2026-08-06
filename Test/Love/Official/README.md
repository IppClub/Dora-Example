# Love official compatibility baseline

The official `love2d/love` 11.5 tag (`6eb8d546736d5915a8b5af30b2cf33456dfdcb1a`)
does not contain the repository's `testing/` tree. Dora's first official-test
baseline therefore pins the last pre-release test snapshot from 2023-11-14:

- repository: `https://github.com/love2d/love.git`
- test commit: `357b005e5332d7fca847a40eac5b1d263e6e7398`
- upstream path: `testing/`

That snapshot explicitly describes itself as targeting the in-development Love
12 API, so it must not be executed wholesale or presented as a Love 11.5 pass
rate. `Fixtures/OfficialCompatibility/data_math.lua` started with the selected
Data and Math assertions and now also carries Event, Timer, System, Filesystem,
Image, Sound, Audio, Font, Physics, Window, and Graphics cases whose APIs and
expected behavior exist in Love 11.5.
Method names remain traceable to the corresponding files under upstream
`testing/tests/`. Filesystem cases use a dedicated temporary save base and the
test Content backend; C require paths, symlink switches, and Love 12-only
constructors remain explicit skips rather than host filesystem fallbacks.
The separate API parity gate reads the vendored Love 11.5 wrapper method tables
directly, so this selected official snapshot cannot hide a method that is absent
from both the runtime and declarations. It also covers the deprecated 11.5
filesystem queries; they keep Dora Content confinement, and modification time
returns Love's `nil, error` result when the Content backend has no timestamp.
Image and Sound use injected deterministic decode backends. Compressed image
cases exercise a two-level DXT1 container through the same backend contract,
including detection, Data bytes, cloning, format and mipmap dimensions; real
Dora builds separately parse supported containers through bimg.
Audio uses a deterministic Dora AudioSource backend and verifies handle cleanup,
pause-all results, app-global listener, Doppler and all seven distance models,
and per-Source spatial properties, including direction/cone state, cone high-
frequency gain, air absorption, and volume limits. Cone base/HF gain, air gain,
and the 5 kHz high-shelf response have separate deterministic coverage. Named
effect definition/query/limits and support reporting now run through the SoLoud
approximation backend. RecordingDevice enumeration, bounded PCM consumption,
format reporting, restart, stop, and cleanup run through a deterministic capture
backend. `setMixWithSystem` reaches the application-global iOS audio-session
policy backend and follows Love 11.5 by returning false on other platforms; only
the aggregate Source placeholder remains a skip.
The independent `love.font` ImageRasterizer, TrueType Rasterizer, BMFont
Rasterizer, and GlyphData object surface is recorded separately from
`love.graphics.Font`. All seven upstream font methods run against deterministic
RGBA8 atlases, Content-backed font data, or the Content-injected default
TrueType font. BMFont text descriptors cover explicit and relative Content page
loading; AngelCode binary BMFont is outside the Love 11.5 compatibility claim.
Physics constructors and meter behavior run against the deterministic
`PhysicsBackend`; all backend handle maps must be empty after state close. The
six upstream object placeholders remain upstream skips, and Love 12's
`getDistance` helper is recorded as an explicit version/implementation gap.
Window validates 28 virtual-surface operations currently equivalent in an
embedded LoveNode, including both Love 11.5 `updateMode` overload families,
single-display dimensions/name/orientation, full-surface safe area, node-routed
focus/visibility/open state, instance-local title/VSync/display-sleep requests,
and the explicit non-fullscreen result. These values describe the LoveNode
surface and never mutate Dora's OS window. The eight host actions which would
close, move, minimize/maximize/restore, set an icon, request attention, or show
a blocking message box remain individual skips.
Graphics classifies all 107 upstream method entries. Seventy-five deterministic
state, constructor, Shader-validation, virtual-surface, capability, and
ordering-hint cases run against the auditable graphics backend. `newVideo`
loads the fixed Ogg/Theora fixture through the injected Content backend and
verifies dimensions, filter state, Vorbis/SoLoud Source synchronization,
background frame decoding, RGBA upload, drawing, the video-only fallback, and
the explicit `audio=false` path;
framebuffer/presentation assertions stay tied to the existing Metal pixel suite
instead of being weakened to call-count checks. The remaining upstream object
placeholders and unsupported API surface remain method-level skips. Love 12-only
`newTextBatch` and `getStencilMode` are version skips; Love 11.5 `newVideo` is a
Video/Theora deferral. Line style/join now use Love-derived miter/bevel/none
tessellation and smooth alpha fringe geometry in Dora's renderer. Arc supports
Love 11.5 pie/open/closed overloads and Love-derived segment generation. Wireframe
converts Love triangle submissions to bgfx line-list edges and keeps point draws unchanged.
`getStats` uses per-LoveNode command, switch,
resource, and owned-texture counters rather than Dora-global renderer values;
its target-table and complete numeric field contract is part of this baseline.
State close must
balance every Image, Canvas, Font, and Shader handle created by this subset.
The Video module's two upstream cases now execute against the same fixture and
cover filename, initial state, play, pause, seek, tell, and rewind. The snapshot
contains no Keyboard, Mouse, Touch, or Joystick test files, so
Dora's existing input injection and platform scenes remain non-official
evidence rather than invented upstream counts. All five Thread cases now run
against runtime-scoped Channels and independent Lua 5.5 worker states, including
blocking supply/demand, atomic access, errors, and the three constructors. With
all Thread and Video entries now executed, every method in all 15 files under the pinned
`testing/tests/` directory has a pass, fail, or skip result.

Each selected case is isolated with `pcall` and produces module-level pass/fail
counts. Unsupported modules and Love 12-only methods are not silently counted as
passes; they remain unselected until the progress document records a concrete
skip reason or a Love 11.5-compatible adaptation.
