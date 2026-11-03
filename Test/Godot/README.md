# Godot integration tests

This directory owns the Godot test hosts, projects, protocol/build regressions,
manual platform acceptance runners, dependency audits and test-package tools
previously kept under Dora-SSR `Tools/Godot`. `paths.json` records their original
locations. Production build/codegen/package tools and required package/SDK
integrity checks remain in Dora-SSR.

From the engine checkout:

```sh
xmake dora-test --repo=/path/to/Dora-Example --suite=godot-contract
xmake dora-test --repo=/path/to/Dora-Example --suite=godot-build
```

The contract suite compiles native protocol fixtures and checks package integrity
and build dispatch. The build suite inspects manifests, configures the standalone
xmake graph and checks codegen; it does not rebuild every Godot runtime or claim
GPU acceptance. Manual runners retain their required arguments and acceptance
thresholds. List cases with `xmake dora-test --repo=/path/to/Dora-Example --list`.

For individual scripts set both roots explicitly:

```sh
export DORA_ENGINE_ROOT=/path/to/Dora-SSR
export DORA_TEST_REPO=/path/to/Dora-Example
python3 "$DORA_TEST_REPO/Test/Godot/tests/runtime_abi.py" --help
```

Build native Godot test hosts with `DORA_TEST_REPO` set, or pass
`--dora_test_repo=/path/to/Dora-Example` during xmake configuration. Normal Dora
and standalone LibGodot builds do not fetch tests. C++/Objective-C++ test sources
are selected from this checkout only when their opt-in build flags are enabled.
CI resolves one immutable Dora-Example revision before invoking these runners.

Disposable Windows/Android bundles include the path resolver and test inventory;
their launchers point both roots at the extracted bundle. Keep GPU, physical
hardware and software/VM acceptance boundaries separate from build results.
