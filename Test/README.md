# Dora-SSR test programs

Run these tests through the engine checkout's `xmake test-suite` command. Set
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
xmake test-suite --repo=/path/to/Dora-Example --suite=engine
xmake test-suite --repo=/path/to/Dora-Example --suite=ui
xmake test-suite --repo=/path/to/Dora-Example --suite=studio
xmake test-suite --repo=/path/to/Dora-Example --case=check_ci_test_coverage.test
xmake test-suite --repo=/path/to/Dora-Example --case=test_shutdown_watchdog -- --engine /absolute/path/Dora
xmake test-suite --repo=/path/to/Dora-Example --case=test_http_access_native -- --engine /absolute/path/Dora --require-lan
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
xmake test-suite --repo=/path/to/Dora-Example --suite=native-agent -- --engine /absolute/path/Dora
```

`--dora` remains an alias for `--engine`; both now launch an isolated service.
An occupied port is a prerequisite error; tests never attach to or stop an
existing service. macOS and Linux profile isolation is supported. On headless
Linux, provide Xvfb/Mesa and run the command under `xvfb-run -a`.
These cases remain explicit native acceptance, outside the lightweight CI suites;
no full engine build or graphical environment is added to ordinary Engine Tests.

Godot integration tests, fixtures, source audits and manual acceptance tools live in
[`Godot/`](Godot/README.md); the original Metal probe is in `LibGodotMetalProbe/`.
Run `xmake test-suite --repo=/path/to/Dora-Example --suite=godot-contract` from
the engine root. Native test-host builds use `DORA_TEST_REPO` or
`--dora_test_repo=/path/to/Dora-Example`; normal runtime builds need no test checkout.

IME and Agent input regressions live in `WebIDE/test-ime-input.mjs` (included in
UI CI) and `WebIDE/test-agent-input-browser.mjs` (explicit browser acceptance).
The browser case uses disposable Chrome profiles and synthetic composition/key
events; it does not require an engine service or call an LLM. Set
`DORA_TEST_CHROME` if Chrome/Chromium is not at a standard install path. Reports
and screenshots are written to the engine's `build/agent-input-qa/` directory.
It covers draft clearing during delayed responses, failure without draft
restoration, continued typing, attachments, and immediate message-editor closure
on resend. System IME acceptance remains a separate manual check.

```sh
xmake test-suite --repo=/path/to/Dora-Example --suite=ui --case=test-ime-input
xmake test-suite --repo=/path/to/Dora-Example --suite=web-ide --case=test-agent-input-browser
```
