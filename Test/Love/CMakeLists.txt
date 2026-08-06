cmake_minimum_required(VERSION 3.16)
project(DoraLoveTests LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The compatibility fixtures contain UTF-8 Lua source and must compile the
# same way as Dora's Windows target.
if(MSVC)
	add_compile_options(/utf-8)
endif()

set(DORA_SSR_ROOT "" CACHE PATH "Path to the Dora-SSR checkout")
if(NOT DORA_SSR_ROOT AND DEFINED ENV{DORA_SSR_ROOT})
	set(DORA_SSR_ROOT "$ENV{DORA_SSR_ROOT}")
endif()
if(NOT DORA_SSR_ROOT)
	foreach(DORA_SSR_CANDIDATE
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../Dora-SSR"
		"${CMAKE_CURRENT_SOURCE_DIR}/../../../../Dora-SSR")
		if(EXISTS "${DORA_SSR_CANDIDATE}/Source/Love/LoveRuntime.cpp")
			get_filename_component(DORA_SSR_ROOT "${DORA_SSR_CANDIDATE}" ABSOLUTE)
			break()
		endif()
	endforeach()
endif()
if(NOT EXISTS "${DORA_SSR_ROOT}/Source/Love/LoveRuntime.cpp")
	message(FATAL_ERROR "Set DORA_SSR_ROOT to a Dora-SSR checkout containing Source/Love/LoveRuntime.cpp")
endif()

set(DORA_SOURCE_ROOT "${DORA_SSR_ROOT}/Source")
set(DORA_LUA_ROOT "${DORA_SOURCE_ROOT}/3rdParty/Lua")
set(DORA_LOVE_UPSTREAM_ROOT "${DORA_SOURCE_ROOT}/3rdParty/Love")

file(GLOB DORA_LUA55_SOURCES CONFIGURE_DEPENDS "${DORA_LUA_ROOT}/*.c")

add_library(dora_lua55 STATIC ${DORA_LUA55_SOURCES})
target_include_directories(dora_lua55 PUBLIC "${DORA_LUA_ROOT}")
if(APPLE)
	target_compile_definitions(dora_lua55 PRIVATE LUA_USE_MACOSX)
elseif(UNIX)
	target_compile_definitions(dora_lua55 PRIVATE LUA_USE_LINUX)
endif()

set(DORA_ZLIB_ROOT "${DORA_SOURCE_ROOT}/3rdParty/Zip/zlib")
add_library(dora_love_zlib STATIC
	"${DORA_ZLIB_ROOT}/adler32.c"
	"${DORA_ZLIB_ROOT}/compress.c"
	"${DORA_ZLIB_ROOT}/crc32.c"
	"${DORA_ZLIB_ROOT}/deflate.c"
	"${DORA_ZLIB_ROOT}/inffast.c"
	"${DORA_ZLIB_ROOT}/inflate.c"
	"${DORA_ZLIB_ROOT}/inftrees.c"
	"${DORA_ZLIB_ROOT}/trees.c"
	"${DORA_ZLIB_ROOT}/uncompr.c"
	"${DORA_ZLIB_ROOT}/zutil.c"
)
target_include_directories(dora_love_zlib PUBLIC "${DORA_ZLIB_ROOT}")

add_library(dora_love_ogg STATIC
	"${DORA_SOURCE_ROOT}/3rdParty/ogg/OggSources.c"
)
target_include_directories(dora_love_ogg PUBLIC "${DORA_SOURCE_ROOT}/3rdParty")

set(DORA_THEORA_ROOT "${DORA_SOURCE_ROOT}/3rdParty/theora")
add_library(dora_love_theoradec STATIC
	"${DORA_THEORA_ROOT}/TheoraSources.c"
)
target_include_directories(dora_love_theoradec PUBLIC
	"${DORA_SOURCE_ROOT}/3rdParty"
	"${DORA_THEORA_ROOT}/include"
	"${DORA_THEORA_ROOT}/Source"
)
target_link_libraries(dora_love_theoradec PUBLIC dora_love_ogg)

# Standalone tests compile the same curated source list as the xmake `love`
# library. Engine targets consume the xmake artifact instead.
add_library(dora_love_common STATIC
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Object.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/types.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Reference.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Module.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Exception.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/deprecation.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/runtime.cpp"
)
target_compile_definitions(dora_love_common PRIVATE LOVE_PROXY_USERVALUES=5)
target_include_directories(dora_love_common PUBLIC
	"${DORA_LOVE_UPSTREAM_ROOT}/src"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules"
	"${DORA_LUA_ROOT}"
)

add_library(dora_love_runtime STATIC
	"${DORA_SOURCE_ROOT}/Love/LoveRuntime.cpp"
	"${DORA_SOURCE_ROOT}/Love/LoveVideoSources.cpp"
	"${DORA_SOURCE_ROOT}/Love/LoveDataAlgorithms.cpp"
	"${DORA_SOURCE_ROOT}/Love/LoveLZ4.c"
	"${DORA_SOURCE_ROOT}/Love/LoveLZ4HC.c"
	"${DORA_SOURCE_ROOT}/3rdParty/stb/stb.cpp"
)
target_include_directories(dora_love_runtime PUBLIC
	"${DORA_SOURCE_ROOT}"
	"${DORA_LUA_ROOT}"
	"${DORA_LOVE_UPSTREAM_ROOT}/src"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules"
)
target_link_libraries(dora_love_runtime PUBLIC
	dora_lua55
	dora_love_common
	dora_love_zlib
	dora_love_theoradec
)

add_executable(dora_love_runtime_tests LoveRuntimeTests.cpp)
target_link_libraries(dora_love_runtime_tests PRIVATE dora_love_runtime)
target_compile_definitions(dora_love_runtime_tests PRIVATE
	DORA_LOVE_TEST_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/Fixtures"
	DORA_LOVE_TEST_DORA_ROOT="${DORA_SSR_ROOT}"
)

add_executable(dora_soloud_filter_response_tests
	SoLoudFilterResponseTests.cpp
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_fader.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_filter.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/filter/soloud_biquadresonantfilter.cpp"
)
target_include_directories(dora_soloud_filter_response_tests PRIVATE
	"${DORA_SOURCE_ROOT}/3rdParty/soloud"
)
if(WIN32)
	target_compile_definitions(dora_soloud_filter_response_tests PRIVATE NOMINMAX)
endif()

add_executable(dora_soloud_voice_budget_tests
	SoLoudVoiceBudgetTests.cpp
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_audiosource.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_bus.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_3d.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_basicops.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_faderops.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_filterops.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_getters.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_setters.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_voicegroup.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_core_voiceops.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_fader.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_fft.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_fft_lut.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_file.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_filter.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_misc.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_queue.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/soloud/core/soloud_thread.cpp"
)
target_include_directories(dora_soloud_voice_budget_tests PRIVATE
	"${DORA_SOURCE_ROOT}/3rdParty/soloud"
)
target_compile_definitions(dora_soloud_voice_budget_tests PRIVATE WITH_NULL)
if(WIN32)
	target_compile_definitions(dora_soloud_voice_budget_tests PRIVATE NOMINMAX)
endif()

add_executable(dora_playrho_ghost_topology_tests
	PlayRhoGhostTopologyTests.cpp
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/Body.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/ChainShapeConf.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/EdgeShapeConf.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/Manifold.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/MassData.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/ShapeSeparation.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/d2/UnitVec.cpp"
	"${DORA_SOURCE_ROOT}/3rdParty/playrho/Math.cpp"
)
target_include_directories(dora_playrho_ghost_topology_tests PRIVATE
	"${DORA_SOURCE_ROOT}"
	"${DORA_SOURCE_ROOT}/3rdParty"
)

enable_testing()
add_test(NAME dora_love_runtime_tests COMMAND dora_love_runtime_tests)
add_test(NAME dora_playrho_ghost_topology_tests COMMAND dora_playrho_ghost_topology_tests)
add_test(NAME dora_soloud_filter_response_tests COMMAND dora_soloud_filter_response_tests)
add_test(NAME dora_soloud_voice_budget_tests COMMAND dora_soloud_voice_budget_tests)

find_program(DORA_NODE_EXECUTABLE node)
if(DORA_NODE_EXECUTABLE)
	add_test(NAME dora_love_license_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/LicenseAudit.mjs")
	add_test(NAME dora_love_api_parity
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/LoveApiParityTests.mjs")
	add_test(NAME dora_love_progress_consistency_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/ProgressConsistencyAudit.mjs")
	add_test(NAME dora_love_mobile_system_host_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/MobileSystemHostAudit.mjs")
	add_test(NAME dora_love_platform_build_manifest_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/PlatformBuildManifestAudit.mjs")
	add_test(NAME dora_love_upstream_source_subset_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/UpstreamSourceSubsetAudit.mjs")
endif()
