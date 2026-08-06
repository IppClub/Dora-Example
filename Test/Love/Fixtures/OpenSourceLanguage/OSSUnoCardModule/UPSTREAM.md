# OSS-UNO Teal module provenance

- repository: https://github.com/WeebNetsu/OSS-UNO
- commit: `215ac4b902762f37cc98f27ff2b4bc75622d8a83`
- upstream paths: `src/game/card.tl`, `src/game/card.d.tl`
- license: MIT (`LICENSE`, copyright 2020 Netsu)
- retrieved: 2026-08-03

The two files under `upstream/` are source from a real Teal Love project,
unchanged apart from patch-format final-newline normalization. They form one
complete typed module and already use
`local love = require("love")`; Dora supplies only its normal `init.lua`
project marker and resolves the built-in `love.d.tl`. The complete OSS-UNO
application is not claimed as compatible by this focused compiler sample.
