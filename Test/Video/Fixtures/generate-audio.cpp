// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
// Generate an original 440 Hz stereo tone with libvorbis/libogg.
#include <vorbis/vorbisenc.h>
#include <ogg/ogg.h>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <stdexcept>
int main(int argc, char** argv) {
 if (argc != 2) return 1;
 std::ofstream file(argv[1], std::ios::binary);
 vorbis_info info; vorbis_info_init(&info);
 if (vorbis_encode_init_vbr(&info, 2, 44100, .3f) != 0) return 1;
 vorbis_comment comment; vorbis_comment_init(&comment);
 vorbis_dsp_state dsp; vorbis_analysis_init(&dsp, &info);
 vorbis_block block; vorbis_block_init(&dsp, &block);
 ogg_stream_state stream; ogg_stream_init(&stream, 81724);
 ogg_packet first, second, third, packet;
 vorbis_analysis_headerout(&dsp, &comment, &first, &second, &third);
 ogg_stream_packetin(&stream, &first);
 ogg_stream_packetin(&stream, &second);
 ogg_stream_packetin(&stream, &third);
 ogg_page page;
 auto write = [&](bool flush) {
  while (flush ? ogg_stream_flush(&stream, &page) : ogg_stream_pageout(&stream, &page)) {
   file.write(reinterpret_cast<char*>(page.header), page.header_len);
   file.write(reinterpret_cast<char*>(page.body), page.body_len);
   if (!file) throw std::runtime_error("fixture write failed");
  }
 };
 write(true);
 constexpr int total = 55125;
 for (int position = 0;;) {
  const int count = std::min(1024, total-position);
  float** buffer = vorbis_analysis_buffer(&dsp, count);
  for (int i = 0; i < count; ++i)
   buffer[0][i] = buffer[1][i] = .25f * std::sin(2*3.141592653589793*440*(position+i)/44100);
  vorbis_analysis_wrote(&dsp, count);
  while (vorbis_analysis_blockout(&dsp, &block) == 1) {
   vorbis_analysis(&block, nullptr); vorbis_bitrate_addblock(&block);
   while (vorbis_bitrate_flushpacket(&dsp, &packet)) {
    ogg_stream_packetin(&stream, &packet); write(false);
   }
  }
  if (count == 0) break;
  position += count;
 }
 write(true);
 ogg_stream_clear(&stream); vorbis_block_clear(&block); vorbis_dsp_clear(&dsp);
 vorbis_comment_clear(&comment); vorbis_info_clear(&info);
}
