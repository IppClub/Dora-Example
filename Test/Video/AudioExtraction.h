// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#pragma once
#include "ogg/ogg.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <span>
#include <vector>
namespace Dora {
namespace AudioDetail {
std::vector<uint8_t> extractOggVorbis(std::span<const uint8_t> data);
}
#include "OggAudioExtraction.inc"
}
