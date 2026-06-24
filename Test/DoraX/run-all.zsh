#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
PROJECT=${PROJECT:-${SCRIPT_DIR:h:h}}
MARKER_ROOT=${MARKER_ROOT:-${PROJECT:h}}

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

for file in "${SCRIPT_DIR}"/*.tsx; do
	run_dora cli build -f "${file}"
done

for file in "${SCRIPT_DIR}"/*Test.tsx; do
	test_name=${file:t:r}
	marker="${MARKER_ROOT}/DoraX${test_name}.result"
	log_file="/tmp/dorax_${test_name}.run.log"
	rm -f "${marker}" "${log_file}"
	run_dora cli stop -p "${PROJECT}" >/dev/null 2>&1 || true
	print "== ${test_name} =="
	run_dora cli run -p "${PROJECT}" --entry "Test/DoraX/${test_name}.lua" >"${log_file}" 2>&1
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
