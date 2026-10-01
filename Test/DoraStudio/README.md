# Dora Studio tests

This directory owns the Dora Studio unit tests, browser acceptance scripts,
fixtures, and manual test servers. The implementation under test remains in a
matching Dora-SSR checkout under `Studio/`.

Set `DORA_SSR_ROOT` when the repositories are not in one of the common sibling
layouts. The runner creates a temporary mirror so the tests retain their
original relative imports without copying implementation code into this
repository.

Run the current frontend build, Node.js contracts and Go backend race suite
from the Dora-Example checkout (Go >= 1.24 and pnpm are required):

```sh
DORA_SSR_ROOT=/path/to/Dora-SSR node Test/DoraStudio/run.mjs
```

Run one or more tests without rebuilding:

```sh
DORA_SSR_ROOT=/path/to/Dora-SSR node Test/DoraStudio/run.mjs --no-build contracts.test.mjs backend-go.test.mjs
```

Browser and manual scripts remain opt-in because they require the services and
environment variables documented by Dora Studio. Pass their filename to the
same runner, for example:

```sh
DORA_SSR_ROOT=/path/to/Dora-SSR node Test/DoraStudio/run.mjs --no-build workbench.browser.mjs
```

The temporary mirror is deleted after each run. Test evidence and application
artifacts continue to be written to the paths selected by each script in the
Dora-SSR checkout.

From the engine root, use `xmake dora-test --suite=studio`. The default run
uses xmake-managed Emscripten for the Teal/Yarn compilers and regenerates
bilingual tutorial assets from the canonical Docs sources before it
refreshes workspace packages and bilingual documentation with `pnpm -r build`;
`-- --no-build` is only appropriate after that build. Production engine/server
packaging is a separate build gate, not a prerequisite for these unit tests.

Test CI is owned by Dora-SSR, not this repository. Dora-Example stores the
test sources; the engine CI fetches the latest test revision. Changes made
only here do not automatically start engine CI: validate locally or manually
dispatch the relevant Dora-SSR workflow.

The backend is now Go. The 45 former Node implementation-specific test files
have been removed because the server modules they tested no longer exist.
`backend-contract.json` records required current Go test groups.
`backend-go.test.mjs` executes real
HTTP/SQLite/quota/model/queue/static-host tests with `-race -count=1`, checks
that every registered Go group actually passed, and fails on missing coverage
or a failing process. This is current-backend acceptance, not a claim of
one-to-one preservation of every obsolete Node internal-unit assertion.
