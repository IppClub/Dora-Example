close_external_web_ide_tabs() {
	local script_dir=${0:A:h}
	osascript "${script_dir}/close-web-ide-tabs.applescript" >/dev/null 2>&1 || true
	pkill -x Dora >/dev/null 2>&1 || true
	for _ in {1..50}; do
		pgrep -x Dora >/dev/null 2>&1 || return 0
		sleep 0.1
	done
	print -u2 "Timed out waiting for the previous Dora process to exit"
	return 1
}

stage_physics_body_3d() {
	cp "${SCRIPT_DIR}/../../PhysicsBody3D.lua" "${STAGE}/PhysicsBody3D.lua"
}
