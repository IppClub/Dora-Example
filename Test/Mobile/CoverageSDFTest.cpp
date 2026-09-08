// c++ -std=c++17 -I/path/to/Dora-SSR/Source/3rdParty CoverageSDFTest.cpp -o /tmp/sdf-test
#include "font/coverage_sdf.h"
#include <cassert>
#include <iostream>

int main() {
	constexpr int size = 9;
	std::vector<uint8_t> bitmap(size * size, 0);
	auto empty = bgfx::buildCoverageSDF(bitmap.data(), size, size);
	for (auto pixel : empty) assert(pixel == 0);
	std::fill(bitmap.begin(), bitmap.end(), 255);
	auto full = bgfx::buildCoverageSDF(bitmap.data(), size, size);
	for (auto pixel : full) assert(pixel == 255);
	// A fractional vertical edge must not jump when coverage crosses 128.
	int previous = 0, maxStep = 0;
	for (int coverage = 1; coverage < 255; ++coverage) {
		for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x)
			bitmap[y * size + x] = x < 4 ? 0 : x == 4 ? coverage : 255;
		auto sdf = bgfx::buildCoverageSDF(bitmap.data(), size, size);
		int value = sdf[4 * size + 4];
		assert(value >= previous);
		if (coverage > 1) maxStep = std::max(maxStep, value - previous);
		previous = value;
		// Transposing the glyph must give identical horizontal/vertical weight.
		std::vector<uint8_t> transposed(size * size);
		for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x)
			transposed[x * size + y] = bitmap[y * size + x];
		auto horizontal = bgfx::buildCoverageSDF(transposed.data(), size, size);
		for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x)
			assert(sdf[y * size + x] == horizontal[x * size + y]);
	}
	assert(maxStep <= 1);
	std::cout << "passed: empty/full, continuous coverage, axis symmetry; max encoded step=" << maxStep << '\n';
}
