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
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Matrix.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Data.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/Variant.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/StringMap.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/b64.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/common/pixelformat.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/libraries/lz4/lz4.c"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/libraries/lz4/lz4hc.c"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/libraries/noise1234/noise1234.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/libraries/noise1234/simplexnoise1234.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/BezierCurve.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/wrap_BezierCurve.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/MathModule.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/wrap_Math.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/RandomGenerator.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/wrap_RandomGenerator.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/Transform.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/math/wrap_Transform.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/ByteData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/CompressedData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/Compressor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/DataModule.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/DataView.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/HashFunction.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/wrap_ByteData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/wrap_CompressedData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/wrap_Data.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/wrap_DataModule.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/data/wrap_DataView.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/audio/Filter.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/audio/Source.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/audio/wrap_Source.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/event/Event.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/event/wrap_Event.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/window/Window.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/window/wrap_Window.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/keyboard/Keyboard.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/keyboard/wrap_Keyboard.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/mouse/Cursor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/mouse/wrap_Cursor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/mouse/wrap_Mouse.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/touch/wrap_Touch.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/joystick/Joystick.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/joystick/wrap_Joystick.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/joystick/wrap_JoystickModule.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/Body.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/Contact.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/Fixture.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/Shape.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/Joint.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/World.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_Body.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_Contact.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_Fixture.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_Joint.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_Shape.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/physics/wrap_World.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/File.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/FileData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/Filesystem.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/wrap_File.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/wrap_FileData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/filesystem/wrap_Filesystem.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/GlyphData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/Rasterizer.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/TrueTypeRasterizer.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/wrap_Font.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/wrap_GlyphData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/font/wrap_Rasterizer.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Drawable.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/vertex.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Font.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Shader.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Text.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Video.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Mesh.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/SpriteBatch.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/ParticleSystem.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/depthstencil.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Texture.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Canvas.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Canvas.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsCanvasConstructor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Image.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/Quad.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Texture.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsDraw.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsDisplayState.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsCapabilities.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsInfo.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsImageConstructor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsScreenshot.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsFontState.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsFontConstructor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsPrimitives.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsPrint.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsQuad.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsShaderConstructor.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsState.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_GraphicsShaderState.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Image.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Font.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Shader.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Text.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Video.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Mesh.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_SpriteBatch.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_ParticleSystem.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/graphics/wrap_Quad.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/ImageDataBase.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/CompressedSlice.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/CompressedImageData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/FormatHandler.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/Image.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/ImageData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/wrap_Image.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/wrap_ImageData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/image/wrap_CompressedImageData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/Decoder.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/Sound.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/SoundData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/wrap_Decoder.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/wrap_Sound.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/sound/wrap_SoundData.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/system/System.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/system/wrap_System.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/timer/wrap_Timer.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/thread/Channel.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/thread/LuaThread.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/thread/wrap_Channel.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/thread/wrap_LuaThread.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/thread/wrap_ThreadModule.cpp"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules/video/wrap_VideoStream.cpp"
)
target_compile_definitions(dora_love_common PRIVATE LOVE_PROXY_USERVALUES=5)
target_include_directories(dora_love_common PUBLIC
	"${DORA_LOVE_UPSTREAM_ROOT}/src"
	"${DORA_LOVE_UPSTREAM_ROOT}/src/modules"
	"${DORA_LUA_ROOT}"
	"${DORA_ZLIB_ROOT}"
)

add_library(dora_love_runtime STATIC
	"${DORA_SOURCE_ROOT}/Love/LoveRuntime.cpp"
	"${DORA_SOURCE_ROOT}/Love/LoveVideoSources.cpp"
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
	add_test(NAME dora_love_open_source_game_manifest
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/OpenSourceGameManifestTests.mjs")
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
	add_test(NAME dora_love_render_allocation_audit
		COMMAND "${DORA_NODE_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/LoveRenderAllocationAuditTests.mjs")
endif()
