#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
RESULT=${DORA_3D_SURFACE_RESULT:-/tmp/dora-3d-surface-result.txt}

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
run_dora cli build -f "${SCRIPT_DIR}/Surface3DRegression.ts"
rm -f "${RESULT}"
run_dora cli run -p "${SCRIPT_DIR}/../.." --entry Test/Model3D/Surface3DRegression.lua

for _ in {1..60}; do
	[[ -f "${RESULT}" ]] && break
	sleep 0.5
done

if [[ ! -f "${RESULT}" ]]; then
	print -u2 "Surface3D regression timed out"
	run_dora cli log -n 100 || true
	exit 1
fi

cat "${RESULT}"
grep -q '^SURFACE_3D_SUMMARY status=PASS' "${RESULT}"
