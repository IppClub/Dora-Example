#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-test}
OUTPUT=${DORA_3D_JOLT_PROFILE_OUTPUT:-/tmp/dora-3d-jolt-profile}

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
run_dora cli build -f "${SCRIPT_DIR}/JoltScaleProfile.ts"

rm -rf "${OUTPUT}" "${STAGE}"
mkdir -p "${OUTPUT}" "${STAGE}/Test/Model3D"
cp "${SCRIPT_DIR}/JoltScaleProfile.lua" "${STAGE}/init.lua"
run_dora cli run -p "${STAGE}"

RSS_FILE=${OUTPUT}/rss.tsv
DORA_PID=$(pgrep -x Dora | tail -1 || true)
RSS_SAMPLER_PID=
if [[ -n ${DORA_PID} ]]; then
	(
		while kill -0 "${DORA_PID}" 2>/dev/null; do
			rss=$(ps -o rss= -p "${DORA_PID}" | tr -d ' ')
			phase=$(cat "${OUTPUT}/phase.txt" 2>/dev/null || print startup)
			[[ -n ${rss} ]] && print "${rss}\t${phase}" >> "${RSS_FILE}"
			sleep 0.25
		done
	) &
	RSS_SAMPLER_PID=$!
fi

for _ in {1..900}; do
	[[ -f "${OUTPUT}/result.txt" ]] && break
	sleep 0.5
done

if [[ ! -f "${OUTPUT}/result.txt" ]]; then
	[[ -n ${RSS_SAMPLER_PID} ]] && kill "${RSS_SAMPLER_PID}" 2>/dev/null || true
	print -u2 "Jolt scale profile timed out"
	exit 1
fi

[[ -n ${RSS_SAMPLER_PID} ]] && wait "${RSS_SAMPLER_PID}" || true
if [[ -s ${RSS_FILE} ]]; then
	awk '
		NR == 1 { first = min = max = $1 }
		{
			if ($1 < min) min = $1
			if ($1 > max) max = $1
			last = $1
		}
		END {
			printf "JOLT_PROFILE_RSS samples=%d firstKB=%d minKB=%d maxKB=%d lastKB=%d deltaKB=%d\n", NR, first, min, max, last, last - first
		}
	' "${RSS_FILE}" | tee "${OUTPUT}/rss-summary.txt"
fi

cat "${OUTPUT}/result.txt"
grep -q '^JOLT_PROFILE_SUMMARY status=PASS' "${OUTPUT}/result.txt"
