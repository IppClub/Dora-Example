#include "soloud.h"
#include "soloud_audiosource.h"

#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <vector>

void soloud_stop_voice(uint32_t) {}

namespace SoLoud
{
// The test never initializes a device. This stub only satisfies the single
// backend symbol selected for the standalone core build.
result null_init(Soloud *, unsigned int, unsigned int, unsigned int, unsigned int)
{
	return NOT_IMPLEMENTED;
}
}

namespace
{

class SilentInstance final : public SoLoud::AudioSourceInstance
{
public:
	explicit SilentInstance(unsigned totalSamples = (std::numeric_limits<unsigned>::max)())
		: totalSamples(totalSamples) { }

	unsigned int getAudio(float *buffer, unsigned int samples, unsigned int) override
	{
		const unsigned produced = (std::min)(samples, totalSamples - decodedSamples);
		for (unsigned index = 0; index < produced; ++index) buffer[index] = 0.0f;
		decodedSamples += produced;
		++getAudioCalls;
		return produced;
	}

	bool hasEnded() override { return decodedSamples >= totalSamples; }
	SoLoud::result rewind() override
	{
		decodedSamples = 0;
		mStreamPosition = 0.0;
		return SoLoud::SO_NO_ERROR;
	}

	unsigned totalSamples;
	unsigned decodedSamples = 0;
	unsigned getAudioCalls = 0;
};

void require(bool condition, const char *message)
{
	if (!condition)
	{
		std::cerr << "FAIL: " << message << '\n';
		std::exit(1);
	}
}

void populate(SoLoud::Soloud& engine, unsigned count, unsigned mandatory)
{
	for (unsigned index = 0; index < count; ++index)
	{
		auto *voice = new SilentInstance;
		voice->mOverallVolume = static_cast<float>(index + 1);
		voice->mSamplerate = 1000.0f;
		voice->mBaseSamplerate = 1000.0f;
		voice->mBusHandle = 0;
		voice->mPlayIndex = index + 1;
		if (index < mandatory) voice->mFlags |= SoLoud::AudioSourceInstance::INAUDIBLE_TICK;
		engine.mVoice[index] = voice;
	}
	engine.mHighestVoice = count;
	engine.mActiveVoiceDirty = true;
}

} // namespace

