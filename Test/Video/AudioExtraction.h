// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#pragma once
#include "ogg/ogg.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <functional>
#include <span>
#include <vector>
namespace Dora {
namespace AudioDetail {
std::vector<uint8_t> extractOggVorbis(std::span<const uint8_t> data);
std::vector<uint8_t> extractOggVorbis(const std::function<size_t(int64_t, char*, size_t)>& readAt);
}
#include "OggAudioExtraction.inc"
}
