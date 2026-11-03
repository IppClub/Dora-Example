// Copyright (c) 2026 Dora SSR contributors. MIT license (see repository LICENSE).
// Run inside the simulator: macOS cannot dlopen an iOS framework. These calls
// deliberately reject all configurations before creating Godot or GPU state.
#include "GodotBridge.h"
#include "GodotBridgeAudio.h"
#include "GodotBridgeIME.h"
#include "GodotBridgeMetalTargets.h"
#include "GodotBridgeOutput.h"
#include "GodotBridgeViewport.h"
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <string>
#include <vector>

static std::vector<std::string> checks;
static void check(bool value, const std::string &name) {
    if (!value) {
        std::fprintf(stderr, "ABI guard failed: %s\n", name.c_str());
        std::exit(2);
    }
    checks.push_back(name);
}

template<class T>
static T table(void *library, const char *name, uint32_t version = 1) {
    using Getter = int (*)(uint32_t, void *);
    auto getter = reinterpret_cast<Getter>(dlsym(library, name));
    check(getter != nullptr, std::string(name) + ": symbol present");
    check(getter(version, nullptr) == 0, std::string(name) + ": null destination");
    const uint32_t versions[] = {0, version + 1, UINT32_MAX, version, version, version};
    const uint32_t sizes[] = {sizeof(T), sizeof(T), sizeof(T), 0, 4, sizeof(T) - 1};
    for (size_t i = 0; i < 6; ++i) {
        alignas(std::max_align_t) unsigned char memory[sizeof(T) + 64];
        std::memset(memory, 0xa5, sizeof(memory));
        std::memcpy(memory, &sizes[i], sizeof(uint32_t));
        unsigned char before[sizeof(memory)];
        std::memcpy(before, memory, sizeof(memory));
        check(getter(versions[i], memory) == 0, std::string(name) + ": invalid version/size " + std::to_string(i));
        check(std::memcmp(memory, before, sizeof(memory)) == 0, std::string(name) + ": rejected destination untouched");
    }
    alignas(std::max_align_t) unsigned char memory[sizeof(T) + 64];
    std::memset(memory, 0xa5, sizeof(memory));
    const uint32_t size = sizeof(memory);
    std::memcpy(memory, &size, sizeof(size));
    check(getter(version, memory) == 1, std::string(name) + ": extended destination accepted");
    bool tail = true;
    for (size_t i = sizeof(T); i < sizeof(memory); ++i) tail &= memory[i] == 0xa5;
    check(tail, std::string(name) + ": trailing canary preserved");
    T result;
    std::memcpy(&result, memory, sizeof(result));
    check(result.size == sizeof(T) && result.abi_version == version, std::string(name) + ": prefix size/version");
    bool complete = true;
    for (size_t i = 8; i < sizeof(T); i += sizeof(void *)) {
        uintptr_t pointer = 0;
        std::memcpy(&pointer, memory + i, sizeof(pointer));
        complete &= pointer != 0;
    }
    check(complete, std::string(name) + ": complete function table");
    return result;
}

static DoraGodotConfig config() {
    return {sizeof(DoraGodotConfig), DORA_GODOT_METAL, 640, 360, 3, ".", "", reinterpret_cast<void *>(1)};
}
static std::string quoted(const std::string &text) {
    std::string out = "\"";
    for (char c : text) {
        if (c == '"' || c == '\\') out += '\\';
        out += c;
    }
    return out + '"';
}

