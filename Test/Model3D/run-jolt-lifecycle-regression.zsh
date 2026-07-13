#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-test}
OUTPUT=${DORA_3D_JOLT_LIFECYCLE_OUTPUT:-/tmp/dora-3d-jolt-lifecycle}

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
pkill -x Dora >/dev/null 2>&1 || true
run_dora cli doctor --fix
sleep 2
run_dora cli build -f "${SCRIPT_DIR}/JoltLifecycleRegression.ts"
rm -rf "${OUTPUT}" "${STAGE}"
mkdir -p "${OUTPUT}" "${STAGE}/Test/Model3D"
rsync -a "${SCRIPT_DIR}/Assets/" "${STAGE}/Test/Model3D/Assets/"
cp "${SCRIPT_DIR}/JoltLifecycleRegression.lua" "${STAGE}/init.lua"
run_dora cli run -p "${STAGE}"

for _ in {1..360}; do
	[[ -f "${OUTPUT}/result.txt" ]] && break
	sleep 0.5
done

if [[ ! -f "${OUTPUT}/result.txt" ]]; then
	print -u2 "Jolt lifecycle regression timed out"
	exit 1
fi

cat "${OUTPUT}/result.txt"
grep -q '^JOLT_LIFECYCLE_SUMMARY status=PASS' "${OUTPUT}/result.txt"
