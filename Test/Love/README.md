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

## 100-game open-source corpus

`OpenSourceGames.json` pins exactly 100 public Love games by repository, full
Git commit, SPDX license, and entry point. Audit the manifest, prepare a local
corpus, and run it against a live Dora Web IDE with:

```sh
node Test/Love/OpenSourceGameManifestTests.mjs
node Test/Love/PrepareOpenSourceGameCorpus.mjs /tmp/dora-love-corpus
node Test/Love/OpenSourceGameManifestTests.mjs /tmp/dora-love-corpus
node Test/Love/OpenSourceGameCompatibilityWorkflowTests.mjs \
  http://127.0.0.1:8866 /tmp/dora-love-corpus
```

For the isolated Android workflow, package the pinned checkouts and run every
case in a freshly started Dora process:

```sh
node Test/Love/PackageOpenSourceGameCorpus.mjs \
  /tmp/dora-love-corpus /tmp/dora-love-packages
Test/Love/RunAndroidOpenSourceGameCorpus.sh \
  /tmp/dora-love-packages /tmp/android-love-results.tsv emulator-5554
node Test/Love/TransientBufferLifecycleWorkflowTests.mjs \
  http://127.0.0.1:8866
```

The corpus preparation step checks out each exact commit instead of testing a
moving default branch. Game repositories and assets are not vendored here.
Platform run reports under `Results/` record compatibility observations; a
non-pass result is kept as test evidence and must not be silently omitted.
