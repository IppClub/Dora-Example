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