int main(int argc, char **argv) {
    if (argc != 2) return 64;
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        std::fprintf(stderr, "%s\n", dlerror());
        return 2;
    }
    const auto api = table<DoraGodotAPI>(library, "dora_godot_get_api");
    const char *version = api.version();
    check(version && std::strstr(version, "Godot 4.6-stable / Dora bridge") == version, "runtime version");
    check(!api.open(nullptr), "null config rejected");
    for (int i = 0; i < 13; ++i) {
        auto c = config();
        switch (i) {
            case 0: c.size = 0; break;
            case 1: c.size = sizeof(c) - 1; break;
            case 2: c.backend = 99; break;
            case 3: c.width = 0; break;
            case 4: c.height = 0; break;
            case 5: c.width = 8193; break;
            case 6: c.height = 8193; break;
            case 7: c.buffer_count = 0; break;
            case 8: c.buffer_count = 1; break;
            case 9: c.buffer_count = 5; break;
            case 10: c.project_path = nullptr; break;
            case 11: c.project_path = ""; break;
            case 12: c.native_device = nullptr; break;
        }
        check(!api.open(&c), "invalid configuration " + std::to_string(i));
        check(std::strstr(api.last_error(nullptr), "configuration") != nullptr, "configuration diagnostic");
    }
    const auto audio = table<DoraGodotAudioAPI>(library, "dora_godot_get_audio_api", 2);
    const auto targets = table<DoraGodotMetalTargetsAPI>(library, "dora_godot_get_metal_targets_api");
    const auto viewport = table<DoraGodotViewportAPI>(library, "dora_godot_get_viewport_api");
    const auto output = table<DoraGodotOutputAPI>(library, "dora_godot_get_output_api");
    const auto ime = table<DoraGodotIMEAPI>(library, "dora_godot_get_ime_api");
    for (uintptr_t value : {uintptr_t(0), uintptr_t(1)}) {
        auto handle = reinterpret_cast<void *>(value);
        check(api.get_slot(handle, 0, nullptr) == 0, "invalid handle get_slot");
        check(api.advance(handle, 0, 0) == 0, "invalid handle advance");
        check(api.input(handle, nullptr) == 0, "invalid handle input");
        check(api.set_paused(handle, 1) == 0, "invalid handle pause");
        check(api.restart_scene(handle, "res://main.tscn") == 0, "invalid handle restart");
        alignas(std::max_align_t) unsigned char memory[80], before[80];
        const auto reset = [&](uint32_t size) {
            std::memset(memory, 0xa5, sizeof(memory));
            std::memcpy(memory, &size, sizeof(size));
            std::memcpy(before, memory, sizeof(memory));
        };
        const auto untouched = [&] { return std::memcmp(memory, before, sizeof(memory)) == 0; };
        reset(64);
        api.close(handle, reinterpret_cast<DoraGodotStats *>(memory));
        check(untouched(), "invalid close leaves stats untouched");
        check(audio.start_capture(handle) == 0, "invalid audio start handle");
        check(audio.get_stats(handle, reinterpret_cast<DoraGodotAudioStats *>(memory)) == 0, "invalid audio stats handle");
        check(untouched(), "rejected audio stats untouched");
        check(audio.get_format(handle, reinterpret_cast<DoraGodotAudioFormat *>(memory)) == 0, "invalid audio format handle");
        check(untouched(), "rejected audio format untouched");
        for (uint32_t frames : {0u, 1u, 4096u, 4097u, UINT32_MAX}) {
            check(audio.read_pcm(handle, reinterpret_cast<float *>(memory), frames) == 0, "invalid audio PCM handle");
            check(untouched(), "rejected audio PCM untouched");
        }
        check(audio.read_pcm(handle, nullptr, 1) == 0, "null PCM destination rejected");
        for (uint32_t count : {0u, 2u, 3u, 4u, 5u, UINT32_MAX}) {
            check(targets.bind(handle, 640, 360, nullptr, count) == 0, "invalid Metal targets rejected");
        }
        const uint32_t dimensions[][2] = {{640, 360}, {0, 360}, {640, 0}, {8193, 360}, {640, 8193}, {UINT32_MAX, 1}};
        for (const auto &size : dimensions) {
            check(viewport.resize(handle, size[0], size[1]) == 0, "invalid viewport rejected");
        }
        reset(sizeof(DoraGodotOutputSize));
        check(output.get_size(handle, reinterpret_cast<DoraGodotOutputSize *>(memory)) == 0, "invalid output handle");
        check(untouched(), "rejected output size untouched");
        check(output.get_size(handle, nullptr) == 0, "null output destination");
        reset(sizeof(DoraGodotIMEState));
        check(ime.get_state(handle, reinterpret_cast<DoraGodotIMEState *>(memory)) == 0, "invalid IME handle");
        check(untouched(), "rejected IME state untouched");
        check(ime.get_state(handle, nullptr) == 0, "null IME destination");
    }
    api.shutdown();
    api.shutdown();
    const auto c = config();
    check(!api.open(&c), "open after shutdown rejected before native device use");
    check(std::strstr(api.last_error(nullptr), "terminated") != nullptr, "post-shutdown diagnostic");
    std::printf("DORA_IOS_ABI_JSON {\"passed\":true,\"gpu_tested\":false,\"checks\":[");
    for (size_t i = 0; i < checks.size(); ++i) std::printf("%s%s", i ? "," : "", quoted(checks[i]).c_str());
    std::printf("],\"runtime_version\":%s,\"pointer_bits\":%zu}\n", quoted(version).c_str(), sizeof(void *) * 8);
    // Process exit owns unloading; this test never attempts LibGodot reinit.
    return 0;
}
