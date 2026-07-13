#!/usr/bin/env zsh
# Engine-side Jolt integration suite. Each case stages its own game and asserts
# public Dora APIs rather than linking directly to the native Jolt bridge.

set -euo pipefail

SCRIPT_DIR=${0:A:h}
for test in \
	run-physics-3d.zsh \
	run-character-controller.zsh \
	run-compound-shape.zsh \
	run-mesh-collider.zsh \
	run-convex-hull.zsh \
	run-constraint-3d.zsh \
	run-jolt-lifecycle-regression.zsh; do
	print "==> ${test}"
	"${SCRIPT_DIR}/${test}"
done

print "JOLT_ENGINE_INTEGRATION_SUMMARY status=PASS"
