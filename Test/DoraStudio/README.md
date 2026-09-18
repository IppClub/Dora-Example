# Dora Studio tests

This directory owns the Dora Studio unit tests, browser acceptance scripts,
fixtures, and manual test servers. The implementation under test remains in a
matching Dora-SSR checkout under `Studio/`.

Set `DORA_SSR_ROOT` when the repositories are not in one of the common sibling
layouts. The runner creates a temporary mirror so the tests retain their
original relative imports without copying implementation code into this
repository.

Run the complete build and Node.js unit suite from the Dora-Example checkout:

```sh
DORA_SSR_ROOT=/path/to/Dora-SSR node Test/DoraStudio/run.mjs
```

Run one or more tests without rebuilding:

```sh
DORA_SSR_ROOT=/path/to/Dora-SSR node Test/DoraStudio/run.mjs --no-build contracts.test.mjs project-store.test.mjs
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
