#!/bin/sh
set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_root=${1:?usage: RunAndroidOpenSourceGameCorpus.sh PACKAGE_ROOT OUTPUT_TSV [ADB_SERIAL] [START] [END]}
output=${2:?usage: RunAndroidOpenSourceGameCorpus.sh PACKAGE_ROOT OUTPUT_TSV [ADB_SERIAL] [START] [END]}
serial=${3:-emulator-5554}
start=${4:-1}
end=${5:-100}
base_url=http://127.0.0.1:8866
android_package=org.ippclub.dorassr

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
: > "$output"

start_app() {
	adb -s "$serial" shell am force-stop "$android_package" >/dev/null 2>&1 || true
	adb -s "$serial" shell monkey -p "$android_package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || return 1
	adb -s "$serial" forward tcp:8866 tcp:8866 >/dev/null || return 1
	attempt=1
	while [ "$attempt" -le 60 ]; do
		if curl -fsS --max-time 2 -X POST "$base_url/status" -H 'Content-Type: application/json' --data '{}' >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
		attempt=$((attempt + 1))
	done
	return 1
}

index=$start
while [ "$index" -le "$end" ]; do
	name=$(jq -r ".[$((index - 1))].name" "$package_root/AndroidCases.json")
	printf 'ANDROID_LOVE_START\t%d\t%s\n' "$index" "$name"
	adb -s "$serial" logcat -c >/dev/null 2>&1 || true
	if ! start_app; then
		printf '%d\t%s\tapp-start-failed\tWeb IDE endpoint unavailable\n' "$index" "$name" >> "$output"
		index=$((index + 1))
		continue
	fi
	case_output=$(mktemp "/tmp/dora-love-android-${index}.XXXXXX")
	if node "$script_dir/AndroidOpenSourceGameCase.mjs" "$base_url" "$package_root" "$index" > "$case_output" 2>&1; then
		result=$(tail -1 "$case_output")
		status=$(printf '%s' "$result" | cut -f2)
		detail=$(printf '%s' "$result" | cut -f3-)
	else
		if adb -s "$serial" shell pidof "$android_package" >/dev/null 2>&1; then
			status=workflow-failed
		else
			status=app-exited
		fi
		detail=$(tr '\n\t' '  ' < "$case_output" | tail -c 500)
	fi
	logcat_output=$(mktemp "/tmp/dora-love-logcat-${index}.XXXXXX")
	adb -s "$serial" logcat -d -v threadtime > "$logcat_output" 2>/dev/null || true
	if rg -q -i 'not enough (space in )?transient|transient buffer for' "$logcat_output"; then
		status=transient-failed
		detail=$(rg -i 'not enough (space in )?transient|transient buffer for' "$logcat_output" | tail -1 | tr '\t' ' ')
	elif [ "$status" = init-failed ] || [ "$status" = runtime-failed ]; then
		love_error=$(rg 'LoveNode \[.*\] .* failed:' "$logcat_output" | tail -1 | sed 's/^[^]]*] //' | tr '\t' ' ')
		if [ -n "$love_error" ]; then
			detail=$love_error
		fi
	fi
	printf '%d\t%s\t%s\t%s\n' "$index" "$name" "$status" "$detail" >> "$output"
	rm -f "$case_output" "$logcat_output"
	printf 'ANDROID_LOVE_DONE\t%d\t%s\n' "$index" "$status"
	index=$((index + 1))
done

printf 'ANDROID_LOVE_COMPLETE\t%s\t%s\t%s\n' "$start" "$end" "$output"
