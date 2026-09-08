# Touch callback lifetime regression

`TouchLifetimeTest.cpp` exercises `NodeTouchHandler::handle(SDL_Event)` directly,
including the `TapEnded -> Tapped` sequence behind the Android Feed download
crash. Calling `Node::emit("Tapped")` does not cover this bug.

The test runs 100 rounds of normal tapping and destruction, detachment, or touch
disabling from TapFilter, TapMoved, and TapEnded. It checks subsequent events are
suppressed, the node survives its callback but is released after dispatch, and a
retained stale handler safely rejects queued input. It uses finger events when
enabled and mouse events on desktop builds with mouse-only input.

## macOS native execution

Build Dora Debug first. Compile the test as a bundle with **the same compiler
response file as that engine** (from its Xcode build log):

```sh
clang++ @/absolute/path/to/Dora-common-args.resp \
  -bundle -undefined dynamic_lookup \
  /absolute/path/to/Dora-Example/Test/Mobile/TouchLifetimeTest.cpp \
  -o /tmp/TouchLifetimeTest.so
```

Run the newly built engine, with only one Dora process listening on port 8866.
Execute this Lua in that engine (or the equivalent Yue in its `/command` API):

```lua
local run = assert(package.loadlib("/tmp/TouchLifetimeTest.so", "luaopen_TouchLifetimeTest"))
local result = run()
assert(result == "PASS: 1000 native SDL touch lifetime cases", result)
print(result)
```

Restart the engine or use a new bundle filename after recompiling: dynamic
libraries are cached within a process. The test is synchronous and does not
download projects or change persistent settings. This native desktop regression
does not replace a physical Android swipe/download smoke test.
