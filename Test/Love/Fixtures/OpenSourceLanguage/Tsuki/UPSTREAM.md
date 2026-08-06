# Tsuki YueScript template provenance

- repository: https://github.com/Kaleidosium/Tsuki
- commit: `7458b8206203fd0cb8f60cbf590108b48ad16065`
- upstream paths: `src/Main.yue`, `src/Game.yue`, `src/Player.yue`, `src/util/Math.yue`, `src/util/Vector2.yue`
- license: MIT (`LICENSE`, copyright 2020-2025 novafacing, Dania Rifki)
- retrieved: 2026-08-03

The files under `upstream/` retain the pinned YueScript project source
unchanged apart from patch-format final-newline normalization. Tsuki relies on
Love's implicit global. The explicit files under
`dora-port/` are a source-level port for Dora's normal strict workflow: each
Love-using module starts with `love = require "love"`; unused aliases are
removed and the intentional cross-callback `game` value becomes module-local.
No compiler, extension, file marker, or generated Lua special case is used.

The upstream PNG is not duplicated because this fixture verifies source check
and generation. It does not claim a full Tsuki runtime acceptance; the generic
Yue-to-Lua-to-LoveRuntime execution fixture remains the runtime gate.
