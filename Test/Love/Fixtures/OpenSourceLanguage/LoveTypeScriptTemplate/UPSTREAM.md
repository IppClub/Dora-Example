# Love TypeScript template provenance

- repository: https://github.com/hazzard993/love-typescript-template
- commit: `5ab6ee98226b22692d979f366df5005bbaf5026b`
- upstream paths: `src/main.ts`, `src/conf.ts`, `res/index.txt`, `package.json`, `tsconfig.json`
- license: MIT (`LICENSE`)
- retrieved: 2026-08-03

The files under `upstream/` retain the pinned project source unchanged. The
files under `dora-port/` differ only by a leading `import "love";`, replacing
the upstream tsconfig-wide ambient type injection with Dora's explicit module
activation policy. This is ordinary TypeScript module syntax and does not use
a Love-specific compiler rule.
