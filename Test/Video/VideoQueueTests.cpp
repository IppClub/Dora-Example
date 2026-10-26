// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#include "AudioExtraction.h"
#include "theora/theoradec.h"
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <deque>
#include <fstream>
#include <iostream>
#include <limits>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>

namespace {
void check(bool value, const char* message) {
 if (!value) throw std::runtime_error(message);
}
template<class T, class U> T s_cast(U value) { return static_cast<T>(value); }
struct String : std::string {
 using std::string::string;
 std::string toString() const { return *this; }
};
struct VideoDataImpl { virtual ~VideoDataImpl() = default; };
// Only the Content file read is replaced; the complete VideoData state machine
// and queue are compiled from the production source below.
struct Content {
 auto load(const String& name) {
  std::ifstream file(name, std::ios::binary | std::ios::ate);
  size_t size = file ? size_t(file.tellg()) : 0;
  auto bytes = std::make_unique<uint8_t[]>(size);
  file.seekg(0);
  file.read(reinterpret_cast<char*>(bytes.get()), size);
  return std::make_pair(std::move(bytes), size);
 }
} SharedContent;
namespace AudioDetail = Dora::AudioDetail;
#include "VideoBufferPolicy.inc"
// Expose queue counters only in this isolated harness, never in the engine API.
#define private public
#define Error(...) ((void)0)
#include "VideoData.inc"
#undef Error
#undef private

struct Worker {
 VideoData& video;
 std::thread thread;
 explicit Worker(VideoData& value) : video(value), thread([&value] { value.decode(); }) {}
 ~Worker() { video.stop(); thread.join(); }
};
void boundedQueue() {
 VideoData video;
 check(video.init(String(DORA_VIDEO_FIXTURES "/1080p.ogv")), "1080p fixture failed");
 check(video.maxBufferedFrames == 4, "1080p queue limit changed");
 Worker worker(video);
 const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
 size_t bytes = 0;
 bool full = false;
 while (std::chrono::steady_clock::now() < deadline) {
  {
   std::scoped_lock lock(video.framesMutex);
   if (video.frames.size() == 4) {
    for (const auto& frame : video.frames) bytes += frame.rgba.size();
    full = true;
    break;
   }
  }
  std::this_thread::yield();
 }
 check(full && bytes == size_t(1920)*1080*4*4 && bytes <= MaxBufferedBytes,
  "decoded RGBA queue exceeded its budget");
 std::this_thread::sleep_for(std::chrono::milliseconds(100));
 std::scoped_lock lock(video.framesMutex);
 check(video.frames.size() == 4, "stalled consumer did not apply backpressure");
}
void timelineAndLoop() {
 VideoData video;
 video.looped = true;
 check(video.init(String(DORA_VIDEO_FIXTURES "/motion.ogv")), "motion fixture failed");
 Worker worker(video);
 const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
 uint64_t cycle = 0;
 size_t frames = 0;
 while (cycle < 2 && std::chrono::steady_clock::now() < deadline) {
  // Consume every frame independently to verify duplicate-image intervals too.
  std::optional<VideoFrame> frame;
  {
   std::scoped_lock lock(video.framesMutex);
   if (!video.frames.empty()) {
    frame = std::move(video.frames.front());
    video.frames.pop_front();
   }
  }
  video.framesChanged.notify_all();
  if (!frame) { std::this_thread::yield(); continue; }
  check(frame->cycle == cycle, "incorrect loop cycle");
  if (frame->rgba.empty()) {
   check(!frame->final && frames == 600 && std::abs(frame->time - 20.0) < 1e-8,
    "loop ended before all frame intervals");
   ++cycle;
   frames = 0;
  } else {
   check(std::abs(frame->time - frames/30.0) < 1e-8, "incorrect frame presentation time");
   ++frames;
  }
 }
 check(cycle == 2, "decoder did not complete two loops");
}
}
int main() {
 try {
  boundedQueue();
  timelineAndLoop();
  std::cout << "VIDEO_QUEUE_PASS 1080p=4 frames/33177600 bytes, backpressure, stop/join, duplicate duration, two loops\n";
 } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
