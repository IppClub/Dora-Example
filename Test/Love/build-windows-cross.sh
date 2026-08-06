#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR="${SCRIPT_DIR}"
BUILD_DIR="${1:-${SOURCE_DIR}/build-zig-windows}"
TOOLCHAIN="${SOURCE_DIR}/Toolchains/ZigWindowsX86.cmake"

if [ -z "${DORA_SSR_ROOT:-}" ]; then
	for candidate in "${SCRIPT_DIR}/../../../Dora-SSR" "${SCRIPT_DIR}/../../../../Dora-SSR"; do
		if [ -f "${candidate}/Source/Love/LoveRuntime.cpp" ]; then
			DORA_SSR_ROOT=$(CDPATH= cd -- "${candidate}" && pwd)
			break
		fi
	done
fi
if [ ! -f "${DORA_SSR_ROOT:-}/Source/Love/LoveRuntime.cpp" ]; then
	echo "set DORA_SSR_ROOT to the Dora-SSR checkout" >&2
	exit 1
fi

command -v zig >/dev/null 2>&1 || {
	echo "zig is required for the Windows x86 cross-build" >&2
	exit 1
}
command -v cmake >/dev/null 2>&1 || {
	echo "cmake is required for the Windows x86 cross-build" >&2
	exit 1
}
command -v ninja >/dev/null 2>&1 || {
	echo "ninja is required for the Windows x86 cross-build" >&2
	exit 1
}

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" -G Ninja \
	-DDORA_SSR_ROOT="${DORA_SSR_ROOT}" \
	-DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}"
cmake --build "${BUILD_DIR}" --parallel

for executable in \
	dora_love_runtime_tests.exe \
	dora_playrho_ghost_topology_tests.exe \
	dora_soloud_filter_response_tests.exe \
	dora_soloud_voice_budget_tests.exe
do
	test -f "${BUILD_DIR}/${executable}" || {
		echo "missing Windows cross-build output: ${executable}" >&2
		exit 1
	}
done

echo "Built Love Windows x86 cross-test executables in ${BUILD_DIR}"
