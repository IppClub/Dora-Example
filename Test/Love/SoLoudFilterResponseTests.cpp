#include "soloud_biquadresonantfilter.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <vector>

namespace
{

constexpr float SampleRate = 48000.0f;
constexpr unsigned SampleCount = 32768;
constexpr unsigned SettleSamples = 2048;
constexpr float LowTone = 250.0f;
constexpr float HighTone = 6000.0f;
constexpr float Pi = 3.14159265358979323846f;

void require(bool condition, const char *message)
{
	if (!condition)
	{
		std::cerr << "FAIL: " << message << '\n';
		std::exit(1);
	}
}

std::vector<float> makeSignal()
{
	auto signal = std::vector<float>(SampleCount);
	for (unsigned index = 0; index < SampleCount; ++index)
	{
		const auto time = static_cast<float>(index) / SampleRate;
		signal[index] = 0.4f * std::sin(2.0f * Pi * LowTone * time)
			+ 0.4f * std::sin(2.0f * Pi * HighTone * time);
	}
	return signal;
}

float amplitude(const std::vector<float>& signal, float frequency)
{
	double sine = 0.0;
	double cosine = 0.0;
	const auto samples = signal.size() - SettleSamples;
	for (unsigned index = SettleSamples; index < signal.size(); ++index)
	{
		const auto phase = 2.0 * static_cast<double>(Pi) * frequency
			* static_cast<double>(index) / SampleRate;
		sine += signal[index] * std::sin(phase);
		cosine += signal[index] * std::cos(phase);
	}
	return static_cast<float>(2.0 / samples * std::sqrt(sine * sine + cosine * cosine));
}

std::vector<float> filter(int type, float frequency, float wet = 1.0f)
{
	SoLoud::BiquadResonantFilter definition;
	require(definition.setParams(type, frequency, 1.0f) == SoLoud::SO_NO_ERROR,
		"failed to configure SoLoud biquad filter");
	auto instance = std::unique_ptr<SoLoud::BiquadResonantFilterInstance>(definition.createInstance());
	require(instance != nullptr, "failed to create SoLoud biquad instance");
	instance->setFilterParameter(SoLoud::BiquadResonantFilter::WET, wet);
	auto signal = makeSignal();
	instance->filter(signal.data(), SampleCount, SampleCount, 1, SampleRate, 0.0);
	return signal;
}

float updatedCutoffHighAmplitude()
{
	SoLoud::BiquadResonantFilter definition;
	require(definition.setParams(SoLoud::BiquadResonantFilter::LOWPASS, 1000.0f, 1.0f)
		== SoLoud::SO_NO_ERROR, "failed to configure dynamic SoLoud filter");
	auto instance = std::unique_ptr<SoLoud::BiquadResonantFilterInstance>(definition.createInstance());
	require(instance != nullptr, "failed to create dynamic SoLoud filter instance");
	auto closed = makeSignal();
	instance->filter(closed.data(), SampleCount, SampleCount, 1, SampleRate, 0.0);
	instance->setFilterParameter(SoLoud::BiquadResonantFilter::FREQUENCY, 8000.0f);
	auto opened = makeSignal();
	instance->filter(opened.data(), SampleCount, SampleCount, 1, SampleRate, 1.0);
	return amplitude(opened, HighTone);
}

} // namespace

int main()
{
	const auto input = makeSignal();
	const auto inputLow = amplitude(input, LowTone);
	const auto inputHigh = amplitude(input, HighTone);
	require(inputLow > 0.39f && inputHigh > 0.39f,
		"input tone amplitudes are not deterministic");

	const auto lowpass = filter(SoLoud::BiquadResonantFilter::LOWPASS, 1000.0f);
	const auto lowpassLow = amplitude(lowpass, LowTone);
	const auto lowpassHigh = amplitude(lowpass, HighTone);
	require(lowpassLow > inputLow * 0.85f,
		"lowpass unexpectedly removed the low-frequency component");
	require(lowpassHigh < inputHigh * 0.04f,
		"lowpass did not attenuate the high-frequency component");

	const auto highpass = filter(SoLoud::BiquadResonantFilter::HIGHPASS, 1000.0f);
	const auto highpassLow = amplitude(highpass, LowTone);
	const auto highpassHigh = amplitude(highpass, HighTone);
	require(highpassLow < inputLow * 0.08f,
		"highpass did not attenuate the low-frequency component");
	require(highpassHigh > inputHigh * 0.90f,
		"highpass unexpectedly removed the high-frequency component");

	const auto openLowpass = filter(SoLoud::BiquadResonantFilter::LOWPASS, 8000.0f);
	const auto openHigh = amplitude(openLowpass, HighTone);
	require(openHigh > lowpassHigh * 10.0f,
		"changing the cutoff frequency did not change the PCM response");
	const auto updatedHigh = updatedCutoffHighAmplitude();
	require(updatedHigh > lowpassHigh * 10.0f,
		"updating a live filter cutoff did not change the PCM response");

	const auto dryLowpass = filter(SoLoud::BiquadResonantFilter::LOWPASS, 1000.0f, 0.0f);
	const auto dryHigh = amplitude(dryLowpass, HighTone);
	require(std::abs(dryHigh - inputHigh) < 0.002f,
		"wet=0 did not preserve the dry PCM signal");

	std::cout << std::fixed << std::setprecision(4)
		<< "SOLOUD_FILTER_RESPONSE_PASS"
		<< " input=" << inputLow << ',' << inputHigh
		<< " lowpass=" << lowpassLow << ',' << lowpassHigh
		<< " highpass=" << highpassLow << ',' << highpassHigh
		<< " cutoff-change-high=" << openHigh
		<< " live-cutoff-high=" << updatedHigh
		<< " dry-high=" << dryHigh << '\n';
}
