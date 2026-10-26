// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#include "modules/video/theora/TheoraVideoStream.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {
void check(bool value, const char* message) { if (!value) throw std::runtime_error(message); }

class MemoryFile final : public love::filesystem::File {
public:
 explicit MemoryFile(std::string data) : bytes(std::move(data)) {}
 bool open(Mode m) override { position=0;return m==MODE_READ; }
 bool close() override { return true; }
 bool isOpen() const override { return true; }
 love::int64 getSize() override { return bytes.size(); }
 love::int64 read(void* dst,love::int64 count) override {
  if(count<=0) return 0;
  auto n=std::min<size_t>(count,bytes.size()-position);
  std::memcpy(dst,bytes.data()+position,n);position+=n;return n;
 }
 bool write(const void*,love::int64) override { return false; }
 bool flush() override { return false; }
 bool isEOF() override { return position==bytes.size(); }
 love::int64 tell() override { return position; }
 bool seek(love::uint64 value) override { if(value>bytes.size())return false;position=value;return true; }
 bool setBuffer(BufferMode,love::int64) override { return true; }
 BufferMode getBuffer(love::int64& size) const override {size=0;return BUFFER_NONE;}
 Mode getMode() const override {return MODE_READ;}
 const std::string& getFilename() const override {return name;}
 std::string bytes;
 size_t position=0;
 std::string name="generated.ogv";
};
using Stream=love::video::theora::TheoraVideoStream;
using Demux=love::video::theora::OggDemuxer;
using Frame=love::video::VideoStream::Frame;
std::string load(const char* name) {
 std::ifstream f(name,std::ios::binary);check(bool(f),"missing fixture");return {std::istreambuf_iterator<char>(f),{}};
}
std::unique_ptr<Stream> stream(const std::string& bytes) {
 auto* file=new MemoryFile(bytes);
 try {auto result=std::make_unique<Stream>(file);file->release();return result;}
 catch(...) {file->release();throw;}
}
uint64_t planeHash(uint64_t hash,const unsigned char* p,int width,int height,int stride) {
 for(int y=0;y<height;++y) for(int x=0;x<width;++x) hash=(hash^p[y*stride+x])*1099511628211ull;
 return hash;
}
uint64_t hash(const Frame& frame) {
 auto h=planeHash(1469598103934665603ull,frame.yplane,frame.yw,frame.yh,frame.yw);
 h=planeHash(h,frame.cbplane,frame.cw,frame.ch,frame.cw);
 return planeHash(h,frame.crplane,frame.cw,frame.ch,frame.cw);
}
struct Reference {std::vector<uint64_t> frames;double fps;};
Reference reference(const std::string& bytes) {
 auto* file=new MemoryFile(bytes);Demux demux(file);file->release();
 check(demux.findStream()==Demux::TYPE_THEORA,"missing Theora stream");
 th_info info;th_info_init(&info);th_comment comment;th_comment_init(&comment);th_setup_info* setup=nullptr;
 ogg_packet packet;int result;
 do {demux.readPacket(packet,true);result=th_decode_headerin(&info,&comment,&setup,&packet);check(result>=0,"bad header");}while(result>0);
 auto* decoder=th_decode_alloc(&info,setup);check(decoder!=nullptr,"decoder allocation");
 th_setup_free(setup);th_comment_clear(&comment);
 Reference ref{{},double(info.fps_numerator)/info.fps_denominator};
 do {
  if(packet.granulepos>=0) th_decode_ctl(decoder,TH_DECCTL_SET_GRANPOS,&packet.granulepos,sizeof(packet.granulepos));
  check(th_decode_packetin(decoder,&packet,nullptr)>=0,"bad reference packet");
  th_ycbcr_buffer planes;check(th_decode_ycbcr_out(decoder,planes)==0,"missing reference frame");
  int sx=info.pixel_fmt==TH_PF_444?0:1,sy=info.pixel_fmt==TH_PF_420?1:0;
  auto h=planeHash(1469598103934665603ull,planes[0].data+info.pic_y*planes[0].stride+info.pic_x,info.pic_width,info.pic_height,planes[0].stride);
  for(int i=1;i<3;++i) h=planeHash(h,planes[i].data+(info.pic_y>>sy)*planes[i].stride+(info.pic_x>>sx),info.pic_width>>sx,info.pic_height>>sy,planes[i].stride);
  ref.frames.push_back(h);
 }while(!demux.readPacket(packet));
 th_decode_free(decoder);th_info_clear(&info);return ref;
}
void matches(Stream& video,const Reference& ref) {
 auto index=std::min<size_t>(size_t(std::max(0.0,video.tell())*ref.fps+1e-7),ref.frames.size()-1);
 auto actual=hash(*static_cast<const Frame*>(video.getFrontBuffer()));
 if(actual!=ref.frames[index]) {
  auto found=std::find(ref.frames.begin(),ref.frames.end(),actual);
  throw std::runtime_error("frame mismatch at "+std::to_string(video.tell())+" expected="+std::to_string(index)+" matched="+std::to_string(found-ref.frames.begin())+" total="+std::to_string(ref.frames.size()));
 }
}
void playbackAndSeeks(const std::string& bytes,size_t expectedFrames) {
 auto ref=reference(bytes);check(ref.frames.size()==expectedFrames,"unexpected fixture frame count");
 auto video=stream(bytes);video->play();video->threadedFillBackBuffer(0);video->swapBuffers();matches(*video,ref);
 const double duration=ref.frames.size()/ref.fps;
 for(int step=0;step<int(std::ceil(duration*240));++step) {
  video->threadedFillBackBuffer(1.0/240);video->swapBuffers();
  if(video->isPlaying())matches(*video,ref);
 }
 // Floating point boundary may need one more worker tick, but not a frame interval.
 if(video->isPlaying()){video->threadedFillBackBuffer(1.0/240);video->swapBuffers();}
 check(!video->isPlaying(),"video did not end at its final frame boundary");
 check(std::abs(video->tell()-duration)<.009,"incorrect playback end time");
 const auto final=hash(*static_cast<const Frame*>(video->getFrontBuffer()));
 check(final==ref.frames.back(),"final frame was discarded");
 video->threadedFillBackBuffer(1);check(!video->swapBuffers(),"EOF restarted decoding");
 for(double target:{duration*.6,duration*.0625,duration*.91,0.0,duration*.5125,duration*.15}) {
  video->seek(target);video->threadedFillBackBuffer(0);video->swapBuffers();matches(*video,ref);
  for(int i=0;i<30 && video->isPlaying();++i){video->threadedFillBackBuffer(1.0/240);video->swapBuffers();if(video->isPlaying())matches(*video,ref);}
 }
 video->pause();video->seek(duration*.35);video->threadedFillBackBuffer(0);check(video->swapBuffers(),"paused seek did not publish a frame");matches(*video,ref);
 auto paused=hash(*static_cast<const Frame*>(video->getFrontBuffer()));double time=video->tell();
 video->threadedFillBackBuffer(10);check(video->tell()==time && !video->swapBuffers(),"paused playback advanced");
 check(paused==hash(*static_cast<const Frame*>(video->getFrontBuffer())),"paused image changed");
 video->play();video->seek(duration+100);video->threadedFillBackBuffer(0);video->swapBuffers();check(!video->isPlaying(),"seek beyond EOF did not end");
 video->seek(0);video->threadedFillBackBuffer(0);video->swapBuffers();check(video->isPlaying(),"rewind after EOF stayed ended");matches(*video,ref);
}
std::string withoutEos(std::string bytes) {
 size_t pos=0;
 while(pos<bytes.size()) {
  auto* h=reinterpret_cast<unsigned char*>(bytes.data()+pos);check(std::memcmp(h,"OggS",4)==0,"fixture page boundary");
  size_t header=27+h[26],body=0;for(unsigned i=0;i<h[26];++i)body+=h[27+i];
  if(h[5]&4){h[5]&=~4;ogg_page page{h,long(header),h+header,long(body)};ogg_page_checksum_set(&page);}
  pos+=header+body;
 }
 return bytes;
}
void truncation(const std::string& bytes) {
 for(size_t length:{size_t(0),size_t(4),size_t(27),size_t(100),bytes.size()/2,bytes.size()-1}) {
  try {auto video=stream(bytes.substr(0,length));video->play();video->threadedFillBackBuffer(100);}
  catch(const love::Exception&) {} // Rejected headers or incomplete data are also valid outcomes.
 }
 auto video=stream(withoutEos(bytes));video->play();video->threadedFillBackBuffer(100);check(!video->isPlaying(),"missing EOS was not treated as EOF");
 // Exercise the real decoder-worker/join pattern used by Dora's runtime.
 auto workerVideo=stream(withoutEos(bytes));workerVideo->play();workerVideo->seek(100);
 std::atomic<bool> stopping=false;std::exception_ptr error;
 std::thread worker([&]{try {while(!stopping.load())workerVideo->threadedFillBackBuffer(.01);}catch(...){error=std::current_exception();}});
 std::this_thread::sleep_for(std::chrono::milliseconds(10));stopping=true;worker.join();if(error)std::rethrow_exception(error);
}
} // namespace
int main() {
 try {
  const auto motion=load(DORA_VIDEO_FIXTURES "/motion.ogv");
  playbackAndSeeks(motion,600);truncation(motion);
  playbackAndSeeks(load(DORA_VIDEO_FIXTURES "/continued.ogv"),4);
  std::cout<<"VIDEO_PLAYBACK_PASS sequential,duplicate,keyframe-seek,continued-packets,paused-seek,EOF,rewind,truncation,worker-join\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