int main()
{
	SoLoud::Soloud engine;
	require(engine.setMaxActiveVoiceCount(255) == SoLoud::SO_NO_ERROR,
		"failed to configure routing capacity");
	require(engine.setMaxActiveSourceVoiceCount(32) == SoLoud::SO_NO_ERROR,
		"failed to configure active Source voice budget");
	populate(engine, 100, 5);
	engine.calcActiveVoices_internal();
	require(engine.mActiveVoiceCount == 37,
		"five mandatory buses plus 32 active Sources were not selected");
	for (unsigned index = 0; index < 5; ++index)
		require(engine.mActiveVoice[index] < 5,
			"mandatory ticking voice was not placed before active Sources");
	for (unsigned index = 5; index < engine.mActiveVoiceCount; ++index)
		require(engine.mActiveVoice[index] >= 68,
			"active Source budget did not retain the 32 strongest voices");

	// A voice omitted from mActiveVoice is virtualized, not destroyed or marked
	// as explicitly paused. It must remain eligible for the next selection.
	auto *virtualized = engine.mVoice[5];
	require(virtualized != nullptr
		&& !(virtualized->mFlags & SoLoud::AudioSourceInstance::PAUSED),
		"budget virtualization destroyed or paused an omitted voice");
	virtualized->mOverallVolume = 1000.0f;
	engine.mActiveVoiceDirty = true;
	engine.calcActiveVoices_internal();
	bool reactivated = false;
	for (unsigned index = 5; index < engine.mActiveVoiceCount; ++index)
		if (engine.mVoice[engine.mActiveVoice[index]] == virtualized) reactivated = true;
	require(reactivated,
		"a virtualized voice could not re-enter the single active list");

	// Exercise the actual mixer transition, not just selection. A voice which
	// loses the Source budget must freeze both its reported playback position
	// and decoder, then restore its read-ahead buffers when selected again.
	SoLoud::Soloud timeline;
	timeline.postinit_internal(1000, 100, 0, 1);
	require(timeline.setMaxActiveVoiceCount(2) == SoLoud::SO_NO_ERROR
		&& timeline.setMaxActiveSourceVoiceCount(1) == SoLoud::SO_NO_ERROR,
		"failed to configure virtual playback timeline test");
	populate(timeline, 2, 0);
	auto *quiet = static_cast<SilentInstance *>(timeline.mVoice[0]);
	auto *loud = static_cast<SilentInstance *>(timeline.mVoice[1]);
	const auto quietHandle = timeline.getHandleFromVoice_internal(0);
	const auto loudHandle = timeline.getHandleFromVoice_internal(1);
	std::vector<float> mix(100);
	timeline.mix(mix.data(), 100);
	require(quiet->getAudioCalls == 0 && timeline.getStreamPosition(quietHandle) == 0.0,
		"a never-active voice advanced its decoder or playback position");
	require(loud->getAudioCalls > 0 && timeline.getStreamPosition(loudHandle) > 0.09,
		"the selected voice did not advance decoder and playback position");
	const unsigned loudDecoded = loud->decodedSamples;
	const double loudPosition = timeline.getStreamPosition(loudHandle);
	quiet->mOverallVolume = 10.0f;
	timeline.mActiveVoiceDirty = true;
	timeline.mix(mix.data(), 100);
	require(loud->decodedSamples == loudDecoded
		&& timeline.getStreamPosition(loudHandle) == loudPosition
		&& loud->mVirtualResampleDataValid,
		"a budget-virtualized voice did not freeze and preserve resampler state");
	loud->mOverallVolume = 20.0f;
	timeline.mActiveVoiceDirty = true;
	timeline.mix(mix.data(), 100);
	require(timeline.getStreamPosition(loudHandle) > loudPosition
		&& !loud->mVirtualResampleDataValid,
		"a reactivated voice did not resume its preserved playback state");
	quiet->mOverallVolume = 30.0f;
	timeline.mActiveVoiceDirty = true;
	timeline.mix(mix.data(), 100);
	require(loud->mVirtualResampleDataValid,
		"a second virtualization did not preserve read-ahead state");
	require(timeline.seek(loudHandle, 0.025) == SoLoud::SO_NO_ERROR
		&& !loud->mVirtualResampleDataValid,
		"seeking a virtualized voice did not replace stale read-ahead state");
	loud->mOverallVolume = 40.0f;
	timeline.mActiveVoiceDirty = true;
	timeline.mix(mix.data(), 100);
	require(timeline.getStreamPosition(loudHandle) > 0.12
		&& timeline.getStreamPosition(loudHandle) < 0.13,
		"a virtualized seek did not resume from the requested playback position");

	// A finite voice must not end while it is outside the budget: virtualization
	// is pause-like, and natural completion resumes only after it is selected.
	SoLoud::Soloud ending;
	ending.postinit_internal(1000, 100, 0, 1);
	require(ending.setMaxActiveVoiceCount(2) == SoLoud::SO_NO_ERROR
		&& ending.setMaxActiveSourceVoiceCount(1) == SoLoud::SO_NO_ERROR,
		"failed to configure virtual natural-end test");
	auto *finite = new SilentInstance(600);
	auto *blocker = new SilentInstance;
	for (auto *voice : {finite, blocker})
	{
		voice->mSamplerate = voice->mBaseSamplerate = 1000.0f;
		voice->mBusHandle = 0;
		voice->mOverallVolume = 1.0f;
	}
	finite->mPlayIndex = 1;
	blocker->mPlayIndex = 2;
	finite->mOverallVolume = 2.0f;
	ending.mVoice[0] = finite;
	ending.mVoice[1] = blocker;
	ending.mHighestVoice = 2;
	ending.mActiveVoiceDirty = true;
	const auto finiteHandle = ending.getHandleFromVoice_internal(0);
	ending.mix(mix.data(), 100);
	blocker->mOverallVolume = 3.0f;
	ending.mActiveVoiceDirty = true;
	for (unsigned pass = 0; pass < 10; ++pass) ending.mix(mix.data(), 100);
	require(ending.isValidVoiceHandle(finiteHandle)
		&& ending.getStreamPosition(finiteHandle) > 0.09
		&& ending.getStreamPosition(finiteHandle) < 0.11,
		"a finite virtualized voice advanced or ended outside the active budget");
	finite->mOverallVolume = 4.0f;
	ending.mActiveVoiceDirty = true;
	for (unsigned pass = 0; pass < 10 && ending.isValidVoiceHandle(finiteHandle); ++pass)
		ending.mix(mix.data(), 100);
	require(!ending.isValidVoiceHandle(finiteHandle),
		"a finite reactivated voice did not reach natural completion");

	SoLoud::Soloud routed;
	require(routed.setMaxActiveVoiceCount(255) == SoLoud::SO_NO_ERROR
		&& routed.setMaxActiveSourceVoiceCount(1) == SoLoud::SO_NO_ERROR,
		"failed to configure routed-volume test");
	populate(routed, 4, 2);
	routed.mVoice[0]->mOverallVolume = 0.01f;
	routed.mVoice[1]->mOverallVolume = 1.0f;
	routed.mVoice[2]->mOverallVolume = 1.0f;
	routed.mVoice[2]->mBusHandle = routed.getHandleFromVoice_internal(0);
	routed.mVoice[3]->mOverallVolume = 0.5f;
	routed.mVoice[3]->mBusHandle = routed.getHandleFromVoice_internal(1);
	routed.calcActiveVoices_internal();
	require(routed.mActiveVoiceCount == 3 && routed.mActiveVoice[2] == 3,
		"active Source selection ignored the parent bus volume");

	// Reproduce the old hard-overload shape: more mandatory buses than routing
	// slots. Every selected bus must still own valid resampling buffers.
	require(engine.setMaxActiveVoiceCount(8) == SoLoud::SO_NO_ERROR,
		"failed to configure overload routing capacity");
	for (unsigned index = 0; index < 10; ++index)
		engine.mVoice[index]->mFlags |= SoLoud::AudioSourceInstance::INAUDIBLE_TICK;
	engine.mActiveVoiceDirty = true;
	engine.calcActiveVoices_internal();
	require(engine.mActiveVoiceCount == 8,
		"mandatory bus overload did not clamp to routing capacity");
	for (unsigned index = 0; index < engine.mActiveVoiceCount; ++index)
	{
		auto *voice = engine.mVoice[engine.mActiveVoice[index]];
		require(voice->mResampleData[0] != nullptr && voice->mResampleData[1] != nullptr,
			"mandatory bus overload left a selected voice without resampling buffers");
	}

	std::cout << "SOLOUD_VOICE_BUDGET_PASS routing=255 active-sources=32 mandatory=5 selected=37"
		<< " reactivation=pass virtual-position=paused resampler-restore=pass"
		<< " virtual-seek=pass natural-end=pass routed-gain=pass"
		<< " overload-routing=8 resamplers=pass\n";
}
