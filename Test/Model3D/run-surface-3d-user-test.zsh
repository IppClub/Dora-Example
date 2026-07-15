#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}

source ~/.zshrc >/dev/null 2>&1 || true
if (( $+aliases[dora] )); then
	DORA_CMD=${aliases[dora]}
else
	DORA_CMD=dora
fi

run_dora() {
	eval "${DORA_CMD} \"\$@\""
}

source "${SCRIPT_DIR}/runner-common.zsh"
close_external_web_ide_tabs
run_dora cli doctor --fix
sleep 2
run_dora cli build -f "${SCRIPT_DIR}/Surface3DUserTest.ts"
run_dora cli run -p "${SCRIPT_DIR}/../.." --entry Test/Model3D/Surface3DUserTest.lua

print "Surface3D user test started. Check the in-engine panel:"
print "  1. Direct DrawNode uses the direct backend and respects the two ducks' depth."
print "  2. Dynamic ClipNode shows a circularly clipped red fill and uses texture."
print "  3. Generic Node and Grabber switch to texture without a full-screen proxy."
print "  4. Screen/Y axis billboard keep facing the camera after Rotate +/-30 deg."
print "  5. Write depth stays visible when toggled; Backend selection remains PASS."
