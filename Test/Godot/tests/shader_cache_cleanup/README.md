# Shader cache program ownership

Run `Test/Godot/test_shader_cache_cleanup.py --output <fresh-directory>` with a C++17 compiler. Use `--cxx` to select the compiler and optional `--baseline-ref ac9882929` to reproduce the pre-fix leak.

The runner compiles the production `_load_from_cache`, `_initialize_version` and `_clear_version` bodies without rewriting them, against serialized cache fixtures and a deterministic GL driver. It checks 13 ownership paths plus 500 repeated failures: current/prior programs are reclaimed on failure, successful programs remain owned by Version until normal teardown, and source compilation/cache saving still occurs after a failed load. Header/version/count failures, truncation, empty entries, allocation failure and transform feedback are covered. The previous source must fail the live-program invariant.

This is a resource ownership regression, not a real GPU or shader binary compatibility test. Generated sources, executables and reports belong in the requested output directory outside the test sources.

The saver has a separate `test_shader_cache_binary.py --output <fresh-directory>
--baseline-ref b206381f2` check. It executes the actual `_save_to_cache` body for
full/short/one-byte/zero/negative/oversized returned lengths and zero queried
capacity. The pre-fix negative control fails because it persists queried capacity
instead of the shorter returned payload. This checks binary serialization, not whether a physical driver
or the Android Emulator can restore the binary.

`tests/android/run_warm_cache.py` runs one ordinary Release readback cold/warm
pair with three buffers, requires exact cache hashes across two app processes,
and audits nonempty GLSC binary entries in the dedicated userdebug emulator.
Its optional independent-probe diagnostic cannot turn a strict warm failure into
a pass. It deliberately does not disable caching, ignore failed GL link status,
filter warnings or introduce a disk GLSL/source-cache fallback. The owner must
clean the test packages and stop the emulator after archiving the result.
