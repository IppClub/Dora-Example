#!/bin/bash
# Compatibility launcher for the maintained native-xmake GodotNode integration.
set -euo pipefail
DORA_TEST_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
source "$DORA_TEST_REPO/Test/support/godot-paths.sh"
export DORA_GODOT_NODE_RESULTS="${DORA_GODOT_PROBE_OUTPUT:-$ROOT/build/godot-metal-probe/results}"
export DORA_GODOT_TEST_BUFFERS="${DORA_GODOT_PROBE_BUFFERS:-3}"
exec "$DORA_TEST_REPO/Test/Godot/test_macos.sh" "$@"
