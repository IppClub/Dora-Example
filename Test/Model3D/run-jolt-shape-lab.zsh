#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy
SCRIPT_DIR=${0:A:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-test}
source ~/.zshrc >/dev/null 2>&1 || true
if (( $+aliases[dora] )); then DORA_CMD=${aliases[dora]}; else DORA_CMD=dora; fi
run_dora() { eval "${DORA_CMD} \"\$@\""; }
source "${SCRIPT_DIR}/runner-common.zsh"
close_external_web_ide_tabs
pkill -x Dora >/dev/null 2>&1 || true
run_dora cli doctor --fix
sleep 2
run_dora cli build -f "${SCRIPT_DIR}/JoltShapeLab3D.ts"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/Test/Model3D"
stage_physics_body_3d
rsync -a "${SCRIPT_DIR}/Assets/" "${STAGE}/Test/Model3D/Assets/"
cp "${SCRIPT_DIR}/JoltShapeLab3D.lua" "${STAGE}/init.lua"
run_dora cli run -p "${STAGE}"
