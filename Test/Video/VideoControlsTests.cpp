// Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
#include "AudioExtraction.h"
#include "VideoContent.h"
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
#include <source_location>
#include <string>
#include <thread>
#include <utility>

namespace {
void check(bool value, const char* message) {
 if (!value) throw std::runtime_error(message);
}
template<class T, class U> T s_cast(U value) { return static_cast<T>(value); }
struct VideoDataImpl { virtual ~VideoDataImpl() = default; };
namespace AudioDetail = Dora::AudioDetail;
#include "VideoBufferPolicy.inc"
// Expose queue counters only in this isolated harness, never in the engine API.
#define private public
#define Error(...) ((void)0)
#include "VideoData.inc"
#undef Error
#undef private

// The production controls and decoder run together. Only rendering and the
// device clock are adapted; native acceptance additionally uses real SoLoud/GPU.
struct AudioSource {
 bool playing=false, paused=false;
 double position=0.0, duration;
 unsigned starts=0, seeks=0;
 explicit AudioSource(double length):duration(length) {}
 bool play(){playing=true;paused=false;position=0;++starts;return true;}
 void seek(double seconds){position=seconds;++seeks;}
 void stop(){playing=false;}
 bool isPlaying()const{return playing;}
 double getCurrentTime()const{return position;}
 void setPaused(bool value){paused=value;}
 void removeFromParent(bool){playing=false;}
};
struct Sprite {
 bool running=true;
 bool isRunning()const{return running;}
 virtual void onEnter(){running=true;}
 virtual void onExit(){running=false;}
 virtual bool update(double){return false;}
};
uint64_t imageHash(const std::vector<uint8_t>& rgba) {
 uint64_t result=1469598103934665603ull;
 for(auto byte:rgba)result=(result^byte)*1099511628211ull;
 return result;
}
struct VideoNode:Sprite {
 enum class UpdateFlag {Wait,Done,Loop,End,Stop};
 std::shared_ptr<VideoDataImpl> _videoData;
 std::shared_ptr<AudioSource> _audioSource;
 double _playbackTime=0,_duration=0,_audioDuration=0,_seekTime=0;
 bool _seeking=false,_ended=false;
 uint64_t _cycle=0;
 bool _started=false,_audioEnded=true;
 UpdateFlag _videoEnd=UpdateFlag::Wait;
 unsigned endedEvents=0;
 bool _looped=false,_paused=false;
 std::thread worker;
 uint64_t image=0;
 explicit VideoNode(const char* fixture,double audioDuration,bool looped=false) {
  auto data=std::make_shared<VideoData>();data->looped=_looped=looped;
  check(data->init(String(fixture)),"fixture init failed");_videoData=data;
  _duration=std::max(data->duration,audioDuration);_audioDuration=audioDuration;
  if(audioDuration>0)_audioSource=std::make_shared<AudioSource>(audioDuration);
#ifndef DORA_EMSCRIPTEN
  worker=std::thread([data]{data->decode();});
#endif
 }
 ~VideoNode(){static_cast<VideoData*>(_videoData.get())->stop();if(worker.joinable())worker.join();}
 void play();void pause();void resume();void seek(double);void rewind();
 double getCurrentTime()const noexcept;double getDuration()const noexcept;
 bool isPlaying()const noexcept;bool isPaused()const;
 void onEnter()override;void onExit()override;bool update(double)override;
 bool beginPlayback();
 void emit(const String& name) {
  check(name=="VideoEnd" && !isPlaying() && getCurrentTime()==getDuration(),"incorrect VideoEnd callback state");
  ++endedEvents;
 }
 UpdateFlag updateTexture() {
  auto frame=static_cast<VideoData*>(_videoData.get())->getFrame(_playbackTime,_cycle);
  if(!frame)return UpdateFlag::Wait;
  switch(frame->end) {
   case VideoFrame::End::Loop: return UpdateFlag::Loop;
   case VideoFrame::End::Natural: return UpdateFlag::End;
   case VideoFrame::End::Failed: return UpdateFlag::Stop;
   case VideoFrame::End::None: break;
  }
  image=imageHash(frame->rgba);return UpdateFlag::Done;
 }
 void step(double dt) {
  if(_audioSource && _audioSource->playing && !_audioSource->paused){
   _audioSource->position+=dt;
   if(_audioSource->position>=_audioDuration){_audioSource->playing=false;_audioEnded=true;}
  }
  update(dt);
 }
};
constexpr auto operator""_slice(const char* value, size_t) { return value; }
#define Warn(...) ((void)0)
#include "VideoControls.inc"
#include "VideoUpdate.inc"
#undef Warn
std::vector<uint64_t> reference(const char* fixture) {
 VideoData data;check(data.init(String(fixture)),"reference init");
 std::vector<uint64_t> frames;
 while(data.decodeNextFrame()){
  frames.push_back(imageHash(data.frames.back().rgba));data.frames.clear();
 }
 return frames;
}
template<class Predicate> void await(VideoNode& node,Predicate done, const std::source_location where=std::source_location::current()) {
 const auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(5);
 while(!done() && std::chrono::steady_clock::now()<deadline){node.update(0);std::this_thread::yield();}
 if(!done()) {
  std::cerr<<"await line="<<where.line()<<" time="<<node._playbackTime<<" seek="<<node._seeking<<" started="<<node._started<<" ended="<<node._ended<<" videoEnd="<<static_cast<int>(node._videoEnd)<<" audioEnd="<<node._audioEnded<<" cycle="<<node._cycle<<" image="<<node.image<<"\n";
  throw std::runtime_error("controls did not reach requested state");
 }
}
void seekFrame(VideoNode& node,double time,const std::vector<uint64_t>& frames,double fps) {
 node.seek(time);
 const auto index=std::min<size_t>(size_t(std::max(0.0,time)*fps+1e-7),frames.size()-1);
 await(node,[&]{return !node._seeking && node.image==frames[index];});
}
void controls(const char* fixture,size_t frameCount,double fps) {
 auto frames=reference(fixture);check(frames.size()==frameCount,"reference frame count");
 const double videoDuration=frameCount/fps;
 VideoNode node(fixture,videoDuration+2);
 check(node.getDuration()==videoDuration+2 && node.isPlaying(),"initial state/duration");
 node.pause();
 for(double time:{videoDuration*.61,videoDuration*.0625,videoDuration*.91,0.0}){
  seekFrame(node,time,frames,fps);
  check(node.isPaused() && !node.isPlaying() && node.getCurrentTime()==time,"paused seek state");
  const auto image=node.image;node.step(5);check(node.image==image && node.getCurrentTime()==time,"pause advanced");
 }
 node.seek(videoDuration*.8);node.seek(videoDuration*.1);seekFrame(node,videoDuration*.33,frames,fps);
 node.rewind();await(node,[&]{return !node._seeking && node.image==frames[0];});
 check(node.isPaused() && node.getCurrentTime()==0,"rewind did not preserve pause");
 node.play();await(node,[&]{return node._started;});
 check(node.isPlaying() && node._audioSource->playing,"play did not start both tracks");
 seekFrame(node,videoDuration*.5,frames,fps);await(node,[&]{return node._started;});
 check(node._audioSource->position==videoDuration*.5,"audio seek missed target");
 node.step(1/fps);
 auto expected=std::min<size_t>(size_t(node.getCurrentTime()*fps+1e-7),frames.size()-1);
 await(node,[&]{return node.image==frames[expected];});
 node.pause();double held=node.getCurrentTime();node.step(2);check(node.getCurrentTime()==held,"audio pause advanced");
 node.onExit();node.play();check(!node.isPlaying() && node._audioSource->paused,"detached play started audio");node.onEnter();
 check(node.isPlaying() && !node._audioSource->paused,"re-entry did not resume");
 seekFrame(node,node.getDuration()+100,frames,fps);
 check(!node.isPlaying() && node.getCurrentTime()==node.getDuration(),"seek beyond end");
 check(node.endedEvents==0,"seek, pause or scene exit emitted VideoEnd");
 node.play();await(node,[&]{return !node._seeking && node._started && node.image==frames[0];});
 check(node.getCurrentTime()==0 && node.isPlaying(),"play after end did not restart");
 seekFrame(node,videoDuration+1,frames,fps);await(node,[&]{return node._started;});
 check(node._audioSource->position==videoDuration+1,"longer audio tail did not seek");
 await(node,[&]{return node._videoEnd==VideoNode::UpdateFlag::End;});
 check(node.endedEvents==0 && node.isPlaying(),"VideoEnd preceded the audio tail");
 node.step(1.1);await(node,[&]{return node._ended;});
 check(!node.isPlaying() && node.getCurrentTime()==node.getDuration(),"natural EOF state");
 node.step(1);check(node.endedEvents==1,"natural EOF must emit VideoEnd once");
 node.play();await(node,[&]{return !node._seeking && node._started && node.image==frames[0];});
 check(node.isPlaying() && node.getCurrentTime()==0,"natural EOF replay");
 node.pause();seekFrame(node,-1,frames,fps);check(node.getCurrentTime()==0,"negative seek clamp");
 auto cycle=node._cycle;node.seek(std::numeric_limits<double>::quiet_NaN());node.seek(std::numeric_limits<double>::infinity());
 check(node._cycle==cycle,"non-finite seek changed state");
}
void shortAudioAndLoop(const char* fixture) {
 auto frames=reference(fixture);
 VideoNode silent(fixture,0);
 seekFrame(silent,12.5,frames,30);await(silent,[&]{return silent._started;});
 check(silent.getDuration()==20 && silent.isPlaying(),"silent duration/playing state");
 silent.step(7.5);await(silent,[&]{return silent._ended;});
 silent.play();await(silent,[&]{return !silent._seeking && silent._started && silent.image==frames[0];});
 check(silent.getCurrentTime()==0 && silent.isPlaying(),"silent EOF replay");
 seekFrame(silent,19.9,frames,30);await(silent,[&]{return silent._started;});
 silent.step(.2);await(silent,[&]{return silent._ended;});
 check(silent.endedEvents==2,"replay must emit VideoEnd again");
 VideoNode shortAudio(fixture,1.25);
 seekFrame(shortAudio,18,frames,30);await(shortAudio,[&]{return shortAudio._started;});
 check(shortAudio._audioEnded && !shortAudio._audioSource->playing,"short audio restarted past EOF");
 shortAudio.step(2);await(shortAudio,[&]{return shortAudio._ended;});
 check(shortAudio.getCurrentTime()==20 && !shortAudio.isPlaying(),"silent video tail failed");
 VideoNode loop(fixture,20,true);seekFrame(loop,19.9,frames,30);await(loop,[&]{return loop._started;});
 const auto cycle=loop._cycle;loop.step(.2);
 await(loop,[&]{return loop._cycle>cycle && loop._started && loop.image==frames.front();});
 check(loop.isPlaying() && loop.getCurrentTime()==0,"seeked loop did not restart both tracks");
 check(loop.endedEvents==0,"loop transition emitted VideoEnd");
}
}
int main(){
 try{
  controls(DORA_VIDEO_FIXTURES "/motion.ogv",600,30);
  controls(DORA_VIDEO_FIXTURES "/continued.ogv",4,30);
  shortAudioAndLoop(DORA_VIDEO_FIXTURES "/motion.ogv");
  std::cout<<"VIDEO_CONTROLS_PASS keyframe and superseded seeks, audio clock, paused preview, rewind, duration, EOF replay, tails, loop, scene lifecycle\n";
 }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
