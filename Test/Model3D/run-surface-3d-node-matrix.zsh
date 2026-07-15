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
run_dora cli build -f "${SCRIPT_DIR}/Surface3DNodeMatrixUserTest.ts"
run_dora cli run -p "${SCRIPT_DIR}/../.." --entry Test/Model3D/Surface3DNodeMatrixUserTest.lua

print "Surface3D 2D-node matrix started."
print "Use Previous/Rebuild/Next or Auto advance to inspect every single-node and tree scenario."
print "Each scenario reports expected/actual backend, resource state, rebuild count, and draw calls."
