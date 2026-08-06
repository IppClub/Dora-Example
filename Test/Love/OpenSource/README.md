# Open-source Love project baseline

P6-18 runs unchanged project sources from independently maintained Love
repositories. Every sample must pin a full commit, retain its upstream license,
avoid LuaJIT FFI/native modules, and exercise the source through a Content-backed
isolated LoveRuntime. Harness code may drive frames and inspect the injected
backend, but must not rewrite the project's Love calls to make it pass.

| Sample | Repository / commit | License | Upstream files | Current coverage |
| --- | --- | --- | --- | --- |
| Game Timer | `Samuel-de-Oliveira/Love2D-Examples@2b13922a5705895e00e0f52c9a3f1e5d39fce55d` | MIT | `Game_Timer/main.lua`, `tools.lua`, `conf.lua` | Multi-file require, load/update/draw, timer formatting, keyboard query, Font selection, three Text submissions, clean close |
| Learn2Love Breakout | `RVAGameJams/learn2love@89b3ce21d6fc0cbdb46ca787f651da30aaf31d2f` | MIT | Complete `code/breakout-5/` runtime tree: 15 Lua files | Deep Content require graph, 800×600 conf, focus/key callbacks, colored primitives/Text, one World with 45 Body/Shape/Fixture triples, user data, contact callbacks, frame update/draw, and clean cascade close |
| Denver Synthesizer | `superzazu/denver.lua@36fdb278e99de6827427633a905c5a862e0e3913` | MIT | `denver.lua` and complete `example-synthesizer/` runtime tree | Confined multi-root require path, generated 16-bit mono SoundData, 108 static Sources, note key press/release, loop/play/stop, two centered text draws, and clean bulk release |
| Runtime Texture Atlas | `EngineerSmith/Runtime-TextureAtlas@f992abe9fe3afe2a06fdcc8d433e6e338ef0440e` | MIT | Complete root Lua module tree | Content-backed module graph, Love Object `type/typeOf`, renderer system limits, generated RGBA8 ImageData, map/paste/extrusion, power-of-two packing, ImageData-to-Image upload/draw, and clean release |

The vendored source and per-sample provenance live under
`Fixtures/OpenSource/<sample>/`. A sample passing one deterministic backend is
not sufficient evidence for broad project compatibility; projects with images,
audio, physics, or interaction must additionally run on the corresponding Dora
backend and platform acceptance path.
