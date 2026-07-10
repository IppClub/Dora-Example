#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-async-visual}

source ~/.zshrc >/dev/null 2>&1 || true
if (( $+aliases[dora] )); then
	DORA_CMD=${aliases[dora]}
else
	DORA_CMD=dora
fi

run_dora() {
	eval "${DORA_CMD} \"\$@\""
}

pkill -x Dora >/dev/null 2>&1 || true
run_dora cli doctor --fix
sleep 2
run_dora cli build -f "${SCRIPT_DIR}/AsyncLoadVisual.ts"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/Test/Model3D/Assets/Model"
cp "${SCRIPT_DIR}/Assets/Model/DamagedHelmet.glb" "${STAGE}/Test/Model3D/Assets/Model/"
cp "${SCRIPT_DIR}/AsyncLoadVisual.lua" "${STAGE}/init.lua"
run_dora cli run -p "${STAGE}"
