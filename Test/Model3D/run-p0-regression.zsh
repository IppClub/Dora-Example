#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
PROJECT=${SCRIPT_DIR:h:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-test}
OUTPUT=${DORA_3D_OUTPUT:-/tmp/dora-3d-p0}
BACKEND=${DORA_3D_BACKEND:-metal}
BASELINE=${SCRIPT_DIR}/Baselines/${BACKEND}
UPDATE_BASELINE=0
if [[ ${1:-} == "--update-baseline" ]]; then
	UPDATE_BASELINE=1
fi

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

close_web_ide_tabs() {
	osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
repeat with appName in {"Google Chrome", "Microsoft Edge"}
	if application appName is running then
		using terms from application "Google Chrome"
			tell application appName
				repeat with windowIndex from (count windows) to 1 by -1
					repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
						set tabURL to URL of tab tabIndex of window windowIndex
						if tabURL contains "localhost:8866" or tabURL contains "127.0.0.1:8866" then close tab tabIndex of window windowIndex
					end repeat
				end repeat
			end tell
		end using terms from
	end if
end repeat
if application "Safari" is running then
	tell application "Safari"
		repeat with windowIndex from (count windows) to 1 by -1
			repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
				set tabURL to URL of tab tabIndex of window windowIndex
				if tabURL contains "localhost:8866" or tabURL contains "127.0.0.1:8866" then close tab tabIndex of window windowIndex
			end repeat
		end repeat
	end tell
end if
APPLESCRIPT
}

close_web_ide_tabs
pkill -x Dora >/dev/null 2>&1 || true
run_dora cli doctor --fix
sleep 2
run_dora cli build -f "${SCRIPT_DIR}/P0Regression.ts"

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}" "${STAGE}/Test/Model3D"
rsync -a --delete "${SCRIPT_DIR}/Assets/" "${STAGE}/Test/Model3D/Assets/"
cp "${SCRIPT_DIR}/P0Regression.lua" "${STAGE}/init.lua"

run_dora cli stop -p "${STAGE}" >/dev/null 2>&1 || true
run_dora cli run -p "${STAGE}"

RSS_FILE=${OUTPUT}/rss.tsv
RSS_SUMMARY=${OUTPUT}/rss-summary.txt
DORA_PID=$(pgrep -x Dora | head -1 || true)
RSS_SAMPLER_PID=
if [[ -n ${DORA_PID} ]]; then
	(
		while kill -0 "${DORA_PID}" 2>/dev/null; do
			rss=$(ps -o rss= -p "${DORA_PID}" | tr -d ' ')
			elapsed=$(ps -o etime= -p "${DORA_PID}" | tr -d ' ')
			phase=cases
			if [[ -f "${OUTPUT}/stress-end" ]]; then
				phase=post
			elif [[ -f "${OUTPUT}/stress-start" ]]; then
				phase=stress
			fi
			[[ -n ${rss} ]] && printf '%s\t%s\t%s\n' "${elapsed}" "${rss}" "${phase}" >> "${RSS_FILE}"
			sleep 0.5
		done
	) &
	RSS_SAMPLER_PID=$!
fi

for _ in {1..360}; do
	if [[ -f "${OUTPUT}/result.txt" ]]; then
		break
	fi
	sleep 0.5
done

if [[ ! -f "${OUTPUT}/result.txt" ]]; then
	[[ -n ${RSS_SAMPLER_PID} ]] && kill "${RSS_SAMPLER_PID}" 2>/dev/null || true
	print -u2 "P0 regression timed out waiting for ${OUTPUT}/result.txt"
	exit 1
fi

if [[ -n ${RSS_SAMPLER_PID} ]]; then
	wait "${RSS_SAMPLER_PID}" || true
fi

if [[ -s ${RSS_FILE} ]]; then
	awk '
		NR == 1 { first = min = max = $2 }
		{
			if ($2 < min) min = $2
			if ($2 > max) max = $2
			last = $2
			if ($3 == "stress") {
				stressCount++
				if (stressCount == 1) stressFirst = stressMin = stressMax = $2
				if ($2 < stressMin) stressMin = $2
				if ($2 > stressMax) stressMax = $2
				stressLast = $2
			}
		}
		END {
			printf "P0_RSS samples=%d firstKB=%d minKB=%d maxKB=%d lastKB=%d deltaKB=%d", NR, first, min, max, last, last - first
			if (stressCount > 0) {
				printf " stressSamples=%d stressFirstKB=%d stressMinKB=%d stressMaxKB=%d stressLastKB=%d stressDeltaKB=%d", stressCount, stressFirst, stressMin, stressMax, stressLast, stressLast - stressFirst
			}
			printf "\n"
		}
	' "${RSS_FILE}" | tee "${RSS_SUMMARY}"
fi

cat "${OUTPUT}/result.txt"
if ! grep -q '^P0_SUMMARY status=PASS ' "${OUTPUT}/result.txt"; then
	exit 1
fi

for input in "${OUTPUT}"/*.tga; do
	[[ -e ${input} ]] || continue
	magick "${input}" "${input:r}.png"
done

if (( UPDATE_BASELINE )); then
	mkdir -p "${BASELINE}"
	cp "${OUTPUT}"/*.png "${BASELINE}/"
	print "P0_BASELINE_UPDATED backend=${BACKEND} path=${BASELINE}"
	exit 0
fi

if [[ ! -d "${BASELINE}" ]]; then
	print "P0_BASELINE_MISSING backend=${BACKEND} path=${BASELINE} hint=run-with---update-baseline"
	exit 0
fi

for actual in "${OUTPUT}"/*.png; do
	name=${actual:t}
	expected=${BASELINE}/${name}
	if [[ ! -f ${expected} ]]; then
		print -u2 "P0_COMPARE_FAIL image=${name} reason=missing_baseline"
		exit 1
	fi
	metric=$(magick compare -metric RMSE "${expected}" "${actual}" null: 2>&1 || true)
	normalized=${${metric##*\(}%\)}
	if (( ${normalized:-1} > 0.05 )); then
		print -u2 "P0_COMPARE_FAIL image=${name} rmse=${normalized} threshold=0.05"
		exit 1
	fi
	print "P0_COMPARE_PASS image=${name} rmse=${normalized}"
done
