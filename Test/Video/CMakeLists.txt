cmake_minimum_required(VERSION 3.16)
project(DoraVideoTests LANGUAGES C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(DORA_SSR_ROOT "$ENV{DORA_SSR_ROOT}" CACHE PATH "Dora-SSR source checkout")
if(NOT EXISTS "${DORA_SSR_ROOT}/Source/Node/VideoNode.cpp")
 message(FATAL_ERROR "Set DORA_SSR_ROOT to the engine checkout")
endif()
set(SOURCE "${DORA_SSR_ROOT}/Source")
set(LOVE "${SOURCE}/3rdParty/Love/src")
add_library(video_ogg STATIC "${SOURCE}/3rdParty/ogg/OggSources.c")
target_include_directories(video_ogg PUBLIC "${SOURCE}/3rdParty")
add_library(video_theora STATIC "${SOURCE}/3rdParty/theora/TheoraSources.c")
target_include_directories(video_theora PUBLIC "${SOURCE}/3rdParty/theora/include")
target_link_libraries(video_theora PUBLIC video_ogg)
find_package(Threads REQUIRED)
add_executable(dora_love_video_playback_tests
 VideoPlaybackTests.cpp
 "${SOURCE}/Love/LoveVideoSources.cpp"
 "${LOVE}/common/Object.cpp"
 "${LOVE}/common/types.cpp"
 "${LOVE}/common/Exception.cpp"
)
target_include_directories(dora_love_video_playback_tests PRIVATE "${SOURCE}" "${LOVE}" "${LOVE}/modules")
target_link_libraries(dora_love_video_playback_tests PRIVATE video_theora Threads::Threads)
target_compile_definitions(dora_love_video_playback_tests PRIVATE DORA_VIDEO_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/Fixtures")
function(extract_source INPUT START_MARKER END_MARKER OUTPUT)
 set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${INPUT}")
 file(READ "${INPUT}" CODE)
 string(FIND "${CODE}" "${START_MARKER}" START)
 string(FIND "${CODE}" "${END_MARKER}" END)
 if(START LESS 0 OR END LESS START)
  message(FATAL_ERROR "Could not extract ${OUTPUT} from ${INPUT}")
 endif()
 math(EXPR LENGTH "${END} - ${START}")
 string(SUBSTRING "${CODE}" ${START} ${LENGTH} EXTRACTED)
 file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${OUTPUT}" "${EXTRACTED}")
endfunction()
extract_source("${SOURCE}/Node/VideoNode.cpp" "constexpr size_t MaxBufferedBytes" "\nstruct VideoFrame" VideoBufferPolicy.inc)
add_executable(dora_video_buffer_tests VideoBufferTests.cpp)
target_include_directories(dora_video_buffer_tests PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
# Compile private production implementations for isolated decoder tests. Source
# changes regenerate these includes; no policy/demux implementation is copied.

extract_source("${SOURCE}/Audio/Audio.cpp" "// SoLoud's stb_vorbis" "static void prepareOggAudio" OggAudioExtraction.inc)
extract_source("${SOURCE}/Node/VideoNode.cpp" "struct VideoFrame" "void releaseFrame(" VideoData.inc)
add_executable(dora_video_queue_tests VideoQueueTests.cpp)
target_include_directories(dora_video_queue_tests PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(dora_video_queue_tests PRIVATE video_theora Threads::Threads)
target_compile_definitions(dora_video_queue_tests PRIVATE DORA_VIDEO_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/Fixtures")
set(SOLOUD "${SOURCE}/3rdParty/soloud")
add_executable(dora_ogv_audio_tests AudioPlaybackTests.cpp
 "${SOLOUD}/audiosource/wav/soloud_wavstream.cpp"
 "${SOLOUD}/audiosource/wav/stb_vorbis.c"
 "${SOLOUD}/audiosource/wav/dr_impl.cpp"
 "${SOLOUD}/core/soloud_file.cpp"
 "${SOLOUD}/core/soloud_audiosource.cpp"
 "${SOLOUD}/core/soloud_filter.cpp"
 "${SOLOUD}/core/soloud_fader.cpp"
)
target_include_directories(dora_ogv_audio_tests PRIVATE "${CMAKE_CURRENT_BINARY_DIR}" "${SOLOUD}" "${SOLOUD}/audiosource/wav")
target_compile_definitions(dora_ogv_audio_tests PRIVATE DORA_VIDEO_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/Fixtures")
target_link_libraries(dora_ogv_audio_tests PRIVATE video_ogg)
if(MSVC)
 target_compile_options(dora_love_video_playback_tests PRIVATE /utf-8)
 target_compile_definitions(dora_love_video_playback_tests PRIVATE NOMINMAX)
 target_compile_definitions(dora_video_buffer_tests PRIVATE NOMINMAX)
 target_compile_definitions(dora_video_queue_tests PRIVATE NOMINMAX)
 target_compile_definitions(dora_ogv_audio_tests PRIVATE NOMINMAX)
endif()
enable_testing()
add_test(NAME dora_love_video_playback_tests COMMAND dora_love_video_playback_tests)
set_tests_properties(dora_love_video_playback_tests PROPERTIES TIMEOUT 15)
add_test(NAME dora_video_buffer_tests COMMAND dora_video_buffer_tests)

add_test(NAME dora_video_queue_tests COMMAND dora_video_queue_tests)
add_test(NAME dora_ogv_audio_tests COMMAND dora_ogv_audio_tests)
set_tests_properties(dora_video_queue_tests dora_ogv_audio_tests PROPERTIES TIMEOUT 15)

extract_source("${SOURCE}/Node/VideoNode.cpp" "void VideoNode::pause()" "VideoNode::UpdateFlag VideoNode::updateTexture" VideoControls.inc)
extract_source("${SOURCE}/Node/VideoNode.cpp" "bool VideoNode::beginPlayback()" "NS_DORA_END" VideoUpdate.inc)
add_executable(dora_video_controls_tests VideoControlsTests.cpp)
target_include_directories(dora_video_controls_tests PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(dora_video_controls_tests PRIVATE video_theora Threads::Threads)
target_compile_definitions(dora_video_controls_tests PRIVATE DORA_VIDEO_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/Fixtures")
if(MSVC)
 target_compile_definitions(dora_video_controls_tests PRIVATE NOMINMAX)
endif()
add_test(NAME dora_video_controls_tests COMMAND dora_video_controls_tests)
set_tests_properties(dora_video_controls_tests PROPERTIES TIMEOUT 30)
