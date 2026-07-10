#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
PROJECT=${PROJECT:-${SCRIPT_DIR:h:h}}

if [[ -z ${DORA_CMD:-} ]]; then
	if [[ -f ~/.zshrc ]]; then
		source ~/.zshrc >/dev/null 2>&1 || true
	fi
	if (( $+aliases[dora] )); then
		DORA_CMD=${aliases[dora]}
	else
		DORA_CMD=dora
	fi
fi

run_dora() {
	eval "${DORA_CMD} \"\$@\""
}

run_dora cli build -f "${SCRIPT_DIR}/PBRViewer.ts"
run_dora cli stop -p "${PROJECT}" >/dev/null 2>&1 || true
run_dora cli run -p "${PROJECT}" --entry "Test/Model3D/PBRViewer.lua"
