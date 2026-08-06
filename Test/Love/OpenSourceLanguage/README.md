# Open-source Love language-project corpus

P6-18 keeps compiler acceptance separate from runtime-project acceptance. These
fixtures come from real Love projects written in TypeScript, Teal, and
YueScript. Every source is tied to a fixed upstream commit and license.

| Sample | Repository / commit | License | Acceptance scope |
| --- | --- | --- | --- |
| Love TypeScript Template | `hazzard993/love-typescript-template@5ab6ee98226b22692d979f366df5005bbaf5026b` | MIT | Both upstream TS files receive only a checked-in leading `import "love"`; standard Dora `/ts/build` type-checks and generates both files, including `love.conf` |
| OSS-UNO Card module | `WeebNetsu/OSS-UNO@215ac4b902762f37cc98f27ff2b4bc75622d8a83` | MIT | The unchanged typed Card module resolves its project declaration and Dora `love.d.tl`, passes `/check`, and generates Lua through `/build` |
| Tsuki | `Kaleidosium/Tsuki@7458b8206203fd0cb8f60cbf590108b48ad16065` | MIT | A clearly separated Dora source port explicitly requires Love, keeps ordinary Yue modules, passes `/check`, and generates five Lua modules through `/build` |

The test uploads projects through Dora's HTTP API into `Content.writablePath`,
adds only the normal `init.lua` project marker where module discovery needs it,
and invokes the existing generic build endpoints. It asserts generated source
headers and ordinary `require("love")` output. There is no filename marker,
comment pragma, TSX exception, implicit global injection, or Love-specific
generation branch.

This corpus is a compiler and editor workflow gate. It does not claim that the
entire upstream applications run against the current runtime subset. Runtime
coverage remains in `../OpenSource/README.md` and the generated-language
LoveRuntime fixtures.
