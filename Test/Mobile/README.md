# Mobile / Go UI tests

This directory contains the tests migrated from Dora-SSR's
`Assets/Script/Dev/Mobile`: TypeScript/TSX/Yue sources, their Lua counterparts,
native UI fixtures, previews, and `*TestRunner.lua` entry points. Production
modules still live in Dora-SSR and retain their `Dev/Mobile/*` imports.
Test modules use `Test/Mobile/*` (or `Test.Mobile.*` in Lua).

## Running tests

Use a matching Dora-SSR checkout/build. Open Dora-Example as the project so its
root is on `Content.searchPaths`; also include the engine's `Assets/Script`
directory when resolving `Dev.Mobile.*`. Existing runners set up the engine
script path. They do not include copies of production UI code.

For a home-shell test through Dora's `/command` endpoint (Yue), add the project
root explicitly without clearing the home shell:

```yue
paths = Content.searchPaths
table.insert paths, "/path/to/Dora-Example"
table.insert paths, Path(Content.assetPath, "Script")
Content.searchPaths = paths
require "Test.Mobile.GamepadTest"
```

Use a fresh engine or clear that test's `package.loaded` entry before rerunning.
Wait for its result file: command submission success is not a test result.

- Model-only smoke tests: `FeedModelTestRunner`, `LightMarkdownTestRunner`,
  `RemixModelTestRunner`. Results are `/tmp/dora-mobile-feed-model.result`,
  `/tmp/dora-mobile-light-markdown.result`, and `/tmp/dora-mobile-remix-model.result`.
- `GamepadTest` and `NavigationTest` run native UI regressions with mock agent
  services and restore the visible UI/window. Results are `/tmp/dora-gamepad.result`
  and `/tmp/dora-navigation.result`. Disconnect Web IDE before running them.
- `UIMode*`, `EntryNavigationTest`, `MobileFeedEntryCacheTest`, and takeover/lifecycle
  tests need the actual home shell; use `/command`, not a project `/run` that clears it.
- Preview tests and some runners intentionally clear system UI or resize the
  window. Integration tests can create temporary projects, write configuration,
  install resources, or use real agent services. Review the individual test before
  running it. This directory is not an unattended run-all suite.

## Keyboard-driven virtual controller

From the Dora-SSR checkout, build macOS Debug and enable the existing development
virtual controller at launch:

```sh
xcodebuild -project Projects/macOS/Dora.xcodeproj -scheme Dora \
  -configuration Debug -derivedDataPath Projects/macOS/build/codex-feed-layout \
  build CODE_SIGNING_ALLOWED=NO
DORA_VIRTUAL_CONTROLLER=1 Projects/macOS/build/codex-feed-layout/Build/Products/Debug/Dora.app/Contents/MacOS/Dora \
  --asset "$PWD/Assets"
```

Arrows/WASD → D-pad; J/K → A/B; U/I → X/Y; Q/E → LB/RB;
Tab or Ctrl → Back; Enter → Start. Ctrl+Enter tests Go's Back+Start exit chord.
This mapping is desktop Debug-only and requires the environment flag; disable it
when testing ordinary text entry. Real handheld/controller QA is separate from
injected-event regression and keyboard-driven SDL virtual-controller testing.
