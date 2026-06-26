#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
PROJECT=${PROJECT:-${SCRIPT_DIR:h:h}}
MARKER_ROOT=${MARKER_ROOT:-${PROJECT:h}}
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
build_file "${SSR_ROOT}/Assets/Script/Lib/UIX.ts"

for file in "${SCRIPT_DIR}"/*.tsx; do
	build_file "${file}"
done

for file in "${SCRIPT_DIR}"/*Test.tsx; do
	test_name=${file:t:r}
	marker="${MARKER_ROOT}/UIX${test_name}.result"
	log_file="/tmp/uix_${test_name}.run.log"
	rm -f "${marker}" "${log_file}"
	run_dora cli stop -p "${PROJECT}" >/dev/null 2>&1 || true
	print "== ${test_name} =="
	(
		cd "${PROJECT}"
		run_dora cli run --entry "Test/UIX/${test_name}.lua"
	) >"${log_file}" 2>&1
	passed=false
	for _ in {1..100}; do
		if [[ -f "${marker}" ]]; then
			marker_status=$(<"${marker}")
			if [[ "${marker_status}" == "passed" ]]; then
				passed=true
				break
			fi
			if [[ "${marker_status}" != "running" ]]; then
				print "marker=${marker_status}"
				cat "${log_file}"
				exit 1
			fi
		fi
		sleep 0.25
	done
	if [[ "${passed}" != true ]]; then
		print "Timed out waiting for ${marker}"
		[[ -f "${marker}" ]] && print "marker=$(<"${marker}")"
		cat "${log_file}"
		exit 1
	fi
	if rg -n "\\[Warn\\]|Warning|Error|failed|must be placed" "${log_file}" >/dev/null; then
		print "warning in ${test_name}"
		cat "${log_file}"
		exit 1
	fi
	print "passed"
done

run_dora cli stop -p "${PROJECT}" >/dev/null 2>&1 || true
