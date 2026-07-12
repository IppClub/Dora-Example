close_external_web_ide_tabs() {
	local script_dir=${0:A:h}
	osascript "${script_dir}/close-web-ide-tabs.applescript" >/dev/null 2>&1 || true
}
