#!/usr/bin/env zsh
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy

SCRIPT_DIR=${0:A:h}
STAGE=${DORA_3D_STAGE:-/tmp/dora-3d-test}

source ~/.zshrc >/dev/null 2>&1 || true
if (( $+aliases[dora] )); then
	DORA_CMD=${aliases[dora]}
else
	DORA_CMD=dora
fi

run_dora() {
	eval "${DORA_CMD} \"\$@\""
}

close_web_ide_tabs() {
	osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
if application "Google Chrome" is running then
	tell application "Google Chrome"
		repeat with windowIndex from (count windows) to 1 by -1
			repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
				set tabURL to URL of tab tabIndex of window windowIndex
				if tabURL contains "localhost:8866" or tabURL contains "127.0.0.1:8866" then close tab tabIndex of window windowIndex
			end repeat
		end repeat
	end tell
end if
if application "Microsoft Edge" is running then
	tell application "Microsoft Edge"
		repeat with windowIndex from (count windows) to 1 by -1
			repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
				set tabURL to URL of tab tabIndex of window windowIndex
				if tabURL contains "localhost:8866" or tabURL contains "127.0.0.1:8866" then close tab tabIndex of window windowIndex
			end repeat
		end repeat
	end tell
end if
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
run_dora cli build -f "${SCRIPT_DIR}/Physics3D.ts"
OUTPUT=/tmp/dora-3d-physics
rm -rf "${OUTPUT}" "${STAGE}"
mkdir -p "${STAGE}/Test/Model3D"
rsync -a "${SCRIPT_DIR}/Assets/" "${STAGE}/Test/Model3D/Assets/"
cp "${SCRIPT_DIR}/Physics3D.lua" "${STAGE}/init.lua"
run_dora cli run -p "${STAGE}"

for _ in {1..240}; do
	[[ -f "${OUTPUT}/summary.txt" ]] && break
	sleep 0.5
done

if [[ ! -f "${OUTPUT}/summary.txt" ]]; then
	print -u2 "Physics3D test timed out"
	exit 1
fi

cat "${OUTPUT}/summary.txt"
grep -q '^PHYSICS3D_SUMMARY status=PASS' "${OUTPUT}/summary.txt"
