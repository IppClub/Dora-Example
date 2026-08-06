# Dora Love compatibility tests

This directory owns the regression tests and fixtures for Dora-SSR's embedded
Love 11.5 compatibility layer. The production implementation remains in the
Dora-SSR repository.

Configure and run the native suite with a neighboring Dora-SSR checkout:

```sh
cmake -S Test/Love -B /tmp/dora-love-tests \
  -DDORA_SSR_ROOT=/path/to/Dora-SSR \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/dora-love-tests --parallel
ctest --test-dir /tmp/dora-love-tests --output-on-failure
```

`DORA_SSR_ROOT` may also be provided as an environment variable. The CMake and
Node.js test entrypoints additionally recognize the common layouts where
Dora-Example and Dora-SSR are sibling checkouts or share the same Workspace
parent. Generated build trees must stay outside this directory or under an
ignored `build*` directory.

The `Fixtures` directory is versioned test input, not generated validation
output. Full logs, screenshots, videos, and sanitizer reports belong in CI
artifacts rather than this repository.
