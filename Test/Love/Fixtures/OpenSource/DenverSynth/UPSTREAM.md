# Denver synthesizer upstream provenance

- repository: https://github.com/superzazu/denver.lua
- commit: `36fdb278e99de6827427633a905c5a862e0e3913`
- upstream paths: `denver.lua`, `example-synthesizer/`
- license: MIT (`LICENSE`, copyright 2015 Nicolas Allemand)
- retrieved: 2026-08-03

The complete runtime source of the synthesizer example, its root Denver module,
and the repository license are retained unchanged. Dora's harness supplies only
an isolated LoveRuntime, a Content-backed source root, an explicit confined
require path spanning the root and example directory, deterministic graphics
and audio backends, and frame/event calls.
