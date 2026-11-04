# Shader cache program ownership

Run `Test/Godot/test_shader_cache_cleanup.py --output <fresh-directory>` with a C++17 compiler. Use `--cxx` to select the compiler and optional `--baseline-ref ac9882929` to reproduce the pre-fix leak.

The runner compiles the production `_load_from_cache`, `_initialize_version` and `_clear_version` bodies without rewriting them, against serialized cache fixtures and a deterministic GL driver. It checks 13 ownership paths plus 500 repeated failures: current/prior programs are reclaimed on failure, successful programs remain owned by Version until normal teardown, and source compilation/cache saving still occurs after a failed load. Header/version/count failures, truncation, empty entries, allocation failure and transform feedback are covered. The previous source must fail the live-program invariant.

This is a resource ownership regression, not a real GPU or shader binary compatibility test. Generated sources, executables and reports belong in the requested output directory outside the test sources.
