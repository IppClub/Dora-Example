// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include "VideoBufferPolicy.inc"
#include <iostream>
#include <stdexcept>
void check(bool value){if(!value)throw std::runtime_error("video buffer limit failed");}
int main(){
 try {
  check(bufferedFrameLimit(1920,1080,30)==4);
  check(bufferedFrameLimit(3840,2160,30)==1);
  check(bufferedFrameLimit(480,204,24)==48);
  for(size_t width:{size_t(16),size_t(64),size_t(1280),size_t(1920),size_t(3840)})
   for(size_t height:{size_t(16),size_t(64),size_t(720),size_t(1080),size_t(2160)})
    for(double rate:{1.,24.,30.,60.,240.}) {
     auto frames=bufferedFrameLimit(width,height,rate);auto bytes=width*height*4;
     check(frames>=1 && frames<=240 && frames<=std::ceil(rate*2));
     check(frames*bytes<=MaxBufferedBytes || frames==1);
    }
  check(bufferedFrameLimit(7680,4320,30)==1); // One oversized frame remains playable.
  check(bufferedFrameLimit(0,1080,30)==0);
  check(bufferedFrameLimit(1920,0,30)==0);
  check(bufferedFrameLimit(1920,1080,std::numeric_limits<double>::quiet_NaN())==0);
  check(bufferedFrameLimit(std::numeric_limits<size_t>::max(),2,30)==0);
  std::cout<<"VIDEO_BUFFER_PASS 1080p="<<bufferedFrameLimit(1920,1080,30)*1920*1080*4<<" bytes; 4K=1 frame; time/byte/overflow limits\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
