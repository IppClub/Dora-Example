# Game Timer upstream provenance

- repository: https://github.com/Samuel-de-Oliveira/Love2D-Examples
- commit: `2b13922a5705895e00e0f52c9a3f1e5d39fce55d`
- upstream path: `Game_Timer/`
- license: MIT (`LICENSE`, copyright 2022 Samuel-de-Oliveira)
- retrieved: 2026-08-03

`main.lua`, `tools.lua`, and `conf.lua` are retained as the upstream project
files rather than rewritten as Dora-specific fixtures. The repository-level
license is copied beside the sample. Dora's test harness supplies only the
isolated LoveRuntime, Content-backed source root, deterministic graphics
backend, and frame calls.
