// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
// Build with libtheoraenc and libogg, then run: generate OUTPUT WIDTH HEIGHT FRAMES [noise]
#include <theora/theoraenc.h>
#include <ogg/ogg.h>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cassert>
int main(int argc,char**argv) {
 assert(argc>=5);
 unsigned w=std::atoi(argv[2]),h=std::atoi(argv[3]),frames=std::atoi(argv[4]);bool noise=argc>5;
 th_info info;th_info_init(&info);info.frame_width=(w+15)&~15;info.frame_height=(h+15)&~15;
 info.pic_width=w;info.pic_height=h;info.fps_numerator=30;info.fps_denominator=1;
 info.aspect_numerator=1;info.aspect_denominator=1;info.pixel_fmt=TH_PF_420;info.quality=noise?63:40;
 info.keyframe_granule_shift=6;
 auto* encoder=th_encode_alloc(&info);assert(encoder);
 unsigned keyRate=noise?1:64;assert(th_encode_ctl(encoder,TH_ENCCTL_SET_KEYFRAME_FREQUENCY_FORCE,&keyRate,sizeof(keyRate))==0);
 ogg_stream_state stream;assert(ogg_stream_init(&stream,81723)==0);
 FILE* file=std::fopen(argv[1],"wb");assert(file);ogg_page page;
 auto write=[&](bool flush){while(flush?ogg_stream_flush(&stream,&page):ogg_stream_pageout(&stream,&page)) {
  assert(std::fwrite(page.header,1,page.header_len,file)==size_t(page.header_len));
  assert(std::fwrite(page.body,1,page.body_len,file)==size_t(page.body_len));
 }};
 th_comment comment;th_comment_init(&comment);ogg_packet packet;
 while(th_encode_flushheader(encoder,&comment,&packet)>0){ogg_stream_packetin(&stream,&packet);write(true);}
 std::vector<unsigned char> y(info.frame_width*info.frame_height),cb(y.size()/4),cr(y.size()/4);
 th_ycbcr_buffer planes={{int(info.frame_width),int(info.frame_height),int(info.frame_width),y.data()},
  {int(info.frame_width/2),int(info.frame_height/2),int(info.frame_width/2),cb.data()},
  {int(info.frame_width/2),int(info.frame_height/2),int(info.frame_width/2),cr.data()}};
 unsigned rng=941;
 for(unsigned frame=0;frame<frames;++frame){
  const auto motion=(frame>=250 && frame<280)?249:frame;
  for(unsigned row=0;row<info.frame_height;++row)for(unsigned x=0;x<info.frame_width;++x){
   rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;
   y[row*info.frame_width+x]=noise?16+rng%220:16+(x/4+row/3+motion*7)%220;
  }
  std::fill(cb.begin(),cb.end(),128+int(motion%19)-9);std::fill(cr.begin(),cr.end(),128+int(motion%23)-11);
  assert(th_encode_ycbcr_in(encoder,planes)==0);
  while(th_encode_packetout(encoder,frame+1==frames,&packet)>0){ogg_stream_packetin(&stream,&packet);write(false);}
 }
 write(true);std::fclose(file);ogg_stream_clear(&stream);th_encode_free(encoder);th_info_clear(&info);th_comment_clear(&comment);
}
