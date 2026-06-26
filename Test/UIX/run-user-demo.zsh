#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
PROJECT=${PROJECT:-${SCRIPT_DIR:h:h}}
SSR_ROOT=${SSR_ROOT:-/Users/Jin/Workspace/Dora-SSR}

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

build_file() {
	local file=$1
	local log_file="/tmp/uix_build_${file:t}.log"
	run_dora cli build -f "${file}" >"${log_file}" 2>&1
	cat "${log_file}"
	if rg -n "\\[error\\] Compiling error" "${log_file}" >/dev/null; then
		exit 1
	fi
}

build_uix_sources() {
	(
		cd "${SSR_ROOT}/Assets/Script/Lib"
		for file in $(find UIX -type f \( -name '*.ts' -o -name '*.tsx' \) | sort); do
			build_file "${file}"
		done
	)
}

build_uix_sources
run_dora cli build -f "${SSR_ROOT}/Assets/Script/Lib/UIX.ts"
run_dora cli build -f "${SCRIPT_DIR}/UserTestDemo.tsx"
run_dora cli stop -p "${PROJECT}" >/dev/null 2>&1 || true
(
	cd "${PROJECT}"
	run_dora cli run --entry "Test/UIX/UserTestDemo.lua"
)
