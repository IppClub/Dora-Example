# Dora-SSR test programs

Run these tests through the engine checkout's `xmake dora-test` command. Set
`DORA_TEST_REPO` to this checkout while developing; CI fetches the latest published
default branch once per job and executes a revision snapshot.

`manifest.json` maps each test to its original source location, so relocated
programs can read current engine code and resolve production JS modules.
`suites.json` assigns runnable cases to suites. `ci-coverage.json` records the
previous CI coverage and manual acceptance exclusions; the contract audit catches
missing or duplicate cases and missing push/PR trigger inputs.

- `Engine/`: native HTTP/SQLite/shutdown, Lua services, platform and manual desktop checks.
- `Frontend/`: Web IDE unit/proxy/lifecycle tests and Studio source checks.
- `WebIDE/`, `BuildScripts/`, `DoraStudio/`: previously migrated acceptance and build tests.

From the engine root:

```sh
xmake dora-test --repo=/path/to/Dora-Example --suite=engine
xmake dora-test --repo=/path/to/Dora-Example --suite=ui
xmake dora-test --repo=/path/to/Dora-Example --suite=studio
xmake dora-test --repo=/path/to/Dora-Example --case=check_ci_test_coverage.test
xmake dora-test --repo=/path/to/Dora-Example --case=test_shutdown_watchdog -- --engine /absolute/path/Dora
xmake dora-test --repo=/path/to/Dora-Example --case=test_http_access_native -- --engine /absolute/path/Dora --require-lan
```

Graphical, paid-model, and project-specific acceptance programs remain manual,
with their required arguments and disposable-profile guards preserved. They are
listed in the CI coverage manifest instead of silently treated as automated CI.
Fixtures for browser/native HTTP acceptance are under `Engine/fixtures/`.

Native Agent acceptance starts its own engine in a disposable user profile. Both
Content and Catalog tests work without a connected Web IDE. The lifecycle case
also checks cleanup after assertions, Lua failures, CLI/startup timeouts and an
unresponsive engine. Run the three cases sequentially (they use ports 8866/8868):

```sh
xmake dora-test --repo=/path/to/Dora-Example --suite=native-agent -- --engine /absolute/path/Dora
```

`--dora` remains an alias for `--engine`; both now launch an isolated service.
An occupied port is a prerequisite error; tests never attach to or stop an
existing service. macOS and Linux profile isolation is supported. On headless
Linux, provide Xvfb/Mesa and run the command under `xvfb-run -a`.
These cases remain explicit native acceptance, outside the lightweight CI suites;
no full engine build or graphical environment is added to ordinary Engine Tests.
