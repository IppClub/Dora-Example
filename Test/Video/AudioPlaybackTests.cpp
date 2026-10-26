// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#include "AudioExtraction.h"
#include "soloud.h"
#include "soloud_wavstream.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <random>
#include <stdexcept>
// The decoder test never attaches a mixer.
namespace SoLoud { void Soloud::stopAudioSource(AudioSource&) {} }
namespace {
void check(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
std::vector<uint8_t> load(const char* path) {
 std::ifstream file(path, std::ios::binary);
 check(bool(file), "missing audio fixture");
 return {std::istreambuf_iterator<char>(file), {}};
}
std::vector<std::vector<uint8_t>> pages(const std::vector<uint8_t>& data) {
 std::vector<std::vector<uint8_t>> result;
 size_t offset = 0;
 while (offset < data.size()) {
  check(data.size()-offset >= 27, "short Ogg page header");
  size_t length = 27 + data[offset+26];
  check(length <= data.size()-offset, "short lacing table");
  for (size_t i = 0; i < data[offset+26]; ++i) length += data[offset+27+i];
  check(length <= data.size()-offset, "short Ogg body");
  result.emplace_back(data.begin()+offset, data.begin()+offset+length);
  offset += length;
 }
 return result;
}
void extraction(const std::vector<uint8_t>& audio) {
 const auto video = load(DORA_VIDEO_FIXTURES "/motion.ogv");
 const auto vp = pages(video), ap = pages(audio);
 for (bool audioFirst : {false, true}) {
  std::vector<uint8_t> mux;
  auto append = [&](const auto& page) { mux.insert(mux.end(), page.begin(), page.end()); };
  // Both BOS orders are valid; packet bytes, granules and checksums stay intact.
  if (audioFirst) { append(ap.front()); append(vp.front()); }
  else { append(vp.front()); append(ap.front()); }
  for (size_t i = 1; i < std::max(vp.size(), ap.size()); ++i) {
   if (i < vp.size()) append(vp[i]);
   if (i < ap.size()) append(ap[i]);
  }
  check(Dora::AudioDetail::extractOggVorbis(mux) == audio, "Vorbis pages were altered or lost");
  for (size_t length : {size_t(0), size_t(4), size_t(27), size_t(100)})
   check(Dora::AudioDetail::extractOggVorbis(std::span(mux).first(length)).empty(), "partial headers extracted");
  // Truncate the audio EOS page, not merely an unrelated trailing video page.
  auto tail = mux;
  auto eos = std::find_end(tail.begin(), tail.end(), ap.back().begin(), ap.back().end());
  check(eos != tail.end(), "missing audio EOS page");
  tail.resize(size_t(eos-tail.begin()) + ap.back().size()-1);
  check(Dora::AudioDetail::extractOggVorbis(tail).empty(), "partial audio track extracted");
 }
 check(Dora::AudioDetail::extractOggVorbis(audio).empty(), "plain Ogg audio changed");
 check(Dora::AudioDetail::extractOggVorbis(video).empty(), "silent video acquired audio");
 std::mt19937 random(4242);
 for (int i = 0; i < 500; ++i) {
  std::vector<uint8_t> bytes(random()%20000);
  for (auto& byte : bytes) byte = static_cast<uint8_t>(random());
  if (bytes.size() >= 4) std::memcpy(bytes.data(), "OggS", 4);
  check(Dora::AudioDetail::extractOggVorbis(bytes).empty(), "invalid input extracted");
 }
}
void eof(const std::vector<uint8_t>& audio) {
 SoLoud::WavStream source;
 check(source.loadMem(audio.data(), static_cast<unsigned>(audio.size()), false, false) == 0, "Vorbis load failed");
 // Reproduce the original OGV condition: granule metadata counts samples
 // discarded by the decoder. The real PCM/decoder is unchanged.
 source.mSampleCount += 1024;
 std::unique_ptr<SoLoud::AudioSourceInstance> stream(source.createInstance());
 stream->init(source, 0);
 std::vector<float> buffer(512*source.mChannels);
 auto drain = [&] {
  size_t samples = 0;
  for (int i = 0; i < 20000 && !stream->hasEnded(); ++i) {
   auto count = stream->getAudio(buffer.data(), 512, 512);
   samples += count;
   if (!count) break;
  }
  check(stream->hasEnded() && samples > 0, "Vorbis voice stuck at EOF");
  return samples;
 };
 const auto samples = drain();
 check(samples < source.mSampleCount, "fixture must exercise Vorbis granule/PCM trimming");
 check(stream->rewind() == 0 && !stream->hasEnded(), "rewind did not clear EOF");
 check(drain() == samples, "rewind changed PCM duration");
 check(stream->seek(.25, buffer.data(), static_cast<unsigned>(buffer.size())) == 0 && !stream->hasEnded(), "seek after EOF failed");
 drain();
}
}
int main() {
 try {
  const auto audio = load(DORA_VIDEO_FIXTURES "/tone.ogg");
  extraction(audio); eof(audio);
  std::cout << "OGV_AUDIO_PASS both BOS orders, byte-identical track, plain/silent/truncated/random inputs, Vorbis EOF/rewind/seek\n";
 } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
