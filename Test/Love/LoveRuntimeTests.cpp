#include "Love/LoveRuntime.h"
#include "Love/LoveTextLayout.h"
#include "3rdParty/soloud/soloud_distance_model.h"
#include "3rdParty/soloud/soloud_spatial_gain.h"

#include <array>
#include <bit>
#include <charconv>
#include <cmath>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <unordered_map>

extern "C"
{
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
}

namespace Dora
{

// LoveRuntime is linked without the rest of the engine in this standalone
// suite. Supply the two engine integration hooks used during runtime startup.
void LogInfoThreaded(const std::string &) { }

bool dora_open_builtin_modules(lua_State *, std::string &error)
{
	error.clear();
	return true;
}

} // namespace Dora

namespace
{

class MockGraphics final : public Dora::Love::GraphicsBackend, public Dora::Love::ImageBackend
{
public:
	static int totalMockMipmaps(int width, int height, int depth = 1)
	{
		int dimension = std::max({width, height, depth});
		int count = 1;
		while (dimension > 1) { dimension >>= 1; ++count; }
		return count;
	}
	static std::vector<float> transformPoints(const std::vector<float> &points,
		const Transform2D &transform)
	{
		std::vector<float> transformed;
		transformed.reserve(points.size());
		for (std::size_t index = 0; index < points.size(); index += 2)
		{
			const float x = points[index];
			const float y = points[index + 1];
			transformed.push_back(transform.a * x + transform.c * y + transform.tx);
			transformed.push_back(transform.b * x + transform.d * y + transform.ty);
		}
		return transformed;
	}
	void beginFrame() override { ++begins; }
	Stats getStats() const override { return stats; }
	bool clear(const ClearRequest &request, std::string &error) override
	{
		++clears;
		clearRequests.push_back(request);
		error.clear();
		return true;
	}
	bool rectangle(bool fill, float, float, float, float, float, LineStyle style, LineJoin join,
		float, float, float, float,
		std::string &error) override
	{
		++rectangles;
		if (currentShader != 0) ++shaderPrimitiveDraws;
		lastRectangleFilled = fill;
		lastLineStyle = style;
		lastLineJoin = join;
		error.clear();
		return true;
	}
	bool circle(bool, float, float, float, float, LineStyle style, LineJoin join,
		float, float, float, float, std::string &error) override
	{
		++circles;
		if (currentShader != 0) ++shaderPrimitiveDraws;
		lastLineStyle = style;
		lastLineJoin = join;
		error.clear();
		return true;
	}
	bool line(const std::vector<float> &points, const Transform2D &transform,
		float, LineStyle style, LineJoin join,
		float, float, float, float,
		std::string &error) override
	{
		++lines;
		if (currentShader != 0) ++shaderPrimitiveDraws;
		else
		{
			linePointCount = points.size();
			lastLinePoints = transformPoints(points, transform);
		}
		lastLineStyle = style;
		lastLineJoin = join;
		error.clear();
		return true;
	}
	bool polygon(bool fill, const std::vector<float> &points, const Transform2D &transform,
		float, LineStyle style, LineJoin join,
		float, float, float, float,
		std::string &error) override
	{
		++polygons;
		if (currentShader != 0) ++shaderPrimitiveDraws;
		else
		{
			lastPolygonFilled = fill;
			lastPolygonPoints = transformPoints(points, transform);
		}
		lastLineStyle = style;
		lastLineJoin = join;
		error.clear();
		return true;
	}
	bool points(const std::vector<float> &points, float pointSize, float, float, float, float,
		std::string &error) override
	{
		++pointCalls;
		if (currentShader != 0) ++shaderPrimitiveDraws;
		else
		{
			lastPoints = points;
			lastPointSize = pointSize;
		}
		error.clear();
		return true;
	}
	bool decodeImage(std::string_view encoded, int &width, int &height,
		std::vector<std::uint8_t> &rgba8, std::string &error) override
	{
		++imageDataDecodes;
		if (encoded != "encoded-image")
		{
			error = "mock image decoder rejected encoded data";
			return false;
		}
		width = 2;
		height = 1;
		rgba8 = {255, 0, 0, 255, 0, 255, 0, 128};
		error.clear();
		return true;
	}
	bool decodeCompressedImage(std::string_view encoded,
		Dora::Love::ImageBackend::CompressedImage &image, std::string &error) override
	{
		++compressedImageDecodes;
		if (encoded != "compressed-image")
		{
			error = "mock compressed image parser rejected encoded data";
			return false;
		}
		image.format = "DXT1";
		image.levels = {
			{4, 4, {0, 1, 2, 3, 4, 5, 6, 7}},
			{2, 2, {8, 9, 10, 11, 12, 13, 14, 15}},
		};
		error.clear();
		return true;
	}
	bool encodeImage(std::string_view format, int width, int height,
		std::span<const std::uint8_t> rgba8, std::vector<std::uint8_t> &encoded,
		std::string &error) override
	{
		++imageDataEncodes;
		lastImageDataEncodeFormat = format;
		lastImageDataEncodeWidth = width;
		lastImageDataEncodeHeight = height;
		lastImageDataEncodePixels.assign(rgba8.begin(), rgba8.end());
		if (rejectImageDataEncode)
		{
			error = "mock image encoder rejected rgba8 data";
			return false;
		}
		const std::string marker = "encoded-" + std::string(format);
		encoded.assign(marker.begin(), marker.end());
		error.clear();
		return true;
	}
	ImageHandle newImage(const std::string &filename, std::string &error) override
	{
		lastImageFilename = filename;
		error.clear();
		++imagesCreated;
		return nextImageHandle++;
	}
	ImageHandle newImage(TextureType type, int width, int height, int slices,
		std::span<const std::uint8_t> rgba8, std::string &error) override
	{
		if (width <= 0 || height <= 0 || slices <= 0
			|| rgba8.size() != static_cast<std::size_t>(width * height * slices * 4))
		{
			error = "mock non-2D Image data mismatch";
			return 0;
		}
		const ImageHandle handle = nextImageHandle++;
		layeredImages.emplace(handle, LayeredImage{type, width, height, slices,
			std::vector<std::uint8_t>(rgba8.begin(), rgba8.end())});
		++imagesCreated;
		error.clear();
		return handle;
	}
	ImageHandle newImage(TextureType type, std::span<const ImageLevel> levels,
		std::string &error) override
	{
		if (levels.empty())
		{
			error = "mock Image mipmap chain is empty";
			return 0;
		}
		const auto &base = levels.front();
		for (std::size_t mip = 0; mip < levels.size(); ++mip)
		{
			const auto &level = levels[mip];
			const int expectedSlices = type == TextureType::Volume
				? std::max(1, base.slices >> mip) : base.slices;
			if (level.width != std::max(1, base.width >> mip)
				|| level.height != std::max(1, base.height >> mip)
				|| level.slices != expectedSlices
				|| level.rgba8.size() != static_cast<std::size_t>(level.width)
					* level.height * level.slices * 4)
			{
				error = "mock Image mipmap data mismatch";
				return 0;
			}
		}
		const ImageHandle handle = nextImageHandle++;
		LayeredImage image{type, base.width, base.height, base.slices, base.rgba8};
		image.levels.assign(levels.begin(), levels.end());
		layeredImages.emplace(handle, std::move(image));
		++imagesCreated;
		error.clear();
		return handle;
	}
	ImageHandle newCompressedImage(std::string_view format, int width, int height,
		int mipmapCount, std::span<const std::uint8_t> data, std::string &error) override
	{
		if (format != "DXT1" || width != 4 || height != 4 || mipmapCount <= 0
			|| data.empty())
		{
			error = "mock compressed Image data mismatch";
			return 0;
		}
		lastCompressedImageFormat = format;
		lastCompressedImageMipmaps = mipmapCount;
		lastCompressedImageBytes.assign(data.begin(), data.end());
		const ImageHandle handle = nextImageHandle++;
		layeredImages.emplace(handle, LayeredImage{TextureType::Texture2D,
			width, height, 1, lastCompressedImageBytes});
		++compressedImagesCreated;
		++imagesCreated;
		error.clear();
		return handle;
	}
	ImageHandle newCompressedImage(TextureType type, std::string_view format,
		std::span<const Dora::Love::GraphicsBackend::CompressedImageLevel> levels,
		std::string &error) override
	{
		if (levels.empty() || format != "DXT1")
		{
			error = "mock layered compressed Image data mismatch";
			return 0;
		}
		const auto &base = levels.front();
		const ImageHandle handle = nextImageHandle++;
		LayeredImage image{type, base.width, base.height, base.slices, base.bytes};
		layeredImages.emplace(handle, std::move(image));
		lastCompressedImageFormat = format;
		lastCompressedImageMipmaps = static_cast<int>(levels.size());
		lastCompressedImageType = type;
		lastCompressedImageSlices = base.slices;
		lastCompressedImageBytes.clear();
		for (const auto &level : levels)
			lastCompressedImageBytes.insert(lastCompressedImageBytes.end(),
				level.bytes.begin(), level.bytes.end());
		++compressedImagesCreated;
		++imagesCreated;
		error.clear();
		return handle;
	}
	void releaseImage(ImageHandle image) override
	{
		if (image != 0)
		{
			layeredImages.erase(image);
			++imagesReleased;
		}
	}
	bool updateImage(ImageHandle image, int width, int height,
		std::span<const std::uint8_t> rgba8, std::string &error) override
	{
		auto found = layeredImages.find(image);
		if (found == layeredImages.end() || width != found->second.width
			|| height != found->second.height || found->second.slices != 1
			|| rgba8.size() != static_cast<std::size_t>(width) * height * 4)
		{
			error = "mock dynamic Image update mismatch";
			return false;
		}
		found->second.pixels.assign(rgba8.begin(), rgba8.end());
		++imageUpdates;
		error.clear();
		return true;
	}
	bool replaceImagePixels(ImageHandle image, int slice, int mipmap,
		int x, int y, int width, int height,
		std::span<const std::uint8_t> rgba8, std::string &error) override
	{
		auto found = layeredImages.find(image);
		if (found == layeredImages.end() || slice < 0 || slice >= found->second.slices
			|| mipmap != 0 || x < 0 || y < 0 || width <= 0 || height <= 0
			|| x > found->second.width - width || y > found->second.height - height
			|| rgba8.size() != static_cast<std::size_t>(width) * height * 4)
		{
			error = "mock Image pixel replacement mismatch";
			return false;
		}
		for (int row = 0; row < height; ++row)
		{
			const auto source = rgba8.begin() + static_cast<std::ptrdiff_t>(row * width * 4);
			const auto destination = found->second.pixels.begin() + static_cast<std::ptrdiff_t>(
				((slice * found->second.height + y + row) * found->second.width + x) * 4);
			std::copy_n(source, static_cast<std::size_t>(width) * 4, destination);
		}
		lastImageReplacement = {static_cast<int>(image), slice, mipmap, x, y, width, height};
		++imageReplacements;
		error.clear();
		return true;
	}
	int getImageWidth(ImageHandle image) const override
	{
		const auto found = layeredImages.find(image);
		return found == layeredImages.end() ? (image != 0 ? 32 : 0) : found->second.width;
	}
	int getImageHeight(ImageHandle image) const override
	{
		const auto found = layeredImages.find(image);
		return found == layeredImages.end() ? (image != 0 ? 16 : 0) : found->second.height;
	}
	TextureType getImageTextureType(ImageHandle image) const override
	{
		const auto found = layeredImages.find(image);
		return found == layeredImages.end() ? TextureType::Texture2D : found->second.type;
	}
	int getImageSliceCount(ImageHandle image) const override
	{
		const auto found = layeredImages.find(image);
		return found == layeredImages.end() ? 1 : found->second.slices;
	}
	void drawImage(ImageHandle image, float sourceX, float sourceY, float sourceWidth, float sourceHeight,
		float a, float b, float c, float d, float tx, float ty, float, float,
		float, float, float, float, TextureFilter filter, TextureWrap wrapU, TextureWrap wrapV) override
	{
		++imageDraws;
		lastImageHandle = image;
		imageSource = {sourceX, sourceY, sourceWidth, sourceHeight};
		imageSources.push_back(imageSource);
		imageMatrix = {a, b, c, d, tx, ty};
		lastImageFilter = filter;
		lastImageWrapU = wrapU;
		lastImageWrapV = wrapV;
	}
	bool drawImageLayer(ImageHandle image, int layer,
		float sourceX, float sourceY, float sourceWidth, float sourceHeight,
		float a, float b, float c, float d, float tx, float ty, float, float,
		float, float, float, float, TextureFilter filter, TextureWrap wrapU, TextureWrap wrapV,
		std::string &error) override
	{
		const auto found = layeredImages.find(image);
		if (found == layeredImages.end() || found->second.type != TextureType::Array
			|| layer < 0 || layer >= found->second.slices)
		{
			error = "mock ArrayImage layer draw mismatch";
			return false;
		}
		++imageLayerDraws;
		lastImageLayer = layer;
		lastImageLayerHandle = image;
		imageLayerSource = {sourceX, sourceY, sourceWidth, sourceHeight};
		imageLayerMatrix = {a, b, c, d, tx, ty};
		lastImageFilter = filter;
		lastImageWrapU = wrapU;
		lastImageWrapV = wrapV;
		error.clear();
		return true;
	}
	CanvasHandle newCanvas(int width, int height, const CanvasSettings &settings,
		std::string &error) override
	{
		const CanvasHandle handle = nextCanvasHandle++;
		canvases.emplace(handle, std::pair{width, height});
		canvasSettings.emplace(handle, StoredCanvasSettings{
			std::string(settings.format), settings.type, settings.slices,
			std::string(settings.mipmapMode), settings.dpiScale, settings.msaa, settings.readable});
		++canvasesCreated;
		error.clear();
		return handle;
	}
	bool isCanvasFormatSupported(std::string_view format, bool) const override
	{
		static constexpr std::string_view formats[] = {
			"normal", "hdr", "r8", "rg8", "rgba8", "srgba8", "r16", "rg16",
			"rgba16", "r16f", "rg16f", "rgba16f", "r32f", "rg32f", "rgba32f",
			"rgba4", "rgb5a1", "rgb565", "rgb10a2", "rg11b10f", "stencil8",
			"depth16", "depth24", "depth32f", "depth24stencil8"};
		return std::find(std::begin(formats), std::end(formats), format) != std::end(formats);
	}
	Capabilities getCapabilities() const override
	{
		return {true, true, false, true, true, true, true, false};
	}
	TextureTypes getTextureTypes() const override
	{
		return {true, true, true, true};
	}
	bool isImageFormatSupported(std::string_view format) const override
	{
		return format == "r8" || format == "rgba8" || format == "DXT1";
	}
	RendererInfo getRendererInfo() const override
	{
		return {"Mock Renderer", "1.2.3", "Mock Vendor", "Mock Device"};
	}
	void releaseCanvas(CanvasHandle canvas) override
	{
		canvasSettings.erase(canvas);
		if (canvases.erase(canvas) != 0)
			++canvasesReleased;
	}
	int getCanvasWidth(CanvasHandle canvas) const override
	{
		const auto found = canvases.find(canvas);
		return found == canvases.end() ? 0 : found->second.first;
	}
	int getCanvasHeight(CanvasHandle canvas) const override
	{
		const auto found = canvases.find(canvas);
		return found == canvases.end() ? 0 : found->second.second;
	}
	bool readCanvas(CanvasHandle canvas, int slice, int mipmap,
		int x, int y, int width, int height,
		std::vector<std::uint8_t> &pixels, std::string &error) override
	{
		if (!canvases.contains(canvas))
		{
			error = "mock Canvas is closed";
			return false;
		}
		const auto settings = canvasSettings.find(canvas);
		if (settings == canvasSettings.end() || !settings->second.readable)
		{
			error = "mock Canvas is not readable";
			return false;
		}
		const auto &canvasSettingsValue = settings->second;
		const auto dimensions = canvases.at(canvas);
		const int mipmapCount = 1 + static_cast<int>(std::floor(std::log2(
			static_cast<double>(std::max(dimensions.first, dimensions.second)))));
		if (mipmap < 0 || (canvasSettingsValue.mipmapMode == "none" ? mipmap != 0 : mipmap >= mipmapCount))
		{
			error = "mock Canvas mipmap is invalid";
			return false;
		}
		const int slices = canvasSettingsValue.type == TextureType::Volume
			? std::max(1, canvasSettingsValue.slices >> mipmap) : canvasSettingsValue.slices;
		if (slice < 0 || slice >= slices)
		{
			error = "mock Canvas slice is invalid";
			return false;
		}
		const std::string &format = settings->second.format;
		std::size_t pixelBytes = 4;
		if (format == "r8") pixelBytes = 1;
		else if (format == "rg8" || format == "r16" || format == "r16f"
			|| format == "rgba4" || format == "rgb5a1" || format == "rgb565") pixelBytes = 2;
		else if (format == "rgba16" || format == "rgba16f" || format == "rg32f") pixelBytes = 8;
		else if (format == "rgba32f") pixelBytes = 16;
		pixels.assign(static_cast<std::size_t>(width) * static_cast<std::size_t>(height)
			* pixelBytes, 0);
		if (format == "rgba8" || format == "srgba8")
		for (int row = 0; row < height; ++row)
			for (int column = 0; column < width; ++column)
			{
				const std::size_t offset = (static_cast<std::size_t>(row) * width + column) * 4;
				pixels[offset] = static_cast<std::uint8_t>(x + column);
				pixels[offset + 1] = static_cast<std::uint8_t>(y + row);
				pixels[offset + 2] = 128;
				pixels[offset + 3] = 255;
			}
		lastCanvasRead = {slice, mipmap, x, y, width, height};
		++canvasReads;
		error.clear();
		return true;
	}
	bool generateCanvasMipmaps(CanvasHandle canvas, std::string &error) override
	{
		const auto found = canvasSettings.find(canvas);
		if (found == canvasSettings.end() || found->second.mipmapMode == "none")
		{
			error = "mock Canvas has no mipmaps";
			return false;
		}
		lastGeneratedCanvas = canvas;
		++canvasMipmapGenerations;
		error.clear();
		return true;
	}
	bool setCanvases(std::span<const CanvasHandle> targets, CanvasHandle depthStencil,
		bool depth, bool stencil, std::string &error) override
	{
		int width = 0;
		int height = 0;
		int msaa = -1;
		for (const auto target : targets)
		{
			const auto found = canvases.find(target);
			if (found == canvases.end())
			{
				error = "mock Canvas is closed";
				return false;
			}
			const auto settings = canvasSettings.find(target);
			if (width == 0)
			{
				width = found->second.first;
				height = found->second.second;
				msaa = settings->second.msaa;
			}
			else if (found->second.first != width || found->second.second != height)
			{
				error = "mock Canvas dimensions differ";
				return false;
			}
			else if (settings->second.msaa != msaa)
			{
				error = "mock Canvas MSAA sample counts differ";
				return false;
			}
		}
		if (depthStencil != 0)
		{
			const auto found = canvases.find(depthStencil);
			const auto settings = canvasSettings.find(depthStencil);
			if (found == canvases.end() || settings == canvasSettings.end()
				|| (settings->second.format != "stencil8"
					&& settings->second.format != "depth16"
					&& settings->second.format != "depth24"
					&& settings->second.format != "depth32f"
					&& settings->second.format != "depth24stencil8"))
			{
				error = "mock depthstencil Canvas is invalid";
				return false;
			}
			if (width != 0 && (found->second.first != width || found->second.second != height
				|| settings->second.msaa != msaa))
			{
				error = "mock depthstencil Canvas dimensions or MSAA differ";
				return false;
			}
		}
		if (currentShader != 0)
		{
			for (const auto &[name, texture] : shaderTextures[currentShader])
			{
				if (texture.canvas != 0
					&& (std::find(targets.begin(), targets.end(), texture.canvas) != targets.end()
						|| texture.canvas == depthStencil))
				{
					error = "mock Canvas feedback through Shader uniform " + name;
					return false;
				}
			}
		}
		currentCanvases.assign(targets.begin(), targets.end());
		currentDepthStencil = depthStencil;
		currentCanvasDepth = depth;
		currentCanvasStencil = stencil;
		++canvasSwitches;
		error.clear();
		return true;
	}
	bool setCanvasTargets(std::span<const CanvasTarget> targets,
		const CanvasTarget *depthStencil, bool depth, bool stencil, std::string &error) override
	{
		int width = 0;
		int height = 0;
		int msaa = -1;
		auto validate = [&](const CanvasTarget &target, bool depthTarget) {
			const auto found = canvases.find(target.canvas);
			const auto setting = canvasSettings.find(target.canvas);
			if (found == canvases.end() || setting == canvasSettings.end())
			{
				error = "mock Canvas target is closed";
				return false;
			}
			const auto &value = setting->second;
			const bool isDepth = value.format == "stencil8" || value.format == "depth16"
				|| value.format == "depth24" || value.format == "depth32f"
				|| value.format == "depth24stencil8";
			if (isDepth != depthTarget)
			{
				error = "mock Canvas target role mismatch";
				return false;
			}
			const int mipmaps = value.mipmapMode == "none" ? 1
				: totalMockMipmaps(found->second.first, found->second.second,
					value.type == TextureType::Volume ? value.slices : 1);
			const int slices = value.type == TextureType::Volume
				? std::max(1, value.slices >> target.mipmap) : value.slices;
			if (target.mipmap < 0 || target.mipmap >= mipmaps
				|| target.slice < 0 || target.slice >= slices)
			{
				error = "mock Canvas target subresource mismatch";
				return false;
			}
			const int targetWidth = std::max(1, found->second.first >> target.mipmap);
			const int targetHeight = std::max(1, found->second.second >> target.mipmap);
			if (width == 0) { width = targetWidth; height = targetHeight; msaa = value.msaa; }
			else if (width != targetWidth || height != targetHeight || msaa != value.msaa)
			{
				error = "mock Canvas target dimensions or MSAA differ";
				return false;
			}
			return true;
		};
		for (const auto &target : targets) if (!validate(target, false)) return false;
		if (depthStencil && !validate(*depthStencil, true)) return false;
		if (currentShader != 0)
		{
			for (const auto &[name, texture] : shaderTextures[currentShader])
			{
				if (texture.canvas != 0
					&& (std::any_of(targets.begin(), targets.end(), [&](const auto &target) {
						return target.canvas == texture.canvas;
					}) || (depthStencil && depthStencil->canvas == texture.canvas)))
				{
					error = "mock Canvas feedback through Shader uniform " + name;
					return false;
				}
			}
		}
		currentCanvasTargets.assign(targets.begin(), targets.end());
		currentCanvases.clear();
		for (const auto &target : targets) currentCanvases.push_back(target.canvas);
		currentDepthStencil = depthStencil ? depthStencil->canvas : 0;
		currentCanvasDepth = depth;
		currentCanvasStencil = stencil;
		++canvasSwitches;
		error.clear();
		return true;
	}
	void drawCanvas(CanvasHandle canvas, float sourceX, float sourceY, float sourceWidth, float sourceHeight,
		float a, float b, float c, float d, float tx, float ty, float, float,
		float, float, float, float, TextureFilter filter, TextureWrap wrapU, TextureWrap wrapV) override
	{
		++canvasDraws;
		lastCanvasHandle = canvas;
		canvasSource = {sourceX, sourceY, sourceWidth, sourceHeight};
		canvasMatrix = {a, b, c, d, tx, ty};
		lastCanvasFilter = filter;
		lastCanvasWrapU = wrapU;
		lastCanvasWrapV = wrapV;
	}
	bool drawCanvasLayer(CanvasHandle canvas, int layer,
		float, float, float, float, float, float, float, float, float, float, float, float,
		float, float, float, float, TextureFilter, TextureWrap, TextureWrap,
		std::string &error) override
	{
		const auto settings = canvasSettings.find(canvas);
		if (settings == canvasSettings.end() || settings->second.type != TextureType::Array
			|| layer < 0 || layer >= settings->second.slices)
		{
			error = "mock array Canvas layer draw mismatch";
			return false;
		}
		++canvasLayerDraws;
		lastCanvasLayer = layer;
		error.clear();
		return true;
	}
	bool drawMesh(std::span<const MeshVertex> vertices, std::span<const MeshAttributeData> attributes,
		std::span<const std::uint32_t> indices,
		std::string_view drawMode, ImageHandle image, CanvasHandle canvas, float pointSize,
		TextureFilter, TextureWrap, TextureWrap, std::string &error, int instanceCount = 1) override
	{
		++meshDraws;
		lastMeshVertices.assign(vertices.begin(), vertices.end());
		lastMeshAttributes.assign(attributes.begin(), attributes.end());
		if (meshDraws == 2) attachedMeshVertices = lastMeshVertices;
		lastMeshIndices.assign(indices.begin(), indices.end());
		lastMeshDrawMode = drawMode;
		lastMeshImage = image;
		lastMeshCanvas = canvas;
		lastMeshPointSize = pointSize;
		lastMeshInstanceCount = instanceCount;
		if (currentShader != 0 && image == 0 && canvas == 0)
			++untexturedShaderMeshDraws;
		if (currentShader != 0 && drawMode == "points")
		{
			++shaderPointMeshDraws;
			shaderPointAttributes.assign(attributes.begin(), attributes.end());
		}
		error.clear();
		return true;
	}
	bool drawMeshBuffer(const std::shared_ptr<const MeshBuffer> &buffer,
		std::string_view drawMode, ImageHandle image, CanvasHandle canvas, float pointSize,
		TextureFilter filter, TextureWrap wrapU, TextureWrap wrapV,
		const Transform2D &transform, const std::array<float, 4> &color,
		std::string &error, int instanceCount = 1) override
	{
		++meshBufferDraws;
		lastMeshBuffer = buffer.get();
		lastMeshBufferRevision = buffer ? buffer->revision : 0;
		meshBufferRecords.emplace_back(lastMeshBuffer, lastMeshBufferRevision);
		return GraphicsBackend::drawMeshBuffer(buffer, drawMode, image, canvas, pointSize,
			filter, wrapU, wrapV, transform, color, error, instanceCount);
	}
	bool supportsMeshInstancing(ShaderHandle shader,
		std::size_t perInstanceAttributeCount) const override
	{
		return meshInstancingSupported && shader != 0 && perInstanceAttributeCount <= 5;
	}
	bool requiresMeshInstancing(ShaderHandle shader) const override
	{
		const auto found = shaderRequiresInstancing.find(shader);
		return found != shaderRequiresInstancing.end() && found->second;
	}
	bool requiresMeshVertexID(ShaderHandle shader) const override
	{
		const auto found = shaderRequiresVertexID.find(shader);
		return found != shaderRequiresVertexID.end() && found->second;
	}
	ShaderHandle newShader(std::string_view vertexSource, std::string_view pixelSource,
		std::string &warnings, std::string &error) override
	{
		if (vertexSource.find("compile_error") != std::string_view::npos
			|| pixelSource.find("compile_error") != std::string_view::npos)
		{
			error = "mock Shader compile error at source line 1";
			return 0;
		}
		const ShaderHandle handle = nextShaderHandle++;
		const std::string combined = std::string(vertexSource) + "\n" + std::string(pixelSource);
		shaderRequiresInstancing[handle] = combined.find("love_InstanceID") != std::string::npos;
		shaderRequiresVertexID[handle] = combined.find("love_VertexID") != std::string::npos;
		shaderMainTextureTypes[handle] = combined.find("vec4 effect") != std::string::npos
			? std::optional<TextureType>(TextureType::Texture2D) : std::nullopt;
		auto &shader = shaderUniforms[handle];
		int colorOutputs = 1;
		static const std::regex canvasAccess(R"(\blove_Canvases\s*\[\s*([0-9]+)\s*\])");
		for (std::sregex_iterator it(combined.begin(), combined.end(), canvasAccess), end; it != end; ++it)
			colorOutputs = std::max(colorOutputs, std::stoi((*it)[1].str()) + 1);
		shaderColorOutputs[handle] = colorOutputs;
		for (std::size_t offset = 0; (offset = combined.find("extern ", offset)) != std::string::npos;)
		{
			const std::size_t semicolon = combined.find(';', offset);
			if (semicolon == std::string::npos) break;
			std::string declaration = combined.substr(offset + 7, semicolon - offset - 7);
			if (const auto equals = declaration.find('='); equals != std::string::npos)
				declaration.resize(equals);
			while (!declaration.empty() && std::isspace(static_cast<unsigned char>(declaration.back())))
				declaration.pop_back();
			const std::size_t nameStart = declaration.find_last_of(" \t");
			std::string name = declaration.substr(nameStart == std::string::npos ? 0 : nameStart + 1);
			int count = 1;
			if (const auto bracket = name.find('['); bracket != std::string::npos)
			{
				const auto close = name.find(']', bracket + 1);
				const std::string countText = name.substr(bracket + 1, close - bracket - 1);
				std::from_chars(countText.data(), countText.data() + countText.size(), count);
				name.resize(bracket);
			}
			if (!name.empty())
			{
				const std::string type = declaration.substr(0, declaration.find_first_of(" \t"));
				ShaderUniformInfo info;
				info.count = count;
				if (type == "Image" || type == "ArrayImage" || type == "CubeImage" || type == "VolumeImage")
				{
					info.type = ShaderUniformType::Sampler;
					info.components = 0;
					if (type == "ArrayImage") info.textureType = TextureType::Array;
					else if (type == "CubeImage") info.textureType = TextureType::Cube;
					else if (type == "VolumeImage") info.textureType = TextureType::Volume;
					if (name == "MainTex") shaderMainTextureTypes[handle] = info.textureType;
				}
				else if (type == "mat2") { info.type = ShaderUniformType::Matrix; info.components = 4; }
				else if (type == "mat3") { info.type = ShaderUniformType::Matrix; info.components = 9; }
				else if (type == "mat4") { info.type = ShaderUniformType::Matrix; info.components = 16; }
				else if (type == "int" || type.starts_with("ivec")) info.type = ShaderUniformType::Int;
				else if (type == "uint" || type.starts_with("uvec")) info.type = ShaderUniformType::UInt;
				else if (type == "bool" || type.starts_with("bvec")) info.type = ShaderUniformType::Bool;
				if (type.ends_with("vec4") || type == "vec4") info.components = 4;
				else if (type.ends_with("vec3") || type == "vec3") info.components = 3;
				else if (type.ends_with("vec2") || type == "vec2") info.components = 2;
				shaderUniformInfos[handle].emplace(name, info);
				shader.emplace(std::move(name), std::vector<float>{});
			}
			offset = semicolon + 1;
		}
		warnings = combined.find("mock_warning") == std::string::npos ? "" : "mock Shader warning";
		++shadersCreated;
		error.clear();
		return handle;
	}
	void releaseShader(ShaderHandle shader) override
	{
		if (shaderUniforms.erase(shader) != 0) ++shadersReleased;
		shaderTextures.erase(shader);
		shaderUniformInfos.erase(shader);
		shaderColorOutputs.erase(shader);
		shaderRequiresInstancing.erase(shader);
		shaderRequiresVertexID.erase(shader);
		shaderMainTextureTypes.erase(shader);
		if (currentShader == shader) currentShader = 0;
	}
	bool hasShaderUniform(ShaderHandle shader, std::string_view name) const override
	{
		const auto found = shaderUniforms.find(shader);
		return found != shaderUniforms.end() && found->second.contains(std::string(name));
	}
	bool getShaderUniformInfo(ShaderHandle shader, std::string_view name,
		ShaderUniformInfo &info) const override
	{
		const auto found = shaderUniformInfos.find(shader);
		if (found == shaderUniformInfos.end()) return false;
		const auto uniform = found->second.find(std::string(name));
		if (uniform == found->second.end()) return false;
		info = uniform->second;
		return true;
	}
	bool sendShaderFloats(ShaderHandle shader, std::string_view name,
		std::span<const float> values, bool colors, std::string &error) override
	{
		const auto found = shaderUniforms.find(shader);
		if (found == shaderUniforms.end() || !found->second.contains(std::string(name)))
		{
			error = "mock Shader uniform is missing";
			return false;
		}
		const auto info = shaderUniformInfos[shader].at(std::string(name));
		if (info.type == ShaderUniformType::Sampler)
		{
			error = "mock Shader uniform is an Image sampler";
			return false;
		}
		if (values.empty() || values.size() % static_cast<std::size_t>(info.components) != 0
			|| values.size() / static_cast<std::size_t>(info.components) > static_cast<std::size_t>(info.count))
		{
			error = "mock Shader uniform value count mismatch";
			return false;
		}
		found->second[std::string(name)] = {values.begin(), values.end()};
		lastShaderSendWasColor = colors;
		error.clear();
		return true;
	}
	bool sendShaderTextures(ShaderHandle shader, std::string_view name,
		std::span<const ShaderTexture> textures, std::string &error) override
	{
		const auto found = shaderUniforms.find(shader);
		if (found == shaderUniforms.end() || !found->second.contains(std::string(name)))
		{
			error = "mock Shader uniform is missing";
			return false;
		}
		const auto info = shaderUniformInfos[shader].at(std::string(name));
		if (info.type != ShaderUniformType::Sampler)
		{
			error = "mock Shader uniform is numeric";
			return false;
		}
		if (textures.empty() || textures.size() > static_cast<std::size_t>(info.count))
		{
			error = "mock Shader texture count mismatch";
			return false;
		}
		for (const auto &texture : textures)
		{
			if (texture.image != 0 && getImageTextureType(texture.image) != info.textureType)
			{
				error = "mock Shader texture type mismatch";
				return false;
			}
			if (texture.canvas != 0 && info.textureType != TextureType::Texture2D)
			{
				error = "mock Canvas requires a 2D sampler";
				return false;
			}
			if (texture.canvas != 0
				&& std::find(currentCanvases.begin(), currentCanvases.end(), texture.canvas) != currentCanvases.end())
			{
				error = "mock Canvas feedback";
				return false;
			}
		}
		for (std::size_t index = 0; index < textures.size(); ++index)
		{
			const std::string elementName = info.count == 1 ? std::string(name)
				: std::string(name) + "[" + std::to_string(index + 1) + "]";
			const auto &texture = textures[index];
			shaderTextures[shader][elementName] = {
				texture.image, texture.canvas, texture.filter, texture.wrapU, texture.wrapV, texture.wrapW};
		}
		error.clear();
		return true;
	}
	bool setShader(ShaderHandle shader, std::string &error) override
	{
		if (shader != 0 && !shaderUniforms.contains(shader))
		{
			error = "mock Shader is closed";
			return false;
		}
		if (shader != 0)
		{
			for (const auto &[name, texture] : shaderTextures[shader])
			{
				if (texture.canvas != 0
					&& std::find(currentCanvases.begin(), currentCanvases.end(), texture.canvas) != currentCanvases.end())
				{
					error = "mock Canvas feedback through Shader uniform " + name;
					return false;
				}
			}
		}
		currentShader = shader;
		shaderSelections.push_back(shader);
		error.clear();
		return true;
	}
	bool validateShaderDraw(std::string &error,
		TextureType mainTextureType = TextureType::Texture2D) const override
	{
		if (currentShader == 0)
		{
			error.clear();
			return true;
		}
		const int available = currentCanvases.empty() ? 1 : static_cast<int>(currentCanvases.size());
		const int required = shaderColorOutputs.at(currentShader);
		if (required > available)
		{
			error = "mock Shader output count exceeds current Canvas count";
			return false;
		}
		const auto type = shaderMainTextureTypes.find(currentShader);
		if (type != shaderMainTextureTypes.end() && type->second
			&& *type->second != mainTextureType)
		{
			error = "mock Shader main texture type mismatch";
			return false;
		}
		error.clear();
		return true;
	}
	FontHandle newFont(const std::string &filename, int size, std::string &error) override
	{
		lastFontFilename = filename;
		lastFontSize = size;
		error.clear();
		const FontHandle handle = nextFontHandle++;
		fontSizes.emplace(handle, size);
		++fontsCreated;
		return handle;
	}
	FontHandle newImageFont(int width, int height, std::span<const std::uint8_t> rgba8,
		std::span<const ImageFontGlyph> glyphs, float dpiScale, TextureFilter filter,
		std::string &error) override
	{
		if (width <= 0 || height <= 0 || rgba8.size() != static_cast<std::size_t>(width) * height * 4
			|| !std::isfinite(dpiScale) || dpiScale <= 0.0f)
		{
			error = "invalid mock ImageFont";
			return 0;
		}
		const FontHandle handle = nextFontHandle++;
		fontSizes.emplace(handle, static_cast<int>(std::floor(height / dpiScale + 0.5f)));
		imageFontDPIScales.emplace(handle, dpiScale);
		auto &stored = imageFontGlyphs[handle];
		for (const auto &glyph : glyphs) stored.emplace(glyph.codepoint, glyph);
		if (lastImageFontPixels.empty())
		{
			lastImageFontWidth = width;
			lastImageFontHeight = height;
			lastImageFontPixels.assign(rgba8.begin(), rgba8.end());
			lastImageFontFilter = filter;
		}
		++fontsCreated;
		error.clear();
		return handle;
	}
	FontHandle newBMFont(std::span<const BMFontPage> pages, std::span<const BMFontGlyph> glyphs,
		int lineHeight, int baseline, float dpiScale, TextureFilter filter, std::string &error) override
	{
		if (pages.empty() || glyphs.empty() || lineHeight <= 0 || !std::isfinite(dpiScale) || dpiScale <= 0.0f)
		{
			error = "invalid mock BMFont";
			return 0;
		}
		for (const auto &page : pages)
			if (page.width <= 0 || page.height <= 0
				|| page.rgba8.size() != static_cast<std::size_t>(page.width) * page.height * 4)
			{
				error = "invalid mock BMFont page";
				return 0;
			}
		const FontHandle handle = nextFontHandle++;
		fontSizes.emplace(handle, static_cast<int>(std::floor(lineHeight / dpiScale + 0.5f)));
		imageFontDPIScales.emplace(handle, dpiScale);
		imageFontBaselines.emplace(handle, static_cast<float>(baseline) / dpiScale);
		auto &stored = imageFontGlyphs[handle];
		for (const auto &glyph : glyphs)
			stored.emplace(glyph.codepoint, ImageFontGlyph{glyph.codepoint, glyph.x, glyph.width, glyph.advance});
		lastBMFontPageCount = static_cast<int>(pages.size());
		lastBMFontGlyphCount = static_cast<int>(glyphs.size());
		lastBMFontFilter = filter;
		++bmFontsCreated;
		++fontsCreated;
		error.clear();
		return handle;
	}
	void releaseFont(FontHandle font) override
	{
		fontLineHeights.erase(font);
		fontFallbacks.erase(font);
		imageFontGlyphs.erase(font);
		imageFontDPIScales.erase(font);
		imageFontBaselines.erase(font);
		if (fontSizes.erase(font) != 0)
			++fontsReleased;
	}
	float getFontWidth(FontHandle font, std::string_view text) const override
	{
		if (const auto image = imageFontGlyphs.find(font); image != imageFontGlyphs.end())
		{
			float width = 0.0f, maximum = 0.0f;
			for (std::size_t index = 0; index < text.size();)
			{
				const auto first = static_cast<unsigned char>(text[index]);
				std::uint32_t codepoint = first;
				std::size_t length = 1;
				if ((first & 0xe0) == 0xc0) { codepoint = first & 0x1f; length = 2; }
				else if ((first & 0xf0) == 0xe0) { codepoint = first & 0x0f; length = 3; }
				else if ((first & 0xf8) == 0xf0) { codepoint = first & 0x07; length = 4; }
				for (std::size_t byte = 1; byte < length && index + byte < text.size(); ++byte)
					codepoint = (codepoint << 6) | (static_cast<unsigned char>(text[index + byte]) & 0x3f);
				index += length;
				if (codepoint == '\n') { maximum = std::max(maximum, width); width = 0.0f; continue; }
				auto addGlyph = [&](FontHandle candidate) {
					const auto candidateGlyphs = imageFontGlyphs.find(candidate);
					if (candidateGlyphs == imageFontGlyphs.end()) return false;
					const auto glyph = candidateGlyphs->second.find(codepoint);
					if (glyph == candidateGlyphs->second.end()) return false;
					width += std::floor(glyph->second.advance
						/ imageFontDPIScales.at(candidate) + 0.5f);
					return true;
				};
				if (!addGlyph(font))
					if (const auto fallbacks = fontFallbacks.find(font); fallbacks != fontFallbacks.end())
						for (const auto fallback : fallbacks->second) if (addGlyph(fallback)) break;
			}
			return std::max(maximum, width);
		}
		const auto found = fontSizes.find(font);
		return found == fontSizes.end() ? 0.0f : static_cast<float>(text.size() * found->second) * 0.5f;
	}
	float getFontGlyphSpacing(FontHandle font, std::uint32_t codepoint) const override
	{
		if (const auto image = imageFontGlyphs.find(font); image != imageFontGlyphs.end())
		{
			auto findGlyph = [&](FontHandle candidate) -> const ImageFontGlyph * {
				const auto candidateGlyphs = imageFontGlyphs.find(candidate);
				if (candidateGlyphs == imageFontGlyphs.end()) return nullptr;
				const auto glyph = candidateGlyphs->second.find(codepoint);
				return glyph == candidateGlyphs->second.end() ? nullptr : &glyph->second;
			};
			if (const auto *glyph = findGlyph(font))
				return std::floor(glyph->advance / imageFontDPIScales.at(font) + 0.5f);
			if (const auto fallbacks = fontFallbacks.find(font); fallbacks != fontFallbacks.end())
				for (const auto fallback : fallbacks->second)
					if (const auto *glyph = findGlyph(fallback))
						return std::floor(glyph->advance / imageFontDPIScales.at(fallback) + 0.5f);
			return 0.0f;
		}
		const auto found = fontSizes.find(font);
		return found == fontSizes.end() ? 0.0f : static_cast<float>(found->second) * 0.5f;
	}
	float getFontHeight(FontHandle font) const override
	{
		const auto found = fontSizes.find(font);
		return found == fontSizes.end() ? 0.0f : static_cast<float>(found->second);
	}
	float getFontBaseline(FontHandle font) const override
	{
		if (const auto baseline = imageFontBaselines.find(font); baseline != imageFontBaselines.end())
			return baseline->second;
		return imageFontGlyphs.contains(font) ? 0.0f : getFontHeight(font) * 0.8f;
	}
	float getFontAscent(FontHandle font) const override
	{ return getFontBaseline(font); }
	float getFontDescent(FontHandle font) const override
	{ return imageFontGlyphs.contains(font) ? 0.0f : -getFontHeight(font) * 0.2f; }
	bool hasFontGlyph(FontHandle font, std::uint32_t codepoint) const override
	{
		if (const auto image = imageFontGlyphs.find(font); image != imageFontGlyphs.end())
		{
			if (image->second.contains(codepoint)) return true;
			if (const auto fallbacks = fontFallbacks.find(font); fallbacks != fontFallbacks.end())
				for (const auto fallback : fallbacks->second)
					if (const auto candidate = imageFontGlyphs.find(fallback);
						candidate != imageFontGlyphs.end() && candidate->second.contains(codepoint)) return true;
			return false;
		}
		return fontSizes.contains(font) && codepoint != 0x10ffff;
	}
	float getFontKerning(FontHandle font, std::uint32_t left, std::uint32_t right) const override
	{
		if (imageFontGlyphs.contains(font)) return 0.0f;
		return fontSizes.contains(font) && left == 'A' && right == 'V' ? -1.5f : 0.0f;
	}
	bool setFontFallbacks(FontHandle font, std::span<const FontHandle> fallbacks,
		std::string &error) override
	{
		if (!fontSizes.contains(font))
		{
			error = "mock Font is closed";
			return false;
		}
		const bool imageFont = imageFontGlyphs.contains(font);
		for (const auto fallback : fallbacks)
		{
			if (!fontSizes.contains(fallback))
			{
				error = "mock fallback Font is closed";
				return false;
			}
			if (imageFontGlyphs.contains(fallback) != imageFont)
			{
				error = "mock Font fallback rasterizer type mismatch";
				return false;
			}
		}
		fontFallbacks[font].assign(fallbacks.begin(), fallbacks.end());
		lastFontFallbacks.assign(fallbacks.begin(), fallbacks.end());
		error.clear();
		return true;
	}
	void setFontLineHeight(FontHandle font, float lineHeight) override
	{
		fontLineHeights[font] = lineHeight;
	}
	float getFontLineHeight(FontHandle font) const override
	{
		const auto found = fontLineHeights.find(font);
		return found == fontLineHeights.end() ? 1.0f : found->second;
	}
	float getFontWrap(FontHandle font, std::string_view text, float limit, std::vector<std::string> &lines) const override
	{
		if (text == "a b")
			lines = {"a b"};
		else
			lines = {"hello", "world"};
		float width = 0.0f;
		for (const auto &line : lines) width = std::max(width, getFontWidth(font, line));
		return std::min(limit, width);
	}
	void drawText(FontHandle font, std::string_view text, float wrapLimit, std::string_view align,
		float a, float b, float c, float d, float tx, float ty, float, float,
		float red, float green, float blue, float alpha) override
	{
		++textDraws;
		lastTextFont = font;
		lastText = text;
		lastTextWrapLimit = wrapLimit;
		lastTextAlign = align;
		textMatrix = {a, b, c, d, tx, ty};
		textDrawRecords.push_back({font, std::string(text), {a, b, c, d, tx, ty},
			{red, green, blue, alpha}});
	}
	bool setBlendMode(std::string_view mode, std::string_view alphaMode, std::string &error) override
	{
		if (mode == "multiply" && alphaMode != "premultiplied")
		{
			error = "multiply requires premultiplied alpha";
			return false;
		}
		lastBlendMode = mode;
		lastBlendAlphaMode = alphaMode;
		++blendChanges;
		error.clear();
		return true;
	}
	void setScissor(bool enabled, float x, float y, float width, float height) override
	{
		scissorEnabled = enabled;
		lastScissor = {x, y, width, height};
		++scissorChanges;
	}
	void setColorMask(bool red, bool green, bool blue, bool alpha) override
	{
		colorMask = {red, green, blue, alpha};
		++colorMaskChanges;
	}
	void setDepthMode(std::string_view compare, bool write) override
	{
		lastDepthCompare = compare;
		depthWrite = write;
		++depthModeChanges;
	}
	void setMeshCullMode(std::string_view mode, std::string_view winding) override
	{
		lastMeshCullMode = mode;
		lastFrontFaceWinding = winding;
		++meshCullChanges;
	}
	void setWireframe(bool enabled) override
	{
		wireframe = enabled;
		++wireframeChanges;
	}
	bool clearStencil(int value, std::string &error) override
	{
		if (!currentCanvases.empty() && !currentCanvasStencil)
		{
			error = "mock Canvas stencil is disabled";
			return false;
		}
		++stencilClears;
		lastStencilClearValue = value;
		error.clear();
		return true;
	}
	bool beginStencilWrite(std::string_view action, int value, std::string &error) override
	{
		if (!currentCanvases.empty() && !currentCanvasStencil)
		{
			error = "mock Canvas stencil is disabled";
			return false;
		}
		++stencilWrites;
		stencilWriting = true;
		lastStencilAction = action;
		lastStencilWriteValue = value;
		error.clear();
		return true;
	}
	void endStencilWrite() override
	{
		++stencilWriteEnds;
		stencilWriting = false;
	}
	void setStencilTest(std::string_view compare, int value) override
	{
		++stencilTestChanges;
		lastStencilCompare = compare;
		lastStencilTestValue = value;
	}
	bool setMode(int width, int height, std::string &error) override
	{
		pixelWidth = width;
		pixelHeight = height;
		error.clear();
		++modeChanges;
		return true;
	}
	bool requestScreenshot(std::uint64_t requestId, std::string &error) override
	{
		if (rejectScreenshot)
		{
			error = "mock screenshot backend rejected the request";
			return false;
		}
		screenshotRequests.push_back(requestId);
		error.clear();
		return true;
	}
	void endFrame() override { ++ends; }
	int getPixelWidth() const override
	{
		return pixelWidth;
	}
	int getPixelHeight() const override
	{
		return pixelHeight;
	}

	int begins = 0;
	int clears = 0;
	std::vector<ClearRequest> clearRequests;
	int rectangles = 0;
	int circles = 0;
	int lines = 0;
	int polygons = 0;
	int pointCalls = 0;
	int imagesCreated = 0;
	int imagesReleased = 0;
	int imageUpdates = 0;
	int imageDraws = 0;
	int imageLayerDraws = 0;
	int canvasesCreated = 0;
	int canvasesReleased = 0;
	int canvasSwitches = 0;
	int canvasDraws = 0;
	int imageDataDecodes = 0;
	int compressedImageDecodes = 0;
	int compressedImagesCreated = 0;
	int imageDataEncodes = 0;
	bool rejectImageDataEncode = false;
	std::string lastImageDataEncodeFormat;
	int lastImageDataEncodeWidth = 0;
	int lastImageDataEncodeHeight = 0;
	std::vector<std::uint8_t> lastImageDataEncodePixels;
	int ends = 0;
	int modeChanges = 0;
	int blendChanges = 0;
	int scissorChanges = 0;
	int colorMaskChanges = 0;
	int depthModeChanges = 0;
	int meshCullChanges = 0;
	int wireframeChanges = 0;
	int meshDraws = 0;
	int meshBufferDraws = 0;
	const MeshBuffer *lastMeshBuffer = nullptr;
	std::uint64_t lastMeshBufferRevision = 0;
	std::vector<std::pair<const MeshBuffer *, std::uint64_t>> meshBufferRecords;
	int untexturedShaderMeshDraws = 0;
	int shaderPointMeshDraws = 0;
	int shaderPrimitiveDraws = 0;
	int shadersCreated = 0;
	int shadersReleased = 0;
	int stencilClears = 0;
	int stencilWrites = 0;
	int stencilWriteEnds = 0;
	int stencilTestChanges = 0;
	int lastStencilClearValue = 0;
	int lastStencilWriteValue = 0;
	int lastStencilTestValue = 0;
	bool stencilWriting = false;
	bool currentCanvasStencil = false;
	std::string lastStencilAction;
	std::string lastStencilCompare = "always";
	int fontsCreated = 0;
	int fontsReleased = 0;
	int textDraws = 0;
	int pixelWidth = 800;
	int pixelHeight = 600;
	bool rejectScreenshot = false;
	std::vector<std::uint64_t> screenshotRequests;
	std::size_t linePointCount = 0;
	std::vector<float> lastLinePoints;
	bool lastRectangleFilled = false;
	LineStyle lastLineStyle = LineStyle::Smooth;
	LineJoin lastLineJoin = LineJoin::Miter;
	Stats stats{7, 3, 2, 4, 5, 6, 8, 4096};
	bool lastPolygonFilled = false;
	std::vector<float> lastPolygonPoints;
	std::vector<float> lastPoints;
	float lastPointSize = 0.0f;
	std::string lastImageFilename;
	std::string lastCompressedImageFormat;
	int lastCompressedImageMipmaps = 0;
	TextureType lastCompressedImageType = TextureType::Texture2D;
	int lastCompressedImageSlices = 0;
	std::vector<std::uint8_t> lastCompressedImageBytes;
	std::array<int, 7> lastImageReplacement{};
	int imageReplacements = 0;
	struct LayeredImage
	{
		TextureType type = TextureType::Texture2D;
		int width = 0;
		int height = 0;
		int slices = 0;
		std::vector<std::uint8_t> pixels;
		std::vector<ImageLevel> levels;
	};
	std::unordered_map<ImageHandle, LayeredImage> layeredImages;
	ImageHandle nextImageHandle = 1;
	ImageHandle lastImageHandle = 0;
	ImageHandle lastImageLayerHandle = 0;
	int lastImageLayer = -1;
	std::vector<float> imageMatrix;
	std::vector<float> imageSource;
	std::vector<std::vector<float>> imageSources;
	std::vector<float> imageLayerMatrix;
	std::vector<float> imageLayerSource;
	CanvasHandle nextCanvasHandle = 100;
	std::unordered_map<CanvasHandle, std::pair<int, int>> canvases;
	struct StoredCanvasSettings
	{
		std::string format;
		TextureType type = TextureType::Texture2D;
		int slices = 1;
		std::string mipmapMode = "none";
		float dpiScale = 1.0f;
		int msaa = 0;
		bool readable = true;
	};
	std::unordered_map<CanvasHandle, StoredCanvasSettings> canvasSettings;
	std::vector<CanvasHandle> currentCanvases;
	std::vector<CanvasTarget> currentCanvasTargets;
	CanvasHandle currentDepthStencil = 0;
	bool currentCanvasDepth = false;
	CanvasHandle lastCanvasHandle = 0;
	std::vector<float> canvasSource;
	std::vector<float> canvasMatrix;
	std::vector<int> lastCanvasRead;
	int canvasReads = 0;
	CanvasHandle lastGeneratedCanvas = 0;
	int canvasMipmapGenerations = 0;
	int canvasLayerDraws = 0;
	int lastCanvasLayer = -1;
	TextureFilter lastCanvasFilter = TextureFilter::Linear;
	TextureWrap lastCanvasWrapU = TextureWrap::Clamp;
	TextureWrap lastCanvasWrapV = TextureWrap::Clamp;
	TextureFilter lastImageFilter = TextureFilter::Linear;
	TextureWrap lastImageWrapU = TextureWrap::Clamp;
	TextureWrap lastImageWrapV = TextureWrap::Clamp;
	std::string lastBlendMode;
	std::string lastBlendAlphaMode;
	bool scissorEnabled = false;
	std::vector<float> lastScissor;
	std::array<bool, 4> colorMask = {true, true, true, true};
	std::string lastDepthCompare = "always";
	bool depthWrite = false;
	std::string lastMeshCullMode = "none";
	bool wireframe = false;
	std::string lastFrontFaceWinding = "ccw";
	std::vector<MeshVertex> lastMeshVertices;
	std::vector<MeshVertex> attachedMeshVertices;
	std::vector<MeshAttributeData> lastMeshAttributes;
	std::vector<MeshAttributeData> shaderPointAttributes;
	std::vector<std::uint32_t> lastMeshIndices;
	std::string lastMeshDrawMode;
	ImageHandle lastMeshImage = 0;
	CanvasHandle lastMeshCanvas = 0;
	float lastMeshPointSize = 0.0f;
	int lastMeshInstanceCount = 1;
	bool meshInstancingSupported = true;
	ShaderHandle nextShaderHandle = 200;
	ShaderHandle currentShader = 0;
	bool lastShaderSendWasColor = false;
	struct MockShaderTexture
	{
		ImageHandle image = 0;
		CanvasHandle canvas = 0;
		TextureFilter filter = TextureFilter::Linear;
		TextureWrap wrapU = TextureWrap::Clamp;
		TextureWrap wrapV = TextureWrap::Clamp;
		TextureWrap wrapW = TextureWrap::Clamp;
	};
	std::unordered_map<ShaderHandle, std::unordered_map<std::string, std::vector<float>>> shaderUniforms;
	std::unordered_map<ShaderHandle, std::unordered_map<std::string, MockShaderTexture>> shaderTextures;
	std::unordered_map<ShaderHandle, std::unordered_map<std::string, ShaderUniformInfo>> shaderUniformInfos;
	std::unordered_map<ShaderHandle, int> shaderColorOutputs;
	std::unordered_map<ShaderHandle, bool> shaderRequiresInstancing;
	std::unordered_map<ShaderHandle, bool> shaderRequiresVertexID;
	std::unordered_map<ShaderHandle, std::optional<TextureType>> shaderMainTextureTypes;
	std::vector<ShaderHandle> shaderSelections;
	FontHandle nextFontHandle = 10;
	std::unordered_map<FontHandle, int> fontSizes;
	std::unordered_map<FontHandle, std::unordered_map<std::uint32_t, ImageFontGlyph>> imageFontGlyphs;
	std::unordered_map<FontHandle, float> imageFontDPIScales;
	std::unordered_map<FontHandle, float> imageFontBaselines;
	std::unordered_map<FontHandle, float> fontLineHeights;
	std::unordered_map<FontHandle, std::vector<FontHandle>> fontFallbacks;
	std::vector<FontHandle> lastFontFallbacks;
	std::string lastFontFilename;
	int lastFontSize = 0;
	int lastImageFontWidth = 0;
	int lastImageFontHeight = 0;
	std::vector<std::uint8_t> lastImageFontPixels;
	TextureFilter lastImageFontFilter = TextureFilter::Linear;
	int bmFontsCreated = 0;
	int lastBMFontPageCount = 0;
	int lastBMFontGlyphCount = 0;
	TextureFilter lastBMFontFilter = TextureFilter::Linear;
	FontHandle lastTextFont = 0;
	std::string lastText;
	float lastTextWrapLimit = -1.0f;
	std::string lastTextAlign;
	std::vector<float> textMatrix;
	struct TextDrawRecord
	{
		FontHandle font = 0;
		std::string text;
		std::array<float, 6> matrix{};
		std::array<float, 4> color{};
	};
	std::vector<TextDrawRecord> textDrawRecords;
};

class TestFilesystemBackend final : public Dora::Love::FilesystemBackend
{
public:
	~TestFilesystemBackend() override
	{
		for (const auto &root : mountedRoots)
		{
			std::error_code error;
			std::filesystem::remove_all(root, error);
		}
	}
	bool exist(const std::string &path) const override { return std::filesystem::exists(path); }
	bool isFolder(const std::string &path) const override { return std::filesystem::is_directory(path); }
	std::string getExecutablePath() const override { return "/mock/Dora"; }
	bool load(const std::string &path, std::string &data, std::string &error) const override
	{
		loadedPaths.push_back(path);
		std::ifstream input(path, std::ios::binary);
		if (!input)
		{
			error = "test filesystem failed to load: " + path;
			return false;
		}
		std::ostringstream content;
		content << input.rdbuf();
		data = content.str();
		error.clear();
		return true;
	}
	bool save(const std::string &path, std::string_view data, std::string &error) override
	{
		std::ofstream output(path, std::ios::binary | std::ios::trunc);
		if (!output || !output.write(data.data(), static_cast<std::streamsize>(data.size())))
		{
			error = "test filesystem failed to save: " + path;
			return false;
		}
		error.clear();
		return true;
	}
	bool createFolder(const std::string &path, std::string &error) override
	{
		std::error_code pathError;
		const bool created = std::filesystem::create_directories(path, pathError);
		if (!pathError && (created || std::filesystem::is_directory(path)))
		{
			error.clear();
			return true;
		}
		error = pathError.message();
		return false;
	}
	bool remove(const std::string &path, std::string &error) override
	{
		std::error_code pathError;
		const bool removed = std::filesystem::remove(path, pathError);
		if (removed && !pathError)
		{
			error.clear();
			return true;
		}
		error = pathError ? pathError.message() : "entry does not exist";
		return false;
	}
	std::optional<std::uint64_t> getFileSize(const std::string &path) const override
	{
		std::error_code pathError;
		const auto size = std::filesystem::file_size(path, pathError);
		return pathError ? std::nullopt : std::optional<std::uint64_t>(size);
	}
	std::vector<std::string> getDirectoryItems(const std::string &path) const override
	{
		std::vector<std::string> items;
		std::error_code pathError;
		for (std::filesystem::directory_iterator it(path, pathError), end; !pathError && it != end; it.increment(pathError))
			items.push_back(it->path().filename().string());
		return items;
	}
	bool mountArchive(std::string_view archiveName, std::string_view data,
		std::string &mountedRoot, std::string &error) override
	{
		if (data.empty() || data == "invalid")
		{
			error = "test mount rejected archive";
			return false;
		}
		mountedRoot = (std::filesystem::temp_directory_path()
			/ ("dora-love-mount-" + std::to_string(++mountSequence))).string();
		std::error_code pathError;
		std::filesystem::create_directories(mountedRoot, pathError);
		if (pathError)
		{
			error = pathError.message();
			return false;
		}
		mountedRoots.insert(mountedRoot);
		std::size_t start = 0;
		while (start <= data.size())
		{
			const std::size_t end = data.find('\n', start);
			const std::string_view entry = data.substr(start,
				end == std::string_view::npos ? data.size() - start : end - start);
			const std::size_t separator = entry.find(':');
			if (separator == std::string_view::npos || separator == 0)
			{
				unmountArchive(mountedRoot);
				error = "test mount entry is invalid";
				return false;
			}
			const auto target = std::filesystem::path(mountedRoot)
				/ std::string(entry.substr(0, separator));
			std::filesystem::create_directories(target.parent_path(), pathError);
			std::ofstream output(target, std::ios::binary | std::ios::trunc);
			const std::string_view contents = entry.substr(separator + 1);
			if (pathError || !output.write(contents.data(), static_cast<std::streamsize>(contents.size())))
			{
				unmountArchive(mountedRoot);
				error = "test mount failed to stage entry";
				return false;
			}
			if (end == std::string_view::npos) break;
			start = end + 1;
		}
		error.clear();
		return true;
	}
	void unmountArchive(const std::string &mountedRoot) override
	{
		std::error_code error;
		std::filesystem::remove_all(mountedRoot, error);
		mountedRoots.erase(mountedRoot);
	}

	std::uint64_t mountSequence = 0;
	std::set<std::string> mountedRoots;
	mutable std::vector<std::string> loadedPaths;
};

class MockSound final : public Dora::Love::SoundBackend
{
public:
	bool decodeSound(std::string_view encoded, int &sampleRate, int &channels,
		std::vector<float> &samples, std::string &error) override
	{
		++decodes;
		if (encoded != "encoded-sound" && encoded != "encoded-sound\n")
		{
			error = "mock SoLoud decoder rejected encoded data";
			return false;
		}
		sampleRate = 22050;
		channels = 2;
		samples = {1.0f, -1.0f, 0.5f, -0.5f};
		error.clear();
		return true;
	}

	int decodes = 0;
};

class MockAudio final : public Dora::Love::AudioBackend
{
public:
	struct Source
	{
		std::string filename;
		std::string type;
		bool playing = false;
		bool paused = false;
		bool looping = false;
		float volume = 1.0f;
		float pitch = 1.0f;
		double position = 0.0;
		double duration = 2.5;
		double sampleRate = 1000.0;
		double sampleCount = 2500.0;
		int channelCount = 2;
		int bitDepth = 16;
		int bufferCount = 0;
		std::vector<std::size_t> queuedBuffers;
		std::array<float, 3> spatialPosition{0.0f, 0.0f, 0.0f};
		std::array<float, 3> velocity{0.0f, 0.0f, 0.0f};
		std::array<float, 3> direction{0.0f, 0.0f, 0.0f};
		float coneInnerAngle = 6.28318530717958647692f;
		float coneOuterAngle = 6.28318530717958647692f;
		float coneOuterVolume = 0.0f;
		float coneOuterHighGain = 1.0f;
		float airAbsorptionFactor = 0.0f;
		float minVolume = 0.0f;
		float maxVolume = 1.0f;
		bool relative = false;
		float referenceDistance = 1.0f;
		float maxDistance = 1000000.0f;
		float rolloff = 1.0f;
		std::optional<FilterSettings> filter;
		std::map<std::string, std::optional<FilterSettings>> effects;
	};

	SourceHandle newSource(const std::string &filename, std::string_view sourceType,
		std::string &error) override
	{
		const bool rejectedFilename = std::any_of(unavailableSourceSuffixes.begin(),
			unavailableSourceSuffixes.end(), [&](const std::string &suffix) {
				return filename.ends_with(suffix);
			});
		if (!sourceCreationAvailable || rejectedFilename)
		{
			error = "mock Dora Content/SoLoud source creation unavailable";
			return 0;
		}
		const SourceHandle handle = nextHandle++;
		sources.emplace(handle, Source{filename, std::string(sourceType)});
		error.clear();
		return handle;
	}
	SourceHandle newSourceFromSoundData(std::string_view pcm, int sampleRate,
		int bitDepth, int channels, std::string &error) override
	{
		if (!sourceCreationAvailable || pcm.empty())
		{
			error = "mock Dora SoundData source creation unavailable";
			return 0;
		}
		const SourceHandle handle = nextHandle++;
		Source source{"<SoundData>", "static"};
		source.sampleRate = sampleRate;
		source.duration = static_cast<double>(pcm.size())
			/ static_cast<double>(bitDepth / 8 * channels) / sampleRate;
		source.sampleCount = static_cast<double>(pcm.size())
			/ static_cast<double>(bitDepth / 8 * channels);
		source.channelCount = channels;
		sources.emplace(handle, std::move(source));
		lastPCMSize = pcm.size();
		lastPCMSampleRate = sampleRate;
		lastPCMBitDepth = bitDepth;
		lastPCMChannels = channels;
		error.clear();
		return handle;
	}
	SourceHandle newQueueableSource(int sampleRate, int bitDepth, int channels,
		int buffers, std::string &error) override
	{
		if (!sourceCreationAvailable || sampleRate <= 0
			|| (bitDepth != 8 && bitDepth != 16) || (channels != 1 && channels != 2))
		{
			error = "mock Dora PCM queue creation unavailable";
			return 0;
		}
		const SourceHandle handle = nextHandle++;
		Source source{"<Queue>", "queue"};
		source.sampleRate = sampleRate;
		source.sampleCount = 0.0;
		source.duration = 0.0;
		source.channelCount = channels;
		source.bitDepth = bitDepth;
		source.bufferCount = buffers < 1 ? 8 : std::min(buffers, 64);
		sources.emplace(handle, std::move(source));
		error.clear();
		return handle;
	}
	SourceHandle cloneSource(SourceHandle source, std::string &error) override
	{
		const auto found = sources.find(source);
		if (!cloneCreationAvailable || found == sources.end())
		{
			error = "mock Dora AudioSource clone unavailable";
			return 0;
		}
		const SourceHandle handle = nextHandle++;
		Source clone = found->second;
		clone.playing = false;
		clone.paused = false;
		clone.position = 0.0;
		if (clone.type == "queue")
		{
			clone.queuedBuffers.clear();
			clone.sampleCount = 0.0;
			clone.duration = 0.0;
		}
		sources.emplace(handle, std::move(clone));
		error.clear();
		return handle;
	}
	bool queueSource(SourceHandle source, std::string_view pcm, int sampleRate,
		int bitDepth, int channels, std::string &error) override
	{
		auto found = sources.find(source);
		if (found == sources.end() || found->second.type != "queue")
		{
			error = "only queueable mock Sources accept PCM";
			return false;
		}
		auto &value = found->second;
		if (sampleRate != value.sampleRate || bitDepth != value.bitDepth
			|| channels != value.channelCount)
		{
			error = "queued mock SoundData format mismatch";
			return false;
		}
		if (pcm.empty())
		{
			error.clear();
			return true;
		}
		if (static_cast<int>(value.queuedBuffers.size()) >= value.bufferCount)
		{
			error.clear();
			return false;
		}
		value.queuedBuffers.push_back(pcm.size());
		const auto bytesPerFrame = static_cast<std::size_t>(bitDepth / 8 * channels);
		value.sampleCount += static_cast<double>(pcm.size() / bytesPerFrame);
		value.duration = value.sampleCount / value.sampleRate;
		error.clear();
		return true;
	}
	int getSourceFreeBufferCount(SourceHandle source) const override
	{
		const auto found = sources.find(source);
		return found == sources.end() || found->second.type != "queue" ? 0
			: found->second.bufferCount - static_cast<int>(found->second.queuedBuffers.size());
	}
	void releaseSource(SourceHandle source) override
	{
		if (sources.erase(source) != 0)
			++released;
	}
	bool playSource(SourceHandle source) override
	{
		if (!deviceAvailable) return false;
		auto found = sources.find(source);
		if (found == sources.end()) return false;
		found->second.playing = true;
		found->second.paused = false;
		return true;
	}
	void pauseSource(SourceHandle source, bool paused) override
	{
		if (auto found = sources.find(source); found != sources.end() && found->second.playing)
			found->second.paused = paused;
	}
	void stopSource(SourceHandle source) override
	{
		if (auto found = sources.find(source); found != sources.end())
		{
			found->second.playing = false;
			found->second.paused = false;
			found->second.position = 0.0;
			if (found->second.type == "queue")
			{
				found->second.queuedBuffers.clear();
				found->second.sampleCount = 0.0;
				found->second.duration = 0.0;
			}
		}
	}
	bool isSourcePlaying(SourceHandle source) const override
	{
		const auto found = sources.find(source);
		return found != sources.end() && found->second.playing && !found->second.paused;
	}
	bool isSourcePaused(SourceHandle source) const override
	{
		const auto found = sources.find(source);
		return found != sources.end() && found->second.playing && found->second.paused;
	}
	void setSourceLooping(SourceHandle source, bool looping) override { sources.at(source).looping = looping; }
	bool isSourceLooping(SourceHandle source) const override { return sources.at(source).looping; }
	void setSourceVolume(SourceHandle source, float volume) override { sources.at(source).volume = volume; }
	float getSourceVolume(SourceHandle source) const override { return sources.at(source).volume; }
	void setSourcePitch(SourceHandle source, float pitch) override { sources.at(source).pitch = pitch; }
	float getSourcePitch(SourceHandle source) const override { return sources.at(source).pitch; }
	void seekSource(SourceHandle source, double seconds) override { sources.at(source).position = seconds; }
	double tellSource(SourceHandle source) const override { return sources.at(source).position; }
	double getSourceDuration(SourceHandle source) const override { return sources.at(source).duration; }
	double getSourceSampleRate(SourceHandle source) const override { return sources.at(source).sampleRate; }
	double getSourceSampleCount(SourceHandle source) const override { return sources.at(source).sampleCount; }
	int getSourceChannelCount(SourceHandle source) const override { return sources.at(source).channelCount; }
	void setSourcePosition(SourceHandle source, float x, float y, float z) override
	{
		sources.at(source).spatialPosition = {x, y, z};
	}
	void getSourcePosition(SourceHandle source, float &x, float &y, float &z) const override
	{
		const auto &value = sources.at(source).spatialPosition;
		x = value[0]; y = value[1]; z = value[2];
	}
	void setSourceVelocity(SourceHandle source, float x, float y, float z) override
	{
		sources.at(source).velocity = {x, y, z};
	}
	void getSourceVelocity(SourceHandle source, float &x, float &y, float &z) const override
	{
		const auto &value = sources.at(source).velocity;
		x = value[0]; y = value[1]; z = value[2];
	}
	void setSourceDirection(SourceHandle source, float x, float y, float z) override
	{
		sources.at(source).direction = {x, y, z};
	}
	void getSourceDirection(SourceHandle source, float &x, float &y, float &z) const override
	{
		const auto &value = sources.at(source).direction;
		x = value[0]; y = value[1]; z = value[2];
	}
	void setSourceCone(SourceHandle source, float innerAngle, float outerAngle,
		float outerVolume, float outerHighGain) override
	{
		auto &value = sources.at(source);
		value.coneInnerAngle = innerAngle;
		value.coneOuterAngle = outerAngle;
		value.coneOuterVolume = outerVolume;
		value.coneOuterHighGain = outerHighGain;
	}
	void getSourceCone(SourceHandle source, float &innerAngle, float &outerAngle,
		float &outerVolume, float &outerHighGain) const override
	{
		const auto &value = sources.at(source);
		innerAngle = value.coneInnerAngle;
		outerAngle = value.coneOuterAngle;
		outerVolume = value.coneOuterVolume;
		outerHighGain = value.coneOuterHighGain;
	}
	void setSourceAirAbsorption(SourceHandle source, float factor) override
	{
		sources.at(source).airAbsorptionFactor = factor;
	}
	float getSourceAirAbsorption(SourceHandle source) const override
	{
		return sources.at(source).airAbsorptionFactor;
	}
	void setSourceVolumeLimits(SourceHandle source, float minVolume, float maxVolume) override
	{
		sources.at(source).minVolume = minVolume;
		sources.at(source).maxVolume = maxVolume;
	}
	void getSourceVolumeLimits(SourceHandle source, float &minVolume, float &maxVolume) const override
	{
		minVolume = sources.at(source).minVolume;
		maxVolume = sources.at(source).maxVolume;
	}
	void setSourceRelative(SourceHandle source, bool relative) override
	{
		sources.at(source).relative = relative;
	}
	bool isSourceRelative(SourceHandle source) const override { return sources.at(source).relative; }
	void setSourceAttenuationDistances(SourceHandle source,
		float referenceDistance, float maxDistance) override
	{
		sources.at(source).referenceDistance = referenceDistance;
		sources.at(source).maxDistance = std::min(maxDistance, 1000000.0f);
	}
	void getSourceAttenuationDistances(SourceHandle source,
		float &referenceDistance, float &maxDistance) const override
	{
		referenceDistance = sources.at(source).referenceDistance;
		maxDistance = sources.at(source).maxDistance;
	}
	void setSourceRolloff(SourceHandle source, float rolloff) override
	{
		sources.at(source).rolloff = rolloff;
	}
	float getSourceRolloff(SourceHandle source) const override { return sources.at(source).rolloff; }
	void setInstanceVolume(float volume) override
	{
		instanceVolume = volume;
		++instanceVolumeChanges;
	}
	bool setMixWithSystem(bool mix) override
	{
		mixWithSystem = mix;
		++mixWithSystemChanges;
		return mixWithSystemAvailable;
	}
	void setListenerPosition(float x, float y, float z) override
	{
		listenerPosition = {x, y, z};
	}
	void getListenerPosition(float &x, float &y, float &z) const override
	{
		x = listenerPosition[0]; y = listenerPosition[1]; z = listenerPosition[2];
	}
	void setListenerOrientation(float forwardX, float forwardY, float forwardZ,
		float upX, float upY, float upZ) override
	{
		listenerOrientation = {forwardX, forwardY, forwardZ, upX, upY, upZ};
	}
	void getListenerOrientation(float &forwardX, float &forwardY, float &forwardZ,
		float &upX, float &upY, float &upZ) const override
	{
		forwardX = listenerOrientation[0]; forwardY = listenerOrientation[1];
		forwardZ = listenerOrientation[2]; upX = listenerOrientation[3];
		upY = listenerOrientation[4]; upZ = listenerOrientation[5];
	}
	void setListenerVelocity(float x, float y, float z) override
	{
		listenerVelocity = {x, y, z};
	}
	void getListenerVelocity(float &x, float &y, float &z) const override
	{
		x = listenerVelocity[0]; y = listenerVelocity[1]; z = listenerVelocity[2];
	}
	void setDopplerScale(float scale) override { dopplerScale = scale; }
	float getDopplerScale() const override { return dopplerScale; }
	void setDistanceModel(std::string_view model) override { distanceModel = model; }
	std::string getDistanceModel() const override { return distanceModel; }
	bool isEffectsSupported() const override { return true; }
	int getMaxSceneEffects() const override { return 64; }
	int getMaxSourceEffects() const override { return 3; }
	bool setEffect(std::string_view name, const EffectSettings *effect,
		std::string &error) override
	{
		if (effect == nullptr)
		{
			effects.erase(std::string(name));
			for (auto &[_, source] : sources) source.effects.erase(std::string(name));
			error.clear();
			return true;
		}
		if (!effects.contains(std::string(name)) && effects.size() >= 64)
		{
			error = "maximum number of mock scene effects reached";
			return false;
		}
		effects[std::string(name)] = *effect;
		error.clear();
		return true;
	}
	bool setSourceFilter(SourceHandle source, const FilterSettings *filter,
		std::string &error) override
	{
		auto found = sources.find(source);
		if (found == sources.end()) { error = "mock Source is closed"; return false; }
		found->second.filter = filter ? std::optional<FilterSettings>(*filter) : std::nullopt;
		error.clear();
		return true;
	}
	bool setSourceEffect(SourceHandle source, std::string_view name,
		const FilterSettings *filter, bool enabled, std::string &error) override
	{
		auto found = sources.find(source);
		if (found == sources.end()) { error = "mock Source is closed"; return false; }
		const std::string key(name);
		if (!enabled)
		{
			found->second.effects.erase(key);
			error.clear();
			return true;
		}
		if (!effects.contains(key)) { error = "mock effect does not exist"; return false; }
		if (!found->second.effects.contains(key) && found->second.effects.size() >= 3)
		{
			error = "maximum number of mock source effects reached";
			return false;
		}
		found->second.effects[key] = filter
			? std::optional<FilterSettings>(*filter) : std::nullopt;
		error.clear();
		return true;
	}
	std::vector<std::string> getRecordingDeviceNames() const override
	{
		return recordingAvailable ? std::vector<std::string>{"Default Microphone", "USB Input"}
			: std::vector<std::string>{};
	}
	RecordingHandle startRecording(std::string_view deviceName, int maxSamples,
		int sampleRate, int bitDepth, int channels, std::string &error) override
	{
		if (!recordingAvailable)
		{
			error.clear();
			return 0;
		}
		const RecordingHandle handle = nextRecordingHandle++;
		Recording recording;
		recording.name = deviceName;
		recording.maxSamples = maxSamples;
		recording.sampleRate = sampleRate;
		recording.bitDepth = bitDepth;
		recording.channels = channels;
		const int frames = std::min(maxSamples, 4);
		recording.pcm.resize(static_cast<std::size_t>(frames * (bitDepth / 8) * channels));
		for (std::size_t index = 0; index < recording.pcm.size(); ++index)
			recording.pcm[index] = static_cast<std::uint8_t>(index + 1);
		recordings.emplace(handle, std::move(recording));
		error.clear();
		return handle;
	}
	void stopRecording(RecordingHandle recording) override
	{
		if (recordings.erase(recording) != 0) ++recordingsStopped;
	}
	int getRecordingSampleCount(RecordingHandle recording) const override
	{
		const auto found = recordings.find(recording);
		if (found == recordings.end()) return 0;
		const int bytesPerFrame = found->second.bitDepth / 8 * found->second.channels;
		return static_cast<int>(found->second.pcm.size() / static_cast<std::size_t>(bytesPerFrame));
	}
	bool getRecordingData(RecordingHandle recording, std::vector<std::uint8_t> &pcm,
		std::string &error) override
	{
		auto found = recordings.find(recording);
		if (found == recordings.end())
		{
			error = "mock RecordingDevice is not recording";
			return false;
		}
		pcm.swap(found->second.pcm);
		error.clear();
		return true;
	}

	struct Recording
	{
		std::string name;
		int maxSamples = 0;
		int sampleRate = 0;
		int bitDepth = 0;
		int channels = 0;
		std::vector<std::uint8_t> pcm;
	};

	SourceHandle nextHandle = 1;
	RecordingHandle nextRecordingHandle = 1;
	int released = 0;
	std::size_t lastPCMSize = 0;
	int lastPCMSampleRate = 0;
	int lastPCMBitDepth = 0;
	int lastPCMChannels = 0;
	bool deviceAvailable = true;
	bool sourceCreationAvailable = true;
	bool cloneCreationAvailable = true;
	bool recordingAvailable = true;
	std::set<std::string> unavailableSourceSuffixes;
	int recordingsStopped = 0;
	float instanceVolume = 1.0f;
	int instanceVolumeChanges = 0;
	bool mixWithSystem = false;
	bool mixWithSystemAvailable = true;
	int mixWithSystemChanges = 0;
	std::array<float, 3> listenerPosition{0.0f, 0.0f, 0.0f};
	std::array<float, 6> listenerOrientation{0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f};
	std::array<float, 3> listenerVelocity{0.0f, 0.0f, 0.0f};
	float dopplerScale = 1.0f;
	std::string distanceModel = "inverseclamped";
	std::map<std::string, EffectSettings> effects;
	std::unordered_map<SourceHandle, Source> sources;
	std::unordered_map<RecordingHandle, Recording> recordings;
};

class MockSystem final : public Dora::Love::SystemBackend
{
public:
	std::string getOS() const override { return os; }
	int getProcessorCount() const override { return processorCount; }
	bool setClipboardText(std::string_view text, std::string &error) override
	{
		if (rejectClipboard)
		{
			error = "mock clipboard rejected text";
			return false;
		}
		clipboard.assign(text);
		error.clear();
		return true;
	}
	bool getClipboardText(std::string &text, std::string &error) const override
	{
		if (rejectClipboard)
		{
			error = "mock clipboard unavailable";
			return false;
		}
		text = clipboard;
		error.clear();
		return true;
	}
	PowerInfo getPowerInfo() const override { return powerInfo; }
	bool openURL(std::string_view url, std::string &error) override
	{
		lastURL.assign(url);
		if (url.starts_with("https://"))
		{
			error.clear();
			return true;
		}
		error = "mock URL rejected";
		return false;
	}
	void vibrate(double seconds) override { lastVibration = seconds; }
	bool hasBackgroundMusic() const override { return backgroundMusic; }

	std::string os = "Linux";
	int processorCount = 12;
	std::string clipboard;
	PowerInfo powerInfo{PowerState::Charging, 73, 900};
	std::string lastURL;
	double lastVibration = -1.0;
	bool backgroundMusic = true;
	bool rejectClipboard = false;
};

class MockKeyboard final : public Dora::Love::KeyboardBackend
{
public:
	void setTextInput(bool enabled, bool hasRectangle,
		float x, float y, float width, float height) override
	{
		textInputEnabled = enabled;
		this->hasRectangle = hasRectangle;
		rectangle = {x, y, width, height};
	}
	std::string getScancodeFromKey(std::string_view key) const override
	{
		if (key == "a") return "q";
		if (key == "q") return "a";
		if (key == "return") return "return";
		return "unknown";
	}
	std::string getKeyFromScancode(std::string_view scancode) const override
	{
		if (scancode == "q") return "a";
		if (scancode == "a") return "q";
		if (scancode == "return") return "return";
		return "unknown";
	}
	bool hasScreenKeyboard() const override { return screenKeyboard; }

	bool textInputEnabled = true;
	bool hasRectangle = false;
	bool screenKeyboard = true;
	std::array<float, 4> rectangle{};
};

class MockMouse final : public Dora::Love::MouseBackend
{
public:
	void setMousePosition(float x, float y) override
	{
		position = {x, y};
		++positionCalls;
	}
	void setMouseVisible(bool value) override { visible = value; ++visibleCalls; }
	void setMouseGrabbed(bool value) override { grabbed = value; ++grabbedCalls; }
	bool setMouseRelativeMode(bool value) override
	{
		++relativeCalls;
		if (!acceptRelative) return false;
		relative = value;
		return true;
	}
	CursorHandle createImageCursor(int width, int height, std::span<const std::uint8_t> rgba8,
		int hotX, int hotY, std::string &error) override
	{
		imageWidth = width; imageHeight = height; imageHotX = hotX; imageHotY = hotY;
		imagePixels.assign(rgba8.begin(), rgba8.end()); error.clear();
		imageCursorRequests.push_back({width, height, hotX, hotY});
		const auto handle = nextCursor++;
		cursors.emplace(handle, "image");
		return handle;
	}
	CursorHandle createSystemCursor(std::string_view type, std::string &error) override
	{
		error.clear(); const auto handle = nextCursor++;
		cursors.emplace(handle, std::string(type));
		return handle;
	}
	void releaseCursor(CursorHandle handle) override { cursors.erase(handle); ++releasedCursors; }
	void setMouseCursor(CursorHandle handle) override { activeCursor = handle; ++cursorChanges; }
	bool isMouseCursorSupported() const override { return true; }

	std::array<float, 2> position{};
	bool visible = true;
	bool grabbed = false;
	bool relative = false;
	bool acceptRelative = true;
	int positionCalls = 0;
	int visibleCalls = 0;
	int grabbedCalls = 0;
	int relativeCalls = 0;
	CursorHandle nextCursor = 1;
	CursorHandle activeCursor = 0;
	std::unordered_map<CursorHandle, std::string> cursors;
	std::vector<std::uint8_t> imagePixels;
	std::vector<std::array<int, 4>> imageCursorRequests;
	int imageWidth = 0;
	int imageHeight = 0;
	int imageHotX = 0;
	int imageHotY = 0;
	int releasedCursors = 0;
	int cursorChanges = 0;
};

class MockJoystick final : public Dora::Love::JoystickBackend
{
public:
	DeviceInfo getJoystickInfo(int id) const override
	{
		(void)id;
		return {.guid = "03000000mock00000000000000000000", .instanceId = 41, .vendorId = 0x1234,
			.productId = 0x5678, .productVersion = 9, .axisCount = 3,
			.buttonCount = 4, .hatCount = 1, .vibrationSupported = true};
	}
	float getJoystickAxis(int id, int axis) const override
	{
		(void)id;
		return std::array<float, 3>{-0.25f, 0.5f, 1.0f}.at(static_cast<std::size_t>(axis));
	}
	int getJoystickHat(int id, int hat) const override
	{
		(void)id;
		(void)hat;
		return 3; // right + up
	}
	bool isJoystickButtonDown(int id, int button) const override
	{
		(void)id;
		return button == 1;
	}
	bool setJoystickVibration(int id, float left, float right, double duration) override
	{
		lastId = id;
		lastLeft = left;
		lastRight = right;
		lastDuration = duration;
		return acceptVibration;
	}
	bool setGamepadMapping(std::string_view guid, std::string_view gamepadInput,
		std::string_view inputType, int index, std::string_view hat, std::string &error) override
	{
		lastGuid = guid;
		lastGamepadInput = gamepadInput;
		lastInputType = inputType;
		lastMappingIndex = index;
		lastHat = hat;
		error.clear();
		return true;
	}
	bool loadGamepadMappings(std::string_view mappings, std::string &error) override
	{
		if (mappings == "invalid")
		{
			error = "mock invalid gamepad mappings";
			return false;
		}
		loadedMappings = mappings;
		error.clear();
		return true;
	}
	std::string saveGamepadMappings() const override { return mappingString + "\n"; }
	std::string getGamepadMappingString(std::string_view guid) const override
	{
		return guid == "03000000mock00000000000000000000" ? mappingString : std::string{};
	}
	std::optional<GamepadMapping> getJoystickGamepadMapping(int id,
		std::string_view gamepadInput) const override
	{
		if (id != 0) return std::nullopt;
		if (gamepadInput == "a") return GamepadMapping{"button", 1, {}};
		if (gamepadInput == "leftx") return GamepadMapping{"axis", 2, {}};
		if (gamepadInput == "dpup") return GamepadMapping{"hat", 0, "u"};
		return std::nullopt;
	}
	std::string getJoystickGamepadMappingString(int id) const override
	{
		return id == 0 ? mappingString : std::string{};
	}

	int lastId = -1;
	float lastLeft = -1.0f;
	float lastRight = -1.0f;
	double lastDuration = 0.0;
	bool acceptVibration = true;
	std::string lastGuid;
	std::string lastGamepadInput;
	std::string lastInputType;
	int lastMappingIndex = -1;
	std::string lastHat;
	std::string loadedMappings;
	std::string mappingString = "03000000mock00000000000000000000,Mock Gamepad,a:b1,leftx:a2,dpup:h0.1,";
};

class MockPhysics final : public Dora::Love::PhysicsBackend
{
public:
	struct World { float gx = 0.0f; float gy = 0.0f; bool sleep = true; ContactCallback callback; int updates = 0; ContactHandle contact = 0; };
	struct Shape { std::string type; float x = 0.0f; float y = 0.0f; float width = 0.0f; float height = 0.0f; float angle = 0.0f; std::vector<float> points; bool loop = false; bool hasPrevious = false; float previousX = 0.0f; float previousY = 0.0f; bool hasNext = false; float nextX = 0.0f; float nextY = 0.0f; };
	struct Body { WorldHandle world = 0; std::string type; float x = 0.0f; float y = 0.0f; float angle = 0.0f; float vx = 0.0f; float vy = 0.0f; float angularVelocity = 0.0f; float linearDamping = 0.0f; float angularDamping = 0.0f; float mass = 2.0f; float inertia = 3.0f; float centerX = 0.0f; float centerY = 0.0f; float gravityScale = 1.0f; bool fixedRotation = false; bool awake = true; bool sleepingAllowed = true; bool active = true; bool bullet = false; };
	struct Fixture { BodyHandle body = 0; ShapeHandle shape = 0; float density = 1.0f; float friction = 0.2f; float restitution = 0.0f; bool sensor = false; std::uint16_t category = 1; std::uint16_t mask = 0xffff; std::int16_t group = 0; };
	struct Joint { BodyHandle a = 0; BodyHandle b = 0; JointHandle sourceA = 0; JointHandle sourceB = 0; float x1 = 0; float y1 = 0; float x2 = 0; float y2 = 0; float groundX1 = 0; float groundY1 = 0; float groundX2 = 0; float groundY2 = 0; bool collide = false; float length = 0; float lengthB = 0; float ratio = 1; float frequency = 0; float damping = 0; std::string type = "distance"; float referenceAngle = 0; bool motorEnabled = false; float maxMotorTorque = 0; float motorSpeed = 0; bool limitsEnabled = false; float lowerLimit = 0; float upperLimit = 0; float axisX = 1; float axisY = 0; float maxForce = 0; float maxTorque = 0; float offsetX = 0; float offsetY = 0; float angularOffset = 0; float correctionFactor = 0.3f; };
	struct Contact { WorldHandle world = 0; FixtureHandle a = 0; FixtureHandle b = 0; float friction = 0.3f; float restitution = 0.1f; bool enabled = true; bool touching = true; float tangentSpeed = 0.0f; };

	void setMeter(float value) override
	{
		// The mock exposes Love pixel units while its stored coordinates stand in for
		// the backend's meter-space values. Match Box2D/Love semantics when the
		// global pixel scale changes: existing bodies keep their physical location.
		if (meter > 0.0f)
		{
			const float scale = value / meter;
			for (auto &[_, body] : bodies)
			{
				body.x *= scale;
				body.y *= scale;
			}
		}
		meter = value;
	}
	WorldHandle newWorld(float gx, float gy, bool sleep, std::string &error) override { auto h = next++; worlds[h].gx=gx; worlds[h].gy=gy; worlds[h].sleep=sleep; error.clear(); return h; }
	void releaseWorld(WorldHandle h) override { for(auto i=contacts.begin();i!=contacts.end();)if(i->second.world==h)i=contacts.erase(i);else++i;std::vector<BodyHandle> owned;for(const auto&[bh,b]:bodies)if(b.world==h)owned.push_back(bh);for(auto bh:owned)releaseBody(bh);if (worlds.erase(h)) ++worldsReleased; }
	bool isWorldValid(WorldHandle h) const override { return worlds.contains(h); }
	bool updateWorld(WorldHandle h, float dt, int, int, std::string &error) override
	{
		const auto w = worlds.find(h); if (w == worlds.end()) { error = "mock World is closed"; return false; }
		for (auto &[_, body] : bodies) if (body.world == h && body.type == "dynamic")
		{ body.vx += w->second.gx * body.gravityScale * dt; body.vy += w->second.gy * body.gravityScale * dt; body.x += body.vx * dt; body.y += body.vy * dt; }
		auto &world=w->second;
		if(world.callback){std::vector<FixtureHandle> owned;for(const auto&[fh,f]:fixtures)if(bodies.at(f.body).world==h)owned.push_back(fh);std::sort(owned.begin(),owned.end());if(owned.size()>=2){if(world.contact==0){world.contact=next++;contacts[world.contact]={h,owned[0],owned[1]};}auto emit=[&](ContactPhase phase,std::vector<float> impulses={}){std::string callbackError;if(!world.callback({phase,world.contact,owned[0],owned[1],std::move(impulses)},callbackError)){error=callbackError;return false;}return true;};if(world.updates==0&&!emit(ContactPhase::Begin))return false;if(!emit(ContactPhase::PreSolve))return false;if(!emit(ContactPhase::PostSolve,{3.0f,1.0f,2.0f,0.5f}))return false;if(world.updates==1){if(!emit(ContactPhase::End))return false;contacts.erase(world.contact);world.contact=0;}}++world.updates;}
		error.clear(); return true;
	}
	bool setWorldGravity(WorldHandle h, float x, float y, std::string &error) override { auto i=worlds.find(h); if(i==worlds.end()){error="mock World is closed";return false;} i->second.gx=x;i->second.gy=y;error.clear();return true; }
	bool getWorldGravity(WorldHandle h, float &x, float &y, std::string &error) const override { auto i=worlds.find(h);if(i==worlds.end()){error="mock World is closed";return false;}x=i->second.gx;y=i->second.gy;error.clear();return true; }
	bool setWorldSleepingAllowed(WorldHandle h,bool v,std::string&e) override {auto i=worlds.find(h);if(i==worlds.end()){e="mock World is closed";return false;}i->second.sleep=v;for(auto&[_,b]:bodies)if(b.world==h)b.sleepingAllowed=v;e.clear();return true;}
	bool isWorldSleepingAllowed(WorldHandle h,bool&v,std::string&e) const override {auto i=worlds.find(h);if(i==worlds.end()){e="mock World is closed";return false;}v=i->second.sleep;e.clear();return true;}
	bool queryWorld(WorldHandle h,float x1,float y1,float x2,float y2,std::vector<FixtureHandle>&out,std::string&e) const override { if(!worlds.contains(h)){e="mock World is closed";return false;}const float l=std::min(x1,x2),r=std::max(x1,x2),t=std::min(y1,y2),b=std::max(y1,y2);for(const auto&[fh,f]:fixtures){const auto&i=bodies.at(f.body);if(i.world==h&&i.x>=l&&i.x<=r&&i.y>=t&&i.y<=b)out.push_back(fh);}e.clear();return true; }
	bool raycastWorld(WorldHandle h,float x1,float y1,float x2,float y2,std::vector<RayHit>&out,std::string&e) const override { if(!worlds.contains(h)){e="mock World is closed";return false;}const float dx=x2-x1,dy=y2-y1,den=dx*dx+dy*dy;for(const auto&[fh,f]:fixtures){const auto&i=bodies.at(f.body);if(i.world!=h)continue;const float fraction=den>0?std::clamp(((i.x-x1)*dx+(i.y-y1)*dy)/den,0.0f,1.0f):0.0f;out.push_back({fh,x1+dx*fraction,y1+dy*fraction,0,-1,fraction});}std::sort(out.begin(),out.end(),[](const auto&a,const auto&b){return a.fraction<b.fraction;});e.clear();return true; }
	bool setWorldContactCallback(WorldHandle h,ContactCallback callback,std::string&e) override {auto i=worlds.find(h);if(i==worlds.end()){e="mock World is closed";return false;}i->second.callback=std::move(callback);e.clear();return true;}
	bool isContactValid(ContactHandle h) const override{return contacts.contains(h);}
	bool getContactPositions(ContactHandle h,std::vector<float>&v,std::string&e) const override{if(!contacts.contains(h)){e="mock Contact is invalid";return false;}v={10,20,11,21};e.clear();return true;}
	bool getContactNormal(ContactHandle h,float&x,float&y,std::string&e) const override{if(!contacts.contains(h)){e="mock Contact is invalid";return false;}x=0;y=-1;e.clear();return true;}
	bool getContactFriction(ContactHandle h,float&v,std::string&e) const override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}v=i->second.friction;e.clear();return true;}
	bool setContactFriction(ContactHandle h,float v,std::string&e) override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}i->second.friction=v;e.clear();return true;}
	bool resetContactFriction(ContactHandle h,std::string&e) override{return setContactFriction(h,0.3f,e);}
	bool getContactRestitution(ContactHandle h,float&v,std::string&e) const override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}v=i->second.restitution;e.clear();return true;}
	bool setContactRestitution(ContactHandle h,float v,std::string&e) override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}i->second.restitution=v;e.clear();return true;}
	bool resetContactRestitution(ContactHandle h,std::string&e) override{return setContactRestitution(h,0.1f,e);}
	bool isContactEnabled(ContactHandle h,bool&v,std::string&e) const override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}v=i->second.enabled;e.clear();return true;}
	bool setContactEnabled(ContactHandle h,bool v,std::string&e) override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}i->second.enabled=v;e.clear();return true;}
	bool isContactTouching(ContactHandle h,bool&v,std::string&e) const override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}v=i->second.touching;e.clear();return true;}
	bool getContactTangentSpeed(ContactHandle h,float&v,std::string&e) const override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}v=i->second.tangentSpeed;e.clear();return true;}
	bool setContactTangentSpeed(ContactHandle h,float v,std::string&e) override{auto i=contacts.find(h);if(i==contacts.end()){e="mock Contact is invalid";return false;}i->second.tangentSpeed=v;e.clear();return true;}
	ShapeHandle newCircleShape(float x,float y,float r,std::string &error) override { auto h=next++;shapes[h]={"circle",x,y,r,r,0};error.clear();return h; }
	ShapeHandle newRectangleShape(float x,float y,float w,float hgt,float a,std::string &error) override { auto h=next++;shapes[h]={"polygon",x,y,w,hgt,a};error.clear();return h; }
	ShapeHandle newPolygonShape(std::vector<float>&p,std::string&e) override {auto h=next++;shapes[h].type="polygon";shapes[h].points=p;e.clear();return h;}
	ShapeHandle newEdgeShape(float x1,float y1,float x2,float y2,std::string&e) override {auto h=next++;shapes[h].type="edge";shapes[h].points={x1,y1,x2,y2};e.clear();return h;}
	ShapeHandle newChainShape(bool loop,const std::vector<float>&p,std::string&e) override {auto h=next++;shapes[h].type="chain";shapes[h].points=p;shapes[h].loop=loop;e.clear();return h;}
	bool setShapePreviousVertex(ShapeHandle h,bool has,float x,float y,std::string&e) override {auto i=shapes.find(h);if(i==shapes.end()){e="mock Shape is closed";return false;}i->second.hasPrevious=has;i->second.previousX=x;i->second.previousY=y;e.clear();return true;}
	bool setShapeNextVertex(ShapeHandle h,bool has,float x,float y,std::string&e) override {auto i=shapes.find(h);if(i==shapes.end()){e="mock Shape is closed";return false;}i->second.hasNext=has;i->second.nextX=x;i->second.nextY=y;e.clear();return true;}
	void releaseShape(ShapeHandle h) override { if(shapes.erase(h))++shapesReleased; }
	BodyHandle newBody(WorldHandle w,float x,float y,std::string_view type,std::string &error) override { if(!worlds.contains(w)){error="mock World is closed";return 0;}auto h=next++;bodies[h]={w,std::string(type),x,y};bodies[h].sleepingAllowed=worlds[w].sleep;error.clear();return h; }
	void releaseBody(BodyHandle h) override { std::vector<FixtureHandle> ownedFixtures;std::vector<JointHandle> ownedJoints;for(const auto&[fh,f]:fixtures)if(f.body==h)ownedFixtures.push_back(fh);for(const auto&[jh,j]:joints)if(j.a==h||j.b==h)ownedJoints.push_back(jh);for(auto jh:ownedJoints)releaseJoint(jh);for(auto fh:ownedFixtures)releaseFixture(fh);if(bodies.erase(h))++bodiesReleased; }
	bool isBodyValid(BodyHandle h) const override { return bodies.contains(h); }
	bool getBodyPosition(BodyHandle h,float &x,float &y,std::string &error) const override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}x=i->second.x;y=i->second.y;error.clear();return true; }
	bool setBodyPosition(BodyHandle h,float x,float y,std::string &error) override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}i->second.x=x;i->second.y=y;error.clear();return true; }
	bool getBodyAngle(BodyHandle h,float &v,std::string &error) const override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}v=i->second.angle;error.clear();return true; }
	bool setBodyAngle(BodyHandle h,float v,std::string &error) override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}i->second.angle=v;error.clear();return true; }
	bool getBodyLinearVelocity(BodyHandle h,float &x,float &y,std::string &error) const override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}x=i->second.vx;y=i->second.vy;error.clear();return true; }
	bool setBodyLinearVelocity(BodyHandle h,float x,float y,std::string &error) override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}i->second.vx=x;i->second.vy=y;error.clear();return true; }
	bool getBodyAngularVelocity(BodyHandle h,float &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.angularVelocity;e.clear();return true;}
	bool setBodyAngularVelocity(BodyHandle h,float v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.angularVelocity=v;e.clear();return true;}
	bool getBodyLinearDamping(BodyHandle h,float &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.linearDamping;e.clear();return true;}
	bool setBodyLinearDamping(BodyHandle h,float v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.linearDamping=v;e.clear();return true;}
	bool getBodyAngularDamping(BodyHandle h,float &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.angularDamping;e.clear();return true;}
	bool setBodyAngularDamping(BodyHandle h,float v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.angularDamping=v;e.clear();return true;}
	bool getBodyMass(BodyHandle h,float &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.mass;e.clear();return true;}
	bool getBodyInertia(BodyHandle h,float &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.inertia;e.clear();return true;}
	bool getBodyMassData(BodyHandle h,float&x,float&y,float&m,float&i,std::string&e) const override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}x=b->second.centerX;y=b->second.centerY;m=b->second.mass;i=b->second.inertia;e.clear();return true;}
	bool setBodyMassData(BodyHandle h,float x,float y,float m,float i,std::string&e) override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}b->second.centerX=x;b->second.centerY=y;b->second.mass=m>0?m:1;b->second.inertia=std::max(i,0.0f);e.clear();return true;}
	bool resetBodyMassData(BodyHandle h,std::string&e) override {return setBodyMassData(h,0,0,2,3,e);}
	bool setBodyMass(BodyHandle h,float v,std::string&e) override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}b->second.mass=v>0?v:1;e.clear();return true;}
	bool setBodyInertia(BodyHandle h,float v,std::string&e) override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}b->second.inertia=std::max(v,0.0f);e.clear();return true;}
	bool getBodyGravityScale(BodyHandle h,float&v,std::string&e) const override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}v=b->second.gravityScale;e.clear();return true;}
	bool setBodyGravityScale(BodyHandle h,float v,std::string&e) override {auto b=bodies.find(h);if(b==bodies.end()){e="mock Body is closed";return false;}b->second.gravityScale=v;e.clear();return true;}
	bool getBodyCenter(BodyHandle h,bool world,float &x,float &y,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}x=world?i->second.x+i->second.centerX:i->second.centerX;y=world?i->second.y+i->second.centerY:i->second.centerY;e.clear();return true;}
	bool isBodyFixedRotation(BodyHandle h,bool &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.fixedRotation;e.clear();return true;}
	bool setBodyFixedRotation(BodyHandle h,bool v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.fixedRotation=v;e.clear();return true;}
	bool isBodyAwake(BodyHandle h,bool &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.awake;e.clear();return true;}
	bool setBodyAwake(BodyHandle h,bool v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.awake=v;e.clear();return true;}
	bool isBodySleepingAllowed(BodyHandle h,bool &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.sleepingAllowed;e.clear();return true;}
	bool setBodySleepingAllowed(BodyHandle h,bool v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.sleepingAllowed=v;e.clear();return true;}
	bool isBodyActive(BodyHandle h,bool &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.active;e.clear();return true;}
	bool setBodyActive(BodyHandle h,bool v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.active=v;e.clear();return true;}
	bool isBodyBullet(BodyHandle h,bool &v,std::string &e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}v=i->second.bullet;e.clear();return true;}
	bool setBodyBullet(BodyHandle h,bool v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.bullet=v;e.clear();return true;}
	bool setBodyType(BodyHandle h,std::string_view v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.type=v;e.clear();return true;}
	bool transformBodyPoint(BodyHandle h,bool toWorld,bool vector,float x,float y,float&ox,float&oy,std::string&e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}const float c=std::cos(i->second.angle),s=std::sin(i->second.angle);if(toWorld){ox=c*x-s*y+(vector?0:i->second.x);oy=s*x+c*y+(vector?0:i->second.y);}else{const float px=x-(vector?0:i->second.x),py=y-(vector?0:i->second.y);ox=c*px+s*py;oy=-s*px+c*py;}e.clear();return true;}
	bool getBodyPointVelocity(BodyHandle h,bool local,float x,float y,float&ox,float&oy,std::string&e) const override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}float wx=x,wy=y;if(local){const float c=std::cos(i->second.angle),s=std::sin(i->second.angle);wx=c*x-s*y+i->second.x;wy=s*x+c*y+i->second.y;}const float rx=wx-i->second.x,ry=wy-i->second.y;ox=i->second.vx-i->second.angularVelocity*ry;oy=i->second.vy+i->second.angularVelocity*rx;e.clear();return true;}
	bool applyBodyLinearImpulse(BodyHandle h,float x,float y,float,float,std::string &error) override { auto i=bodies.find(h);if(i==bodies.end()){error="mock Body is closed";return false;}i->second.vx+=x;i->second.vy+=y;error.clear();return true; }
	bool applyBodyAngularImpulse(BodyHandle h,float v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.angularVelocity+=v;e.clear();return true;}
	bool applyBodyForce(BodyHandle h,float x,float y,float,float,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.vx+=x;i->second.vy+=y;e.clear();return true;}
	bool applyBodyTorque(BodyHandle h,float v,std::string &e) override {auto i=bodies.find(h);if(i==bodies.end()){e="mock Body is closed";return false;}i->second.angularVelocity+=v;e.clear();return true;}
	FixtureHandle newFixture(BodyHandle b,ShapeHandle s,float d,std::string &error) override { if(!bodies.contains(b)||!shapes.contains(s)){error="mock fixture input is closed";return 0;}auto h=next++;fixtures[h]={b,s,d};error.clear();return h; }
	void releaseFixture(FixtureHandle h) override { if(fixtures.erase(h))++fixturesReleased; }
	bool isFixtureValid(FixtureHandle h) const override { return fixtures.contains(h); }
	bool setFixtureFriction(FixtureHandle h,float v,std::string &e) override { auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}i->second.friction=v;e.clear();return true; }
	bool setFixtureRestitution(FixtureHandle h,float v,std::string &e) override { auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}i->second.restitution=v;e.clear();return true; }
	bool setFixtureSensor(FixtureHandle h,bool v,std::string &e) override { auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}i->second.sensor=v;e.clear();return true; }
	bool setFixtureDensity(FixtureHandle h,float v,std::string&e) override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}i->second.density=v;e.clear();return true;}
	bool testFixturePoint(FixtureHandle h,float x,float y,bool&v,std::string&e) const override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}const auto&b=bodies.at(i->second.body);const auto&s=shapes.at(i->second.shape);const float cx=b.x+s.x,cy=b.y+s.y,r=s.width;v=(x-cx)*(x-cx)+(y-cy)*(y-cy)<=r*r;e.clear();return true;}
	bool rayCastFixture(FixtureHandle h,float,float,float,float,float max,std::uint16_t child,bool&hit,float&nx,float&ny,float&fraction,std::string&e) const override {if(!fixtures.contains(h)){e="mock Fixture is closed";return false;}if(child!=0){e="Fixture child index is out of range";return false;}hit=max>=0.25f;nx=-1;ny=0;fraction=0.25f;e.clear();return true;}
	bool getFixtureFilterData(FixtureHandle h,std::uint16_t&c,std::uint16_t&m,std::int16_t&g,std::string&e) const override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}c=i->second.category;m=i->second.mask;g=i->second.group;e.clear();return true;}
	bool setFixtureFilterData(FixtureHandle h,std::uint16_t c,std::uint16_t m,std::int16_t g,std::string&e) override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}i->second.category=c;i->second.mask=m;i->second.group=g;e.clear();return true;}
	bool getFixtureBoundingBox(FixtureHandle h,std::uint16_t child,float&x1,float&y1,float&x2,float&y2,std::string&e) const override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}if(child!=0){e="Fixture child index is out of range";return false;}const auto&b=bodies.at(i->second.body);const auto&s=shapes.at(i->second.shape);x1=b.x+s.x-s.width;y1=b.y+s.y-s.width;x2=b.x+s.x+s.width;y2=b.y+s.y+s.width;e.clear();return true;}
	bool getFixtureMassData(FixtureHandle h,float&x,float&y,float&m,float&inertia,std::string&e) const override {auto i=fixtures.find(h);if(i==fixtures.end()){e="mock Fixture is closed";return false;}const auto&s=shapes.at(i->second.shape);x=s.x;y=s.y;m=i->second.density*2;inertia=i->second.density*3;e.clear();return true;}
	JointHandle newDistanceJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,bool collide,std::string &error) override { if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){error="mock joint bodies differ";return 0;}auto h=next++;const float dx=x2-x1,dy=y2-y1;Joint joint;joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.collide=collide;joint.length=std::sqrt(dx*dx+dy*dy);joints[h]=joint;error.clear();return h; }
	void releaseJoint(JointHandle h) override {std::vector<JointHandle> dependents;for(const auto&[id,j]:joints)if(j.sourceA==h||j.sourceB==h)dependents.push_back(id);for(auto id:dependents)releaseJoint(id);if(joints.erase(h))++jointsReleased;}
	bool isJointValid(JointHandle h) const override { return joints.contains(h); }
	bool getJointAnchors(JointHandle h,float&x1,float&y1,float&x2,float&y2,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}x1=j->second.x1;y1=j->second.y1;x2=j->second.x2;y2=j->second.y2;e.clear();return true;}
	bool getJointReactionForce(JointHandle h,float inv,float&x,float&y,std::string&e) const override {if(!joints.contains(h)){e="mock Joint is closed";return false;}x=2*inv;y=3*inv;e.clear();return true;}
	bool getJointReactionTorque(JointHandle h,float inv,float&v,std::string&e) const override {if(!joints.contains(h)){e="mock Joint is closed";return false;}v=4*inv;e.clear();return true;}
	bool getJointCollideConnected(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}v=j->second.collide;e.clear();return true;}
	bool getDistanceJointLength(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}v=j->second.length;e.clear();return true;}
	bool setDistanceJointLength(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}j->second.length=v;e.clear();return true;}
	bool getDistanceJointFrequency(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}v=j->second.frequency;e.clear();return true;}
	bool setDistanceJointFrequency(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}j->second.frequency=v;e.clear();return true;}
	bool getDistanceJointDampingRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}v=j->second.damping;e.clear();return true;}
	bool setDistanceJointDampingRatio(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()){e="mock Joint is closed";return false;}j->second.damping=v;e.clear();return true;}
	JointHandle newRevoluteJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,bool collide,bool hasReference,float reference,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;Joint joint; joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.collide=collide;joint.type="revolute";joint.referenceAngle=hasReference?reference:bodies[b].angle-bodies[a].angle;joints[h]=joint;e.clear();return h;}
	bool getRevoluteJointAngle(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=bodies.at(j->second.b).angle-bodies.at(j->second.a).angle-j->second.referenceAngle;e.clear();return true;}
	bool getRevoluteJointSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=bodies.at(j->second.b).angularVelocity-bodies.at(j->second.a).angularVelocity;e.clear();return true;}
	bool isRevoluteJointMotorEnabled(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=j->second.motorEnabled;e.clear();return true;}
	bool setRevoluteJointMotorEnabled(JointHandle h,bool v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}j->second.motorEnabled=v;e.clear();return true;}
	bool getRevoluteJointMaxMotorTorque(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=j->second.maxMotorTorque;e.clear();return true;}
	bool setRevoluteJointMaxMotorTorque(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}j->second.maxMotorTorque=v;e.clear();return true;}
	bool getRevoluteJointMotorSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=j->second.motorSpeed;e.clear();return true;}
	bool setRevoluteJointMotorSpeed(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}j->second.motorSpeed=v;e.clear();return true;}
	bool getRevoluteJointMotorTorque(JointHandle h,float inv,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=2*inv;e.clear();return true;}
	bool areRevoluteJointLimitsEnabled(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=j->second.limitsEnabled;e.clear();return true;}
	bool setRevoluteJointLimitsEnabled(JointHandle h,bool v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}j->second.limitsEnabled=v;e.clear();return true;}
	bool getRevoluteJointLimits(JointHandle h,float&lower,float&upper,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}lower=j->second.lowerLimit;upper=j->second.upperLimit;e.clear();return true;}
	bool setRevoluteJointLimits(JointHandle h,float lower,float upper,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}j->second.lowerLimit=lower;j->second.upperLimit=upper;e.clear();return true;}
	bool getRevoluteJointReferenceAngle(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="revolute"){e="mock RevoluteJoint is closed";return false;}v=j->second.referenceAngle;e.clear();return true;}
	JointHandle newPrismaticJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,float ax,float ay,bool collide,bool hasReference,float reference,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;const float magnitude=std::sqrt(ax*ax+ay*ay);Joint joint;joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.collide=collide;joint.type="prismatic";joint.referenceAngle=hasReference?reference:bodies[b].angle-bodies[a].angle;joint.limitsEnabled=true;joint.upperLimit=100*meter;joint.axisX=ax/magnitude;joint.axisY=ay/magnitude;joints[h]=joint;e.clear();return h;}
	bool getPrismaticJointTranslation(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=(j->second.x2-j->second.x1)*j->second.axisX+(j->second.y2-j->second.y1)*j->second.axisY;e.clear();return true;}
	bool getPrismaticJointSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}const auto&a=bodies.at(j->second.a);const auto&b=bodies.at(j->second.b);v=(b.vx-a.vx)*j->second.axisX+(b.vy-a.vy)*j->second.axisY;e.clear();return true;}
	bool isPrismaticJointMotorEnabled(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=j->second.motorEnabled;e.clear();return true;}
	bool setPrismaticJointMotorEnabled(JointHandle h,bool v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}j->second.motorEnabled=v;e.clear();return true;}
	bool getPrismaticJointMaxMotorForce(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=j->second.maxMotorTorque;e.clear();return true;}
	bool setPrismaticJointMaxMotorForce(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}j->second.maxMotorTorque=v;e.clear();return true;}
	bool getPrismaticJointMotorSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=j->second.motorSpeed;e.clear();return true;}
	bool setPrismaticJointMotorSpeed(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}j->second.motorSpeed=v;e.clear();return true;}
	bool getPrismaticJointMotorForce(JointHandle h,float inv,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=3*inv;e.clear();return true;}
	bool arePrismaticJointLimitsEnabled(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=j->second.limitsEnabled;e.clear();return true;}
	bool setPrismaticJointLimitsEnabled(JointHandle h,bool v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}j->second.limitsEnabled=v;e.clear();return true;}
	bool getPrismaticJointLimits(JointHandle h,float&lower,float&upper,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}lower=j->second.lowerLimit;upper=j->second.upperLimit;e.clear();return true;}
	bool setPrismaticJointLimits(JointHandle h,float lower,float upper,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}j->second.lowerLimit=lower;j->second.upperLimit=upper;e.clear();return true;}
	bool getPrismaticJointAxis(JointHandle h,float&x,float&y,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}x=j->second.axisX;y=j->second.axisY;e.clear();return true;}
	bool getPrismaticJointReferenceAngle(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="prismatic"){e="mock PrismaticJoint is closed";return false;}v=j->second.referenceAngle;e.clear();return true;}
	JointHandle newWeldJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,bool collide,bool hasReference,float reference,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;Joint joint;joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.collide=collide;joint.type="weld";joint.referenceAngle=hasReference?reference:bodies[b].angle-bodies[a].angle;joints[h]=joint;e.clear();return h;}
	bool getWeldJointFrequency(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="weld"){e="mock WeldJoint is closed";return false;}v=j->second.frequency;e.clear();return true;}
	bool setWeldJointFrequency(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="weld"){e="mock WeldJoint is closed";return false;}j->second.frequency=v;e.clear();return true;}
	bool getWeldJointDampingRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="weld"){e="mock WeldJoint is closed";return false;}v=j->second.damping;e.clear();return true;}
	bool setWeldJointDampingRatio(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="weld"){e="mock WeldJoint is closed";return false;}j->second.damping=v;e.clear();return true;}
	bool getWeldJointReferenceAngle(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="weld"){e="mock WeldJoint is closed";return false;}v=j->second.referenceAngle;e.clear();return true;}
	JointHandle newFrictionJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,bool collide,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;Joint joint;joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.collide=collide;joint.type="friction";joints[h]=joint;e.clear();return h;}
	bool getFrictionJointMaxForce(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="friction"){e="mock FrictionJoint is closed";return false;}v=j->second.maxForce;e.clear();return true;}
	bool setFrictionJointMaxForce(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="friction"){e="mock FrictionJoint is closed";return false;}j->second.maxForce=v;e.clear();return true;}
	bool getFrictionJointMaxTorque(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="friction"){e="mock FrictionJoint is closed";return false;}v=j->second.maxTorque;e.clear();return true;}
	bool setFrictionJointMaxTorque(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="friction"){e="mock FrictionJoint is closed";return false;}j->second.maxTorque=v;e.clear();return true;}
	JointHandle newRopeJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,float maxLength,bool collide,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;Joint joint;joint.a=a;joint.b=b;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.length=maxLength;joint.collide=collide;joint.type="rope";joints[h]=joint;e.clear();return h;}
	bool getRopeJointMaxLength(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="rope"){e="mock RopeJoint is closed";return false;}v=j->second.length;e.clear();return true;}
	bool setRopeJointMaxLength(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="rope"){e="mock RopeJoint is closed";return false;}j->second.length=v;e.clear();return true;}
	JointHandle newPulleyJoint(BodyHandle a,BodyHandle b,float gx1,float gy1,float gx2,float gy2,float x1,float y1,float x2,float y2,float ratio,bool collide,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;Joint joint;joint.a=a;joint.b=b;joint.groundX1=gx1;joint.groundY1=gy1;joint.groundX2=gx2;joint.groundY2=gy2;joint.x1=x1;joint.y1=y1;joint.x2=x2;joint.y2=y2;joint.length=std::hypot(x1-gx1,y1-gy1);joint.lengthB=std::hypot(x2-gx2,y2-gy2);joint.ratio=ratio;joint.collide=collide;joint.type="pulley";joints[h]=joint;e.clear();return h;}
	bool getPulleyJointGroundAnchors(JointHandle h,float&x1,float&y1,float&x2,float&y2,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="pulley"){e="mock PulleyJoint is closed";return false;}x1=j->second.groundX1;y1=j->second.groundY1;x2=j->second.groundX2;y2=j->second.groundY2;e.clear();return true;}
	bool getPulleyJointLengthA(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="pulley"){e="mock PulleyJoint is closed";return false;}v=j->second.length;e.clear();return true;}
	bool getPulleyJointLengthB(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="pulley"){e="mock PulleyJoint is closed";return false;}v=j->second.lengthB;e.clear();return true;}
	bool getPulleyJointRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="pulley"){e="mock PulleyJoint is closed";return false;}v=j->second.ratio;e.clear();return true;}
	JointHandle newWheelJoint(BodyHandle a,BodyHandle b,float x1,float y1,float x2,float y2,float ax,float ay,bool collide,std::string&e) override {if(!bodies.contains(a)||!bodies.contains(b)||bodies[a].world!=bodies[b].world){e="mock joint bodies differ";return 0;}auto h=next++;auto m=std::hypot(ax,ay);Joint j;j.a=a;j.b=b;j.x1=x1;j.y1=y1;j.x2=x2;j.y2=y2;j.axisX=ax/m;j.axisY=ay/m;j.collide=collide;j.frequency=2;j.damping=0.7f;j.type="wheel";joints[h]=j;e.clear();return h;}
	bool getWheelJointTranslation(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=(j->second.x2-j->second.x1)*j->second.axisX+(j->second.y2-j->second.y1)*j->second.axisY;e.clear();return true;}
	bool getWheelJointSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=(bodies.at(j->second.b).angularVelocity-bodies.at(j->second.a).angularVelocity)*meter;e.clear();return true;}
	bool isWheelJointMotorEnabled(JointHandle h,bool&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.motorEnabled;e.clear();return true;}
	bool setWheelJointMotorEnabled(JointHandle h,bool v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}j->second.motorEnabled=v;e.clear();return true;}
	bool getWheelJointMotorSpeed(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.motorSpeed;e.clear();return true;}
	bool setWheelJointMotorSpeed(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}j->second.motorSpeed=v;e.clear();return true;}
	bool getWheelJointMaxMotorTorque(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.maxMotorTorque;e.clear();return true;}
	bool setWheelJointMaxMotorTorque(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}j->second.maxMotorTorque=v;e.clear();return true;}
	bool getWheelJointMotorTorque(JointHandle h,float inv,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.motorEnabled?std::min(j->second.maxMotorTorque,inv):0;e.clear();return true;}
	bool getWheelJointSpringFrequency(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.frequency;e.clear();return true;}
	bool setWheelJointSpringFrequency(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}j->second.frequency=v;e.clear();return true;}
	bool getWheelJointSpringDampingRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}v=j->second.damping;e.clear();return true;}
	bool setWheelJointSpringDampingRatio(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}j->second.damping=v;e.clear();return true;}
	bool getWheelJointAxis(JointHandle h,float&x,float&y,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="wheel"){e="mock WheelJoint is closed";return false;}x=j->second.axisX;y=j->second.axisY;e.clear();return true;}
	JointHandle newMouseJoint(BodyHandle b,float x,float y,std::string&e) override {auto body=bodies.find(b);if(body==bodies.end()){e="mock Body is closed";return 0;}if(body->second.type=="kinematic"){e="Cannot create a MouseJoint for a kinematic Body";return 0;}auto h=next++;Joint j;j.a=b;j.x1=x;j.y1=y;j.x2=x;j.y2=y;j.maxForce=1000*body->second.mass;j.frequency=5;j.damping=0.7f;j.type="mouse";joints[h]=j;e.clear();return h;}
	bool getMouseJointTarget(JointHandle h,float&x,float&y,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}x=j->second.x1;y=j->second.y1;e.clear();return true;}
	bool setMouseJointTarget(JointHandle h,float x,float y,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}j->second.x1=x;j->second.y1=y;e.clear();return true;}
	bool getMouseJointMaxForce(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}v=j->second.maxForce;e.clear();return true;}
	bool setMouseJointMaxForce(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}j->second.maxForce=v;e.clear();return true;}
	bool getMouseJointFrequency(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}v=j->second.frequency;e.clear();return true;}
	bool setMouseJointFrequency(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}j->second.frequency=v;e.clear();return true;}
	bool getMouseJointDampingRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}v=j->second.damping;e.clear();return true;}
	bool setMouseJointDampingRatio(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="mouse"){e="mock MouseJoint is closed";return false;}j->second.damping=v;e.clear();return true;}
	JointHandle newMotorJoint(BodyHandle a,BodyHandle b,float correction,bool collide,std::string&e) override {auto ba=bodies.find(a);auto bb=bodies.find(b);if(ba==bodies.end()||bb==bodies.end()||ba->second.world!=bb->second.world){e="mock joint bodies differ";return 0;}auto h=next++;const float dx=bb->second.x-ba->second.x;const float dy=bb->second.y-ba->second.y;const float c=std::cos(ba->second.angle);const float s=std::sin(ba->second.angle);Joint j;j.a=a;j.b=b;j.x1=ba->second.x;j.y1=ba->second.y;j.x2=bb->second.x;j.y2=bb->second.y;j.offsetX=c*dx+s*dy;j.offsetY=-s*dx+c*dy;j.angularOffset=bb->second.angle-ba->second.angle;j.maxForce=meter;j.maxTorque=meter*meter;j.correctionFactor=correction;j.collide=collide;j.type="motor";joints[h]=j;e.clear();return h;}
	bool getMotorJointLinearOffset(JointHandle h,float&x,float&y,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}x=j->second.offsetX;y=j->second.offsetY;e.clear();return true;}
	bool setMotorJointLinearOffset(JointHandle h,float x,float y,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}j->second.offsetX=x;j->second.offsetY=y;e.clear();return true;}
	bool getMotorJointAngularOffset(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}v=j->second.angularOffset;e.clear();return true;}
	bool setMotorJointAngularOffset(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}j->second.angularOffset=v;e.clear();return true;}
	bool getMotorJointMaxForce(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}v=j->second.maxForce;e.clear();return true;}
	bool setMotorJointMaxForce(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}j->second.maxForce=v;e.clear();return true;}
	bool getMotorJointMaxTorque(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}v=j->second.maxTorque;e.clear();return true;}
	bool setMotorJointMaxTorque(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}j->second.maxTorque=v;e.clear();return true;}
	bool getMotorJointCorrectionFactor(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}v=j->second.correctionFactor;e.clear();return true;}
	bool setMotorJointCorrectionFactor(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="motor"){e="mock MotorJoint is closed";return false;}j->second.correctionFactor=v;e.clear();return true;}
	JointHandle newGearJoint(JointHandle a,JointHandle b,float ratio,bool collide,std::string&e) override {auto ja=joints.find(a);auto jb=joints.find(b);if(ja==joints.end()||jb==joints.end()||(ja->second.type!="revolute"&&ja->second.type!="prismatic")||(jb->second.type!="revolute"&&jb->second.type!="prismatic")){e="mock GearJoint sources invalid";return 0;}auto h=next++;Joint j;j.a=ja->second.b;j.b=jb->second.b;j.sourceA=a;j.sourceB=b;j.ratio=ratio;j.collide=collide;j.type="gear";joints[h]=j;e.clear();return h;}
	bool getGearJointRatio(JointHandle h,float&v,std::string&e) const override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="gear"){e="mock GearJoint is closed";return false;}v=j->second.ratio;e.clear();return true;}
	bool setGearJointRatio(JointHandle h,float v,std::string&e) override {auto j=joints.find(h);if(j==joints.end()||j->second.type!="gear"){e="mock GearJoint is closed";return false;}j->second.ratio=v;e.clear();return true;}

	float meter = 0.0f; std::uint64_t next = 1;
	int worldsReleased=0, shapesReleased=0, bodiesReleased=0, fixturesReleased=0, jointsReleased=0;
	std::unordered_map<WorldHandle,World> worlds; std::unordered_map<ShapeHandle,Shape> shapes;
	std::unordered_map<BodyHandle,Body> bodies; std::unordered_map<FixtureHandle,Fixture> fixtures;
	std::unordered_map<JointHandle,Joint> joints;
	std::unordered_map<ContactHandle,Contact> contacts;
};

[[noreturn]] void fail(const std::string &message)
{
	std::cerr << "FAIL: " << message << std::endl;
	std::exit(1);
}

void require(bool condition, const std::string &message)
{
	if (!condition)
		fail(message);
}

void requireNear(float actual, float expected, const std::string &message)
{
	if (std::abs(actual - expected) > 0.001f)
		fail(message + ": expected " + std::to_string(expected) + ", got " + std::to_string(actual));
}

void testLoveTextLayoutParity()
{
	const std::string text = "AB  V AB\nA B ";
	std::vector<Dora::LoveTextLayout::Codepoint> codepoints;
	for (std::size_t index = 0; index < text.size(); ++index)
		codepoints.push_back({static_cast<std::uint32_t>(text[index]), index, index + 1, 0});
	auto spacing = [](std::uint32_t value) {
		switch (value)
		{
			case 'A': return 4.0f;
			case 'B': return 6.0f;
			case 'V': return 7.0f;
			default: return 0.0f;
		}
	};
	auto kerning = [](std::uint32_t, std::uint32_t) { return 0.0f; };
	require(Dora::LoveTextLayout::measure(codepoints, spacing, kerning) == 27.0f,
		"LÖVE text measurement state machine diverged");
	const auto wrapped = Dora::LoveTextLayout::wrap(codepoints, 10.0f, spacing, kerning);
	const std::vector<std::string> expected{"AB  ", "V ", "AB", "A B "};
	require(wrapped.size() == expected.size(), "LÖVE text wrap line count diverged");
	for (std::size_t lineIndex = 0; lineIndex < wrapped.size(); ++lineIndex)
	{
		std::string line;
		for (const auto &codepoint : wrapped[lineIndex].codepoints)
			line.push_back(static_cast<char>(codepoint.value));
		require(line == expected[lineIndex], "LÖVE text wrap content diverged");
	}
	const std::vector<Dora::LoveTextLayout::Codepoint> overwide{{'V', 0, 1, 0}};
	const auto skipped = Dora::LoveTextLayout::wrap(overwide, 0.0f, spacing, kerning);
	require(skipped.size() == 2 && skipped[0].codepoints.empty()
		&& skipped[1].codepoints.empty(), "LÖVE over-wide first glyph behavior diverged");
}

void execute(Dora::Love::LoveRuntime &runtime, const char *code, const char *name)
{
	std::string error;
	if (!runtime.execute(code, name, error))
		fail(error);
}

std::string readFixture(const char *relativePath)
{
	std::ifstream input(std::string(DORA_LOVE_TEST_FIXTURES) + "/" + relativePath, std::ios::binary);
	if (!input)
		fail(std::string("failed to read fixture: ") + relativePath);
	std::ostringstream content;
	content << input.rdbuf();
	return content.str();
}

} // namespace

int main()
{
	static_assert(LUA_VERSION_NUM == 505, "LoveRuntime tests must use Dora Lua 5.5");
	testLoveTextLayoutParity();

	using namespace SoLoud;
	requireNear(calculateDistanceAttenuation(DISTANCE_NONE, 18.0f, 2.0f, 10.0f, 0.5f),
		1.0f, "none distance model attenuated audio");
	requireNear(calculateDistanceAttenuation(DISTANCE_INVERSE, 1.0f, 2.0f, 10.0f, 0.5f),
		4.0f / 3.0f, "unclamped inverse near-distance formula diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_INVERSE_CLAMPED, 1.0f, 2.0f, 10.0f, 0.5f),
		1.0f, "clamped inverse did not clamp to reference distance");
	requireNear(calculateDistanceAttenuation(DISTANCE_INVERSE, 18.0f, 2.0f, 10.0f, 0.5f),
		0.2f, "unclamped inverse far-distance formula diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_INVERSE_CLAMPED, 18.0f, 2.0f, 10.0f, 0.5f),
		1.0f / 3.0f, "clamped inverse did not clamp to max distance");
	requireNear(calculateDistanceAttenuation(DISTANCE_LINEAR, 1.0f, 2.0f, 10.0f, 0.5f),
		1.0625f, "unclamped linear near-distance formula diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_LINEAR, 18.0f, 2.0f, 10.0f, 0.5f),
		0.0f, "unclamped linear far-distance floor diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_LINEAR_CLAMPED, 18.0f, 2.0f, 10.0f, 0.5f),
		0.5f, "clamped linear did not clamp to max distance");
	requireNear(calculateDistanceAttenuation(DISTANCE_EXPONENT, 1.0f, 2.0f, 10.0f, 0.5f),
		std::sqrt(2.0f), "unclamped exponent near-distance formula diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_EXPONENT, 18.0f, 2.0f, 10.0f, 0.5f),
		1.0f / 3.0f, "unclamped exponent far-distance formula diverged from OpenAL");
	requireNear(calculateDistanceAttenuation(DISTANCE_EXPONENT_CLAMPED, 18.0f, 2.0f, 10.0f, 0.5f),
		1.0f / std::sqrt(5.0f), "clamped exponent did not clamp to max distance");
	requireNear(calculateDistanceAttenuation(DISTANCE_LINEAR_CLAMPED, 5.0f, 10.0f, 2.0f, 1.0f),
		1.0f, "clamped model did not follow OpenAL reference-above-max rule");
	requireNear(calculateConeAttenuation(0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 1.0f,
		1.57079632679f, 4.71238898038f, 0.2f), 1.0f,
		"source listener inside the inner cone did not preserve full gain");
	requireNear(calculateConeAttenuation(0.0f, 0.0f, -1.0f, 0.0f, 0.0f, -1.0f,
		1.57079632679f, 4.71238898038f, 0.2f), 0.2f,
		"source listener outside the outer cone did not use outer volume");
	requireNear(calculateConeAttenuation(0.0f, 0.0f, -1.0f, 1.0f, 0.0f, 0.0f,
		1.57079632679f, 4.71238898038f, 0.2f), 0.6f,
		"source cone transition did not linearly interpolate gain");
	requireNear(calculateConeAttenuation(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, -1.0f,
		0.0f, 0.0f, 0.0f), 1.0f, "zero source direction did not disable cone attenuation");
	requireNear(calculateHighFrequencyAttenuation(0.0f, 0.0f, -1.0f,
		0.0f, 0.0f, -1.0f, 1.57079632679f, 4.71238898038f, 0.5f,
		11.0f, 1.0f, 2.0f, 0.5f),
		0.5f * std::pow(OPENAL_AIR_ABSORPTION_GAIN_HF, 10.0f),
		"cone high-frequency and air absorption gains were not combined");
	const HighShelfCoefficients shelf = calculateOpenALHighShelf(48000.0f, 0.5f);
	requireNear((shelf.b0 + shelf.b1 + shelf.b2) / (1.0f + shelf.a1 + shelf.a2),
		1.0f, "OpenAL high shelf changed low-frequency gain");
	requireNear((shelf.b0 - shelf.b1 + shelf.b2) / (1.0f - shelf.a1 + shelf.a2),
		0.25f, "OpenAL high shelf did not reach the expected high-frequency response");
	float shelfState1 = 0.0f, shelfState2 = 0.0f, shelfOutput = 0.0f;
	for (int sample = 0; sample < 2048; ++sample)
		shelfOutput = processHighShelfSample(1.0f, shelf, shelfState1, shelfState2);
	requireNear(shelfOutput, 1.0f, "high shelf processing changed a settled DC signal");
	shelfState1 = shelfState2 = 0.0f;
	for (int sample = 0; sample < 2048; ++sample)
		shelfOutput = processHighShelfSample((sample & 1) ? -1.0f : 1.0f,
			shelf, shelfState1, shelfState2);
	requireNear(std::abs(shelfOutput), 0.25f,
		"high shelf processing did not attenuate a settled Nyquist signal");
	requireNear(clampSourceGain(0.1f, 0.25f, 0.75f), 0.25f,
		"source minimum volume limit was not applied");
	requireNear(clampSourceGain(0.9f, 0.25f, 0.75f), 0.75f,
		"source maximum volume limit was not applied");
	requireNear(clampSourceGain(0.5f, 0.8f, 0.4f), 0.4f,
		"source min-above-max volume limit did not follow OpenAL semantics");
	requireNear(calculateFinalSourceGain(2.0f, 0.0f, 1.0f, false, false), 2.0f,
		"ordinary Dora gain was unexpectedly clamped by Love volume limits");
	requireNear(calculateFinalSourceGain(2.0f, 0.0f, 1.0f, true, false), 1.0f,
		"explicit Love volume limits did not clamp final source gain");

	lua_State *doraState = luaL_newstate();
	require(doraState != nullptr, "failed to create the control Dora Lua state");
	luaL_openlibs(doraState);
	lua_getglobal(doraState, "love");
	require(lua_isnil(doraState, -1), "control Dora state unexpectedly contains love");
	lua_pop(doraState, 1);

	Dora::Love::LoveRuntime first;
	Dora::Love::LoveRuntime second;
	std::string error;
	require(first.open(error), error);
	require(second.open(error), error);
	require(first.getStatus() == Dora::Love::LoveRuntime::Status::Ready, "first runtime is not ready");
	execute(first,
		"local video = require('love.video')\n"
		"assert(video == love.video and type(video.newVideoStream) == 'function')\n"
		"assert(type(love.graphics.newVideo) == 'function' and type(love.graphics._newVideo) == 'function')\n"
		"assert(type(arg) == 'table' and string.format('%d/%02x', 3.9, 15.8) == '3/0f')\n"
		"for _ = 1, 20 do local value = math.random(64, 0); assert(value >= 0 and value <= 64) end\n"
		"local numericLoop = {}; for i = 2, 4 do i = i * 2; numericLoop[#numericLoop + 1] = i end\n"
		"assert(table.concat(numericLoop, ',') == '4,6,8', table.concat(numericLoop, ','))\n"
		"table.insert(package.searchers, 1, function(name) if name == 'loader_arg_compat' then return function(moduleName, loaderData) assert(moduleName == name and loaderData == nil); return {ok=true} end, '/virtual/loader.lua' end end)\n"
		"assert(require('loader_arg_compat').ok)\n"
		"package.preload.legacy_compat = function(...) module(..., package.seeall); answer = 42 end\n"
		"local legacy = require('legacy_compat'); assert(legacy.answer == 42 and _G.legacy_compat == legacy)\n",
		"@video-module-surface.lua");
	Dora::Love::LoveRuntime loadArgumentRuntime;
	require(loadArgumentRuntime.open(error), error);
	require(loadArgumentRuntime.boot(
		"function love.load(arguments) assert(arguments == arg and type(arguments) == 'table') end\n",
		"@load-argument-compat.lua", error), error);
	loadArgumentRuntime.close();

	Dora::Love::LoveRuntime threadRuntime;
	TestFilesystemBackend threadFilesystem;
	MockGraphics threadImageBackend;
	threadRuntime.setFilesystemBackend(&threadFilesystem);
	threadRuntime.setImageBackend(&threadImageBackend);
	require(threadRuntime.open(error), error);
	require(threadRuntime.setSourceRoot(std::string(DORA_LOVE_TEST_FIXTURES)
		+ "/RuntimeScene", error), error);
	execute(threadRuntime,
		"local threadModule = require('love.thread'); assert(threadModule == love.thread)\n"
		"local named = threadModule.getChannel('official-thread')\n"
		"assert(named == threadModule.getChannel('official-thread'))\n"
		"local producer = threadModule.newThread([[\n"
		"  require('love.timer').sleep(0.01)\n"
		"  love.thread.getChannel('official-thread'):push('hello world')\n"
		"  love.thread.getChannel('official-thread'):push('me again')\n"
		"]])\n"
		"assert(producer:type() == 'Thread' and producer:typeOf('Object'))\n"
		"assert(producer:start() and producer:isRunning())\n"
		"assert(named:demand(1) == 'hello world')\n"
		"producer:wait(); assert(not producer:isRunning() and producer:getError() == nil)\n"
		"assert(named:getCount() == 1 and named:peek() == 'me again' and named:pop() == 'me again')\n"
		"local atomic = function(channel, value) channel:clear(); return channel:push(value), value end\n"
		"local id, echoed = named:performAtomic(atomic, 'atomic')\n"
		"assert(echoed == 'atomic' and named:hasRead(id) == false and named:pop() == 'atomic' and named:hasRead(id))\n"
		"local argumentChannel = threadModule.newChannel()\n"
		"assert(argumentChannel:type() == 'Channel' and argumentChannel:typeOf('Object'))\n"
		"local fileThread = threadModule.newThread('thread-worker.lua')\n"
		"local transferred = love.data.newByteData('from-data')\n"
		"assert(fileThread:start(argumentChannel, transferred)); local result = argumentChannel:demand(1)\n"
		"fileThread:wait(); assert(type(result.value) == 'userdata' and result.value:getString() == 'from-data'\n"
		"  and result.worker and fileThread:getError() == nil)\n"
		"local fileObjectThread = threadModule.newThread(love.filesystem.newFile('thread-worker.lua'))\n"
		"local fileObjectChannel = threadModule.newChannel()\n"
		"assert(fileObjectThread:start(fileObjectChannel, 'from-file-object'))\n"
		"local fileObjectResult = fileObjectChannel:demand(1); fileObjectThread:wait()\n"
		"assert(fileObjectResult.value == 'from-file-object' and fileObjectResult.worker\n"
		"  and fileObjectThread:getError() == nil)\n"
		"local moduleChannel = threadModule.newChannel()\n"
		"local moduleThread = threadModule.newThread([[module(..., package.seeall)\nlocal event, channel = ...\nchannel:push(type(channel.demand))\n]])\n"
		"assert(moduleThread:start('eval', moduleChannel)); assert(moduleChannel:demand(1) == 'function'); moduleThread:wait(); assert(moduleThread:getError() == nil)\n"
		"local imageChannel = threadModule.newChannel()\n"
		"local imageThread = threadModule.newThread([[local channel = ...\nlocal bytes = love.filesystem.newFileData('encoded-image', 'mock.png')\nchannel:push(love.image.newImageData(bytes))\n]])\n"
		"assert(imageThread:start(imageChannel)); local threadImage = imageChannel:demand(1); imageThread:wait()\n"
		"assert(threadImage:getWidth() == 2 and threadImage:getHeight() == 1 and imageThread:getError() == nil)\n"
		"local timeoutChannel = threadModule.newChannel()\n"
		"assert(timeoutChannel:demand(0.001) == nil and timeoutChannel:supply('unread', 0.001) == false)\n"
		"assert(timeoutChannel:getCount() == 1 and timeoutChannel:pop() == 'unread')\n"
		"local bad = threadModule.newThread([[\nerror('thread boom')\n]])\n"
		"assert(bad:start()); bad:wait(); assert(bad:getError():find('thread boom', 1, true))\n"
		"local generatedCases = {\n"
		"  {[[-- [ts]: scripts/thread-fault.ts\nerror('THREAD_TS_MAP') -- 17\n]], 'scripts/thread-fault.ts:17:', 'THREAD_TS_MAP'},\n"
		"  {[[-- [tsx]: scripts/thread-fault.tsx\nerror('THREAD_TSX_MAP') -- 23\n]], 'scripts/thread-fault.tsx:23:', 'THREAD_TSX_MAP'},\n"
		"  {[[-- [tl]: scripts/thread-fault.tl\n\n\n\nerror('THREAD_TEAL_MAP')\n]], 'scripts/thread-fault.tl:4:', 'THREAD_TEAL_MAP'},\n"
		"  {[[-- [yue]: scripts/thread-fault.yue\nerror('THREAD_YUE_MAP') -- 31\n]], 'scripts/thread-fault.yue:31:', 'THREAD_YUE_MAP'},\n"
		"  {[[-- [ts]: scripts/thread-syntax.ts\nlocal value = -- 41\n]], 'scripts/thread-syntax.ts:41:', nil},\n"
		"}\n"
		"for _, case in ipairs(generatedCases) do\n"
		"  local generated = threadModule.newThread(case[1]); assert(generated:start()); generated:wait()\n"
		"  local generatedError = generated:getError(); assert(generatedError:find(case[2], 1, true))\n"
		"  assert(case[3] == nil or generatedError:find(case[3], 1, true))\n"
		"end\n"
		"love.event.pump(); local sawError = false\n"
		"for name, object, message in love.event.poll() do\n"
		"  if name == 'threaderror' and object == bad and message:find('thread boom', 1, true) then sawError = true end\n"
		"end\n"
		"assert(sawError)\n",
		"@thread-runtime.lua");

	Dora::Love::LoveRuntime isolatedThreadRuntime;
	isolatedThreadRuntime.setFilesystemBackend(&threadFilesystem);
	require(isolatedThreadRuntime.open(error), error);
	require(isolatedThreadRuntime.setSourceRoot(std::string(DORA_LOVE_TEST_FIXTURES)
		+ "/RuntimeScene", error), error);
	execute(isolatedThreadRuntime,
		"local channel = love.thread.getChannel('official-thread')\n"
		"assert(channel:getCount() == 0 and channel:pop() == nil)\n",
		"@thread-channel-isolation.lua");
	isolatedThreadRuntime.close();
	require(isolatedThreadRuntime.getAllocationBytes() == 0,
		"isolated Thread state retained Lua allocations after close");

	execute(threadRuntime,
		"blockedThread = love.thread.newThread([[\n"
		"  love.thread.getChannel('close-block'):demand()\n"
		"]])\n"
		"assert(blockedThread:start())\n",
		"@thread-close-cancellation.lua");
	const auto threadCloseStart = std::chrono::steady_clock::now();
	threadRuntime.close();
	require(std::chrono::steady_clock::now() - threadCloseStart < std::chrono::seconds(2),
		"LoveRuntime close did not cancel and join a blocked Thread");
	require(threadRuntime.getAllocationBytes() == 0,
		"Thread state retained Lua allocations after close");
	const auto emptyRuntimeBytes = first.getAllocationBytes();
	const auto emptyRuntimePeakBytes = first.getPeakAllocationBytes();
	require(emptyRuntimeBytes > 0 && emptyRuntimeBytes < 16 * 1024 * 1024,
		"empty LoveRuntime allocation baseline is outside the diagnostic guardrail");
	require(emptyRuntimePeakBytes >= emptyRuntimeBytes,
		"empty LoveRuntime peak allocation is below its live allocation");
	std::cout << "LOVE_EMPTY_RUNTIME_MEMORY_BASELINE " << emptyRuntimeBytes << ' '
		<< emptyRuntimePeakBytes << '\n';
	require(first.setPreloadModule("lualib_bundle", "return {owner = 'first'}\n", error), error);
	require(second.setPreloadModule("lualib_bundle", "return {owner = 'second'}\n", error), error);
	require(!first.setPreloadModule("../escape", "return {}\n", error),
		"invalid preload module name unexpectedly succeeded");
	execute(first, "assert(require('lualib_bundle').owner == 'first')\n", "@first-lualib.lua");
	execute(second, "assert(require('lualib_bundle').owner == 'second')\n", "@second-lualib.lua");

	const std::string defaultFontPath = std::string(DORA_LOVE_TEST_DORA_ROOT)
		+ "/Assets/Font/sarasa-mono-sc-regular.ttf";
	std::ifstream defaultFontInput(defaultFontPath, std::ios::binary);
	require(defaultFontInput.good(), "failed to open Dora default font fixture");
	const std::string defaultFontData((std::istreambuf_iterator<char>(defaultFontInput)),
		std::istreambuf_iterator<char>());
	Dora::Love::LoveRuntime trueTypeRuntime;
	TestFilesystemBackend trueTypeFilesystem;
	trueTypeRuntime.setFilesystemBackend(&trueTypeFilesystem);
	trueTypeRuntime.setDefaultFontData(defaultFontData);
	require(trueTypeRuntime.open(error), error);
	require(trueTypeRuntime.setSourceRoot(std::string(DORA_LOVE_TEST_DORA_ROOT)
		+ "/Assets/Font", error), error);
	execute(trueTypeRuntime,
		"local font = require('love.font'); assert(font == love.font)\n"
		"local raster = font.newTrueTypeRasterizer(20, 'normal', 1)\n"
		"assert(raster:type() == 'Rasterizer' and raster:typeOf('Object'))\n"
		"assert(raster:getHeight() > 0 and raster:getLineHeight() >= raster:getHeight())\n"
		"assert(raster:getAscent() > 0 and raster:getDescent() < 0 and raster:getGlyphCount() > 100)\n"
		"assert(raster:hasGlyphs('A中') and not pcall(raster.hasGlyphs, raster, string.char(0xff)))\n"
		"local glyph = raster:getGlyphData('A'); assert(glyph:getFormat() == 'la8')\n"
		"local w, h = glyph:getDimensions(); assert(w > 0 and h > 0 and glyph:getAdvance() > 0)\n"
		"assert(glyph:getSize() == w * h * 2 and love.data.newByteData(glyph):getSize() == glyph:getSize())\n"
		"local explicit = font.newTrueTypeRasterizer('sarasa-mono-sc-regular.ttf', 18, 'mono', 1.5)\n"
		"assert(explicit:hasGlyphs('A中') and explicit:getGlyphData('中'):getFormat() == 'la8')\n"
		"local generic = font.newRasterizer('sarasa-mono-sc-regular.ttf', 16, 'none', 1)\n"
		"assert(generic:hasGlyphs('Love'))\n"
		"assert(not pcall(font.newTrueTypeRasterizer, 0))\n"
		"assert(not pcall(font.newTrueTypeRasterizer, 12, 'invalid'))\n"
		"assert(not pcall(font.newTrueTypeRasterizer, 12, 'normal', 0))\n"
		"assert(not pcall(font.newTrueTypeRasterizer, love.filesystem.newFileData('bad', 'bad.ttf'), 12))\n",
		"@truetype-rasterizer.lua");
	trueTypeRuntime.close();
	require(trueTypeRuntime.getAllocationBytes() == 0,
		"TrueType Rasterizer state retained Lua allocations after close");

	execute(first,
		"assert(Dora == nil and DoraHost == nil)\n"
		"assert(not pcall(require, 'Dora'))\n"
		"assert(not pcall(require, 'DoraHost'))\n"
		"assert(type(love.run) == 'function')\n",
		"@pure-love.lua");
	execute(first,
		"assert(unpack == table.unpack and loadstring == load and package.loaders == package.searchers)\n"
		"local major, minor, revision, codename = love.getVersion()\n"
		"assert(major == 11 and minor == 5 and revision == 0 and codename == 'Mysterious Mysteries')\n"
		"assert(type(love.handlers) == 'table' and type(love.handlers.keypressed) == 'function')\n"
		"assert(select('#', require('love')) == 1)\n"
		"local loop = {}; for key, value in pairs({answer = 42, second = 7}) do key = key:upper(); loop[key] = value end\n"
		"assert(loop.ANSWER == 42 and loop.SECOND == 7)\n"
		"local dynamic = assert(loadstring('local char = string.char; return char(65)'))\n"
		"assert(dynamic() == 'A')\n"
		"assert(type(table.getn) == 'function' and table.getn({10, 20, 30}) == 3)\n"
		"assert(math.random(0.2, 0.4) == 0 and math.random(1.2, 1.9) == 1)\n"
		"assert(math.pow(2, 8) == 256)\n"
		"assert(math.abs(math.atan2(1, 0) - math.pi / 2) < 0.000001)\n"
		"local bit = require('bit')\n"
		"assert(bit.band(0xf0, 0x3c) == 0x30)\n"
		"assert(bit.bor(0x10, 0x03) == 0x13)\n"
		"assert(bit.bxor(0xff, 0x0f) == 0xf0)\n"
		"assert(bit.lshift(1, 4) == 16 and bit.rshift(0x80000000, 31) == 1)\n"
		"assert(bit.arshift(-8, 2) == -2 and bit.tohex(255, 4) == '00ff')\n"
		"local ok, message = pcall(require, 'ffi')\n"
		"assert(not ok and message:find('Lua 5.5') and message:find('ffi'))\n"
		"ok, message = pcall(require, 'jit')\n"
		"assert(not ok and message:find('Lua 5.5') and message:find('LuaJIT'))\n"
		"ok, message = pcall(package.loadlib, 'legacy.so', 'luaopen_legacy')\n"
		"assert(not ok and message:find('Lua 5.5') and message:find('native Lua modules'))\n"
		"local current = string.dump(function() return 55 end, true)\n"
		"local loader, loadError = load(current); assert(loader and loadError == nil and loader() == 55)\n"
		"loader, loadError = load(string.char(0x1b) .. 'Lua' .. string.char(0x51) .. 'legacy')\n"
		"assert(loader == nil and loadError:find('Lua 5.1 bytecode', 1, true) and loadError:find('recompile', 1, true))\n"
		"loader, loadError = load(string.char(0x1b) .. 'LJ' .. string.char(2) .. 'legacy')\n"
		"assert(loader == nil and loadError:find('LuaJIT bytecode', 1, true) and loadError:find('Lua 5.5', 1, true))\n",
		"@lua55-compat.lua");
	lua_State *strictLua55 = luaL_newstate();
	require(strictLua55 != nullptr, "failed to create strict Lua 5.5 control state");
	require(luaL_loadstring(strictLua55,
		"for key in pairs({answer = 42}) do key = key:upper() end") == LUA_ERRSYNTAX,
		"Love loop-variable compatibility leaked into an ordinary Lua 5.5 state");
	lua_close(strictLua55);
	execute(first,
		"assert(type(getfenv) == 'function' and type(setfenv) == 'function')\n"
		"assert(getfenv(0) == _G and getfenv(print) == _G)\n"
		"local oldMarker = rawget(_G, 'compatibility_marker')\n"
		"compatibility_marker = 'global'\n"
		"local function makePair()\n"
		"  local function isolated() return compatibility_marker end\n"
		"  local function untouched() return compatibility_marker end\n"
		"  return isolated, untouched\n"
		"end\n"
		"local isolated, untouched = makePair()\n"
		"local isolatedEnv = {compatibility_marker = 'isolated'}\n"
		"assert(setfenv(isolated, isolatedEnv) == isolated)\n"
		"assert(getfenv(isolated) == isolatedEnv and isolated() == 'isolated')\n"
		"assert(getfenv(untouched) == _G and untouched() == 'global')\n"
		"local noGlobals = function(value) return value + 1 end\n"
		"local noGlobalsEnv = {tag = 'no-env'}\n"
		"assert(setfenv(noGlobals, noGlobalsEnv) == noGlobals)\n"
		"assert(getfenv(noGlobals) == noGlobalsEnv and noGlobals(4) == 5)\n"
		"local stackEnv = setmetatable({stack_marker = 'stack'}, {__index = _G})\n"
		"local function stackLevel()\n"
		"  local result = setfenv(1, stackEnv)\n"
		"  return result, stack_marker, getfenv()\n"
		"end\n"
		"local level, marker, currentEnv = stackLevel()\n"
		"assert(level == 1 and marker == 'stack' and currentEnv == stackEnv)\n"
		"local function stackLevelTwo()\n"
		"  local function replaceOuter()\n"
		"    local environment = setmetatable({level_two_marker = 'outer'}, {__index = _G})\n"
		"    assert(setfenv(2, environment) == 2)\n"
		"    return environment\n"
		"  end\n"
		"  local environment = replaceOuter()\n"
		"  return level_two_marker, getfenv(), environment\n"
		"end\n"
		"local levelTwoMarker, levelTwoCurrent, levelTwoExpected = stackLevelTwo()\n"
		"assert(levelTwoMarker == 'outer' and levelTwoCurrent == levelTwoExpected)\n"
		"local ok, message = pcall(setfenv, 0, {})\n"
		"assert(not ok and message:find('Lua 5.5', 1, true) and message:find('thread environment', 1, true))\n"
		"ok, message = pcall(setfenv, print, {})\n"
		"assert(not ok and message:find('C function', 1, true))\n"
		"assert(not pcall(getfenv, -1) and not pcall(getfenv, 1.5) and not pcall(getfenv, {}))\n"
		"assert(not pcall(setfenv, isolated, false) and not pcall(getfenv, 100000))\n"
		"local weak = setmetatable({}, {__mode = 'v'})\n"
		"do\n"
		"  local function temporary(value) return value end\n"
		"  local temporaryEnv = {temporary = true}\n"
		"  setfenv(temporary, temporaryEnv)\n"
		"  weak[1], weak[2] = temporary, temporaryEnv\n"
		"end\n"
		"collectgarbage('collect'); collectgarbage('collect')\n"
		"assert(weak[1] == nil and weak[2] == nil)\n"
		"compatibility_marker = oldMarker\n",
		"@setfenv-compat.lua");
	execute(second,
		"local environment = {state_owner = 'second'}\n"
		"local function readOwner() return state_owner end\n"
		"setfenv(readOwner, environment)\n"
		"assert(readOwner() == 'second' and getfenv(readOwner) == environment)\n",
		"@setfenv-second-state.lua");
	const std::string lua51Bytecode = std::string("\x1bLua", 4) + static_cast<char>(0x51) + "legacy";
	require(!first.execute(lua51Bytecode, "@legacy-5.1.luac", error),
		"LoveRuntime execute unexpectedly accepted Lua 5.1 bytecode");
	require(error.find("Lua 5.1 bytecode") != std::string::npos
		&& error.find("Lua 5.5") != std::string::npos && error.find("recompile") != std::string::npos,
		"Lua 5.1 bytecode execute error was not actionable");
	const std::string luaJitBytecode = std::string("\x1bLJ", 3) + static_cast<char>(2) + "legacy";
	require(!first.execute(luaJitBytecode, "@legacy-luajit.luac", error),
		"LoveRuntime execute unexpectedly accepted LuaJIT bytecode");
	require(error.find("LuaJIT bytecode") != std::string::npos
		&& error.find("Lua 5.5") != std::string::npos && error.find("recompile") != std::string::npos,
		"LuaJIT bytecode execute error was not actionable");

	execute(first,
		"local system = require('love.system'); assert(system == love.system)\n"
		"assert(system.getOS() == 'Unknown' and system.getProcessorCount() >= 1)\n"
		"local state, percent, seconds = system.getPowerInfo(); assert(state == 'unknown' and percent == nil and seconds == nil)\n"
		"assert(not system.openURL('https://example.com') and not system.hasBackgroundMusic())\n"
		"system.vibrate(); local ok, message = pcall(system.getClipboardText); assert(not ok and message:find('backend is unavailable', 1, true))\n",
		"@system-without-backend.lua");

	MockSystem systemBackend;
	Dora::Love::LoveRuntime systemRuntime;
	systemRuntime.setSystemBackend(&systemBackend);
	require(systemRuntime.open(error), error);
	execute(systemRuntime,
		"local system = require('love.system'); assert(system == love.system)\n"
		"assert(system.getOS() == 'Linux' and system.getProcessorCount() == 12)\n"
		"system.setClipboardText('Love clipboard'); assert(system.getClipboardText() == 'Love clipboard')\n"
		"local state, percent, seconds = system.getPowerInfo(); assert(state == 'charging' and percent == 73 and seconds == 900)\n"
		"assert(system.openURL('https://example.com/love') and not system.openURL('file:///tmp/no'))\n"
		"system.vibrate(0.25); assert(system.hasBackgroundMusic())\n"
		"assert(not pcall(system.vibrate, -1) and not pcall(system.vibrate, 0/0))\n",
		"@system.lua");
	require(systemBackend.clipboard == "Love clipboard", "system clipboard setter did not reach backend");
	require(systemBackend.lastURL == "file:///tmp/no", "system openURL did not preserve URL input");
	requireNear(static_cast<float>(systemBackend.lastVibration), 0.25f, "system vibration duration");
	systemBackend.rejectClipboard = true;
	execute(systemRuntime,
		"local ok, message = pcall(love.system.setClipboardText, 'blocked'); assert(not ok and message:find('mock clipboard rejected text', 1, true))\n"
		"ok, message = pcall(love.system.getClipboardText); assert(not ok and message:find('mock clipboard unavailable', 1, true))\n",
		"@system-errors.lua");
	systemRuntime.close();
	require(systemRuntime.getAllocationBytes() == 0, "system state retained Lua allocations after close");

	Dora::Love::LoveRuntime officialCompatibilityRuntime;
	systemBackend.rejectClipboard = false;
	TestFilesystemBackend officialFilesystem;
	MockGraphics officialGraphics;
	MockSound officialSound;
	MockAudio officialAudio;
	MockPhysics officialPhysics;
	officialCompatibilityRuntime.setSystemBackend(&systemBackend);
	officialCompatibilityRuntime.setFilesystemBackend(&officialFilesystem);
	officialCompatibilityRuntime.setGraphicsBackend(&officialGraphics);
	officialCompatibilityRuntime.setImageBackend(&officialGraphics);
	officialCompatibilityRuntime.setSoundBackend(&officialSound);
	officialCompatibilityRuntime.setAudioBackend(&officialAudio);
	officialCompatibilityRuntime.setPhysicsBackend(&officialPhysics);
	officialCompatibilityRuntime.setDefaultFontData(defaultFontData);
	officialAudio.unavailableSourceSuffixes.insert("sample-no-audio.ogv");
	require(officialCompatibilityRuntime.open(error), error);
	const std::string officialFixtureRoot = DORA_LOVE_TEST_FIXTURES;
	require(officialCompatibilityRuntime.setSourceRoot(officialFixtureRoot + "/RuntimeScene", error), error);
	const std::filesystem::path officialSaveBase = std::filesystem::temp_directory_path()
		/ ("dora-love-official-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	require(officialCompatibilityRuntime.setSaveBaseRoot(officialSaveBase.string(), error), error);
	const std::string officialDataMath = readFixture("OfficialCompatibility/data_math.lua");
	execute(officialCompatibilityRuntime, officialDataMath.c_str(), "@official-data-math.lua");
	execute(officialCompatibilityRuntime,
		"assert(official_passed == 231)\n"
		"assert(#official_failed == 0, table.concat(official_failed, '\\n'))\n"
		"assert(#official_skipped == 60)\n"
		"assert(official_modules.data.passed == 8 and official_modules.data.failed == 0 and official_modules.data.skipped == 0)\n"
		"assert(official_modules.math.passed == 6 and official_modules.math.failed == 0 and official_modules.math.skipped == 2)\n"
		"assert(official_modules.event.passed == 4 and official_modules.event.failed == 0 and official_modules.event.skipped == 2)\n"
		"assert(official_modules.timer.passed == 6 and official_modules.timer.failed == 0 and official_modules.timer.skipped == 0)\n"
		"assert(official_modules.system.passed == 6 and official_modules.system.failed == 0 and official_modules.system.skipped == 2)\n"
		"assert(official_modules.filesystem.passed == 26 and official_modules.filesystem.failed == 0 and official_modules.filesystem.skipped == 6)\n"
		"assert(official_modules.image.passed == 5 and official_modules.image.failed == 0 and official_modules.image.skipped == 0)\n"
		"assert(official_modules.sound.passed == 4 and official_modules.sound.failed == 0 and official_modules.sound.skipped == 0)\n"
		"assert(official_modules.audio.passed == 28 and official_modules.audio.failed == 0 and official_modules.audio.skipped == 1)\n"
		"assert(official_modules.font.passed == 7 and official_modules.font.failed == 0 and official_modules.font.skipped == 0)\n"
		"assert(official_modules.physics.passed == 21 and official_modules.physics.failed == 0 and official_modules.physics.skipped == 7)\n"
		"assert(official_modules.window.passed == 28 and official_modules.window.failed == 0 and official_modules.window.skipped == 8)\n"
		"assert(official_modules.graphics.passed == 75 and official_modules.graphics.failed == 0 and official_modules.graphics.skipped == 32)\n"
		"assert(official_modules.thread.passed == 5 and official_modules.thread.failed == 0 and official_modules.thread.skipped == 0)\n"
		"assert(official_modules.video.passed == 2 and official_modules.video.failed == 0 and official_modules.video.skipped == 0)\n",
		"@verify-official-data-math.lua");
	officialCompatibilityRuntime.close();
	require(officialCompatibilityRuntime.getAllocationBytes() == 0,
		"official compatibility state retained Lua allocations after close");
	require(officialAudio.sources.empty(),
		"official compatibility state retained Dora AudioSource handles after close");
	require(officialGraphics.imageUpdates > 0 && officialGraphics.imageDraws >= 20,
		"official Video did not decode, upload, and draw a real Ogg/Theora frame");
	require(std::count_if(officialFilesystem.loadedPaths.begin(), officialFilesystem.loadedPaths.end(),
		[](const std::string &path) { return path.ends_with(".ogv"); }) >= 6,
		"official Video fixtures were not loaded through the injected Dora Content backend");
	require(officialPhysics.worlds.empty() && officialPhysics.bodies.empty()
		&& officialPhysics.fixtures.empty() && officialPhysics.joints.empty()
		&& officialPhysics.shapes.empty(),
		"official compatibility state retained physics handles after close");
	require(officialGraphics.imagesCreated == officialGraphics.imagesReleased
		&& officialGraphics.canvasesCreated == officialGraphics.canvasesReleased
		&& officialGraphics.fontsCreated == officialGraphics.fontsReleased
		&& officialGraphics.shadersCreated == officialGraphics.shadersReleased
		&& officialGraphics.layeredImages.empty() && officialGraphics.canvases.empty()
		&& officialGraphics.fontSizes.empty() && officialGraphics.shaderUniforms.empty()
		&& officialGraphics.currentCanvases.empty() && officialGraphics.currentShader == 0,
		"official compatibility state retained graphics handles after close");
	std::error_code officialCleanupError;
	std::filesystem::remove_all(officialSaveBase, officialCleanupError);

	MockGraphics openSourceGraphics;
	TestFilesystemBackend openSourceFilesystem;
	Dora::Love::LoveRuntime openSourceGameTimer;
	openSourceGameTimer.setFilesystemBackend(&openSourceFilesystem);
	openSourceGameTimer.setGraphicsBackend(&openSourceGraphics);
	require(openSourceGameTimer.open(error), error);
	require(openSourceGameTimer.setSourceRoot(officialFixtureRoot + "/OpenSource/GameTimer", error), error);
	execute(openSourceGameTimer, readFixture("OpenSource/GameTimer/conf.lua").c_str(),
		"@OpenSource/GameTimer/conf.lua");
	require(openSourceGameTimer.configure(error), error);
	const std::string gameTimerMain = readFixture("OpenSource/GameTimer/main.lua");
	require(openSourceGameTimer.boot(gameTimerMain, "@OpenSource/GameTimer/main.lua", error), error);
	require(openSourceGameTimer.update(0.5, error), error);
	require(openSourceGameTimer.draw(error), error);
	execute(openSourceGameTimer,
		"assert(type(timeFormat) == 'function')\n"
		"assert(type(fontConfig) == 'userdata')\n"
		"assert(Width == 800 and Height == 600)\n"
		"print('LOVE_OPEN_SOURCE_GAME_TIMER_PASS', Width, Height, timeFormat(0.5))\n",
		"@verify-open-source-game-timer.lua");
	require(openSourceGraphics.begins == 2 && openSourceGraphics.ends == 2,
		"open-source Game Timer load and draw were not bracketed by graphics frames");
	require(openSourceGraphics.textDrawRecords.size() == 3
		&& openSourceGraphics.textDrawRecords[0].text == "0.500"
		&& openSourceGraphics.textDrawRecords[2].text == "Press 'spacebar' to start/stop the timer",
		"open-source Game Timer did not render its upstream timer and instruction text");
	openSourceGameTimer.close();
	require(openSourceGameTimer.getAllocationBytes() == 0,
		"open-source Game Timer retained Lua allocations after close");
	require(openSourceGraphics.fontsCreated == openSourceGraphics.fontsReleased
		&& openSourceGraphics.fontSizes.empty(),
		"open-source Game Timer retained Font handles after close");

	MockGraphics openSourceBreakoutGraphics;
	MockPhysics openSourceBreakoutPhysics;
	TestFilesystemBackend openSourceBreakoutFilesystem;
	Dora::Love::LoveRuntime openSourceBreakout;
	openSourceBreakout.setFilesystemBackend(&openSourceBreakoutFilesystem);
	openSourceBreakout.setGraphicsBackend(&openSourceBreakoutGraphics);
	openSourceBreakout.setPhysicsBackend(&openSourceBreakoutPhysics);
	require(openSourceBreakout.open(error), error);
	require(openSourceBreakout.setSourceRoot(
		officialFixtureRoot + "/OpenSource/Learn2LoveBreakout", error), error);
	execute(openSourceBreakout,
		readFixture("OpenSource/Learn2LoveBreakout/conf.lua").c_str(),
		"@OpenSource/Learn2LoveBreakout/conf.lua");
	require(openSourceBreakout.configure(error), error);
	const std::string breakoutMain = readFixture("OpenSource/Learn2LoveBreakout/main.lua");
	require(openSourceBreakout.boot(
		breakoutMain, "@OpenSource/Learn2LoveBreakout/main.lua", error), error);
	execute(openSourceBreakout,
		"assert(love.graphics.getWidth() == 800 and love.graphics.getHeight() == 600)\n"
		"assert(#require('entities') == 48)\n"
		"assert(type(package.loaded['entities/ball']) == 'function')\n"
		"assert(require('state').game_over == false)\n",
		"@verify-open-source-breakout-boot.lua");
	require(openSourceBreakoutPhysics.worlds.size() == 1
		&& openSourceBreakoutPhysics.bodies.size() == 45
		&& openSourceBreakoutPhysics.shapes.size() == 45
		&& openSourceBreakoutPhysics.fixtures.size() == 45,
		"open-source Breakout did not construct its complete upstream physics scene");
	require(openSourceBreakout.draw(error), error);
	openSourceBreakout.queueKeyPressed("left", "left");
	require(openSourceBreakout.update(1.0 / 60.0, error), error);
	auto paddleBody = openSourceBreakoutPhysics.bodies.end();
	for (auto body = openSourceBreakoutPhysics.bodies.begin();
		body != openSourceBreakoutPhysics.bodies.end(); ++body)
	{
		if (body->second.type == "kinematic")
		{
			paddleBody = body;
			break;
		}
	}
	require(paddleBody != openSourceBreakoutPhysics.bodies.end()
		&& paddleBody->second.vx == -600.0f,
		"open-source Breakout key callback did not drive its kinematic paddle");
	openSourceBreakout.queueKeyReleased("left", "left");
	require(openSourceBreakout.update(1.0 / 60.0, error), error);
	require(paddleBody->second.vx == 0.0f,
		"open-source Breakout key release did not stop its kinematic paddle");
	require(openSourceBreakout.draw(error), error);
	execute(openSourceBreakout,
		"local state = require('state')\n"
		"assert(state.game_over == true and state.stage_cleared == false)\n"
		"print('LOVE_OPEN_SOURCE_BREAKOUT_PASS', #require('entities'), love.graphics.getWidth(), love.graphics.getHeight())\n",
		"@verify-open-source-breakout-run.lua");
	require(openSourceBreakoutGraphics.begins == 2
		&& openSourceBreakoutGraphics.ends == 2
		&& openSourceBreakoutGraphics.polygons == 80
		&& openSourceBreakoutGraphics.circles == 2,
		"open-source Breakout did not draw two complete upstream frames");
	require(openSourceBreakoutGraphics.textDrawRecords.size() == 1
		&& openSourceBreakoutGraphics.textDrawRecords[0].text == "GAME OVER",
		"open-source Breakout contact callback did not reach its game-over draw state");
	openSourceBreakout.close();
	require(openSourceBreakout.getAllocationBytes() == 0,
		"open-source Breakout retained Lua allocations after close");
	require(openSourceBreakoutPhysics.worlds.empty()
		&& openSourceBreakoutPhysics.bodies.empty()
		&& openSourceBreakoutPhysics.shapes.empty()
		&& openSourceBreakoutPhysics.fixtures.empty()
		&& openSourceBreakoutPhysics.contacts.empty(),
		"open-source Breakout retained physics handles after close");

	MockGraphics openSourceDenverGraphics;
	MockAudio openSourceDenverAudio;
	TestFilesystemBackend openSourceDenverFilesystem;
	Dora::Love::LoveRuntime openSourceDenver;
	openSourceDenver.setFilesystemBackend(&openSourceDenverFilesystem);
	openSourceDenver.setGraphicsBackend(&openSourceDenverGraphics);
	openSourceDenver.setAudioBackend(&openSourceDenverAudio);
	require(openSourceDenver.open(error), error);
	require(openSourceDenver.setSourceRoot(
		officialFixtureRoot + "/OpenSource/DenverSynth", error), error);
	execute(openSourceDenver,
		"love.filesystem.setRequirePath('example-synthesizer/?.lua;example-synthesizer/?/init.lua;?.lua;?/init.lua')\n",
		"@configure-open-source-denver-path.lua");
	execute(openSourceDenver,
		readFixture("OpenSource/DenverSynth/example-synthesizer/conf.lua").c_str(),
		"@OpenSource/DenverSynth/example-synthesizer/conf.lua");
	require(openSourceDenver.configure(error), error);
	require(openSourceDenver.getConfiguredWidth() == 320
		&& openSourceDenver.getConfiguredHeight() == 288,
		"open-source Denver synthesizer conf dimensions were not retained");
	require(openSourceDenverGraphics.setMode(320, 288, error), error);
	const std::string denverMain = readFixture(
		"OpenSource/DenverSynth/example-synthesizer/main.lua");
	require(openSourceDenver.boot(denverMain,
		"@OpenSource/DenverSynth/example-synthesizer/main.lua", error), error);
	require(openSourceDenverAudio.sources.size() == 108,
		"open-source Denver synthesizer did not generate all 108 note Sources");
	openSourceDenver.queueKeyPressed("q", "q");
	require(openSourceDenver.update(1.0 / 60.0, error), error);
	require(std::count_if(openSourceDenverAudio.sources.begin(), openSourceDenverAudio.sources.end(),
		[](const auto &entry) { return entry.second.playing && entry.second.looping; }) == 1,
		"open-source Denver synthesizer key press did not play one looping note");
	openSourceDenver.queueKeyReleased("q", "q");
	require(openSourceDenver.update(1.0 / 60.0, error), error);
	require(std::none_of(openSourceDenverAudio.sources.begin(), openSourceDenverAudio.sources.end(),
		[](const auto &entry) { return entry.second.playing; }),
		"open-source Denver synthesizer key release did not stop its note");
	require(openSourceDenver.draw(error), error);
	require(openSourceDenverGraphics.textDrawRecords.size() == 2
		&& openSourceDenverGraphics.textDrawRecords[0].text == "LOVE synthesizer",
		"open-source Denver synthesizer did not render both upstream instructions");
	execute(openSourceDenver,
		"print('LOVE_OPEN_SOURCE_DENVER_PASS', love.graphics.getWidth(), love.graphics.getHeight())\n",
		"@verify-open-source-denver.lua");
	openSourceDenver.close();
	require(openSourceDenver.getAllocationBytes() == 0,
		"open-source Denver synthesizer retained Lua allocations after close");
	require(openSourceDenverAudio.sources.empty() && openSourceDenverAudio.released == 108,
		"open-source Denver synthesizer retained generated AudioSource handles after close");
	require(openSourceDenverGraphics.fontsCreated == openSourceDenverGraphics.fontsReleased
		&& openSourceDenverGraphics.fontSizes.empty(),
		"open-source Denver synthesizer retained Font handles after close");

	MockGraphics openSourceAtlasGraphics;
	TestFilesystemBackend openSourceAtlasFilesystem;
	Dora::Love::LoveRuntime openSourceAtlas;
	openSourceAtlas.setFilesystemBackend(&openSourceAtlasFilesystem);
	openSourceAtlas.setGraphicsBackend(&openSourceAtlasGraphics);
	require(openSourceAtlas.open(error), error);
	require(openSourceAtlas.setSourceRoot(
		officialFixtureRoot + "/OpenSource/RuntimeTextureAtlas", error), error);
	const char *atlasHarness =
		"local DynamicAtlas = require('dynamicSize')\n"
		"local function solid(width, height, red, green, blue)\n"
		"  local data = love.image.newImageData(width, height, 'rgba8')\n"
		"  data:mapPixel(function() return red, green, blue, 1 end)\n"
		"  return data\n"
		"end\n"
		"function love.load()\n"
		"  local atlas = DynamicAtlas.new(1, 1, 1):useImageData(true):setMaxSize(32, 32):setBakeAsPow2(true)\n"
		"  atlas:add(solid(2, 2, 1, 0, 0), 'red')\n"
		"  atlas:add(solid(3, 1, 0, 0.5, 1), 'blue')\n"
		"  local _, data = atlas:hardBake()\n"
		"  assert(data:getWidth() == 8 and data:getHeight() == 16)\n"
		"  local rx, ry, rw, rh = atlas:getViewport('red')\n"
		"  local bx, by, bw, bh = atlas:getViewport('blue')\n"
		"  assert(rx == 2 and ry == 2 and rw == 2 and rh == 2)\n"
		"  assert(bx == 2 and by == 9 and bw == 3 and bh == 1)\n"
		"  local r, g, b, a = data:getPixel(rx - 1, ry - 1)\n"
		"  assert(r == 1 and g == 0 and b == 0 and a == 1)\n"
		"  r, g, b, a = data:getPixel(bx, by)\n"
		"  assert(r == 0 and g > 0.49 and g < 0.51 and b == 1 and a == 1)\n"
		"  generatedAtlas = love.graphics.newImage(data)\n"
		"end\n"
		"function love.draw() love.graphics.draw(generatedAtlas, 4, 6) end\n";
	require(openSourceAtlas.boot(atlasHarness,
		"@OpenSource/RuntimeTextureAtlas/dora-test-harness.lua", error), error);
	require(openSourceAtlas.draw(error), error);
	execute(openSourceAtlas,
		"assert(generatedAtlas:getWidth() == 8 and generatedAtlas:getHeight() == 16)\n"
		"print('LOVE_OPEN_SOURCE_ATLAS_PASS', generatedAtlas:getWidth(), generatedAtlas:getHeight())\n",
		"@verify-open-source-runtime-texture-atlas.lua");
	require(openSourceAtlasGraphics.imagesCreated == 1
		&& openSourceAtlasGraphics.imageDraws == 1
		&& openSourceAtlasGraphics.layeredImages.size() == 1,
		"open-source Runtime Texture Atlas did not upload and draw its generated atlas");
	const auto &atlasPixels = openSourceAtlasGraphics.layeredImages.begin()->second;
	require(atlasPixels.width == 8 && atlasPixels.height == 16
		&& atlasPixels.pixels.size() == 8 * 16 * 4,
		"open-source Runtime Texture Atlas uploaded unexpected image dimensions");
	openSourceAtlas.close();
	require(openSourceAtlas.getAllocationBytes() == 0,
		"open-source Runtime Texture Atlas retained Lua allocations after close");
	require(openSourceAtlasGraphics.imagesCreated == openSourceAtlasGraphics.imagesReleased
		&& openSourceAtlasGraphics.layeredImages.empty(),
		"open-source Runtime Texture Atlas retained Image handles after close");

	TestFilesystemBackend bytecodeFilesystem;
	Dora::Love::LoveRuntime bytecodeRuntime;
	bytecodeRuntime.setFilesystemBackend(&bytecodeFilesystem);
	require(bytecodeRuntime.open(error), error);
	require(bytecodeRuntime.setSourceRoot(officialFixtureRoot + "/RuntimeScene", error), error);
	const std::filesystem::path bytecodeSaveBase = std::filesystem::temp_directory_path()
		/ ("dora-love-bytecode-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	require(bytecodeRuntime.setSaveBaseRoot(bytecodeSaveBase.string(), error), error);
	execute(bytecodeRuntime,
		"local filesystem = require('love.filesystem')\n"
		"filesystem.setIdentity('bytecode')\n"
		"local current = string.dump(function() return {runtime = 'Lua 5.5'} end, true)\n"
		"assert(filesystem.write('current.lua', current))\n"
		"local module = require('current'); assert(module.runtime == 'Lua 5.5')\n"
		"local loader, message = filesystem.load('current.lua'); assert(loader and message == nil and loader().runtime == 'Lua 5.5')\n"
		"local legacy = string.char(0x1b) .. 'Lua' .. string.char(0x51) .. 'legacy'\n"
		"assert(filesystem.write('legacy.lua', legacy))\n"
		"local ok; ok, message = pcall(require, 'legacy')\n"
		"assert(not ok and message:find('Lua 5.1 bytecode', 1, true) and message:find('recompile', 1, true))\n"
		"loader, message = filesystem.load('legacy.lua')\n"
		"assert(loader == nil and message:find('Lua 5.1 bytecode', 1, true) and message:find('Lua 5.5', 1, true))\n"
		"local jit = string.char(0x1b) .. 'LJ' .. string.char(2) .. 'legacy'\n"
		"assert(filesystem.write('jit_file.lua', jit))\n"
		"ok, message = pcall(require, 'jit_file')\n"
		"assert(not ok)\n"
		"loader, message = filesystem.load('jit_file.lua')\n"
		"assert(loader == nil and message:find('LuaJIT bytecode', 1, true) and message:find('Lua 5.5', 1, true))\n"
		"print('LOVE_LUA55_BYTECODE_PASS', module.runtime)\n",
		"@bytecode-compatibility.lua");
	bytecodeRuntime.close();
	require(bytecodeRuntime.getAllocationBytes() == 0,
		"bytecode compatibility state retained Lua allocations after close");
	std::error_code bytecodeCleanupError;
	std::filesystem::remove_all(bytecodeSaveBase, bytecodeCleanupError);

	execute(first,
		"local instance = require('love')\n"
		"assert(instance == love)\n"
		"love.owner = 'first'\n"
		"global_owner = 'first'\n"
		"package.loaded.shared_test = {owner = 'first'}\n",
		"@first.lua");
	execute(second,
		"local instance = require('love')\n"
		"assert(instance == love)\n"
		"love.owner = 'second'\n"
		"global_owner = 'second'\n"
		"package.loaded.shared_test = {owner = 'second'}\n",
		"@second.lua");

	execute(first,
		"assert(global_owner == 'first')\n"
		"assert(love.owner == 'first')\n"
		"assert(package.loaded.shared_test.owner == 'first')\n",
		"@verify-first.lua");
	execute(second,
		"assert(global_owner == 'second')\n"
		"assert(love.owner == 'second')\n"
		"assert(package.loaded.shared_test.owner == 'second')\n",
		"@verify-second.lua");

	const char *boot =
		"local instance = require('love')\n"
		"assert(instance == love)\n"
		"boot_generation = (boot_generation or 0) + 1\n"
		"function love.load() loaded = (loaded or 0) + 1 end\n"
		"function love.update(dt) updates = (updates or 0) + 1; elapsed = (elapsed or 0) + dt end\n"
		"function love.draw() draws = (draws or 0) + 1 end\n"
		"function love.quit() quits = (quits or 0) + 1 end\n";
	require(first.boot(boot, "@boot.lua", error), error);
	require(first.update(0.25, error), error);
	require(first.draw(error), error);
	execute(first, "assert(loaded == 1 and updates == 1 and elapsed == 0.25 and draws == 1)\n", "@verify-callbacks.lua");
	require(first.restart(error), error);
	execute(first,
		"assert(boot_generation == 1 and loaded == 1 and updates == nil and draws == nil)\n"
		"assert(require('lualib_bundle').owner == 'first')\n",
		"@verify-restart.lua");
	require(first.stop(error), error);
	execute(first, "assert(quits == 1)\n", "@verify-stop.lua");

	Dora::Love::LoveRuntime eventRuntime;
	require(eventRuntime.open(error), error);
	execute(eventRuntime, "love.keyboard.setKeyRepeat(1); assert(love.keyboard.hasKeyRepeat())",
		"@enable-event-key-repeat.lua");
	eventRuntime.queueKeyPressed("e", "e", true);
	execute(eventRuntime,
		"local event = require('love.event'); assert(event == love.event)\n"
		"event.pump()\n"
		"local iterator = event.poll(); assert(type(iterator) == 'function')\n"
		"local name, key, scancode, repeated = iterator()\n"
		"assert(name == 'keypressed' and key == 'e' and scancode == 'e' and repeated == true)\n"
		"assert(love.keyboard.isDown('e') and iterator() == nil and event.wait() == nil)\n"
		"eventMarker = love.data.newByteData('event-payload')\n"
		"assert(event.push('custom', true, 3.5, 'value', eventMarker, nil, 'ignored'))\n"
		"name, eventBool, eventNumber, eventString, eventObject = event.wait()\n"
		"assert(name == 'custom' and eventBool == true and eventNumber == 3.5)\n"
		"assert(eventString == 'value' and eventObject == eventMarker)\n"
		"assert(event.push('discarded', eventMarker)); event.clear(); assert(event.wait() == nil)\n"
		"assert(event.quit(7)); local reason, status = event.wait(); assert(reason == 'quit' and status == 7)\n"
		"assert(event.quit('restart')); reason, status = event.wait(); assert(reason == 'quit' and status == 'restart')\n"
		"local ok, message = pcall(event.push, 'bad', {}); assert(not ok and message:find('must be boolean', 1, true))\n",
		"@event-queue-api.lua");
	require(eventRuntime.boot(
		"custom_calls = 0\n"
		"function love.custom(flag, number, text, object)\n"
		"  assert(flag == false and number == 9 and text == 'auto' and object == eventMarker)\n"
		"  custom_calls = custom_calls + 1\n"
		"end\n"
		"function love.update() update_after_custom = true end\n",
		"@event-auto-dispatch.lua", error), error);
	execute(eventRuntime,
		"assert(love.event.push('custom', false, 9, 'auto', eventMarker))\n",
		"@queue-custom-event.lua");
	require(eventRuntime.update(0.1, error), error);
	execute(eventRuntime,
		"assert(custom_calls == 1 and update_after_custom == true)\n",
		"@verify-custom-event.lua");
	eventRuntime.close();

	Dora::Love::LoveRuntime requestedQuit;
	require(requestedQuit.open(error), error);
	require(requestedQuit.boot(
		"quit_calls = 0\n"
		"updates_after_quit = 0\n"
		"function love.quit() quit_calls = quit_calls + 1; return quit_calls == 1 end\n"
		"function love.update() updates_after_quit = updates_after_quit + 1 end\n",
		"@requested-quit.lua", error), error);
	execute(requestedQuit, "assert(love.event.quit('restart') == true)\n", "@queue-cancelled-quit.lua");
	require(requestedQuit.update(0.1, error), error);
	require(requestedQuit.getStatus() == Dora::Love::LoveRuntime::Status::Running,
		"truthy love.quit result did not cancel the instance quit request");
	execute(requestedQuit,
		"assert(quit_calls == 1 and updates_after_quit == 1)\n"
		"assert(love.event.quit(7) == true)\n",
		"@queue-accepted-quit.lua");
	require(requestedQuit.update(0.1, error), error);
	require(requestedQuit.getStatus() == Dora::Love::LoveRuntime::Status::Stopped,
		"accepted love.event.quit request did not stop the instance");
	execute(requestedQuit, "assert(quit_calls == 2 and updates_after_quit == 1)\n", "@verify-requested-quit.lua");
	execute(requestedQuit,
		"assert(require('love.event') == love.event)\n"
		"local ok, message = pcall(love.event.quit, 'invalid')\n"
		"assert(not ok and message:find(\"expected 'restart'\", 1, true))\n",
		"@verify-event-module.lua");
	requestedQuit.close();

	Dora::Love::LoveRuntime requestedRestart;
	require(requestedRestart.open(error), error);
	require(requestedRestart.boot(
		"loads = (loads or 0) + 1\n"
		"function love.update() updates = (updates or 0) + 1 end\n"
		"function love.quit() quit_called = true; return false end\n",
		"@requested-restart.lua", error), error);
	execute(requestedRestart, "assert(love.event.quit('restart') == true)\n", "@queue-restart.lua");
	require(requestedRestart.update(0.1, error), error);
	require(requestedRestart.getStatus() == Dora::Love::LoveRuntime::Status::RestartRequested,
		"accepted love.event.quit('restart') did not request an instance restart");
	require(requestedRestart.restart(error), error);
	require(requestedRestart.getStatus() == Dora::Love::LoveRuntime::Status::Running,
		"LoveRuntime restart request did not return to running state");
	execute(requestedRestart,
		"assert(loads == 1 and updates == nil and quit_called == nil)\n"
		"assert(love.event.push('quit', 'restart'))\n",
		"@verify-restarted-state.lua");
	require(requestedRestart.update(0.1, error), error);
	require(requestedRestart.getStatus() == Dora::Love::LoveRuntime::Status::RestartRequested,
		"love.event.push('quit', 'restart') did not request an instance restart");
	requestedRestart.close();

	Dora::Love::LoveRuntime defaultQuit;
	require(defaultQuit.open(error), error);
	require(defaultQuit.boot("function love.update() end\n", "@default-quit.lua", error), error);
	execute(defaultQuit, "assert(love.event.quit() == true)\n", "@queue-default-quit.lua");
	require(defaultQuit.update(0.1, error), error);
	require(defaultQuit.getStatus() == Dora::Love::LoveRuntime::Status::Stopped,
		"love.event.quit without love.quit callback did not stop the instance");
	defaultQuit.close();

	MockAudio configuredAudio;
	Dora::Love::LoveRuntime configured;
	configured.setAudioBackend(&configuredAudio);
	require(configured.open(error), error);
	execute(configured,
		"function love.conf(t) assert(t.version == '11.5' and t.window.width == 800 and t.window.height == 600); "
		"assert(type(t.modules) == 'table' and t.modules.data and t.modules.graphics and t.modules.thread and t.modules.video); "
		"t.modules.touch = false; "
		"assert(type(t.audio) == 'table' and t.audio.mixwithsystem == true and t.audio.mic == false); t.audio.mixwithsystem = false; "
		"assert(t.identity == false and t.console == false and t.appendidentity == false and t.accelerometerjoystick == true); "
		"assert(t.window.minwidth == 1 and t.window.minheight == 1 and t.window.fullscreentype == 'desktop' "
		"and t.window.msaa == 0 and t.window.centered and t.window.usedpiscale); "
		"assert(not t.window.fullscreen and t.window.display == 1 and not t.window.highdpi and not t.window.resizable); "
		"t.window.width = 640; t.window.height = 360; t.window.resizable = true; configured = true end\n"
		"function love.load() assert(configured == true); standard_boot_loaded = true end\n",
		"@conf-and-main.lua");
	require(configured.configure(error), error);
	require(configured.getConfiguredWidth() == 640 && configured.getConfiguredHeight() == 360,
		"love.conf virtual window dimensions were not retained");
	require(!configuredAudio.mixWithSystem && configuredAudio.mixWithSystemChanges == 1,
		"love.conf t.audio.mixwithsystem did not reach the shared audio-session backend");
	execute(configured,
		"local w, h, settings = love.window.getMode(); assert(w == 640 and h == 360 and settings.resizable)\n",
		"@verify-conf-window-settings.lua");
	require(configured.start(error), error);
	execute(configured, "assert(standard_boot_loaded == true)\n", "@verify-standard-boot.lua");
	configured.close();
	require(configured.getAllocationBytes() == 0, "configured Love state retained Lua allocations after close");

	Dora::Love::LoveRuntime invalidConfiguration;
	require(invalidConfiguration.open(error), error);
	execute(invalidConfiguration, "function love.conf(t) t.window.width = '../escape' end\n", "@invalid-conf.lua");
	require(!invalidConfiguration.configure(error), "invalid virtual window width unexpectedly succeeded");
	require(error.find("t.window.width") != std::string::npos, "invalid window error omitted its field name");
	invalidConfiguration.close();

	Dora::Love::LoveRuntime unsupportedWindowConfiguration;
	require(unsupportedWindowConfiguration.open(error), error);
	execute(unsupportedWindowConfiguration,
		"function love.conf(t) t.window.fullscreen = true; t.window.highdpi = true; "
		"t.window.display = 2 end\n", "@unsupported-window-conf.lua");
	require(unsupportedWindowConfiguration.configure(error), error);
	require(unsupportedWindowConfiguration.getConfigurationWarnings().find("ignoring unsupported")
		!= std::string::npos,
		"unsupported embedded window settings did not produce a warning");
	execute(unsupportedWindowConfiguration,
		"local _, _, settings = love.window.getMode(); "
		"assert(not settings.fullscreen and not settings.highdpi and settings.display == 1)\n",
		"@verify-unsupported-window-conf.lua");
	unsupportedWindowConfiguration.close();

	Dora::Love::LoveRuntime legacyWindowConfiguration;
	require(legacyWindowConfiguration.open(error), error);
	execute(legacyWindowConfiguration,
		"function love.conf(t) t.window.vsync = true end\n", "@legacy-vsync-conf.lua");
	require(legacyWindowConfiguration.configure(error), error);
	legacyWindowConfiguration.close();

	Dora::Love::LoveRuntime disabledWindowConfiguration;
	require(disabledWindowConfiguration.open(error), error);
	execute(disabledWindowConfiguration,
		"function love.conf(t) t.window = nil end\n", "@disabled-window-conf.lua");
	require(disabledWindowConfiguration.configure(error), error);
	require(disabledWindowConfiguration.getConfigurationWarnings().find("window module is disabled")
		!= std::string::npos, "disabled Love window did not produce an embedded-surface warning");
	require(disabledWindowConfiguration.getConfiguredWidth() == 800
		&& disabledWindowConfiguration.getConfiguredHeight() == 600,
		"disabled Love window did not retain the virtual surface defaults");
	disabledWindowConfiguration.close();

	Dora::Love::LoveRuntime invalidAudioConfiguration;
	require(invalidAudioConfiguration.open(error), error);
	execute(invalidAudioConfiguration,
		"function love.conf(t) t.audio.mixwithsystem = 'yes' end\n", "@invalid-audio-conf.lua");
	require(!invalidAudioConfiguration.configure(error),
		"invalid t.audio.mixwithsystem unexpectedly succeeded");
	require(error.find("t.audio.mixwithsystem") != std::string::npos,
		"invalid audio configuration error omitted its field name");
	invalidAudioConfiguration.close();

	Dora::Love::LoveRuntime rootedFirst;
	Dora::Love::LoveRuntime rootedSecond;
	TestFilesystemBackend rootedFirstFilesystem;
	TestFilesystemBackend rootedSecondFilesystem;
	rootedFirst.setFilesystemBackend(&rootedFirstFilesystem);
	rootedSecond.setFilesystemBackend(&rootedSecondFilesystem);
	require(rootedFirst.open(error), error);
	require(rootedSecond.open(error), error);
	const std::string fixtureRoot = DORA_LOVE_TEST_FIXTURES;
	require(rootedFirst.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	require(rootedSecond.setSourceRoot(fixtureRoot + "/RuntimeSceneSecond", error), error);
	execute(rootedFirst,
		"local filesystem = require('love.filesystem')\n"
		"assert(filesystem.getRequirePath() == '?.lua;?/init.lua')\n"
		"assert(package.path == '' and package.cpath == '')\n"
		"filesystem.setRequirePath('custom/?.lua;custom/?/init.lua')\n"
		"assert(filesystem.getRequirePath() == 'custom/?.lua;custom/?/init.lua')\n"
		"assert(require('alternate').owner == 'source-custom')\n"
		"filesystem.setRequirePath('?.lua;?/init.lua')\n"
		"local module = require('shared.module'); assert(module.owner == 'first')\n"
		"local slashModule = require('shared/module'); assert(slashModule.owner == 'first')\n"
		"local ok, message = pcall(require, '../RuntimeSceneSecond/shared/module')\n"
		"assert(not ok and message:find('invalid Love module name'))\n"
		"for _, invalidName in ipairs({\n"
		"  'shared//module', 'shared/./module',\n"
		"  'shared/../module', 'shared\\\\module', 'C:/shared/module'\n"
		"}) do\n"
		"  local accepted, invalidMessage = pcall(require, invalidName)\n"
		"  assert(not accepted and invalidMessage:find('invalid Love module name'))\n"
		"end\n"
		"local acceptedNul = pcall(require, 'shared' .. string.char(0) .. '/module')\n"
		"assert(not acceptedNul)\n",
		"@rooted-first.lua");
	execute(rootedSecond,
		"local module = require('shared.module'); assert(module.owner == 'second')\n",
		"@rooted-second.lua");

	namespace fs = std::filesystem;
	const fs::path saveBase = fs::temp_directory_path()
		/ ("dora-love-filesystem-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	require(rootedFirst.setSaveBaseRoot(saveBase.string(), error), error);
	require(rootedSecond.setSaveBaseRoot(saveBase.string(), error), error);
	execute(rootedFirst,
		"local filesystem = require('love.filesystem')\n"
		"filesystem.setIdentity('first-save')\n"
		"assert(filesystem.getIdentity() == 'first-save')\n"
		"assert(filesystem.getSource():find('RuntimeScene', 1, true))\n"
		"assert(filesystem.getSaveDirectory():find('first-save', 1, true))\n"
		"assert(filesystem.getWorkingDirectory() == filesystem.getSource())\n"
		"assert(filesystem.getExecutablePath() == '/mock/Dora')\n"
		"assert(filesystem.getSourceBaseDirectory():find('Fixtures', 1, true))\n"
		"assert(filesystem.getAppdataDirectory():find('dora-love-filesystem-', 1, true))\n"
		"assert(#filesystem.getUserDirectory() > 0)\n"
		"local sourceReal = assert(filesystem.getRealDirectory('shared/module.lua'))\n"
		"assert(sourceReal == filesystem.getSource())\n"
		"local sourceModule, sourceSize = filesystem.read('shared/module.lua')\n"
		"assert(sourceModule:find('owner = \"first\"', 1, true) and sourceSize == #sourceModule)\n"
		"local rootedModule = assert(filesystem.read('/shared/module.lua'))\n"
		"assert(rootedModule == sourceModule)\n"
		"local sharedItems = filesystem.getDirectoryItems('shared/'); assert(#sharedItems == 1 and sharedItems[1] == 'module.lua')\n"
		"assert(filesystem.createDirectory('shared'))\n"
		"assert(filesystem.write('shared/module.lua', \"return {owner = 'save-first'}\\n\"))\n"
		"assert(filesystem.getRealDirectory('shared/module.lua') == filesystem.getSaveDirectory())\n"
		"assert(filesystem.createDirectory('custom'))\n"
		"assert(filesystem.write('custom/alternate.lua', \"return {owner = 'save-custom'}\\n\"))\n"
		"filesystem.setRequirePath('custom/?.lua')\n"
		"package.loaded.alternate = nil; assert(require('alternate').owner == 'save-custom')\n"
		"local okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, '../?.lua')\n"
		"assert(not okRequirePath and requirePathMessage:find('require path', 1, true))\n"
		"okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, '/?.lua')\n"
		"assert(not okRequirePath and requirePathMessage:find('require path', 1, true))\n"
		"okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, 'C:/?.lua')\n"
		"assert(not okRequirePath and requirePathMessage:find('require path', 1, true))\n"
		"okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, 'custom\\\\?.lua')\n"
		"assert(not okRequirePath and requirePathMessage:find('require path', 1, true))\n"
		"okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, string.rep('a', 4097))\n"
		"assert(not okRequirePath and requirePathMessage:find('too long', 1, true))\n"
		"okRequirePath, requirePathMessage = pcall(filesystem.setRequirePath, string.rep('?.lua;', 32) .. '?.lua')\n"
		"assert(not okRequirePath and requirePathMessage:find('too many', 1, true))\n"
		"assert(filesystem.getRequirePath() == 'custom/?.lua')\n"
		"filesystem.setRequirePath(''); assert(filesystem.getRequirePath() == '')\n"
		"package.loaded.alternate = nil; local noSearch = pcall(require, 'alternate'); assert(not noSearch)\n"
		"filesystem.setRequirePath('?.lua;?/init.lua')\n"
		"assert(filesystem.append('journal.txt', 'one'))\n"
		"assert(filesystem.append('journal.txt', '-two'))\n"
		"local nativeFile = assert(io.open('./native-io.txt', 'w')); nativeFile:write('native-line\\n'); nativeFile:close(); local nativeLine; for line in io.lines('./native-io.txt') do nativeLine = line end; assert(nativeLine == 'native-line')\n"
		"local journal, journalSize = filesystem.read('journal.txt')\n"
		"assert(journal == 'one-two' and journalSize == 7)\n"
		"local journalData, dataSize = filesystem.read('data', 'journal.txt')\n"
		"assert(journalData:getString() == journal and journalData:getSize() == 7 and dataSize == 7)\n"
		"assert(journalData:getFilename() == 'journal.txt' and journalData:getExtension() == 'txt')\n"
		"assert(type(journalData:getPointer()) == 'userdata' and journalData:getFFIPointer() == nil)\n"
		"local clonedData = journalData:clone(); assert(clonedData ~= journalData and clonedData:getString() == journal)\n"
		"local rawData = filesystem.newFileData('A\\0B', 'binary.dat')\n"
		"assert(rawData:getSize() == 3 and rawData:getString() == 'A\\0B' and rawData:getExtension() == 'dat')\n"
		"assert(filesystem.write('binary.dat', rawData) and filesystem.append('binary.dat', filesystem.newFileData('C', 'tail.dat')))\n"
		"local binaryCopy, binarySize = filesystem.read('binary.dat'); assert(binaryCopy == 'A\\0BC' and binarySize == 4)\n"
		"local file = filesystem.newFile('object.txt'); assert(not file:isOpen() and file:getMode() == 'c')\n"
		"assert(file:getFilename() == 'object.txt' and file:getExtension() == 'txt')\n"
		"assert(file:open('w') and file:isOpen() and file:getMode() == 'w')\n"
		"assert(file:setBuffer('full', 128)); local bufferMode, bufferSize = file:getBuffer(); assert(bufferMode == 'full' and bufferSize == 128)\n"
		"assert(file:write('abc') and file:tell() == 3 and file:getSize() == 3)\n"
		"assert(file:seek(1) and file:write(filesystem.newFileData('ZZ', 'write.bin')) and file:tell() == 3)\n"
		"assert(file:flush() and file:close() and not file:isOpen() and file:getSize() == 3)\n"
		"assert(file:open('r')); local prefix, prefixSize = file:read(2); assert(prefix == 'aZ' and prefixSize == 2 and file:tell() == 2)\n"
		"local suffixData, suffixSize = file:read('data'); assert(suffixData:getString() == 'Z' and suffixSize == 1 and file:isEOF())\n"
		"assert(file:close() and file:open('a') and file:write('-tail') and file:close())\n"
		"local objectData = filesystem.newFileData(file); assert(objectData:getString() == 'aZZ-tail' and not file:isOpen())\n"
		"local okPath, pathMessage = pcall(filesystem.newFile, '../object.txt'); assert(not okPath and pathMessage:find('confined', 1, true))\n"
		"journalData, clonedData, rawData, objectData, suffixData, file = nil, nil, nil, nil, nil, nil; collectgarbage('collect')\n"
		"assert(filesystem.write('lines.txt', 'one\\n\\nthree\\r\\nfour\\r'))\n"
		"local lines = {}; for line in filesystem.lines('lines.txt') do lines[#lines + 1] = line end\n"
		"assert(#lines == 4 and lines[1] == 'one' and lines[2] == '' and lines[3] == 'three' and lines[4] == 'four')\n"
		"local lineFile = filesystem.newFile('lines.txt'); local objectLines = {}; for line in lineFile:lines() do objectLines[#objectLines + 1] = line end\n"
		"assert(#objectLines == 4 and objectLines[2] == '' and not lineFile:isOpen()); lineFile = nil; collectgarbage('collect')\n"
		"assert(filesystem.write('loaded.lua', \"return love._version, 'save'\"))\n"
		"local chunk, loadError = filesystem.load('loaded.lua'); assert(chunk and loadError == nil)\n"
		"local version, owner = chunk(); assert(version == '11.5' and owner == 'save')\n"
		"assert(filesystem.write('invalid.lua', 'local ='))\n"
		"chunk, loadError = filesystem.load('invalid.lua'); assert(chunk == nil and loadError:find('invalid.lua', 1, true))\n"
		"chunk, loadError = filesystem.load('missing.lua'); assert(chunk == nil and type(loadError) == 'string')\n"
		"local missingReal, missingRealError = filesystem.getRealDirectory('missing.lua')\n"
		"assert(missingReal == nil and type(missingRealError) == 'string')\n"
		"local escapedReal, escapedRealError = filesystem.getRealDirectory('../escape.lua')\n"
		"assert(escapedReal == nil and escapedRealError:find('confined', 1, true))\n"
		"local info = filesystem.getInfo('journal.txt', 'file')\n"
		"assert(info and info.type == 'file' and info.size == 7)\n"
		"assert(filesystem.getInfo('shared', 'directory').type == 'directory')\n"
		"assert(filesystem.exists('journal.txt') and not filesystem.exists('missing.txt'))\n"
		"assert(filesystem.isFile('journal.txt') and not filesystem.isFile('shared'))\n"
		"assert(filesystem.isDirectory('shared') and not filesystem.isDirectory('journal.txt'))\n"
		"assert(not filesystem.isSymlink('journal.txt') and not filesystem.isSymlink('missing.txt'))\n"
		"assert(filesystem.getSize('journal.txt') == 7)\n"
		"local missingSize, missingSizeError = filesystem.getSize('missing.txt')\n"
		"assert(missingSize == nil and missingSizeError == 'File does not exist')\n"
		"local modified, modifiedError = filesystem.getLastModified('journal.txt')\n"
		"assert(modified == nil and modifiedError:find('Could not determine', 1, true))\n"
		"local items = filesystem.getDirectoryItems('shared')\n"
		"assert(#items == 1 and items[1] == 'module.lua')\n"
		"local ok, message = filesystem.write('../escape.txt', 'bad')\n"
		"assert(not ok and message:find('relative', 1, true))\n"
		"ok, message = filesystem.write('/tmp/escape.txt', 'bad')\n"
		"assert(not ok and message:find('relative', 1, true))\n"
		"ok, message = pcall(filesystem.setIdentity, '../bad')\n"
		"assert(not ok and message:find('identity', 1, true))\n"
		"package.loaded['shared.module'] = nil\n"
		"local savedModule = require('shared.module')\n"
		"assert(savedModule.owner == 'save-first', 'resolved owner: ' .. tostring(savedModule.owner) .. ', save: ' .. filesystem.getSaveDirectory())\n",
		"@first-save-filesystem.lua");
	execute(rootedSecond,
		"local filesystem = require('love.filesystem')\n"
		"filesystem.setIdentity('second-save')\n"
		"assert(filesystem.createDirectory('shared'))\n"
		"assert(filesystem.write('shared/module.lua', \"return {owner = 'save-second'}\\n\"))\n"
		"package.loaded['shared.module'] = nil\n"
		"assert(require('shared.module').owner == 'save-second')\n"
		"local data = filesystem.read('journal.txt')\n"
		"assert(data == nil and filesystem.getInfo('object.txt') == nil)\n",
		"@second-save-filesystem.lua");
	execute(rootedSecond,
		"local filesystem = require('love.filesystem')\n"
		"assert(filesystem.isFused() == false)\n"
		"assert(filesystem.write('archive-a.zip', \"helper.lua:return {owner='archive-a'}\\ncustom/alternate.lua:return {owner='archive-custom'}\\nasset.txt:archive-a\"))\n"
		"assert(filesystem.mount('archive-a.zip', 'mods'))\n"
		"assert(filesystem.getRealDirectory('archive-a.zip') == filesystem.getSaveDirectory())\n"
		"assert(filesystem.getRealDirectory('mods'):find('dora-love-mount-', 1, true))\n"
		"assert(filesystem.getRealDirectory('mods/asset.txt'):find('dora-love-mount-', 1, true))\n"
		"assert(not filesystem.mount('archive-a.zip', 'duplicate'))\n"
		"assert(filesystem.read('mods/asset.txt') == 'archive-a')\n"
		"assert(filesystem.getInfo('mods', 'directory').type == 'directory')\n"
		"local rootItems = filesystem.getDirectoryItems(); assert(rootItems[#rootItems] ~= nil)\n"
		"local mountItems = filesystem.getDirectoryItems('mods'); assert(#mountItems == 3)\n"
		"filesystem.setRequirePath('mods/custom/?.lua')\n"
		"package.loaded.alternate = nil; assert(require('alternate').owner == 'archive-custom')\n"
		"filesystem.setRequirePath('?.lua;?/init.lua')\n"
		"package.loaded['mods.helper'] = nil; assert(require('mods.helper').owner == 'archive-a')\n"
		"assert(filesystem.unmount('archive-a.zip'))\n"
		"filesystem.setRequirePath('mods/custom/?.lua'); package.loaded.alternate = nil\n"
		"local mountedRequire = pcall(require, 'alternate'); assert(not mountedRequire)\n"
		"filesystem.setRequirePath('?.lua;?/init.lua')\n"
		"assert(not filesystem.unmount('archive-a.zip') and filesystem.read('mods/asset.txt') == nil)\n"
		"assert(filesystem.getRealDirectory('mods/asset.txt') == nil)\n"
		"local memory = filesystem.newFileData(\"nested/value.txt:filedata\", 'memory.zip')\n"
		"assert(filesystem.mount(memory, 'memory'))\n"
		"collectgarbage('collect'); assert(filesystem.read('memory/nested/value.txt') == 'filedata')\n"
		"assert(filesystem.unmount(memory) and filesystem.read('memory/nested/value.txt') == nil)\n"
		"assert(not filesystem.mount(memory, '../escape'))\n"
		"local invalid = filesystem.newFileData('invalid', 'invalid.zip'); assert(not filesystem.mount(invalid, 'bad'))\n"
		"assert(filesystem.write('back.zip', 'priority.txt:back'))\n"
		"assert(filesystem.write('front.zip', 'priority.txt:front'))\n"
		"assert(filesystem.mount('back.zip', '', true))\n"
		"assert(filesystem.mount('front.zip', '', false))\n"
		"assert(filesystem.read('priority.txt') == 'front')\n"
		"assert(filesystem.unmount('front.zip') and filesystem.read('priority.txt') == 'back')\n"
		"assert(filesystem.unmount('back.zip'))\n",
		"@mounted-filesystem.lua");

	std::error_code symlinkError;
	const fs::path outsideDirectory = saveBase / "outside";
	fs::create_directories(outsideDirectory, symlinkError);
	const fs::path symlinkPath = fs::path(rootedFirst.getSaveRoot()) / "outside-link";
	fs::create_directory_symlink(outsideDirectory, symlinkPath, symlinkError);
	if (!symlinkError)
	{
		execute(rootedFirst,
			"local ok, message = love.filesystem.write('outside-link/escaped.txt', 'bad')\n"
			"assert(not ok and message:find('escapes', 1, true))\n",
			"@save-symlink-escape.lua");
	}

	require(rootedFirst.boot("function love.load() assert(love.filesystem.getRequirePath() == '?.lua;?/init.lua'); assert(require('shared.module').owner == 'save-first') end\n",
		"@rooted-restart.lua", error), error);
	require(rootedFirst.restart(error), error);
	execute(rootedFirst,
		"assert(love.filesystem.getRequirePath() == '?.lua;?/init.lua')\n"
		"assert(package.path == '' and package.cpath == '')\n"
		"assert(require('shared.module').owner == 'save-first')\n"
		"assert(love.filesystem.getIdentity() == 'first-save')\n"
		"local object = love.filesystem.newFile('object.txt', 'r'); assert(object:read() == 'aZZ-tail' and object:isEOF()); object:close()\n"
		"local objectData = love.filesystem.newFileData('object.txt'); assert(objectData:getString() == 'aZZ-tail')\n"
		"assert(love.filesystem.read('journal.txt') == 'one-two')\n"
		"assert(love.filesystem.remove('journal.txt'))\n"
		"assert(love.filesystem.getInfo('journal.txt') == nil)\n",
		"@verify-rooted-restart.lua");
	rootedFirst.close();
	rootedSecond.close();
	require(rootedFirstFilesystem.mountedRoots.empty() && rootedSecondFilesystem.mountedRoots.empty(),
		"Love filesystem mount staging roots survived runtime close");
	fs::remove_all(saveBase, symlinkError);

	MockKeyboard inputKeyboard;
	MockMouse inputMouse;
	MockGraphics inputImage;
	MockJoystick inputJoystick;
	TestFilesystemBackend inputFilesystem;
	Dora::Love::LoveRuntime inputRuntime;
	inputRuntime.setKeyboardBackend(&inputKeyboard);
	inputRuntime.setMouseBackend(&inputMouse);
	inputRuntime.setImageBackend(&inputImage);
	inputRuntime.setJoystickBackend(&inputJoystick);
	inputRuntime.setFilesystemBackend(&inputFilesystem);
	require(inputRuntime.open(error), error);
	const fs::path inputSaveBase = fs::temp_directory_path()
		/ ("dora-love-joystick-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	require(inputRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	require(inputRuntime.setSaveBaseRoot(inputSaveBase.string(), error), error);
	inputRuntime.addJoystick(0, "Mock Gamepad");
	require(inputRuntime.boot(
		"events = {}\n"
		"local joysticks = require('love.joystick'); assert(joysticks == love.joystick and joysticks.getJoystickCount() == 1)\n"
		"pad = joysticks.getJoysticks()[1]; assert(pad == joysticks.getJoysticks()[1] and pad:getName() == 'Mock Gamepad')\n"
		"local id, instanceId = pad:getID(); assert(id == 1 and instanceId == 42 and pad:isConnected() and pad:isGamepad())\n"
		"assert(pad:getGUID() == '03000000mock00000000000000000000')\n"
		"local vendor, product, version = pad:getDeviceInfo(); assert(vendor == 0x1234 and product == 0x5678 and version == 9)\n"
		"assert(pad:getAxisCount() == 3 and pad:getButtonCount() == 4 and pad:getHatCount() == 1)\n"
		"local ax, ay, az = pad:getAxes(); assert(ax == -0.25 and ay == 0.5 and az == 1 and pad:getAxis(2) == ay)\n"
		"assert(pad:getHat(1) == 'ru' and pad:isDown(2) and pad:isDown({1, 2}) and not pad:isDown(1))\n"
		"assert(pad:getConnectedIndex() == 1 and pad:isVibrationSupported())\n"
		"local inputType, inputIndex = pad:getGamepadMapping('a'); assert(inputType == 'button' and inputIndex == 2)\n"
		"inputType, inputIndex = pad:getGamepadMapping('leftx'); assert(inputType == 'axis' and inputIndex == 3)\n"
		"local hatType, hatIndex, hatDirection = pad:getGamepadMapping('dpup'); assert(hatType == 'hat' and hatIndex == 1 and hatDirection == 'u')\n"
		"assert(pad:getGamepadMappingString():find('Mock Gamepad', 1, true))\n"
		"assert(love.joystick.getGamepadMappingString(pad:getGUID()) == pad:getGamepadMappingString())\n"
		"assert(love.joystick.getGamepadMappingString('00000000000000000000000000000000') == nil)\n"
		"assert(love.joystick.setGamepadMapping(pad:getGUID(), 'a', 'button', 4))\n"
		"assert(love.joystick.setGamepadMapping(pad:getGUID(), 'dpup', 'hat', 2, 'ru'))\n"
		"love.filesystem.setIdentity('joystick-mapping')\n"
		"local saved = love.joystick.saveGamepadMappings('mapping.txt'); assert(saved:find('Mock Gamepad', 1, true))\n"
		"local stored = assert(love.filesystem.read('mapping.txt')); assert(stored == saved)\n"
		"love.joystick.loadGamepadMappings('mapping.txt')\n"
		"love.joystick.loadGamepadMappings(saved)\n"
		"local ok, message = pcall(love.joystick.loadGamepadMappings, 'invalid'); assert(not ok and message:find('mock invalid'))\n"
		"assert(pad:setVibration(1.5, -0.5)); local vl, vr = pad:getVibration(); assert(vl == 1 and vr == 0)\n"
		"assert(pad:setVibration()); vl, vr = pad:getVibration(); assert(vl == 0 and vr == 0)\n"
		"assert(not love.keyboard.hasKeyRepeat()); love.keyboard.setKeyRepeat(true); assert(love.keyboard.hasKeyRepeat())\n"
		"assert(love.keyboard.getScancodeFromKey('a') == 'q' and love.keyboard.getKeyFromScancode('q') == 'a')\n"
		"assert(love.keyboard.getScancodeFromKey('f24') == 'unknown' and love.keyboard.hasScreenKeyboard())\n"
		"local ok, message = pcall(love.keyboard.getScancodeFromKey, 'not-a-key'); assert(not ok and message:find('Invalid key constant'))\n"
		"ok, message = pcall(love.keyboard.getKeyFromScancode, 'not-a-scan'); assert(not ok and message:find('Invalid scancode'))\n"
		"assert(love.keyboard.hasTextInput()); love.keyboard.setTextInput(false); assert(not love.keyboard.hasTextInput()); love.keyboard.setTextInput(true, 12, 24, 80, 20); assert(love.keyboard.hasTextInput())\n"
		"assert(love.mouse.isVisible() and not love.mouse.isGrabbed() and not love.mouse.getRelativeMode())\n"
		"love.mouse.setPosition(3, 4); love.mouse.setX(5); love.mouse.setY(6); local mx, my = love.mouse.getPosition(); assert(mx == 5 and my == 6)\n"
		"love.mouse.setVisible(false); assert(not love.mouse.isVisible()); love.mouse.setVisible(true)\n"
		"love.mouse.setGrabbed(true); assert(love.mouse.isGrabbed()); love.mouse.setGrabbed(false)\n"
		"assert(love.mouse.setRelativeMode(true) and love.mouse.getRelativeMode()); assert(love.mouse.setRelativeMode(false) and not love.mouse.getRelativeMode())\n"
		"local mouseOk = pcall(love.mouse.setPosition, 0/0, 0); assert(not mouseOk and not pcall(love.mouse.setVisible, 1) and not pcall(love.mouse.setGrabbed, 1) and not pcall(love.mouse.setRelativeMode, 1))\n"
		"assert(love.mouse.isCursorSupported() and love.mouse.getCursor() == nil)\n"
		"local cursorImage = love.image.newImageData(2, 3); cursorImage:setPixel(1, 2, 1, 0.5, 0.25, 1)\n"
		"imageCursor = love.mouse.newCursor(cursorImage, 1, 2); assert(imageCursor:getType() == 'image' and imageCursor:typeOf('Cursor') and imageCursor:typeOf('Object'))\n"
		"assert(love.filesystem.write('cursor.mock', 'encoded-image'))\n"
		"pathCursor = love.mouse.newCursor('cursor.mock'); assert(pathCursor:getType() == 'image')\n"
		"local cursorFileData = love.filesystem.newFileData('encoded-image', 'cursor-data.mock')\n"
		"dataCursor = love.mouse.newCursor(cursorFileData); assert(dataCursor:getType() == 'image')\n"
		"handCursor = love.mouse.getSystemCursor('hand'); assert(handCursor:getType() == 'hand' and handCursor == love.mouse.getSystemCursor('hand'))\n"
		"love.mouse.setCursor(imageCursor); assert(love.mouse.getCursor() == imageCursor and imageCursor:release()); imageCursor = nil; collectgarbage('collect'); assert(love.mouse.getCursor():getType() == 'image')\n"
		"assert(handCursor:release()); handCursor=love.mouse.getSystemCursor('hand'); assert(handCursor:getType()=='hand')\n"
		"love.mouse.setCursor(handCursor); assert(love.mouse.getCursor() == handCursor); love.mouse.setCursor(); assert(love.mouse.getCursor() == nil)\n"
		"assert(not pcall(love.mouse.getSystemCursor, 'invalid') and not pcall(love.mouse.newCursor, cursorImage, 2, 0))\n"
		"function love.keypressed(key, scancode, repeatValue) table.insert(events, 'kp:' .. key .. ':' .. tostring(repeatValue)); assert(love.keyboard.isDown({key, 'escape'}) and love.keyboard.isScancodeDown({scancode, 'escape'})) end\n"
		"function love.keyreleased(key, scancode) table.insert(events, 'kr:' .. key); assert(not love.keyboard.isDown(key) and not love.keyboard.isScancodeDown(scancode)) end\n"
		"function love.textinput(text) table.insert(events, 'text:' .. text) end\n"
		"function love.textedited(text, start, length) table.insert(events, 'edit:' .. text .. ':' .. start .. ':' .. length) end\n"
		"function love.mousepressed(x, y, button) table.insert(events, 'mp:' .. x .. ':' .. y .. ':' .. button); assert(love.mouse.isDown(button) and love.mouse.isDown({2, button})) end\n"
		"function love.mousemoved(x, y, dx, dy) table.insert(events, 'mm:' .. x .. ':' .. y .. ':' .. dx .. ':' .. dy) end\n"
		"function love.mousereleased(x, y, button) table.insert(events, 'mr:' .. button); assert(not love.mouse.isDown(button)) end\n"
		"function love.wheelmoved(x, y) table.insert(events, 'mw:' .. x .. ':' .. y) end\n"
		"function love.touchpressed(id, x, y, dx, dy, pressure) touchId = id; table.insert(events, 'tp:' .. x .. ':' .. y); local touches = love.touch.getTouches(); assert(#touches == 1 and touches[1] == id); local tx, ty = love.touch.getPosition(id); assert(tx == x and ty == y and love.touch.getPressure(id) == pressure) end\n"
		"function love.touchmoved(id, x, y, dx, dy, pressure) assert(id == touchId and dx == 5 and dy == 6); table.insert(events, 'tm:' .. x .. ':' .. y); local tx, ty = love.touch.getPosition(id); assert(tx == x and ty == y) end\n"
		"function love.touchreleased(id, x, y, dx, dy, pressure) assert(id == touchId and #love.touch.getTouches() == 0); table.insert(events, 'tr:' .. x .. ':' .. y); assert(not pcall(love.touch.getPosition, id)) end\n"
		"function love.joystickpressed(joystick, button) assert(joystick == pad and button == 2 and joystick:isDown(button)); table.insert(events, 'jp:' .. button) end\n"
		"function love.joystickaxis(joystick, axis, value) assert(joystick == pad and axis == 2 and value == 0.5 and joystick:getAxis(axis) == value); table.insert(events, 'ja:' .. axis .. ':' .. value) end\n"
		"function love.joystickhat(joystick, hat, direction) assert(joystick == pad and hat == 1 and direction == 'ru' and joystick:getHat(hat) == direction); table.insert(events, 'jh:' .. hat .. ':' .. direction) end\n"
		"function love.joystickreleased(joystick, button) assert(joystick == pad and button == 2); table.insert(events, 'jr:' .. button) end\n"
		"function love.gamepadpressed(joystick, button) assert(joystick == pad and button == 'a' and joystick:isGamepadDown('a') and joystick:isGamepadDown({'x', 'a'})); table.insert(events, 'gp:' .. button) end\n"
		"function love.gamepadaxis(joystick, axis, value) assert(joystick == pad and axis == 'leftx' and joystick:getGamepadAxis(axis) == value); table.insert(events, 'ga:' .. axis .. ':' .. value) end\n"
		"function love.gamepadreleased(joystick, button) assert(joystick == pad and button == 'a' and not joystick:isGamepadDown('a')); table.insert(events, 'gr:' .. button) end\n"
		"function love.joystickadded(joystick) assert(joystick:getName() == 'Second Gamepad' and joystick:isConnected()); addedPad = joystick end\n"
		"function love.joystickremoved(joystick) assert(joystick == pad and not joystick:isConnected()); removed = true end\n"
		"function love.update() local x, y = love.mouse.getPosition(); assert(x == 30 and y == 40 and love.mouse.getX() == x and love.mouse.getY() == y) end\n",
		"@input-events.lua", error), error);
	inputRuntime.queueKeyPressed("a", "a", false);
	inputRuntime.queueKeyPressed("a", "a", true);
	inputRuntime.queueTextInput("你");
	inputRuntime.queueTextEdited("拼音", 1, 2);
	inputRuntime.queueKeyReleased("a", "a");
	inputRuntime.queueMousePressed(10, 20, 1);
	inputRuntime.queueMouseMoved(30, 40, 20, 20);
	inputRuntime.queueMouseReleased(30, 40, 1);
	inputRuntime.queueWheelMoved(-1, 2);
	inputRuntime.queueTouchPressed(17, 100, 110, 0, 0, 0.75f);
	inputRuntime.queueTouchMoved(17, 105, 116, 5, 6, 0.8f);
	inputRuntime.queueTouchReleased(17, 105, 116, 0, 0, 0.0f);
	inputRuntime.queueJoystickPressed(0, 1);
	inputRuntime.queueJoystickAxis(0, 1, 0.5f);
	inputRuntime.queueJoystickHat(0, 0, "ru");
	inputRuntime.queueJoystickReleased(0, 1);
	inputRuntime.queueGamepadPressed(0, "a");
	inputRuntime.queueGamepadAxis(0, "leftx", 0.5f);
	inputRuntime.queueGamepadReleased(0, "a");
	require(inputRuntime.update(0.1, error), error);
	require(inputKeyboard.textInputEnabled && inputKeyboard.hasRectangle
		&& inputKeyboard.rectangle == std::array<float, 4>{12.0f, 24.0f, 80.0f, 20.0f},
		"Love keyboard text input rectangle did not reach the instance backend");
	require(inputMouse.position == std::array<float, 2>{5.0f, 6.0f}
		&& inputMouse.positionCalls == 3 && inputMouse.visible && inputMouse.visibleCalls == 2
		&& !inputMouse.grabbed && inputMouse.grabbedCalls == 2
		&& !inputMouse.relative && inputMouse.relativeCalls == 2,
		"Love mouse position and focused-host request state did not reach the backend");
	require(inputMouse.imageCursorRequests == std::vector<std::array<int, 4>>{
			{2, 3, 1, 2}, {2, 1, 0, 0}, {2, 1, 0, 0}}
		&& inputImage.imageDataDecodes == 2 && inputMouse.imagePixels.size() == 8
		&& inputMouse.cursors.size() == 4
		&& inputMouse.activeCursor == 0 && inputMouse.cursorChanges == 3,
		"Love Cursor objects did not preserve ImageData/Content/FileData creation, system cache, or active state");
	require(inputJoystick.lastId == 0 && inputJoystick.lastLeft == 0.0f
		&& inputJoystick.lastRight == 0.0f && inputJoystick.lastDuration == 0.0,
		"Love joystick vibration did not reach the instance backend");
	require(inputJoystick.lastGuid == "03000000mock00000000000000000000"
		&& inputJoystick.lastGamepadInput == "dpup" && inputJoystick.lastInputType == "hat"
		&& inputJoystick.lastMappingIndex == 1 && inputJoystick.lastHat == "ru",
		"Love gamepad mapping mutation did not preserve names, 1-based index conversion, or hat direction");
	require(inputJoystick.loadedMappings == inputJoystick.mappingString + "\n",
		"Love gamepad mapping filename/direct string load did not reach the backend");
	execute(inputRuntime,
		"assert(require('love.touch') == love.touch)\n"
		"assert(table.concat(events, '|') == 'kp:a:false|kp:a:true|text:你|edit:拼音:1:2|kr:a|mp:10.0:20.0:1|mm:30.0:40.0:20.0:20.0|mr:1|mw:-1.0:2.0|tp:100.0:110.0|tm:105.0:116.0|tr:105.0:116.0|jp:2|ja:2:0.5|jh:1:ru|jr:2|gp:a|ga:leftx:0.5|gr:a')\n"
		"local ok, message = pcall(pad.getGamepadAxis, pad, 'bad'); assert(not ok and message:find('invalid gamepad axis'))\n"
		"ok, message = pcall(pad.isGamepadDown, pad, 'bad'); assert(not ok and message:find('invalid gamepad button'))\n",
		"@verify-input-events.lua");
	inputRuntime.queueJoystickAxis(0, 2, -0.75f);
	execute(inputRuntime,
		"local name, joystick, axis, value = love.event.poll()()\n"
		"assert(name == 'joystickaxis' and joystick == pad and axis == 3 and value == -0.75)\n",
		"@verify-raw-joystick-poll.lua");
	execute(inputRuntime,
		"keyboardEventCount = #events; love.keyboard.setKeyRepeat(false); assert(not love.keyboard.hasKeyRepeat())",
		"@disable-key-repeat.lua");
	inputRuntime.queueKeyPressed("a", "a", true);
	require(inputRuntime.update(0.1, error), error);
	execute(inputRuntime, "assert(#events == keyboardEventCount)", "@verify-disabled-key-repeat.lua");
	inputRuntime.addJoystick(1, "Second Gamepad", true);
	require(inputRuntime.update(0.1, error), error);
	execute(inputRuntime,
		"assert(addedPad and love.joystick.getJoystickCount() == 2 and addedPad:getConnectedIndex() == 2)",
		"@verify-joystick-added.lua");
	inputRuntime.removeJoystick(0, true);
	require(inputRuntime.update(0.1, error), error);
	execute(inputRuntime,
		"local disconnectedId, disconnectedInstanceId = pad:getID()\n"
		"assert(disconnectedId == 1 and disconnectedInstanceId == nil)\n"
		"assert(removed and not pad:isConnected() and pad:getConnectedIndex() == nil and love.joystick.getJoystickCount() == 1 and love.joystick.getJoysticks()[1] == addedPad and addedPad:getConnectedIndex() == 1)\n",
		"@verify-joystick-removed.lua");
	inputRuntime.queueGamepadPressed(0, "a");
	inputRuntime.queueGamepadAxis(0, "leftx", 1.0f);
	require(inputRuntime.update(0.1, error), error);
	execute(inputRuntime,
		"assert(not pad:isGamepadDown('a') and pad:getGamepadAxis('leftx') == 0 and #events == 19)\n",
		"@verify-disconnected-joystick-ignores-late-events.lua");
	execute(inputRuntime, "assert(addedPad:setVibration(0.4, 0.6))", "@verify-joystick-close-vibration.lua");
	inputRuntime.close();
	fs::remove_all(inputSaveBase, symlinkError);
	require(inputJoystick.lastId == 1 && inputJoystick.lastLeft == 0.0f
		&& inputJoystick.lastRight == 0.0f && inputJoystick.lastDuration == 0.0,
		"Love runtime close did not stop active joystick vibration");
	require(inputMouse.cursors.empty() && inputMouse.releasedCursors == 4,
		"Love runtime close did not release all instance Cursor handles");

	Dora::Love::LoveRuntime firstInputRuntime;
	Dora::Love::LoveRuntime secondInputRuntime;
	require(firstInputRuntime.open(error), error);
	require(secondInputRuntime.open(error), error);
	firstInputRuntime.addJoystick(0, "First Pad");
	secondInputRuntime.addJoystick(0, "Second Pad");
	require(firstInputRuntime.boot(
		"events = {}\n"
		"function love.keypressed(key) table.insert(events, 'key:' .. key) end\n"
		"function love.touchpressed(id, x) table.insert(events, 'touch:' .. x); activeTouch = id end\n"
		"function love.gamepadaxis(joystick, axis, value) table.insert(events, joystick:getName() .. ':' .. value) end\n",
		"@first-input-isolation.lua", error), error);
	require(secondInputRuntime.boot(
		"events = {}\n"
		"function love.keypressed(key) table.insert(events, 'key:' .. key) end\n"
		"function love.touchpressed(id, x) table.insert(events, 'touch:' .. x); activeTouch = id end\n"
		"function love.gamepadaxis(joystick, axis, value) table.insert(events, joystick:getName() .. ':' .. value) end\n",
		"@second-input-isolation.lua", error), error);
	firstInputRuntime.queueKeyPressed("a", "a");
	firstInputRuntime.queueTouchPressed(1, 11, 12, 0, 0);
	firstInputRuntime.queueGamepadAxis(0, "leftx", 0.25f);
	secondInputRuntime.queueKeyPressed("b", "b");
	secondInputRuntime.queueTouchPressed(1, 21, 22, 0, 0);
	secondInputRuntime.queueGamepadAxis(0, "leftx", -0.75f);
	require(firstInputRuntime.update(0.1, error), error);
	execute(firstInputRuntime,
		"assert(table.concat(events, '|') == 'key:a|touch:11.0|First Pad:0.25')\n"
		"local x, y = love.touch.getPosition(activeTouch); assert(x == 11 and y == 12)\n",
		"@verify-first-input-isolation.lua");
	execute(secondInputRuntime,
		"assert(#events == 0 and #love.touch.getTouches() == 0)\n",
		"@verify-second-input-pending.lua");
	require(secondInputRuntime.update(0.1, error), error);
	execute(secondInputRuntime,
		"assert(table.concat(events, '|') == 'key:b|touch:21.0|Second Pad:-0.75')\n"
		"local x, y = love.touch.getPosition(activeTouch); assert(x == 21 and y == 22)\n",
		"@verify-second-input-isolation.lua");
	firstInputRuntime.close();
	secondInputRuntime.close();

	Dora::Love::LoveRuntime timerRuntime;
	require(timerRuntime.open(error), error);
	require(timerRuntime.boot(
		"local timer = require('love.timer'); assert(timer == love.timer)\n"
		"assert(timer.getDelta() == 0 and timer.getFPS() == 0 and timer.getAverageDelta() == 0)\n"
		"local before = timer.getTime(); timer.sleep(0); assert(timer.getTime() >= before)\n"
		"function love.update(dt) assert(timer.getDelta() == dt and timer.step() == dt) end\n",
		"@timer.lua", error), error);
	for (int i = 0; i < 4; ++i)
		require(timerRuntime.update(0.25, error), error);
	execute(timerRuntime,
		"assert(love.timer.getFPS() == 4 and love.timer.getAverageDelta() == 0.25)\n",
		"@verify-timer.lua");
	timerRuntime.close();
	require(timerRuntime.getAllocationBytes() == 0, "timer state retained Lua allocations after close");

	Dora::Love::LoveRuntime mathRuntime;
	require(mathRuntime.open(error), error);
	execute(mathRuntime,
		"local lm = require('love.math'); assert(lm == love.math)\n"
		"lm.setRandomSeed(12345); assert(lm.getRandomState() == '0x6a484838548f8a63')\n"
		"local first = lm.random(); assert(math.abs(first - 0.888946119490527) < 1e-15)\n"
		"local state = lm.getRandomState(); local second = lm.random(); lm.setRandomState(state); assert(lm.random() == second)\n"
		"lm.setRandomSeed(12345); local normal = lm.randomNormal(2, 3); lm.setRandomSeed(12345); assert(lm.randomNormal(2, 3) == normal)\n"
		"local a = lm.newRandomGenerator(1, 2); local b = lm.newRandomGenerator(1, 2)\n"
		"local low, high = a:getSeed(); assert(low == 1 and high == 2 and a:getState() == b:getState())\n"
		"for i = 1, 20 do assert(a:random() == b:random()) end\n"
		"a:setSeed(-1); low, high = a:getSeed(); assert(low == 4294967295 and high == 4294967295)\n"
		"a:setSeed(-1, -2); low, high = a:getSeed(); assert(low == 4294967295 and high == 4294967294)\n"
		"a:setSeed(99); b:setSeed(99); assert(a:random(7) == b:random(7)); assert(a:random(-2, 2) == b:random(-2, 2))\n"
		"local saved = a:getState(); local value = a:random(); a:setState(saved); assert(a:random() == value)\n"
		"assert(lm._getRandomGenerator() == lm._getRandomGenerator())\n"
		"local r,g,bl,alpha = lm.colorToBytes(1, 0.5, -1); assert(r == 255 and g == 128 and bl == 0 and alpha == nil)\n"
		"r,g,bl,alpha = lm.colorToBytes({0, 0.25, 2, 0.5}); assert(r == 0 and g == 64 and bl == 255 and alpha == 128)\n"
		"r,g,bl,alpha = lm.colorFromBytes({255, 128, -4, 300}); assert(r == 1 and math.abs(g - 128/255) < 1e-15 and bl == 0 and alpha == 1)\n"
		"local linear, _, _, unchanged = lm.gammaToLinear(0.5, 0.25, 1, 0.3); assert(math.abs(linear - 0.21404114048223255) < 1e-7 and unchanged == 0.3)\n"
		"local gamma = lm.linearToGamma(linear); assert(math.abs(gamma - 0.5) < 1e-7)\n"
		"assert(lm.isConvex({0,0, 10,0, 10,10, 0,10}))\n"
		"assert(not lm.isConvex(0,0, 10,0, 5,5, 10,10, 0,10))\n"
		"local triangles = lm.triangulate({0,0, 10,0, 10,10, 0,10}); assert(#triangles == 2)\n"
		"local area = 0; for _,t in ipairs(triangles) do area = area + math.abs((t[3]-t[1])*(t[6]-t[2])-(t[5]-t[1])*(t[4]-t[2]))/2 end; assert(area == 100)\n"
		"assert(#lm.triangulate(0,10, 10,10, 10,0, 0,0) == 2)\n"
		"assert(#lm.triangulate({0,0, 10,0, 10,10, 5,5, 0,10}) == 3)\n"
		"local zeroNoise={lm.noise(0),lm.noise(0,0),lm.noise(0,0,0),lm.noise(0,0,0,0)}; for _,value in ipairs(zeroNoise) do assert(math.abs(value-0.5)<1e-6) end\n"
		"local noise1, noise2, noise3, noise4 = lm.noise(0.125), lm.noise(0.125,0.25), lm.noise(0.125,0.25,0.5), lm.noise(0.125,0.25,0.5,1)\n"
		"assert(noise1 >= 0 and noise1 <= 1 and noise2 >= 0 and noise2 <= 1 and noise3 >= 0 and noise3 <= 1 and noise4 >= 0 and noise4 <= 1)\n"
		"assert(noise1 == lm.noise(0.125) and noise4 == lm.noise(0.125,0.25,0.5,1,999))\n"
		"local identity = lm.newTransform(); local ix,iy = identity:transformPoint(4,5); assert(ix == 4 and iy == 5 and identity:isAffine2DTransform())\n"
		"local transform = lm.newTransform(10,20,0,2,3); local tx,ty = transform:transformPoint(4,5); assert(tx == 18 and ty == 35)\n"
		"local bx,by = transform:inverseTransformPoint(tx,ty); assert(math.abs(bx-4)<1e-6 and math.abs(by-5)<1e-6)\n"
		"local inverse = transform:inverse(); bx,by = inverse:transformPoint(tx,ty); assert(math.abs(bx-4)<1e-6 and math.abs(by-5)<1e-6)\n"
		"local clone = transform:clone(); assert(clone:translate(1,2) == clone and clone:rotate(0) == clone and clone:scale(1) == clone and clone:shear(0,0) == clone)\n"
		"local composed = transform * lm.newTransform(1,2); local cx,cy = composed:transformPoint(0,0); assert(cx == 12 and cy == 26)\n"
		"local applied = transform:clone(); assert(applied:apply(lm.newTransform(1,2)) == applied); local ax,ay = applied:transformPoint(0,0); assert(ax == cx and ay == cy)\n"
		"local matrix = {1,0,0,7, 0,1,0,8, 0,0,1,0, 0,0,0,1}; assert(identity:setMatrix(matrix) == identity); tx,ty=identity:transformPoint(2,3); assert(tx==9 and ty==11)\n"
		"local m = {identity:getMatrix()}; assert(#m==16 and m[4]==7 and m[8]==8)\n"
		"identity:setMatrix('column', {1,0,0,0, 0,1,0,0, 0,0,1,0, 5,6,0,1}); tx,ty=identity:transformPoint(2,3); assert(tx==7 and ty==9)\n"
		"assert(identity:reset() == identity); identity:setTransformation(3,4,0,2); tx,ty=identity:transformPoint(1,1); assert(tx==5 and ty==6)\n"
		"local curve = lm.newBezierCurve({0,0, 10,20, 20,0}); assert(curve:getDegree()==2 and curve:getControlPointCount()==3)\n"
		"local ex,ey=curve:evaluate(0.5); assert(ex==10 and ey==10); local lx,ly=curve:getControlPoint(-1); assert(lx==20 and ly==0)\n"
		"local derivative=curve:getDerivative(); local dx,dy=derivative:evaluate(0.5); assert(dx==20 and dy==0)\n"
		"local segment=curve:getSegment(0.25,0.75); local sx1,sy1=segment:evaluate(0); local sx2,sy2=segment:evaluate(1); local ox1,oy1=curve:evaluate(0.25); local ox2,oy2=curve:evaluate(0.75); assert(math.abs(sx1-ox1)<1e-6 and math.abs(sy1-oy1)<1e-6 and math.abs(sx2-ox2)<1e-6 and math.abs(sy2-oy2)<1e-6)\n"
		"local rendered=curve:render(3); assert(#rendered==34); local renderedSegment=curve:renderSegment(0.25,0.75,3); assert(#renderedSegment>0 and #renderedSegment<#rendered)\n"
		"curve:setControlPoint(2,10,10); curve:insertControlPoint(5,5,2); assert(curve:getControlPointCount()==4); curve:removeControlPoint(2); assert(curve:getControlPointCount()==3)\n"
		"curve:translate(2,3); curve:rotate(0); curve:scale(2,2,3); ex,ey=curve:getControlPoint(1); assert(ex==2 and ey==3)\n"
		"local ok, message = pcall(a.setState, a, 'broken'); assert(not ok and message:find('Invalid random state', 1, true))\n"
		"assert(not pcall(a.setSeed, a, 0/0)); assert(not pcall(lm.triangulate, {0,0, 1,0}))\n"
		"assert(not pcall(lm.isConvex, {0,0, 1})); assert(not pcall(lm.isConvex, {0,0, math.huge,1}))\n"
		"assert(not pcall(lm.noise)); assert(not pcall(lm.noise, math.huge)); assert(not pcall(lm.newBezierCurve, {0,0,1}))\n"
		"assert(not pcall(curve.evaluate,curve,-0.1)); assert(not pcall(curve.getSegment,curve,0.8,0.2)); assert(not pcall(curve.render,curve,21))\n"
		"local singular=lm.newTransform(); singular:scale(0,0); assert(singular:inverse()); assert(not pcall(identity.setMatrix,identity,'bad',matrix))\n",
		"@math.lua");
	mathRuntime.close();
	require(mathRuntime.getAllocationBytes() == 0, "math state retained Lua allocations after close");

	Dora::Love::LoveRuntime firstMathRuntime;
	Dora::Love::LoveRuntime secondMathRuntime;
	require(firstMathRuntime.open(error), error);
	require(secondMathRuntime.open(error), error);
	execute(firstMathRuntime,
		"love.math.setRandomSeed(111); isolatedState = love.math.getRandomState()\n"
		"isolatedTransform = love.math.newTransform(10,20); isolatedCurve = love.math.newBezierCurve({0,0,10,20,20,0})\n",
		"@first-math-state.lua");
	execute(secondMathRuntime,
		"love.math.setRandomSeed(222); love.math.random(); love.math.random()\n"
		"local transform=love.math.newTransform(99,88); transform:translate(7,6)\n"
		"local curve=love.math.newBezierCurve({1,1,2,2}); curve:setControlPoint(1,100,100)\n",
		"@second-math-state.lua");
	execute(firstMathRuntime,
		"assert(love.math.getRandomState() == isolatedState)\n"
		"local x,y=isolatedTransform:transformPoint(0,0); assert(x==10 and y==20)\n"
		"x,y=isolatedCurve:evaluate(0.5); assert(x==10 and y==10)\n",
		"@verify-math-state-isolation.lua");
	firstMathRuntime.close();
	secondMathRuntime.close();
	require(firstMathRuntime.getAllocationBytes() == 0 && secondMathRuntime.getAllocationBytes() == 0,
		"isolated math states retained Lua allocations after close");

	Dora::Love::LoveRuntime dataRuntime;
	require(dataRuntime.open(error), error);
	execute(dataRuntime,
		"local data=require('love.data'); assert(data==love.data)\n"
		"local blank=data.newByteData(4); assert(blank:getSize()==4 and blank:getString()=='\\0\\0\\0\\0' and blank:getPointer()~=nil and blank:getFFIPointer()==nil)\n"
		"local bytes=data.newByteData('abcdef'); local clone=bytes:clone(); assert(clone:getString()=='abcdef' and clone:getPointer()~=bytes:getPointer())\n"
		"local subset=data.newByteData(bytes,2,3); assert(subset:getString()=='cde')\n"
		"local view=data.newDataView(bytes,1,4); assert(view:getString()=='bcde' and view:getSize()==4 and view:getFFIPointer()==nil)\n"
		"local viewClone=view:clone(); assert(bytes:release()); bytes=nil; view=nil; collectgarbage('collect'); assert(viewClone:getString()=='bcde')\n"
		"local fileData=love.filesystem.newFileData('fixture','fixture.bin'); local fileView=data.newDataView(fileData,1,3); assert(fileData:release() and fileView:getString()=='ixt')\n"
		"local imageData=love.image.newImageData(1,1); imageData:setPixel(0,0,1,0.5,0,1); assert(data.newByteData(imageData):getSize()==4)\n"
		"local imageView=data.newDataView(imageData,0,4); assert(imageData:release() and imageView:getSize()==4)\n"
		"local soundData=love.sound.newSoundData(2,8000,16,1); local soundView=data.newDataView(soundData,0,2); assert(soundData:release() and soundView:getSize()==2)\n"
		"assert(data.encode('string','hex','Love')=='4c6f7665'); assert(data.decode('string','hex','0x4c6f7665')=='Love')\n"
		"local hexData=data.encode('data','hex',clone); assert(hexData:getString()=='616263646566' and data.decode('data','hex',hexData):getString()=='abcdef')\n"
		"assert(data.encode('string','base64','hello')=='aGVsbG8=' and data.decode('string','base64','aG Vs\\nbG8=')=='hello')\n"
		"assert(data.encode('string','base64','abcdef',4)=='YWJj\\nZGVm\\n')\n"
		"local raw=string.rep('Dora-Love-Data-',128)\n"
		"for _,format in ipairs({'zlib','gzip','deflate'}) do\n"
		" local compressed=data.compress('data',format,raw,9); assert(compressed:getFormat()==format and compressed:getSize()>0 and compressed:getFFIPointer()==nil)\n"
		" assert(data.decompress('string',compressed)==raw); local compressedClone=compressed:clone(); assert(data.decompress('data',compressedClone):getString()==raw)\n"
		" local packed=data.compress('string',format,clone); assert(data.decompress('string',format,packed)=='abcdef')\n"
		"end\n"
		"local lz4=data.compress('data','lz4',raw,9); assert(lz4:getFormat()=='lz4' and data.decompress('string',lz4)==raw)\n"
		"local lz4Bytes=lz4:getString(); local rawSize=#raw; assert(lz4Bytes:byte(1)==rawSize%256 and lz4Bytes:byte(2)==math.floor(rawSize/256)%256 and lz4Bytes:byte(3)==math.floor(rawSize/65536)%256 and lz4Bytes:byte(4)==math.floor(rawSize/16777216)%256)\n"
		"for _,level in ipairs({1,9}) do local packed=data.compress('string','lz4',raw,level); assert(data.decompress('string','lz4',packed)==raw) end\n"
		"local emptyLz4=data.compress('string','lz4',''); assert(data.decompress('string','lz4',emptyLz4)=='')\n"
		"local hashes={md5='900150983cd24fb0d6963f7d28e17f72',sha1='a9993e364706816aba3e25717850c26c9cd0d89d',sha224='23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7',sha256='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',sha384='cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7',sha512='ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'}\n"
		"local lengths={md5=16,sha1=20,sha224=28,sha256=32,sha384=48,sha512=64}; for algorithm,expected in pairs(hashes) do local digest=data.hash(algorithm,'abc'); assert(#digest==lengths[algorithm] and data.encode('string','hex',digest)==expected) end\n"
		"assert(data.encode('string','hex',data.hash('sha256',data.newDataView(clone,0,3)))==hashes.sha256)\n"
		"assert(data.encode('string','hex',data.hash('sha256',''))=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')\n"
		"local legacy=love.math.compress('data','zlib','legacy'); assert(love.math.decompress('string',legacy)=='legacy')\n"
		"local packed=data.pack('data','<I2c3',0x1234,'abc'); assert(packed:getSize()==data.getPackedSize('<I2c3'))\n"
		"local number,text,nextPosition=data.unpack('<I2c3',packed); assert(number==0x1234 and text=='abc' and nextPosition==6)\n"
		"local packedString=data.pack('string','>I4',0x12345678); number,nextPosition=data.unpack('>I4',packedString); assert(number==0x12345678 and nextPosition==5)\n"
		"assert(not pcall(data.newByteData,0)); assert(not pcall(data.newDataView,viewClone,-1,1)); assert(not pcall(data.newDataView,viewClone,3,2))\n"
		"assert(not pcall(data.encode,'string','bad','x')); assert(not pcall(data.hash,'sha3','x')); assert(not pcall(data.decompress,'string','zlib','broken'))\n"
		"assert(not pcall(data.decompress,'string','lz4','broken')); assert(not pcall(data.decompress,'string','lz4',string.char(1,0,0,16)..'x'))\n"
		"assert(blank:type()=='ByteData' and blank:typeOf('ByteData') and blank:typeOf('Data') and blank:typeOf('Object') and not blank:typeOf('ImageData'))\n"
		"local capturedGetSize=blank.getSize; assert(blank:release()==true and blank:release()==false)\n"
		"assert(blank:type()=='ByteData' and blank:typeOf('Data')); local ok,message=pcall(blank.getSize,blank); assert(not ok and message:find('Cannot use object after it has been released.',1,true))\n"
		"ok,message=pcall(capturedGetSize,blank); assert(not ok and message:find('Cannot use object after it has been released.',1,true))\n"
		"ok,message=pcall(data.encode,'string','hex',blank); assert(not ok and message:find('Cannot use object after it has been released.',1,true))\n",
		"@data.lua");
	dataRuntime.close();
	require(dataRuntime.getAllocationBytes() == 0, "data state retained Lua allocations after close");

	Dora::Love::LoveRuntime firstDataRuntime;
	Dora::Love::LoveRuntime secondDataRuntime;
	require(firstDataRuntime.open(error), error);
	require(secondDataRuntime.open(error), error);
	execute(firstDataRuntime,
		"local d=love.data; owned=d.compress('data','lz4','first-state',9); digest=d.hash('sha256','first-state')\n",
		"@first-data-state.lua");
	execute(secondDataRuntime,
		"local d=love.data; owned=d.compress('data','lz4','second-state',1); digest=d.hash('sha256','second-state')\n",
		"@second-data-state.lua");
	execute(firstDataRuntime,
		"assert(love.data.decompress('string',owned)=='first-state'); assert(love.data.hash('sha256','first-state')==digest)\n",
		"@verify-data-state-isolation.lua");
	firstDataRuntime.close();
	secondDataRuntime.close();
	require(firstDataRuntime.getAllocationBytes() == 0 && secondDataRuntime.getAllocationBytes() == 0,
		"isolated data states retained Lua allocations after close");

	MockSound soundBackend;
	TestFilesystemBackend soundFilesystem;
	Dora::Love::LoveRuntime soundRuntime;
	soundRuntime.setSoundBackend(&soundBackend);
	soundRuntime.setFilesystemBackend(&soundFilesystem);
	require(soundRuntime.open(error), error);
	require(soundRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(soundRuntime,
		"local sound = require('love.sound'); assert(sound == love.sound)\n"
		"local filesystem = require('love.filesystem')\n"
		"local truncated = sound.newSoundData(3.9, 48000.9, 16.9, 2.9); assert(truncated:getSampleCount() == 3 and truncated:getSampleRate() == 48000 and truncated:getBitDepth() == 16 and truncated:getChannelCount() == 2)\n"
		"local blank = sound.newSoundData(3, 48000, 16, 2)\n"
		"assert(blank:getSampleCount() == 3 and blank:getSampleRate() == 48000 and blank:getBitDepth() == 16)\n"
		"assert(blank:getChannelCount() == 2 and blank:getChannels() == 2 and blank:getDuration() == 3 / 48000)\n"
		"assert(blank:getSize() == 12 and #blank:getString() == 12 and blank:getPointer() ~= nil and blank:getFFIPointer() == nil)\n"
		"blank:setSample(0, 1); blank:setSample(0, 2, -1); blank:setSample(1, 1, 0.5)\n"
		"assert(blank:getSample(0) == 1 and blank:getSample(0, 2) == -1)\n"
		"assert(math.abs(blank:getSample(1, 1) - 0.5) < 0.0001)\n"
		"local clone = blank:clone(); clone:setSample(0, 0); assert(blank:getSample(0) == 1 and clone:getSample(0) == 0)\n"
		"local eight = sound.newSoundData(1, 8000, 8, 1); assert(eight:getSize() == 1 and eight:getSample(0) == 0)\n"
		"eight:setSample(0, -1); assert(eight:getSample(0) == -1)\n"
		"assert(not pcall(sound.newSoundData, 0)); assert(not pcall(sound.newSoundData, 1, 44100, 24, 1))\n"
		"assert(not pcall(sound.newSoundData, 100000000, 44100, 16, 8))\n"
		"assert(not pcall(blank.getSample, blank, 3, 1)); assert(not pcall(blank.getSample, blank, 0, 3))\n"
		"assert(not pcall(blank.setSample, blank, 0, 0 / 0))\n"
		"local encoded = filesystem.newFileData('encoded-sound', 'fixture.wav')\n"
		"local decoded = sound.newSoundData(encoded)\n"
		"assert(decoded:getSampleCount() == 2 and decoded:getSampleRate() == 22050 and decoded:getChannelCount() == 2)\n"
		"assert(decoded:getBitDepth() == 16 and decoded:getSample(0, 1) == 1 and decoded:getSample(0, 2) == -1)\n"
		"local decoder = sound.newDecoder(encoded, 4)\n"
		"assert(decoder:getChannelCount() == 2 and decoder:getChannels() == 2 and decoder:getBitDepth() == 16)\n"
		"assert(decoder:getSampleRate() == 22050 and decoder:getDuration() == 2 / 22050)\n"
		"local first = assert(decoder:decode()); assert(first:getSampleCount() == 1 and first:getSample(0, 1) == 1 and first:getSample(0, 2) == -1)\n"
		"local decoderClone = decoder:clone(); local cloneFirst = assert(decoderClone:decode())\n"
		"assert(cloneFirst:getSampleCount() == 1 and cloneFirst:getSample(0, 1) == 1)\n"
		"local second = assert(decoder:decode()); assert(second:getSampleCount() == 1 and math.abs(second:getSample(0, 1) - 0.5) < 0.0001)\n"
		"assert(decoder:decode() == nil)\n"
		"decoder:seek(0); local expanded = sound.newSoundData(decoder)\n"
		"assert(expanded:getSampleCount() == 2 and expanded:getSample(1, 2) < -0.49 and decoder:decode() == nil)\n"
		"decoder:seek(1 / 22050); local remainder = sound.newSoundData(decoder)\n"
		"assert(remainder:getSampleCount() == 1 and math.abs(remainder:getSample(0, 1) - 0.5) < 0.0001)\n"
		"local filenameDecoder = sound.newDecoder('sound.mock', 3); assert(filenameDecoder:decode():getSampleCount() == 1)\n"
		"assert(sound.newSoundData(sound.newDecoder(encoded, 1)):getSampleCount() == 2)\n"
		"assert(not pcall(sound.newDecoder, encoded, 0)); assert(not pcall(sound.newDecoder, encoded, 268435457))\n"
		"assert(not pcall(decoder.seek, decoder, -1)); assert(not pcall(decoder.seek, decoder, 0 / 0))\n"
		"local bad = filesystem.newFileData('bad-sound', 'broken.wav'); local ok, message = pcall(sound.newSoundData, bad)\n"
		"assert(not ok and message:find('mock SoLoud decoder rejected encoded data', 1, true))\n"
		"ok, message = pcall(sound.newDecoder, bad); assert(not ok and message:find('mock SoLoud decoder rejected encoded data', 1, true))\n",
		"@sound-data.lua");
	require(soundBackend.decodes == 6, "SoundData/Decoder decode calls did not reach the injected backend");
	soundRuntime.close();
	require(soundRuntime.getAllocationBytes() == 0, "sound state retained Lua allocations after close");

	MockAudio audioBackend;
	TestFilesystemBackend audioFilesystem;
	Dora::Love::LoveRuntime audioRuntime;
	audioRuntime.setFilesystemBackend(&audioFilesystem);
	audioRuntime.setAudioBackend(&audioBackend);
	require(audioRuntime.open(error), error);
	require(audioRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(audioRuntime,
		"local audio = require('love.audio'); assert(audio == love.audio)\n"
		"local recordingDevices=audio.getRecordingDevices(); assert(#recordingDevices==2 and recordingDevices[1]==audio.getRecordingDevices()[1])\n"
		"local recorder=recordingDevices[1]; assert(recorder:type()=='RecordingDevice' and recorder:typeOf('Object') and recorder:getName()=='Default Microphone')\n"
		"assert(not recorder:isRecording() and recorder:getSampleCount()==0 and recorder:getSampleRate()==8000 and recorder:getBitDepth()==16 and recorder:getChannelCount()==1)\n"
		"assert(recorder:start(4,16000,8,2) and recorder:isRecording() and recorder:getSampleCount()==4)\n"
		"local captured=assert(recorder:getData()); assert(captured:getSampleCount()==4 and captured:getSampleRate()==16000 and captured:getBitDepth()==8 and captured:getChannelCount()==2 and captured:getSize()==8 and recorder:getSampleCount()==0)\n"
		"assert(recorder:start() and recorder:getSampleRate()==16000 and recorder:getBitDepth()==8 and recorder:getChannelCount()==2); captured=assert(recorder:stop()); assert(captured:getSampleCount()==4 and not recorder:isRecording() and recorder:getSampleCount()==0)\n"
		"local ok,message=pcall(recorder.start,recorder,0); assert(not ok and message:find('positive',1,true)); ok,message=pcall(recorder.start,recorder,4,8000,24,1); assert(not ok and message:find('8 or 16',1,true)); ok,message=pcall(recorder.start,recorder,4,8000,16,3); assert(not ok and message:find('1 or 2',1,true))\n"
		"local temporary=recordingDevices[2]; assert(temporary:start(2)); temporary=nil; recordingDevices=nil; collectgarbage('collect')\n"
		"assert(audio.getActiveSourceCount() == 0 and audio.getSourceCount() == 0)\n"
		"assert(audio.getVolume() == 1); audio.setVolume(0.4); assert(math.abs(audio.getVolume() - 0.4) < 0.001)\n"
		"assert(audio.setMixWithSystem(false)); assert(audio.setMixWithSystem(true)); assert(not pcall(audio.setMixWithSystem, 1))\n"
		"audio.setPosition(12, -3); local px, py, pz = audio.getPosition(); assert(px == 12 and py == -3 and pz == 0)\n"
		"audio.setOrientation(1, 2, 3, 4, 5, 6); local fx, fy, fz, ux, uy, uz = audio.getOrientation(); assert(fx == 1 and fy == 2 and fz == 3 and ux == 4 and uy == 5 and uz == 6)\n"
		"audio.setVelocity(-7, 8, 9); local vx, vy, vz = audio.getVelocity(); assert(vx == -7 and vy == 8 and vz == 9)\n"
		"local ok, message = pcall(audio.setPosition, 0/0, 0); assert(not ok and message:find('finite', 1, true))\n"
		"ok, message = pcall(audio.setOrientation, 0, 0, 1, 0, math.huge, 0); assert(not ok and message:find('finite', 1, true))\n"
		"ok, message = pcall(audio.setVelocity, 0, -math.huge); assert(not ok and message:find('finite', 1, true))\n"
		"local pcm = love.sound.newSoundData(4, 22050, 8, 2); pcm:setSample(0, 1, -1); pcm:setSample(0, 2, 1)\n"
		"pcmSource = audio.newSource(pcm); assert(pcmSource:getType() == 'static' and pcmSource:getChannelCount() == 2 and pcmSource:getChannels() == 2 and pcmSource:play())\n"
		"monoSource = audio.newSource(love.sound.newSoundData(4, 22050, 8, 1)); assert(monoSource:getChannelCount() == 1)\n"
		"local sx,sy,sz=monoSource:getPosition(); local vx,vy,vz=monoSource:getVelocity(); local dx,dy,dz=monoSource:getDirection(); local ci,co,cv,ch=monoSource:getCone(); local vmin,vmax=monoSource:getVolumeLimits(); local rd,md=monoSource:getAttenuationDistances(); assert(sx==0 and sy==0 and sz==0 and vx==0 and vy==0 and vz==0 and dx==0 and dy==0 and dz==0 and math.abs(ci-math.pi*2)<0.00001 and math.abs(co-math.pi*2)<0.00001 and cv==0 and ch==1 and monoSource:getAirAbsorption()==0 and vmin==0 and vmax==1 and not monoSource:isRelative() and rd==1 and md==1000000 and monoSource:getRolloff()==1)\n"
		"monoSource:setPosition(11,12); monoSource:setVelocity(1,2,3); monoSource:setDirection(0,0,-1); monoSource:setCone(math.pi/2,math.pi*3/2,0.25,0.5); monoSource:setAirAbsorption(2); monoSource:setVolumeLimits(0.1,0.8); monoSource:setRelative(true); monoSource:setAttenuationDistances(2,2000000); monoSource:setRolloff(0.5)\n"
		"sx,sy,sz=monoSource:getPosition(); vx,vy,vz=monoSource:getVelocity(); dx,dy,dz=monoSource:getDirection(); ci,co,cv,ch=monoSource:getCone(); vmin,vmax=monoSource:getVolumeLimits(); rd,md=monoSource:getAttenuationDistances(); assert(sx==11 and sy==12 and sz==0 and vx==1 and vy==2 and vz==3 and dx==0 and dy==0 and dz==-1 and math.abs(ci-math.pi/2)<0.00001 and math.abs(co-math.pi*3/2)<0.00001 and cv==0.25 and ch==0.5 and monoSource:getAirAbsorption()==2 and math.abs(vmin-0.1)<0.00001 and math.abs(vmax-0.8)<0.00001 and monoSource:isRelative() and rd==2 and md==1000000 and monoSource:getRolloff()==0.5)\n"
		"monoClone=monoSource:clone(); sx,sy,sz=monoClone:getPosition(); dx,dy,dz=monoClone:getDirection(); ci,co,cv,ch=monoClone:getCone(); vmin,vmax=monoClone:getVolumeLimits(); rd,md=monoClone:getAttenuationDistances(); assert(sx==11 and sy==12 and sz==0 and dx==0 and dy==0 and dz==-1 and cv==0.25 and ch==0.5 and monoClone:getAirAbsorption()==2 and math.abs(vmin-0.1)<0.00001 and math.abs(vmax-0.8)<0.00001 and monoClone:isRelative() and rd==2 and md==1000000 and monoClone:getRolloff()==0.5)\n"
		"local ok,message=pcall(pcmSource.getPosition,pcmSource); assert(not ok and message:find('mono Sources',1,true)); ok,message=pcall(pcmSource.setDirection,pcmSource,0,0,-1); assert(not ok and message:find('mono Sources',1,true)); ok,message=pcall(pcmSource.getCone,pcmSource); assert(not ok and message:find('mono Sources',1,true)); ok,message=pcall(pcmSource.setAirAbsorption,pcmSource,1); assert(not ok and message:find('mono Sources',1,true)); pcmSource:setVolumeLimits(0.2,0.9); vmin,vmax=pcmSource:getVolumeLimits(); assert(math.abs(vmin-0.2)<0.00001 and math.abs(vmax-0.9)<0.00001); ok,message=pcall(monoSource.setVelocity,monoSource,0/0,0); assert(not ok and message:find('finite',1,true))\n"
		"ok,message=pcall(monoSource.setAttenuationDistances,monoSource,-1,2); assert(not ok and message:find('non%-negative')); ok,message=pcall(monoSource.setRolloff,monoSource,-1); assert(not ok and message:find('non%-negative'))\n"
		"ok,message=pcall(monoSource.setDirection,monoSource,0/0,0); assert(not ok and message:find('finite',1,true)); ok,message=pcall(monoSource.setCone,monoSource,0,1,2); assert(not ok and message:find('between 0 and 1',1,true)); ok,message=pcall(monoSource.setAirAbsorption,monoSource,-1); assert(not ok and message:find('non%-negative')); ok,message=pcall(monoSource.setAirAbsorption,monoSource,0/0); assert(not ok and message:find('finite',1,true)); ok,message=pcall(monoSource.setVolumeLimits,monoSource,-1,1); assert(not ok and message:find('between 0 and 1',1,true))\n"
		"assert(math.abs(pcmSource:getDuration() - 4/22050) < 0.000001 and pcmSource:getDuration('samples') == 4)\n"
		"queueData=love.sound.newSoundData(4,8000,16,1); queueData:setSample(0,-1); queueData:setSample(1,-0.5); queueData:setSample(2,0.5); queueData:setSample(3,1)\n"
		"queueSource=audio.newQueueableSource(8000,16,1,2); assert(queueSource:getType()=='queue' and queueSource:getFreeBufferCount()==2 and queueSource:getDuration('samples')==0)\n"
		"assert(queueSource:queue(queueData) and queueSource:getFreeBufferCount()==1 and queueSource:getDuration('samples')==4)\n"
		"assert(queueSource:queue(queueData,2,4) and queueSource:getFreeBufferCount()==0 and queueSource:getDuration('samples')==6)\n"
		"assert(not queueSource:queue(queueData) and queueSource:queue(queueData,0) and queueSource:getFreeBufferCount()==0)\n"
		"queueSource:setVolume(0.3); queueSource:setPitch(1.5); queueClone=queueSource:clone(); assert(queueClone:getType()=='queue' and queueClone:getFreeBufferCount()==2 and queueClone:getDuration('samples')==0 and math.abs(queueClone:getVolume()-0.3)<0.00001 and queueClone:getPitch()==1.5)\n"
		"ok,message=pcall(queueSource.setLooping,queueSource,true); assert(not ok and message:find('can not be looped',1,true)); assert(not queueSource:isLooping())\n"
		"ok,message=pcall(queueSource.queue,queueSource,love.sound.newSoundData(1,11025,16,1)); assert(not ok and message:find('format mismatch',1,true))\n"
		"ok,message=pcall(queueSource.queue,queueSource,queueData,7,2); assert(not ok and message:find('out of bounds',1,true))\n"
		"ok,message=pcall(pcmSource.queue,pcmSource,queueData); assert(not ok and message:find('Only queueable Sources',1,true))\n"
		"assert(queueSource:play()); queueSource:stop(); assert(queueSource:getFreeBufferCount()==2 and queueSource:getDuration('samples')==0 and not queueSource:isPlaying() and queueSource:isStopped())\n"
		"source = audio.newSource('pig.png', 'static')\n"
		"stream = audio.newSource('pig.png', 'stream')\n"
		"assert(audio.isEffectsSupported() and audio.getMaxSceneEffects()==64 and audio.getMaxSourceEffects()==3)\n"
		"assert(audio.setEffect('echo',{type='echo',volume=0.6,delay=0.2,feedback=0.4,damping=0.3}))\n"
		"assert(audio.setEffect('verb',{type='reverb',decaytime=2,highlimit=true}))\n"
		"local target={keep=true}; assert(audio.getEffect('echo',target)==target and target.keep and target.type=='echo' and math.abs(target.delay-0.2)<0.00001)\n"
		"local active=audio.getActiveEffects(); assert(#active==2 and active[1]=='echo' and active[2]=='verb','active='..table.concat(active,','))\n"
		"assert(source:setFilter({type='lowpass',volume=0.8,highgain=0.25})); local direct=source:getFilter(); assert(direct.type=='lowpass' and math.abs(direct.volume-0.8)<0.00001 and direct.highgain==0.25)\n"
		"assert(source:setEffect('echo',true)); assert(source:setEffect('verb',{type='highpass',lowgain=0.5})); local enabled,send=source:getEffect('verb'); assert(enabled and send.type=='highpass' and send.lowgain==0.5)\n"
		"local sourceEffects=source:getActiveEffects(); assert(#sourceEffects==2 and sourceEffects[1]=='echo' and sourceEffects[2]=='verb')\n"
		"local ok,message=pcall(audio.setEffect,'bad',{type='echo',delay=0/0}); assert(not ok and message:find('finite',1,true)); ok,message=pcall(audio.setEffect,'bad',{type='unknown'}); assert(not ok and message:find('invalid effect type',1,true))\n"
		"assert(source ~= stream and source:getType() == 'static' and stream:getType() == 'stream' and source:getChannelCount() == 2 and stream:getChannels() == 2)\n"
		"assert(source:getVolume() == 1 and source:getPitch() == 1 and not source:isLooping())\n"
		"source:setVolume(0.35); source:setPitch(1.25); source:setLooping(true); source:seek(1500,'samples')\n"
		"assert(math.abs(source:getVolume() - 0.35) < 0.001 and source:getPitch() == 1.25 and source:isLooping())\n"
		"assert(source:tell() == 1.5 and source:tell('seconds') == 1.5 and source:tell('samples') == 1500)\n"
		"assert(source:getDuration()==2.5 and source:getDuration('samples')==2500)\n"
		"clone=source:clone(); assert(clone~=source and clone:getType()=='static' and clone:tell()==0 and not clone:isPlaying())\n"
		"assert(clone:getFilter().type=='lowpass' and #clone:getActiveEffects()==2 and select(1,clone:getEffect('echo')))\n"
		"assert(audio.setEffect('echo',false)); assert(audio.getEffect('echo')==nil and not select(1,source:getEffect('echo')) and not select(1,clone:getEffect('echo')))\n"
		"assert(source:setFilter()); assert(source:getFilter()==nil); assert(source:setEffect('verb',false) and not select(1,source:getEffect('verb')))\n"
		"for index=1,4 do assert(audio.setEffect('slot'..index,{type='echo',delay=0.05*index})) end\n"
		"assert(source:setEffect('slot1') and source:setEffect('slot2') and source:setEffect('slot3')); local slotok,sloterror=pcall(source.setEffect,source,'slot4'); assert(not slotok and (sloterror:find('maximum',1,true) or sloterror:find('at most three',1,true)))\n"
		"assert(#source:getActiveEffects()==3); assert(source:setEffect('slot2',false)); assert(source:setEffect('slot4') and #source:getActiveEffects()==3)\n"
		"assert(math.abs(clone:getVolume()-0.35)<0.001 and clone:getPitch()==1.25 and clone:isLooping() and clone:getDuration()==source:getDuration())\n"
		"clone:setVolume(0.2); assert(math.abs(source:getVolume()-0.35)<0.001 and math.abs(clone:getVolume()-0.2)<0.001)\n"
		"assert(source:play() and clone:play() and source:isPlaying() and clone:isPlaying() and audio.getActiveSourceCount() == 3 and audio.getSourceCount() == 3)\n"
		"clone:pause(); assert(clone:isPaused() and source:isPlaying() and audio.getActiveSourceCount() == 3); clone:stop(); assert(source:isPlaying() and audio.getActiveSourceCount() == 2)\n"
		"source:pause(); assert(not source:isPlaying() and source:isPaused() and audio.getActiveSourceCount() == 2)\n"
		"assert(source:play() and source:isPlaying() and not source:isPaused())\n"
		"audio.stop(source); assert(not source:isPlaying() and source:tell() == 0)\n"
		"assert(audio.play({source, stream})); local paused = audio.pause(); "
		"assert(#paused == 3 and pcmSource:isPaused() and source:isPaused() and stream:isPaused() and audio.getActiveSourceCount() == 3)\n"
		"local seen = {}; for _, item in ipairs(paused) do seen[item] = true end; "
		"assert(seen[pcmSource] and seen[source] and seen[stream] and #audio.pause() == 0)\n"
		"assert(audio.play(source, stream)); audio.pause({source}); "
		"assert(source:isPaused() and stream:isPlaying() and audio.getActiveSourceCount() == 3); audio.stop({source, stream})\n"
		"assert(audio.getActiveSourceCount() == 1); audio.stop(); assert(not source:isPlaying() and not stream:isPlaying() and audio.getActiveSourceCount() == 0)\n"
		"ok, message = pcall(audio.newSource, '../pig.png', 'static')\n"
		"assert(not ok and message:find('relative', 1, true))\n"
		"ok, message = pcall(audio.newSource, 'pig.png', 'queue')\n"
		"assert(not ok and message:find(\"expected 'static' or 'stream'\", 1, true))\n"
		"ok, message = pcall(source.setVolume, source, 2); assert(not ok and message:find('between 0 and 1'))\n"
		"ok, message = pcall(audio.setVolume, 2); assert(not ok and message:find('between 0 and 1'))\n"
		"ok, message = pcall(source.tell, source, 'frames'); assert(not ok and message:find(\"'seconds' or 'samples'\", 1, true))\n"
		"ok, message = pcall(source.getDuration, source, 'frames'); assert(not ok and message:find(\"'seconds' or 'samples'\", 1, true))\n"
		"garbage = audio.newSource('pig.png'); garbage = nil; collectgarbage('collect')\n",
		"@audio.lua");
	require(audioBackend.sources.size() == 8 && audioBackend.released == 1,
		"Source garbage collection did not release exactly its Dora audio resource");
	requireNear(audioBackend.instanceVolume, 0.4f,
		"love.audio instance volume did not reach the injected Dora AudioBus backend");
	require(audioBackend.mixWithSystem && audioBackend.mixWithSystemChanges == 2,
		"love.audio system-mix policy did not reach the application audio backend");
	require(audioBackend.lastPCMSize == 4 && audioBackend.lastPCMSampleRate == 22050
		&& audioBackend.lastPCMBitDepth == 8 && audioBackend.lastPCMChannels == 1,
		"SoundData PCM metadata did not reach the Dora AudioSource backend");
	require(audioBackend.recordings.empty() && audioBackend.recordingsStopped == 3,
		"RecordingDevice restart, stop, or garbage collection leaked a capture resource");
	audioRuntime.close();
	require(audioBackend.sources.empty() && audioBackend.released == 9,
		"Love state close did not release its remaining Dora audio resources");
	require(audioRuntime.getAllocationBytes() == 0, "audio state retained Lua allocations after close");

	Dora::Love::LoveRuntime firstAudioRuntime;
	Dora::Love::LoveRuntime secondAudioRuntime;
	firstAudioRuntime.setFilesystemBackend(&audioFilesystem);
	secondAudioRuntime.setFilesystemBackend(&audioFilesystem);
	firstAudioRuntime.setAudioBackend(&audioBackend);
	secondAudioRuntime.setAudioBackend(&audioBackend);
	require(firstAudioRuntime.open(error) && secondAudioRuntime.open(error), error);
	require(firstAudioRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	require(secondAudioRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(firstAudioRuntime,
		"love.audio.setPosition(101, 102, 103); love.audio.setOrientation(1, 0, 0, 0, 0, 1); "
		"love.audio.setVelocity(7, 8, 9); love.audio.setDopplerScale(2.5); "
		"love.audio.setDistanceModel('exponent')",
		"@audio-global-listener-writer.lua");
	execute(secondAudioRuntime,
		"local x,y,z=love.audio.getPosition(); assert(x==101 and y==102 and z==103); "
		"local fx,fy,fz,ux,uy,uz=love.audio.getOrientation(); assert(fx==1 and fy==0 and fz==0 and ux==0 and uy==0 and uz==1); "
		"local vx,vy,vz=love.audio.getVelocity(); assert(vx==7 and vy==8 and vz==9); "
		"assert(love.audio.getDopplerScale()==2.5); assert(love.audio.getDistanceModel()=='exponent')",
		"@audio-global-listener-reader.lua");
	execute(secondAudioRuntime,
		"love.audio.setDopplerScale(0); assert(love.audio.getDopplerScale()==0); "
		"love.audio.setDopplerScale(-1); assert(love.audio.getDopplerScale()==0); "
		"love.audio.setDopplerScale(0/0); assert(love.audio.getDopplerScale()==0)",
		"@audio-global-doppler-validation.lua");
	execute(secondAudioRuntime,
		"local models={'none','inverse','inverseclamped','linear','linearclamped','exponent','exponentclamped'}; "
		"for _,model in ipairs(models) do love.audio.setDistanceModel(model); assert(love.audio.getDistanceModel()==model) end; "
		"local ok,message=pcall(love.audio.setDistanceModel,'invalid'); assert(not ok and message:find('inverseclamped',1,true))",
		"@audio-global-distance-model-validation.lua");
	execute(firstAudioRuntime, "owned = love.audio.newSource('pig.png'); assert(owned:play())", "@audio-owner-first.lua");
	execute(secondAudioRuntime, "owned = love.audio.newSource('pig.png'); assert(owned:play())", "@audio-owner-second.lua");
	require(audioBackend.sources.size() == 2, "two Love states did not retain independent audio sources");
	firstAudioRuntime.close();
	require(audioBackend.sources.size() == 1, "closing one Love state released another state's audio source");
	execute(secondAudioRuntime, "assert(owned:isPlaying()); owned:pause(); assert(owned:isPaused())",
		"@verify-audio-owner-second.lua");
	secondAudioRuntime.close();
	require(audioBackend.sources.empty(), "second Love state retained its audio source after close");

	MockAudio firstEffectsBackend;
	MockAudio secondEffectsBackend;
	Dora::Love::LoveRuntime firstEffectsRuntime;
	Dora::Love::LoveRuntime secondEffectsRuntime;
	firstEffectsRuntime.setFilesystemBackend(&audioFilesystem);
	secondEffectsRuntime.setFilesystemBackend(&audioFilesystem);
	firstEffectsRuntime.setAudioBackend(&firstEffectsBackend);
	secondEffectsRuntime.setAudioBackend(&secondEffectsBackend);
	require(firstEffectsRuntime.open(error) && secondEffectsRuntime.open(error), error);
	require(firstEffectsRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	require(secondEffectsRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(firstEffectsRuntime,
		"assert(love.audio.setEffect('shared',{type='echo',delay=0.1})); owned=love.audio.newSource('pig.png'); assert(owned:setEffect('shared'))",
		"@audio-effects-owner-first.lua");
	execute(secondEffectsRuntime,
		"assert(love.audio.getEffect('shared')==nil); assert(love.audio.setEffect('shared',{type='echo',delay=0.8})); owned=love.audio.newSource('pig.png'); assert(owned:setEffect('shared')); assert(math.abs(love.audio.getEffect('shared').delay-0.8)<0.00001)",
		"@audio-effects-owner-second.lua");
	firstEffectsRuntime.close();
	require(firstEffectsBackend.effects.empty() && firstEffectsBackend.sources.empty(),
		"closing one Love state retained its effect resources");
	execute(secondEffectsRuntime,
		"assert(math.abs(love.audio.getEffect('shared').delay-0.8)<0.00001 and select(1,owned:getEffect('shared')))",
		"@audio-effects-isolation-second.lua");
	secondEffectsRuntime.close();
	require(secondEffectsBackend.effects.empty() && secondEffectsBackend.sources.empty(),
		"second Love state retained its effect resources");

	audioBackend.deviceAvailable = false;
	Dora::Love::LoveRuntime unavailableAudioRuntime;
	unavailableAudioRuntime.setFilesystemBackend(&audioFilesystem);
	unavailableAudioRuntime.setAudioBackend(&audioBackend);
	require(unavailableAudioRuntime.open(error), error);
	require(unavailableAudioRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(unavailableAudioRuntime,
		"local source = love.audio.newSource('pig.png', 'static')\n"
		"assert(not source:play() and not source:isPlaying() and not source:isPaused())\n"
		"assert(not love.audio.play(source))\n"
		"source:pause(); source:stop(); love.audio.pause(); love.audio.stop()\n",
		"@audio-device-unavailable.lua");
	unavailableAudioRuntime.close();
	require(audioBackend.sources.empty(), "device-unavailable state retained its audio source after close");
	audioBackend.deviceAvailable = true;

	audioBackend.sourceCreationAvailable = false;
	Dora::Love::LoveRuntime unavailableDecoderRuntime;
	unavailableDecoderRuntime.setFilesystemBackend(&audioFilesystem);
	unavailableDecoderRuntime.setAudioBackend(&audioBackend);
	require(unavailableDecoderRuntime.open(error), error);
	require(unavailableDecoderRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(unavailableDecoderRuntime,
		"local ok, message = pcall(love.audio.newSource, 'pig.png', 'static')\n"
		"assert(not ok and message:find('source creation unavailable', 1, true))\n",
		"@audio-decoder-unavailable.lua");
	unavailableDecoderRuntime.close();
	require(audioBackend.sources.empty(), "source-creation failure retained a backend resource");
	audioBackend.sourceCreationAvailable = true;

	audioBackend.cloneCreationAvailable = false;
	Dora::Love::LoveRuntime unavailableCloneRuntime;
	unavailableCloneRuntime.setFilesystemBackend(&audioFilesystem);
	unavailableCloneRuntime.setAudioBackend(&audioBackend);
	require(unavailableCloneRuntime.open(error), error);
	require(unavailableCloneRuntime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
	execute(unavailableCloneRuntime,
		"local source=love.audio.newSource('pig.png','static'); local ok,message=pcall(source.clone,source)\n"
		"assert(not ok and message:find('clone unavailable',1,true))\n",
		"@audio-clone-unavailable.lua");
	unavailableCloneRuntime.close();
	require(audioBackend.sources.empty(), "Source clone failure retained a backend resource");
	audioBackend.cloneCreationAvailable = true;

	MockGraphics graphics;
	MockGraphics stateRestoreGraphics;
	Dora::Love::LoveRuntime stateRestoreRuntime;
	stateRestoreRuntime.setGraphicsBackend(&stateRestoreGraphics);
	require(stateRestoreRuntime.open(error), error);
	const std::array stateRestoreBaseline = {
		stateRestoreGraphics.blendChanges,
		stateRestoreGraphics.scissorChanges,
		stateRestoreGraphics.colorMaskChanges,
		stateRestoreGraphics.depthModeChanges,
		stateRestoreGraphics.meshCullChanges,
		stateRestoreGraphics.wireframeChanges,
		stateRestoreGraphics.stencilTestChanges,
	};
	execute(stateRestoreRuntime,
		"local graphics = require('love.graphics')\n"
		"graphics.push('all'); graphics.pop()\n",
		"@graphics-noop-state-restore.lua");
	require(stateRestoreGraphics.blendChanges == stateRestoreBaseline[0]
		&& stateRestoreGraphics.scissorChanges == stateRestoreBaseline[1]
		&& stateRestoreGraphics.colorMaskChanges == stateRestoreBaseline[2]
		&& stateRestoreGraphics.depthModeChanges == stateRestoreBaseline[3]
		&& stateRestoreGraphics.meshCullChanges == stateRestoreBaseline[4]
		&& stateRestoreGraphics.wireframeChanges == stateRestoreBaseline[5]
		&& stateRestoreGraphics.stencilTestChanges == stateRestoreBaseline[6],
		"unchanged push('all')/pop redundantly restored graphics backend state");
	execute(stateRestoreRuntime,
		"local graphics = require('love.graphics')\n"
		"graphics.push('all')\n"
		"graphics.setColorMask(false, true, false, true)\n"
		"graphics.pop()\n",
		"@graphics-selective-state-restore.lua");
	require(stateRestoreGraphics.colorMaskChanges == stateRestoreBaseline[2] + 2
		&& stateRestoreGraphics.blendChanges == stateRestoreBaseline[0]
		&& stateRestoreGraphics.scissorChanges == stateRestoreBaseline[1]
		&& stateRestoreGraphics.depthModeChanges == stateRestoreBaseline[3]
		&& stateRestoreGraphics.meshCullChanges == stateRestoreBaseline[4]
		&& stateRestoreGraphics.wireframeChanges == stateRestoreBaseline[5]
		&& stateRestoreGraphics.stencilTestChanges == stateRestoreBaseline[6],
		"push('all')/pop did not restore only the changed graphics backend state");
	stateRestoreRuntime.close();
	require(stateRestoreRuntime.getAllocationBytes() == 0,
		"graphics state restore test retained Lua allocations");

	TestFilesystemBackend imageDataFilesystem;
	const fs::path imageDataSaveBase = fs::temp_directory_path()
		/ ("dora-love-imagedata-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	Dora::Love::LoveRuntime graphical;
	graphical.setGraphicsBackend(&graphics);
	graphical.setImageBackend(&graphics);
	graphical.setFilesystemBackend(&imageDataFilesystem);
	require(graphical.open(error), error);
	require(graphical.setSaveBaseRoot(imageDataSaveBase.string(), error), error);
	require(graphical.boot(
		"local graphics = require('love.graphics')\n"
		"local imageModule = require('love.image')\n"
		"local filesystem = require('love.filesystem')\n"
		"filesystem.setIdentity('image-data')\n"
		"local blank = imageModule.newImageData(2, 2); assert(blank:getFormat() == 'rgba8' and blank:getSize() == 16)\n"
		"local nativeFormats = {r8=1,rg8=2,rgba8=4,r16=2,rg16=4,rgba16=8,r16f=2,rg16f=4,rgba16f=8,r32f=4,rg32f=8,rgba32f=16,rgba4=2,rgb5a1=2,rgb565=2,rgb10a2=4,rg11b10f=4}\n"
		"for format, bytes in pairs(nativeFormats) do local data=imageModule.newImageData(2,1,format); assert(data:getFormat()==format and data:getSize()==bytes*2 and #data:getString()==bytes*2); data:setPixel(0,0,0.25,0.5,0.75,0.6); local r,g,b,a=data:getPixel(0,0); assert(math.abs(r-0.25)<0.08 and r==r and g==g and b==b and a==a); local copy=data:clone(); assert(copy:getFormat()==format and copy:getString()==data:getString()) end\n"
		"local wide=imageModule.newImageData(1,1,'rgba16f'); wide:setPixel(0,0,0.25,0.5,0.75,1); local narrow=imageModule.newImageData(1,1,'rgba8'); narrow:paste(wide,0,0); local wr,wg,wb,wa=narrow:getPixel(0,0); assert(math.abs(wr-0.25)<0.01 and math.abs(wg-0.5)<0.01 and math.abs(wb-0.75)<0.01 and wa==1); assert(not pcall(narrow.paste,narrow,imageModule.newImageData(1,1,'r8'),0,0))\n"
		"assert(blank:type() == 'ImageData' and blank:typeOf('ImageData') and blank:typeOf('Data') and blank:typeOf('Object') and not blank:typeOf('Texture'))\n"
		"local bw, bh = blank:getDimensions(); assert(bw == 2 and bh == 2 and blank:getWidth() == 2 and blank:getHeight() == 2)\n"
		"blank:setPixel(1, 0, 1, 0.5, 0, 1); local pr, pg, pb, pa = blank:getPixel(1, 0)\n"
		"assert(pr == 1 and math.abs(pg - 128 / 255) < 0.0001 and pb == 0 and pa == 1)\n"
		"local clone = blank:clone(); clone:setPixel(1, 0, 0, 0, 1, 1); pr, pg, pb, pa = blank:getPixel(1, 0); assert(pr == 1 and pb == 0)\n"
		"assert(#blank:getString() == 16 and blank:getPointer() ~= nil and blank:getFFIPointer() == nil)\n"
		"assert(not pcall(blank.getPixel, blank, -1, 0)); assert(not pcall(blank.setPixel, blank, 2, 0, 1, 1, 1, 1))\n"
		"blank:mapPixel(function(x, y, r, g, b, a) return x / 2, y / 2, 0.25, a end, 0, 1, 2, 1)\n"
		"pr, pg, pb, pa = blank:getPixel(1, 1); assert(math.abs(pr - 128 / 255) < 0.0001 and math.abs(pg - 128 / 255) < 0.0001 and math.abs(pb - 64 / 255) < 0.0001 and pa == 0)\n"
		"assert(not pcall(blank.mapPixel, blank, function() return 0, 0, 0, 0 end, 1, 1, 2, 1))\n"
		"assert(not pcall(blank.mapPixel, blank, function() return 0/0, 0, 0, 0 end))\n"
		"local pasteSource = imageModule.newImageData(3, 2)\n"
		"pasteSource:setPixel(0, 0, 1, 0, 0); pasteSource:setPixel(1, 0, 0, 1, 0); pasteSource:setPixel(2, 0, 0, 0, 1)\n"
		"local pasted = imageModule.newImageData(2, 2); pasted:paste(pasteSource, -1, 0, 0, 0, 3, 2)\n"
		"pr, pg, pb = pasted:getPixel(0, 0); assert(pr == 0 and pg == 1 and pb == 0)\n"
		"pr, pg, pb = pasted:getPixel(1, 0); assert(pr == 0 and pg == 0 and pb == 1)\n"
		"pasteSource:paste(pasteSource, 1, 0, 0, 0, 2, 1); pr, pg, pb = pasteSource:getPixel(1, 0); assert(pr == 1 and pg == 0 and pb == 0)\n"
		"pr, pg, pb = pasteSource:getPixel(2, 0); assert(pr == 0 and pg == 1 and pb == 0)\n"
		"assert(not pcall(pasted.paste, pasted, pasteSource, math.maxinteger, 0))\n"
		"local memoryPng = blank:encode('png'); assert(memoryPng:getFilename() == 'Image.png' and memoryPng:getExtension() == 'png' and memoryPng:getString() == 'encoded-png')\n"
		"local savedPng = blank:encode('png', 'roundtrip.png'); assert(savedPng:getFilename() == 'roundtrip.png' and savedPng:getString() == 'encoded-png')\n"
		"local memoryTga = blank:encode('tga'); assert(memoryTga:getFilename() == 'Image.tga' and memoryTga:getExtension() == 'tga' and memoryTga:getString() == 'encoded-tga')\n"
		"local savedTga = blank:encode('tga', 'roundtrip.tga'); assert(savedTga:getFilename() == 'roundtrip.tga' and savedTga:getString() == 'encoded-tga')\n"
		"assert(not pcall(blank.encode, blank, 'bmp')); assert(not pcall(blank.encode, blank, 'png', '../escape.png'))\n"
		"assert(not pcall(imageModule.newImageData, 0, 1)); assert(not pcall(imageModule.newImageData, 1, 1, 'srgba8'))\n"
		"assert(not pcall(imageModule.newImageData, 1, 1, 'r8', 'bad'))\n"
		"assert(not pcall(imageModule.newImageData, 1, 1, 'rgba8', 'bad'))\n"
		"local raw = imageModule.newImageData(1, 1, 'rgba8', string.char(1, 2, 3, 4)); assert(raw:getSize() == 4)\n"
		"local fontModule = require('love.font'); assert(fontModule == love.font)\n"
		"local atlas = imageModule.newImageData(8, 2); atlas:mapPixel(function() return 1, 0, 0, 1 end)\n"
		"for y = 0, 1 do for x = 1, 2 do atlas:setPixel(x, y, 1, 1, 1, 1) end; for x = 4, 6 do atlas:setPixel(x, y, 0, 1, 0, 1) end end\n"
		"local raster = fontModule.newImageRasterizer(atlas, 'A猫', 2, 1.5)\n"
		"assert(raster:type() == 'Rasterizer' and raster:typeOf('Rasterizer') and raster:typeOf('Object') and not raster:typeOf('Data'))\n"
		"assert(raster:getHeight() == 2 and raster:getLineHeight() == 2 and raster:getAdvance() == 0 and raster:getAscent() == 0 and raster:getDescent() == 0)\n"
		"assert(raster:getGlyphCount() == 2 and raster:hasGlyphs('A猫') and raster:hasGlyphs(65, '猫') and not raster:hasGlyphs('B'))\n"
		"local glyph = raster:getGlyphData('A'); local gw, gh = glyph:getDimensions(); assert(gw == 2 and gh == 2 and glyph:getAdvance() == 4)\n"
		"assert(glyph:type() == 'GlyphData' and glyph:typeOf('GlyphData') and glyph:typeOf('Data') and glyph:typeOf('Object'))\n"
		"assert(glyph:getGlyph() == 65 and glyph:getGlyphString() == 'A' and glyph:getFormat() == 'rgba8' and glyph:getSize() == 16 and #glyph:getString() == 16)\n"
		"local bx, by = glyph:getBearing(); assert(bx == 0 and by == 0); local minx, miny, bbw, bbh = glyph:getBoundingBox(); assert(minx == 0 and miny == 2 and bbw == 2 and bbh == -2)\n"
		"assert(glyph:getPointer() ~= nil and glyph:getFFIPointer() == nil and love.data.newByteData(glyph):getString() == glyph:getString())\n"
		"local glyphClone = glyph:clone(); assert(glyphClone ~= glyph and glyphClone:getString() == glyph:getString())\n"
		"atlas:setPixel(1, 0, 1, 0, 0, 1); atlas = nil; collectgarbage('collect')\n"
		"local changed = raster:getGlyphData(65); local c1, c2, c3, c4 = string.byte(changed:getString(), 1, 4); assert(c1 == 0 and c2 == 0 and c3 == 0 and c4 == 0)\n"
		"local cat = fontModule.newGlyphData(raster, 0x732b); assert(cat:getGlyphString() == '猫' and cat:getWidth() == 3 and cat:getAdvance() == 5)\n"
		"local missing = fontModule.newGlyphData(raster, 'B'); assert(missing:getWidth() == 0 and missing:getHeight() == 2 and missing:getAdvance() == 0 and missing:getSize() == 0)\n"
		"assert(not pcall(fontModule.newImageRasterizer, raw, '') and not pcall(fontModule.newImageRasterizer, raw, 'A', 0, 0))\n"
		"assert(not pcall(fontModule.newImageRasterizer, raw, string.char(255)) and not pcall(raster.getGlyphData, raster, ''))\n"
		"local bmAtlas = imageModule.newImageData(6, 2); bmAtlas:mapPixel(function() return 0, 0, 0, 0 end)\n"
		"for y = 0, 1 do for x = 0, 1 do bmAtlas:setPixel(x, y, 1, 0, 0, 1) end; for x = 2, 4 do bmAtlas:setPixel(x, y, 0, 1, 0, 1) end end\n"
		"local bmText = 'info face=\"Fixture\" size=16 unicode=1\\ncommon lineHeight=3 base=2 pages=1\\npage id=0 file=\"ignored.png\"\\nchars count=2\\nchar id=65 x=0 y=0 width=2 height=2 xoffset=1 yoffset=1 xadvance=3 page=0\\nchar id=29483 x=2 y=0 width=3 height=2 xoffset=0 yoffset=0 xadvance=4 page=0\\n'\n"
		"local bmFile = filesystem.newFileData(bmText, 'fonts/fixture.fnt')\n"
		"local bm = fontModule.newBMFontRasterizer(bmFile, bmAtlas, 1.5)\n"
		"assert(bm:typeOf('Rasterizer') and bm:getHeight() == 3 and bm:getLineHeight() == 3 and bm:getAscent() == 2 and bm:getDescent() == 0 and bm:getAdvance() == 0)\n"
		"assert(bm:getGlyphCount() == 2 and bm:hasGlyphs('A猫') and not bm:hasGlyphs('B'))\n"
		"local bmA = bm:getGlyphData('A'); assert(bmA:getFormat() == 'rgba8' and bmA:getWidth() == 2 and bmA:getHeight() == 2 and bmA:getAdvance() == 3 and bmA:getSize() == 16)\n"
		"bx, by = bmA:getBearing(); assert(bx == 1 and by == -1); minx, miny, bbw, bbh = bmA:getBoundingBox(); assert(minx == 1 and miny == 3 and bbw == 2 and bbh == -4)\n"
		"c1, c2, c3, c4 = string.byte(bmA:getString(), 1, 4); assert(c1 == 255 and c2 == 0 and c3 == 0 and c4 == 255)\n"
		"bmAtlas:setPixel(0, 0, 0, 0, 1, 1); bmAtlas = nil; collectgarbage('collect'); bmA = bm:getGlyphData(65)\n"
		"c1, c2, c3, c4 = string.byte(bmA:getString(), 1, 4); assert(c1 == 0 and c2 == 0 and c3 == 255 and c4 == 255)\n"
		"local bmMissing = bm:getGlyphData('B'); assert(bmMissing:getWidth() == 0 and bmMissing:getHeight() == 0 and bmMissing:getSize() == 0)\n"
		"local bmAtlas2 = imageModule.newImageData(6, 2); local bmTable = fontModule.newBMFontRasterizer(bmFile, {bmAtlas2}); assert(bmTable:getGlyphCount() == 2)\n"
		"local bmPage0 = imageModule.newImageData(1, 1); bmPage0:setPixel(0, 0, 1, 0, 0, 1)\n"
		"local bmPage1 = imageModule.newImageData(1, 1); bmPage1:setPixel(0, 0, 0, 1, 0, 1)\n"
		"local bmMultiText = 'info unicode=1\\ncommon lineHeight=1 base=1 pages=2\\npage id=0 file=\"zero.png\"\\npage id=1 file=\"one.png\"\\nchars count=2\\nchar id=65 x=0 y=0 width=1 height=1 xadvance=1 page=0\\nchar id=66 x=0 y=0 width=1 height=1 xadvance=1 page=1\\n'\n"
		"local bmMulti = fontModule.newBMFontRasterizer(filesystem.newFileData(bmMultiText, 'fonts/multi.fnt'), {bmPage0, bmPage1})\n"
		"assert(bmMulti:getGlyphCount() == 2 and bmMulti:hasGlyphs('AB')); c1, c2, c3, c4 = string.byte(bmMulti:getGlyphData('B'):getString(), 1, 4); assert(c1 == 0 and c2 == 255 and c3 == 0 and c4 == 255)\n"
		"bmFont = graphics.newFont(bm); assert(bmFont:typeOf('Font') and bmFont:getWidth('A猫') == 5 and bmFont:getHeight() == 2 and bmFont:getBaseline() > 1)\n"
		"bmMultiFont = graphics.newFont(bmMulti); assert(bmMultiFont:hasGlyphs('AB') and bmMultiFont:getWidth('AB') == 2)\n"
		"local bmGeneric = fontModule.newRasterizer(bmFile, {bmAtlas2}, 1); assert(bmGeneric:hasGlyphs('A猫'))\n"
		"assert(filesystem.createDirectory('pagefont') and filesystem.write('pagefont/fixture.png', 'encoded-image'))\n"
		"local autoText = 'info size=12 unicode=1\\ncommon lineHeight=1 base=1\\npage id=0 file=\"fixture.png\"\\nchar id=65 x=0 y=0 width=1 height=1 xadvance=1 page=0\\n'\n"
		"assert(filesystem.write('pagefont/auto.fnt', autoText))\n"
		"local autoBM = fontModule.newBMFontRasterizer(filesystem.newFileData(autoText, 'pagefont/auto.fnt')); assert(autoBM:getGlyphData('A'):getSize() == 4)\n"
		"local autoGeneric = fontModule.newRasterizer(filesystem.newFileData(autoText, 'pagefont/auto.fnt')); assert(autoGeneric:hasGlyphs('A'))\n"
		"autoFont = graphics.newFont('pagefont/auto.fnt'); assert(autoFont:hasGlyphs('A') and autoFont:getWidth('A') == 1)\n"
		"assert(not pcall(fontModule.newBMFontRasterizer, filesystem.newFileData('info unicode=1', 'bad.fnt'), bmAtlas2))\n"
		"local badRect = bmText:gsub('width=2', 'width=20', 1); assert(not pcall(fontModule.newBMFontRasterizer, filesystem.newFileData(badRect, 'bad.fnt'), bmAtlas2))\n"
		"local badAscii = bmText:gsub('unicode=1', 'unicode=0', 1); assert(not pcall(fontModule.newBMFontRasterizer, filesystem.newFileData(badAscii, 'bad.fnt'), bmAtlas2))\n"
		"assert(not pcall(fontModule.newBMFontRasterizer, bmFile, bmAtlas2, 0))\n"
		"local encoded = filesystem.newFileData('encoded-image', 'fixture.png')\n"
		"local decoded = imageModule.newImageData(encoded); assert(decoded:getWidth() == 2 and decoded:getHeight() == 1)\n"
		"pr, pg, pb, pa = decoded:getPixel(1, 0); assert(pr == 0 and pg == 1 and pb == 0 and math.abs(pa - 128 / 255) < 0.0001)\n"
		"local imageFontAtlas = imageModule.newImageData(8, 2); imageFontAtlas:mapPixel(function() return 1, 0, 1, 1 end)\n"
		"for y=0,1 do for x=1,2 do imageFontAtlas:setPixel(x,y,1,0,0,1) end; for x=4,6 do imageFontAtlas:setPixel(x,y,0,1,0,1) end end\n"
		"local imageFont = graphics.newImageFont(imageFontAtlas, 'A猫', 2, 2); assert(imageFont:typeOf('Font'))\n"
		"assert(imageFont:getWidth('A猫') == 5 and imageFont:getHeight() == 1 and imageFont:getBaseline() == 0 and imageFont:getAscent() == 0 and imageFont:getDescent() == 0)\n"
		"assert(imageFont:hasGlyphs('A猫') and not imageFont:hasGlyphs('B') and imageFont:getKerning('A','猫') == 0)\n"
		"fallbackAtlas = imageModule.newImageData(3, 2); fallbackAtlas:mapPixel(function() return 1, 0, 1, 1 end); for y=0,1 do for x=1,2 do fallbackAtlas:setPixel(x,y,0,0,1,1) end end\n"
		"imageFallback = graphics.newImageFont(fallbackAtlas, 'B', 1, 1); imageFont:setFallbacks(imageFallback)\n"
		"assert(imageFont:hasGlyphs('A猫B') and imageFont:getWidth('A猫B') == 8 and imageFont:getKerning('猫','B') == 0)\n"
		"local imageRaster = fontModule.newImageRasterizer(imageFontAtlas, 'A猫', -1, 1); local rasterFont = graphics.newImageFont(imageRaster)\n"
		"assert(rasterFont:getWidth('A猫') == 3 and rasterFont:getHeight() == 2); assert(pcall(imageFont.setFallbacks, imageFont, rasterFont)); imageFont:setFallbacks(imageFallback)\n"
		"fileDataImageFont = graphics.newImageFont(encoded, 'A'); assert(fileDataImageFont:getWidth('A') == 1 and fileDataImageFont:getHeight() == 1)\n"
		"pathImageFont = graphics.newImageFont('pagefont/fixture.png', 'A'); assert(pathImageFont:getWidth('A') == 1 and pathImageFont:getHeight() == 1)\n"
		"nonRGBAFontAtlas = imageModule.newImageData(2, 1, 'r8'); assert(not pcall(graphics.newImageFont, nonRGBAFontAtlas, 'A') and not pcall(fontModule.newImageRasterizer, nonRGBAFontAtlas, 'A'))\n"
		"assert(not pcall(graphics.newImageFont, imageFontAtlas, '') and not pcall(graphics.newImageFont, imageFontAtlas, 'A', 0, 0))\n"
		"local compressedInput = filesystem.newFileData('compressed-image', 'fixture.dds')\n"
		"assert(imageModule.isCompressed(compressedInput) and not imageModule.isCompressed(encoded))\n"
		"local compressed = imageModule.newCompressedData(compressedInput)\n"
		"assert(compressed:type() == 'CompressedImageData' and compressed:typeOf('CompressedImageData') and compressed:typeOf('Data') and not compressed:typeOf('ImageData'))\n"
		"local cw, ch = compressed:getDimensions(); assert(cw == 4 and ch == 4 and compressed:getMipmapCount() == 2 and compressed:getFormat() == 'DXT1')\n"
		"cw, ch = compressed:getDimensions(2); assert(cw == 2 and ch == 2 and compressed:getWidth(2) == 2 and compressed:getHeight(2) == 2)\n"
		"assert(compressed:getSize() == 16 and #compressed:getString() == 16 and compressed:getPointer() ~= nil and compressed:getFFIPointer() == nil)\n"
		"local compressedClone = compressed:clone(); assert(compressedClone:getString() == compressed:getString())\n"
		"assert(love.data.newByteData(compressed):getSize() == 16 and love.data.newDataView(compressed, 8, 8):getSize() == 8)\n"
		"assert(not pcall(compressed.getWidth, compressed, 0) and not pcall(compressed.getHeight, compressed, 3))\n"
		"local compressedOk, compressedError = pcall(imageModule.newCompressedData, encoded); assert(not compressedOk and compressedError:find('mock compressed image parser rejected encoded data', 1, true))\n"
		"local badData = filesystem.newFileData('bad-image', 'broken.png'); local decodedOk, decodedError = pcall(imageModule.newImageData, badData)\n"
		"assert(not decodedOk and decodedError:find('mock image decoder rejected encoded data', 1, true))\n"
		"local image = graphics.newImage('fixture.png')\n"
		"fileImage = graphics.newImage(filesystem.newFileData('encoded-image', 'fixture@2x.png')); assert(fileImage:getPixelWidth() == 2 and fileImage:getWidth() == 1 and fileImage:getDPIScale() == 2)\n"
		"explicitFileImage = graphics.newImage(filesystem.newFileData('encoded-image', 'fixture@2x.png'), {linear = false, dpiscale = 4, mipmaps = false}); assert(explicitFileImage:getDPIScale() == 4 and not explicitFileImage:isFormatLinear())\n"
		"compressedFileImage = graphics.newImage(filesystem.newFileData('compressed-image', 'fixture.dds'), {mipmaps = true, linear = false}); assert(compressedFileImage:getMipmapCount() == 2 and compressedFileImage:isCompressed() and not compressedFileImage:isFormatLinear())\n"
		"autoFileImage = graphics.newImage(filesystem.newFileData('encoded-image', 'fixture.png'), {mipmaps = true}); assert(autoFileImage:getMipmapCount() == 2)\n"
		"local compressedBase = graphics.newImage(compressed)\n"
		"local cbw, cbh = compressedBase:getDimensions(); assert(cbw == 4 and cbh == 4 and compressedBase:getTextureType() == '2d')\n"
		"local compressedMipmapped = graphics.newImage(compressed, {mipmaps = true})\n"
		"local cmw, cmh = compressedMipmapped:getDimensions(); assert(cmw == 4 and cmh == 4)\n"
		"compressedArray = graphics.newArrayImage({compressed, compressed}, {mipmaps = true}); assert(compressedArray:isCompressed() and compressedArray:getLayerCount() == 2 and compressedArray:getMipmapCount() == 2, 'compressed array '..tostring(compressedArray:isCompressed())..' '..compressedArray:getLayerCount()..' '..compressedArray:getMipmapCount())\n"
		"compressedCube = graphics.newCubeImage({compressed,compressed,compressed,compressed,compressed,compressed}); assert(compressedCube:isCompressed() and compressedCube:getTextureType() == 'cube', 'compressed cube')\n"
		"compressedVolume = graphics.newVolumeImage(compressed, {mipmaps = true}); assert(compressedVolume:isCompressed() and compressedVolume:getTextureType() == 'volume' and compressedVolume:getMipmapCount() == 2, 'compressed volume')\n"
		"assert(not pcall(graphics.newImage, compressed, {mipmaps = 'yes'}))\n"
		"local layerA = imageModule.newImageData(2, 2); layerA:mapPixel(function() return 1, 0, 0, 1 end)\n"
		"local layerB = imageModule.newImageData(2, 2); layerB:mapPixel(function() return 0, 1, 0, 1 end)\n"
		"mipA = imageModule.newImageData(1, 1); mipA:setPixel(0, 0, 1, 0.5, 0, 1)\n"
		"mipB = imageModule.newImageData(1, 1); mipB:setPixel(0, 0, 0, 0.5, 1, 1)\n"
		"replacement = imageModule.newImageData(1, 1); replacement:setPixel(0, 0, 0, 0, 1, 1)\n"
		"replace2D = graphics.newImage(layerA); replace2D:replacePixels(replacement, 99, 1, 1, 0)\n"
		"auto2D = graphics.newImage(layerA, {mipmaps = true}); assert(auto2D:getMipmapCount() == 2 and auto2D:getPixelWidth(2) == 1)\n"
		"mip2D = graphics.newImage({layerA, mipA}, {linear = false, dpiscale = 2}); mw, mh = mip2D:getPixelDimensions(2); assert(mip2D:getMipmapCount() == 2 and mw == 1 and mh == 1 and not mip2D:isFormatLinear() and mip2D:getDPIScale() == 2, '2d mip chain')\n"
		"fileMip = graphics.newImage({filesystem.newFileData('encoded-image', 'fixture@2x.png'), mipA}); assert(fileMip:getMipmapCount() == 2 and fileMip:getDPIScale() == 2 and fileMip:getPixelWidth() == 2)\n"
		"partialMipBase = imageModule.newImageData(4, 4); assert(not pcall(graphics.newImage, {layerA, layerA}) and not pcall(graphics.newImage, {partialMipBase, layerA}) and not pcall(graphics.newImage, {}), 'invalid 2d mip chain')\n"
		"local arrayImage = graphics.newArrayImage({layerA, layerB}, {mipmaps = false})\n"
		"assert(arrayImage:getTextureType() == 'array' and arrayImage:getLayerCount() == 2 and arrayImage:getDepth() == 1)\n"
		"layeredFileImage = graphics.newArrayImage({filesystem.newFileData('encoded-image', 'slice@2x.png'), filesystem.newFileData('encoded-image', 'slice@2x.png')}); assert(layeredFileImage:getLayerCount() == 2 and layeredFileImage:getPixelWidth() == 2 and layeredFileImage:getDPIScale() == 2)\n"
		"mipArray = graphics.newArrayImage({{layerA, mipA}, {layerB, mipB}}, {mipmaps = true, linear = false, dpiscale = 3}); mw, mh = mipArray:getPixelDimensions(2); assert(mipArray:getMipmapCount() == 2 and mipArray:getLayerCount() == 2 and mw == 1 and mh == 1 and not mipArray:isFormatLinear() and mipArray:getDPIScale() == 3, 'array mip chain')\n"
		"arrayImage:replacePixels(replacement, 2, 1, 1, 0)\n"
		"graphics.drawLayer(arrayImage, 2, 3, 4); arrayQuad = graphics.newQuad(0, 0, 1, 2, 2, 2); graphics.drawLayer(arrayImage, 1, arrayQuad, 5, 6)\n"
		"arrayQuad:setLayer(2); graphics.draw(arrayImage, arrayQuad, 7, 8); assert(not pcall(graphics.drawLayer, arrayImage, 0) and not pcall(graphics.drawLayer, arrayImage, 3) and not pcall(graphics.drawLayer, image, 1))\n"
		"local cubeImage = graphics.newCubeImage({layerA, layerA, layerA, layerA, layerA, layerA})\n"
		"assert(cubeImage:getTextureType() == 'cube' and cubeImage:getLayerCount() == 1 and cubeImage:getDepth() == 1)\n"
		"mipCube = graphics.newCubeImage({{layerA,mipA},{layerA,mipA},{layerA,mipA},{layerA,mipA},{layerA,mipA},{layerA,mipA}}, {mipmaps = true}); assert(mipCube:getMipmapCount() == 2 and mipCube:getPixelWidth(2) == 1)\n"
		"cubeStrip = imageModule.newImageData(12, 2); autoCube = graphics.newCubeImage(cubeStrip, {mipmaps = true}); assert(autoCube:getTextureType() == 'cube' and autoCube:getMipmapCount() == 2 and autoCube:getPixelWidth() == 2)\n"
		"cubeImage:replacePixels(replacement, 6, 1, 0, 1)\n"
		"local volumeImage = graphics.newVolumeImage({layerA, layerB}); volumeImage:setWrap('repeat', 'clamp', 'mirroredrepeat')\n"
		"assert(volumeImage:getTextureType() == 'volume' and volumeImage:getDepth() == 2 and volumeImage:getLayerCount() == 1)\n"
		"mipVolume = graphics.newVolumeImage({{layerA, layerB}, {mipA}}, {mipmaps = true}); assert(mipVolume:getMipmapCount() == 2 and mipVolume:getDepth(2) == 1 and mipVolume:getPixelWidth(2) == 1)\n"
		"volumeStrip = imageModule.newImageData(4, 2); autoVolume = graphics.newVolumeImage(volumeStrip, {mipmaps = true}); assert(autoVolume:getTextureType() == 'volume' and autoVolume:getDepth() == 2 and autoVolume:getMipmapCount() == 2)\n"
		"volumeImage:replacePixels(replacement, 2, 1, 1, 1)\n"
		"assert(not pcall(volumeImage.replacePixels, volumeImage, replacement, 3, 1, 0, 0))\n"
		"assert(not pcall(volumeImage.replacePixels, volumeImage, replacement, 1, 1, 2, 0))\n"
		"assert(not pcall(compressedBase.replacePixels, compressedBase, replacement, 1, 1, 0, 0))\n"
		"assert(not pcall(graphics.newArrayImage, {})); autoArray = graphics.newArrayImage({layerA}, {mipmaps = true}); assert(autoArray:getMipmapCount() == 2 and autoArray:getLayerCount() == 1)\n"
		"assert(not pcall(graphics.newCubeImage, {layerA})); assert(not pcall(graphics.newVolumeImage, {layerA, imageModule.newImageData(1, 1)}))\n"
		"local quad = graphics.newQuad(4, 2, 12, 8, image)\n"
		"local qx, qy, qw, qh = quad:getViewport(); assert(qx == 4 and qy == 2 and qw == 12 and qh == 8)\n"
		"local qtw, qth = quad:getTextureDimensions(); assert(qtw == 32 and qth == 16, tostring(qtw) .. 'x' .. tostring(qth))\n"
		"assert(quad:getLayer() == 1); quad:setLayer(2); assert(quad:getLayer() == 2)\n"
		"local invalidLayer = pcall(graphics.draw, image, quad); assert(not invalidLayer); quad:setLayer(1)\n"
		"quad:setViewport(6, 4, 10, 6)\n"
		"local incompleteDimensions = pcall(quad.setViewport, quad, 0, 0, 8, 8, 32); assert(not incompleteDimensions)\n"
		"local numericQuad = graphics.newQuad(0, 0, 8, 8, 32, 16)\n"
		"qtw, qth = numericQuad:getTextureDimensions(); assert(qtw == 32 and qth == 16)\n"
		"local window = require('love.window')\n"
		"local invalidMultiply = pcall(graphics.setBlendMode, 'multiply')\n"
		"assert(not invalidMultiply)\n"
		"graphics.setBlendMode('subtract', 'premultiplied')\n"
		"assert(table.concat({graphics.getBlendMode()}, ':') == 'subtract:premultiplied')\n"
		"graphics.setBlendMode('alpha', 'alphamultiply')\n"
		"local ww, wh, flags = window.getMode(); assert(ww == 800 and wh == 600 and not flags.fullscreen and not flags.resizable and flags.display == 1 and not flags.highdpi)\n"
		"assert(window.getDPIScale() == 1 and window.getNativeDPIScale() == 1)\n"
		"local pw, ph = graphics.getPixelDimensions(); assert(pw == 800 and ph == 600)\n"
		"assert(graphics.getPixelWidth() == 800 and graphics.getPixelHeight() == 600 and graphics.getDPIScale() == 1)\n"
		"local supportedTarget={sentinel=true}; local supported=graphics.getSupported(supportedTarget); assert(supported==supportedTarget and supported.sentinel and supported.multicanvasformats and supported.clampzero and not supported.lighten and supported.fullnpot and supported.pixelshaderhighp and supported.shaderderivatives and supported.glsl3 and not supported.instancing)\n"
		"local typesTarget={sentinel=true}; local types=graphics.getTextureTypes(typesTarget); assert(types==typesTarget and types.sentinel and types['2d'] and types.array and types.cube and types.volume)\n"
		"local formatsTarget={sentinel=true}; local imageFormats=graphics.getImageFormats(formatsTarget); assert(imageFormats==formatsTarget and imageFormats.sentinel and imageFormats.r8 and imageFormats.rgba8 and imageFormats.DXT1 and not imageFormats.BC4 and imageFormats.normal==nil and imageFormats.srgba8==nil and imageFormats.depth24==nil)\n"
		"local rendererName,rendererVersion,rendererVendor,rendererDevice=graphics.getRendererInfo(); assert(rendererName=='Mock Renderer' and rendererVersion=='1.2.3' and rendererVendor=='Mock Vendor' and rendererDevice=='Mock Device')\n"
		"statsTarget={sentinel=true}; stats=graphics.getStats(statsTarget); assert(stats==statsTarget and stats.sentinel and stats.drawcalls==7 and stats.drawcallsbatched==3 and stats.canvasswitches==2 and stats.shaderswitches==4 and stats.canvases==5 and stats.images==6 and stats.fonts==8 and stats.texturememory==4096)\n"
		"assert(window.toPixels(12.5) == 12.5 and window.fromPixels(12.5) == 12.5)\n"
		"local px, py = window.toPixels(12.5, -4); assert(px == 12.5 and py == -4)\n"
		"local lx, ly = window.fromPixels(px, py); assert(lx == 12.5 and ly == -4)\n"
		"assert(window.toPixels(7, nil) == 7 and not pcall(window.toPixels, 'bad'))\n"
		"assert(window.setMode(640, 360, {resizable = true}))\n"
		"ww, wh, flags = window.getMode(); assert(ww == 640 and wh == 360 and flags.resizable)\n"
		"assert(window.updateMode({resizable = false})); ww, wh, flags = window.getMode(); assert(ww == 640 and wh == 360 and not flags.resizable)\n"
		"assert(window.updateMode(512, 288)); ww, wh, flags = window.getMode(); assert(ww == 512 and wh == 288 and not flags.resizable)\n"
		"assert(window.updateMode(640, 360, {resizable = true})); assert(not pcall(window.updateMode) and not pcall(window.updateMode, 'bad'))\n"
		"assert(not window.updateMode({fullscreen = true})); ww, wh, flags = window.getMode(); assert(ww == 640 and wh == 360 and flags.resizable)\n"
		"pw, ph = graphics.getPixelDimensions(); assert(pw == 640 and ph == 360)\n"
		"assert(not window.setMode(320, 200, {fullscreen = true})); assert(not window.setMode(320, 200, {highdpi = true}))\n"
		"assert(not window.setMode(320, 200, {display = 2})); assert(not pcall(window.setMode, 320, 200, {resizable = 'yes'}))\n"
		"ww, wh, flags = window.getMode(); assert(ww == 640 and wh == 360 and flags.resizable)\n"
		"assert(image:getWidth() == 32 and image:getHeight() == 16)\n"
		"local iw, ih = image:getDimensions(); assert(iw == 32 and ih == 16)\n"
		"local min, mag, anisotropy = image:getFilter(); assert(min == 'linear' and mag == 'linear' and anisotropy == 1)\n"
		"image:setFilter('nearest'); min, mag, anisotropy = image:getFilter(); assert(min == 'nearest' and mag == 'nearest' and anisotropy == 1)\n"
		"image:setFilter('nearest', 'linear'); assert(select(1, image:getFilter()) == 'nearest' and select(2, image:getFilter()) == 'linear')\n"
		"assert(not pcall(image.setFilter, image, 'invalid'))\n"
		"image:setFilter('linear', 'linear', 4); min, mag, anisotropy = image:getFilter(); assert(min == 'linear' and mag == 'linear' and anisotropy == 4)\n"
		"image:setFilter('linear', 'linear', 0); min, mag, anisotropy = image:getFilter(); assert(min == 'linear' and mag == 'linear' and anisotropy == 1); image:setFilter('linear', 'linear', 4)\n"
		"local wrapU, wrapV, wrapW = image:getWrap(); assert(wrapU == 'clamp' and wrapV == 'clamp' and wrapW == 'clamp')\n"
		"assert(image:setWrap('repeat', 'mirroredrepeat', 'clampzero'))\n"
		"wrapU, wrapV, wrapW = image:getWrap(); assert(wrapU == 'repeat' and wrapV == 'mirroredrepeat' and wrapW == 'clampzero')\n"
		"assert(not pcall(image.setWrap, image, 'invalid'))\n"
		"local defaultFont = graphics.getFont(); assert(defaultFont:getHeight() == 12); assert(not pcall(imageFont.setFallbacks, imageFont, defaultFont))\n"
		"local font = graphics.newFont(24.9); graphics.setFont(font); assert(graphics.getFont():getWidth('abcd') == 48)\n"
		"assert(font:getHeight() == 24 and math.abs(font:getBaseline() - 19.2) < 0.001)\n"
		"assert(math.abs(font:getAscent() - 19.2) < 0.001 and math.abs(font:getDescent() + 4.8) < 0.001)\n"
		"assert(font:hasGlyphs('AV', 65) and not font:hasGlyphs(0x10ffff))\n"
		"assert(math.abs(font:getKerning('A', 'V') + 1.5) < 0.001 and math.abs(font:getKerning(65, 86) + 1.5) < 0.001)\n"
		"font:setFallbacks(defaultFont); assert(not pcall(font.hasGlyphs, font, string.char(0xff)))\n"
		"assert(font:getLineHeight() == 1); font:setLineHeight(1.5); assert(font:getLineHeight() == 1.5)\n"
		"assert(not pcall(font.setLineHeight, font, 0)); assert(not pcall(font.setLineHeight, font, 0/0))\n"
		"local wrappedWidth, wrappedLines = font:getWrap('hello world', 100)\n"
		"assert(wrappedWidth == 60 and #wrappedLines == 2 and wrappedLines[1] == 'hello')\n"
		"assert(graphics.getCanvas() == nil)\n"
		"local canvasFormats = graphics.getCanvasFormats(); assert(canvasFormats.rgba8 and canvasFormats.hdr and canvasFormats.depth24 and canvasFormats.depth24stencil8 and not canvasFormats.depth32fstencil8 and not canvasFormats.la8)\n"
		"local suppliedFormats = {sentinel = true}; assert(graphics.getCanvasFormats(false, suppliedFormats) == suppliedFormats and suppliedFormats.r8 and suppliedFormats.sentinel)\n"
		"graphics.setDefaultFilter('linear', 'linear', 0); dfmin, dfmag, dfanisotropy = graphics.getDefaultFilter(); assert(dfmin == 'linear' and dfmag == 'linear' and dfanisotropy == 1)\n"
		"local canvas = graphics.newCanvas(128.9, 64.9, {dpiscale = 1, msaa = 0, format = 'rgba8', type = '2d', readable = true, mipmaps = 'none'})\n"
		"mipCanvas = graphics.newCanvas(8, 4, {dpiscale = 2, mipmaps = 'manual'}); assert(mipCanvas:getPixelWidth() == 8 and mipCanvas:getWidth() == 4 and mipCanvas:getHeight() == 2 and mipCanvas:getMipmapCount() == 4 and mipCanvas:getMipmapMode() == 'manual', 'mip Canvas metadata')\n"
		"arrayCanvas = graphics.newCanvas(8, 4, 3, {type = 'array', mipmaps = 'auto'}); assert(arrayCanvas:getTextureType() == 'array' and arrayCanvas:getLayerCount() == 3 and arrayCanvas:getMipmapCount() == 4 and arrayCanvas:getMipmapMode() == 'auto', 'array Canvas metadata')\n"
		"cubeCanvas = graphics.newCanvas(4, 4, {type = 'cube', mipmaps = 'manual'}); assert(cubeCanvas:getTextureType() == 'cube' and cubeCanvas:getMipmapCount() == 3, 'cube Canvas metadata')\n"
		"volumeCanvas = graphics.newCanvas(8, 4, 4, {type = 'volume', mipmaps = 'manual'}); assert(volumeCanvas:getTextureType() == 'volume' and volumeCanvas:getDepth() == 4 and volumeCanvas:getDepth(2) == 2 and volumeCanvas:getMipmapCount() == 4, 'volume Canvas metadata')\n"
		"mipCanvas:generateMipmaps(); arrayCanvas:generateMipmaps(); cubeCanvas:generateMipmaps(); volumeCanvas:generateMipmaps()\n"
		"assert(not pcall(canvas.generateMipmaps, canvas))\n"
		"mipPixels=mipCanvas:newImageData(1,2,1,0,2,1); mpw,mph=mipPixels:getDimensions(); assert(mpw==2 and mph==1)\n"
		"arrayPixels=arrayCanvas:newImageData(3,2,0,0,1,1); apw,aph=arrayPixels:getDimensions(); assert(apw==1 and aph==1)\n"
		"cubePixels=cubeCanvas:newImageData(6,3); cpw2,cph2=cubePixels:getDimensions(); assert(cpw2==1 and cph2==1)\n"
		"volumePixels=volumeCanvas:newImageData(2,2,0,0,1,1); vpw,vph=volumePixels:getDimensions(); assert(vpw==1 and vph==1)\n"
		"assert(not pcall(arrayCanvas.newImageData, arrayCanvas, 4, 1) and not pcall(cubeCanvas.newImageData, cubeCanvas, 7, 1) and not pcall(volumeCanvas.newImageData, volumeCanvas, 2, 3) and not pcall(mipCanvas.newImageData, mipCanvas, 1, 5))\n"
		"graphics.setCanvas({{arrayCanvas, layer = 2, mipmap = 2}}); targetInfo = graphics.getCanvas(); assert(targetInfo[1][1] == arrayCanvas and targetInfo[1].layer == 2 and targetInfo[1].mipmap == 2)\n"
		"graphics.setCanvas(mipCanvas, 2); targetInfo = graphics.getCanvas(); assert(targetInfo[1][1] == mipCanvas and targetInfo[1].mipmap == 2)\n"
		"graphics.setCanvas(cubeCanvas, 3, 2); targetInfo = graphics.getCanvas(); assert(targetInfo[1][1] == cubeCanvas and targetInfo[1].face == 3 and targetInfo[1].mipmap == 2)\n"
		"graphics.setCanvas({{volumeCanvas, layer = 2, mipmap = 2}}); targetInfo = graphics.getCanvas(); assert(targetInfo[1][1] == volumeCanvas and targetInfo[1].layer == 2)\n"
		"assert(not pcall(graphics.setCanvas, arrayCanvas) and not pcall(graphics.setCanvas, arrayCanvas, 4) and not pcall(graphics.setCanvas, mipCanvas, 5)); graphics.setCanvas(); graphics.drawLayer(arrayCanvas, 2); assert(not pcall(graphics.draw, arrayCanvas))\n"
		"local canvas2 = graphics.newCanvas(128, 64)\n"
		"local mismatchedCanvas = graphics.newCanvas(64, 64)\n"
		"local hdrCanvas = graphics.newCanvas(128, 64, {format = 'hdr', msaa = 4})\n"
		"local writeOnlyCanvas = graphics.newCanvas(128, 64, {format = 'r8', readable = false})\n"
		"depthStencilCanvas = graphics.newCanvas(128, 64, {format = 'depth24stencil8', readable = false})\n"
		"depthOnlyCanvas = graphics.newCanvas(128, 64, {format = 'depth24', readable = false})\n"
		"mismatchedDepthCanvas = graphics.newCanvas(64, 64, {format = 'depth24stencil8', readable = false})\n"
		"local cw, ch = canvas:getDimensions(); assert(cw == 128 and ch == 64)\n"
		"local cpw, cph = canvas:getPixelDimensions(); assert(cpw == 128 and cph == 64 and canvas:getDPIScale() == 1)\n"
		"assert(canvas:getFormat() == 'rgba8' and canvas:getMSAA() == 0 and canvas:isReadable())\n"
		"assert(hdrCanvas:getFormat() == 'rgba16f' and hdrCanvas:getMSAA() == 4 and hdrCanvas:isReadable())\n"
		"assert(writeOnlyCanvas:getFormat() == 'r8' and writeOnlyCanvas:getMSAA() == 0 and not writeOnlyCanvas:isReadable())\n"
		"assert(depthStencilCanvas:getFormat() == 'depth24stencil8' and not depthStencilCanvas:isReadable())\n"
		"assert(depthOnlyCanvas:getFormat() == 'depth24' and not pcall(depthOnlyCanvas.newImageData, depthOnlyCanvas))\n"
		"local canvasPixels = canvas:newImageData(1, 1, 3, 4, 2, 1)\n"
		"assert(canvasPixels:getWidth() == 2 and canvasPixels:getHeight() == 1 and canvasPixels:getFormat() == 'rgba8')\n"
		"local pr, pg, pb, pa = canvasPixels:getPixel(0, 0); assert(math.abs(pr - 3/255) < 0.001 and math.abs(pg - 4/255) < 0.001 and math.abs(pb - 128/255) < 0.001 and pa == 1)\n"
		"local hdrPixels = hdrCanvas:newImageData(1, 1, 0, 0, 2, 1); assert(hdrPixels:getFormat() == 'rgba16f' and hdrPixels:getSize() == 16)\n"
		"assert(not pcall(writeOnlyCanvas.newImageData, writeOnlyCanvas)); assert(not pcall(canvas.newImageData, canvas, 2))\n"
		"assert(not pcall(graphics.newCanvas, 16, 16, {msaa = 3}))\n"
		"assert(not pcall(graphics.newCanvas, 16, 16, {format = 'la8'}))\n"
		"assert(not pcall(graphics.newCanvas, 16, 16, {readable = 'yes'}))\n"
		"canvas:setFilter('nearest'); local cmin, cmag, caniso = canvas:getFilter(); assert(cmin == 'nearest' and cmag == 'nearest' and caniso == 1)\n"
		"assert(canvas:setWrap('repeat', 'clampzero')); local cu, cv = canvas:getWrap(); assert(cu == 'repeat' and cv == 'clampzero')\n"
		"local canvasQuad = graphics.newQuad(4, 2, 24, 12, canvas)\n"
		"local mesh = graphics.newMesh({{0,0,0,0,1,0,0,1},{20,0,1,0,0,1,0,1},{0,20,0,1,0,0,1,1}}, 'triangles', 'dynamic')\n"
		"assert(mesh:getVertexCount() == 3 and mesh:getDrawMode() == 'triangles')\n"
		"local vx, vy, vu, vv, vr = mesh:getVertex(1); assert(vx == 0 and vy == 0 and vu == 0 and vv == 0 and vr == 1)\n"
		"mesh:setVertex(2, 24, 0, 1, 0, 0, 1, 0, 1); mesh:setVertices({{0,24,0,1,0,0,1,1}}, 3, 1)\n"
		"mesh:setVertexMap(1, 2, 3); local vertexMap = mesh:getVertexMap(); assert(#vertexMap == 3 and vertexMap[2] == 2)\n"
		"mesh:setDrawRange(1, 3); local rangeStart, rangeCount = mesh:getDrawRange(); assert(rangeStart == 1 and rangeCount == 3)\n"
		"mesh:setTexture(image); assert(mesh:getTexture() == image); mesh:flush()\n"
		"local custom = graphics.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','byte',4},{'Extra','float',1}}, {{4,5,0.2,0,0,1,1,1,1,9},{28,5,0.2,1,0,1,0,0,1,8},{4,29,0.2,0,1,0,1,0,1,7}}, 'fan', 'stream')\n"
		"local format = custom:getVertexFormat(); assert(#format == 4 and format[1][1] == 'VertexPosition' and format[4][3] == 1)\n"
		"custom:setVertexAttribute(1, 4, 12); assert(custom:getVertexAttribute(1, 4) == 12)\n"
		"custom:setVertexMap({1,2,3}); custom:setDrawMode('strip'); assert(custom:getDrawMode() == 'strip')\n"
		"custom:setDrawRange(); assert(custom:getDrawRange() == nil); assert(not pcall(custom.setVertexMap, custom, {4}))\n"
		"local packedVertices = string.pack('=ffBBBBffBBBBffBBBB', 2,3,255,0,0,255, 22,3,0,255,0,255, 2,23,0,0,255,255)\n"
		"local packedData = filesystem.newFileData(packedVertices, 'mesh-vertices.bin')\n"
		"local dataMesh = graphics.newMesh({{'VertexPosition','float',2},{'VertexColor','byte',4}}, packedData, 'triangles', 'static')\n"
		"assert(dataMesh:getVertexCount() == 3); local dx,dy,dr,dg,db,da = dataMesh:getVertex(2); assert(dx == 22 and dy == 3 and dr == 0 and dg == 1 and db == 0 and da == 1)\n"
		"dataMesh:setVertices(filesystem.newFileData(string.pack('=ffBBBB', 26,4,0,255,255,255), 'mesh-patch.bin'), 2, 1)\n"
		"dx,dy,dr,dg,db,da = dataMesh:getVertex(2); assert(dx == 26 and dy == 4 and dr == 0 and dg == 1 and db == 1 and da == 1)\n"
		"local indexData = filesystem.newFileData(string.pack('=I2I2I2', 0,1,2), 'mesh-indices.bin'); dataMesh:setVertexMap(indexData, 'uint16', 3)\n"
		"local dataMap = dataMesh:getVertexMap(); assert(#dataMap == 3 and dataMap[1] == 1 and dataMap[3] == 3)\n"
		"dataMesh:setVertexMap({}); assert(#dataMesh:getVertexMap() == 0); dataMesh:setVertexMap(filesystem.newFileData(string.pack('=I4I4I4', 0,1,2), 'mesh-indices32.bin'), 'uint32')\n"
		"local unormMesh = graphics.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','unorm16',2},{'VertexColor','byte',4}}, filesystem.newFileData(string.pack('=ffI2I2BBBB', 1,2,32767,65535,128,64,255,255), 'mesh-unorm.bin'), 'points')\n"
		"local ux,uy,uu,uv,ur,ug = unormMesh:getVertex(1); assert(ux == 1 and uy == 2 and math.abs(uu - 32767/65535) < 0.0001 and uv == 1 and math.abs(ur - 128/255) < 0.0001 and math.abs(ug - 64/255) < 0.0001)\n"
		"local attached = graphics.newMesh({{'ReplacementPosition','float',2},{'ReplacementColor','byte',4}}, {{6,7,1,1,0,1},{30,7,1,0,1,1},{6,31,0,1,1,1}}, 'triangles')\n"
		"dataMesh:attachAttribute('VertexPosition', attached, 'pervertex', 'ReplacementPosition'); dataMesh:attachAttribute('VertexColor', attached, 'perinstance', 'ReplacementColor')\n"
		"assert(dataMesh:isAttributeEnabled('VertexPosition')); dataMesh:setAttributeEnabled('VertexColor', false); assert(not dataMesh:isAttributeEnabled('VertexColor')); dataMesh:setAttributeEnabled('VertexColor', true)\n"
		"attached = nil; collectgarbage(); assert(not pcall(dataMesh.setAttributeEnabled, dataMesh, 'Missing', true))\n"
		"assert(not pcall(graphics.newMesh, {{'Bad','byte',3}}, 3)); assert(not pcall(dataMesh.setVertexMap, dataMesh, indexData, 'bad'))\n"
		"assert(not pcall(graphics.newCanvas, 0, 16)); assert(not pcall(graphics.newCanvas, 16, 16, {mipmaps = 'invalid'})); assert(not pcall(graphics.newCanvas, 16, 8, {type = 'cube'}))\n"
		"local pixelShaderCode = [[extern vec4 tint; extern Image mask; extern Image overlay; extern Image layers[3]; // mock_warning\n"
		"extern ArrayImage arrayTexture; extern CubeImage cubeTexture; extern VolumeImage volumeTexture;\n"
		"extern int mode; extern uint flags; extern bool enabled; extern float weights[3];\n"
		"extern ivec2 offsets[2]; extern vec3 palette[2]; extern mat2 basis; extern mat3 frames[2]; extern mat4 transforms[2];\n"
		"extern vec2 packedVecs[2]; extern mat2 packedMatrices[2]; extern uint imageWord; extern bool soundWord;\n"
		"vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Texel(mask, uv) * Texel(overlay, uv) * Texel(layers[mode + 1], uv) * color * tint; }]]\n"
		"shader = graphics.newShader(pixelShaderCode); assert(shader:getWarnings():find('mock Shader warning', 1, true))\n"
		"assert(shader:hasUniform('tint') and shader:hasUniform('mask') and shader:hasUniform('overlay') and shader:hasUniform('layers') and not shader:hasUniform('missing')); assert(shader:getExternVariable('tint') and not shader:getExternVariable('missing')); shader:send('tint', {1, 0.5, 0.25, 1})\n"
		"shader:sendColor('tint', {2, -1, 0.75, 1}); assert(not pcall(shader.send, shader, 'missing', 1))\n"
		"local samplerImage = graphics.newImage('fixture.png'); samplerImage:setFilter('nearest'); samplerImage:setWrap('repeat', 'mirroredrepeat')\n"
		"local arrayOnlyImage = graphics.newImage('fixture.png')\n"
		"shader:send('mask', samplerImage); shader:send('overlay', canvas); shader:send('layers', samplerImage, canvas, arrayOnlyImage)\n"
		"shader:send('arrayTexture', arrayImage); shader:send('cubeTexture', cubeImage); shader:send('volumeTexture', volumeImage)\n"
		"assert(not pcall(shader.send, shader, 'arrayTexture', image)); assert(not pcall(shader.send, shader, 'cubeTexture', canvas))\n"
		"shader:send('mode', -2147483648); shader:send('flags', 4000000000); shader:send('enabled', true)\n"
		"shader:send('weights', 0.25, 0.5, 0.75); shader:send('offsets', {1, -2}, {2147483647, -2147483648})\n"
		"shader:sendColor('palette', {2, -1, 0.25}, {0.5, 0.75, 1}); shader:send('transforms', {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}, {2,0,0,0, 0,2,0,0, 0,0,2,0, 0,0,0,1})\n"
		"shader:send('basis', {1,2,3,4}); shader:send('frames', 'column', {{1,2,3},{4,5,6},{7,8,9}}, {{9,8,7},{6,5,4},{3,2,1}})\n"
		"local packedUniforms = filesystem.newFileData(string.pack('=I4ffff', 99, 1.25, 2.5, 3.75, 4.5), 'uniforms.bin')\n"
		"shader:send('packedVecs', packedUniforms, 4, 16); shader:send('imageWord', raw)\n"
		"local uniformSound = require('love.sound').newSoundData(2, 8000, 16, 1); uniformSound:setSample(0, 1); shader:send('soundWord', uniformSound)\n"
		"local packedMatrices = filesystem.newFileData(string.pack('=ffffffff', 1,2,3,4, 5,6,7,8), 'matrices.bin')\n"
		"shader:send('packedMatrices', 'row', packedMatrices, 0, 32)\n"
		"shader:send('basis', packedMatrices, 'column', 0, 16)\n"
		"assert(not pcall(shader.send, shader, 'packedVecs', packedUniforms, -1)); assert(not pcall(shader.send, shader, 'packedVecs', packedUniforms, 4, 7))\n"
		"assert(not pcall(shader.send, shader, 'packedVecs', packedUniforms, 20)); assert(not pcall(shader.send, shader, 'mask', packedUniforms))\n"
		"assert(not pcall(shader.send, shader, 'enabled', 1)); assert(not pcall(shader.send, shader, 'mode', 1.5)); assert(not pcall(shader.send, shader, 'flags', -1))\n"
		"assert(not pcall(shader.send, shader, 'offsets', {1})); assert(not pcall(shader.sendColor, shader, 'weights', 1, 1, 1))\n"
		"assert(not pcall(shader.send, shader, 'basis', 'diagonal', {1,2,3,4})); assert(not pcall(shader.send, shader, 'frames', {{1,2},{3,4}}))\n"
		"assert(not pcall(shader.sendColor, shader, 'mask', 1)); assert(not pcall(shader.send, shader, 'tint', samplerImage))\n"
		"assert(pcall(shader.send, shader, 'mask', samplerImage, samplerImage)); assert(not pcall(shader.send, shader, 'overlay', writeOnlyCanvas))\n"
		"graphics.setCanvas(canvas); assert(not pcall(shader.send, shader, 'layers', image, canvas)); graphics.setCanvas()\n"
		"graphics.setCanvas(canvas); assert(not pcall(shader.send, shader, 'overlay', canvas)); graphics.setCanvas()\n"
		"graphics.setShader(shader); assert(not pcall(graphics.setCanvas, canvas)); graphics.setShader()\n"
		"shader:sendColor('tint', {2, -1, 0.75, 1})\n"
		"samplerImage = nil; arrayOnlyImage = nil; collectgarbage('collect')\n"
		"local vertexData = filesystem.newFileData('attribute float Extra; vec4 position(mat4 transform, vec4 vertex) { return transform * (vertex + vec4(Extra * 0.0)); }', 'fixture.vert')\n"
		"local pixelData = filesystem.newFileData(pixelShaderCode, 'fixture.frag'); alternateShader = graphics.newShader(vertexData, pixelData)\n"
		"local valid, validationError = graphics.validateShader(false, pixelShaderCode); assert(valid and validationError == nil)\n"
		"valid, validationError = graphics.validateShader(false, 'vec4 effect() { compile_error }'); assert(not valid and validationError:find('source line 1', 1, true))\n"
		"local badFile, badFileError = graphics.validateShader(false, 'missing.frag'); assert(not badFile and badFileError:find('Does not exist', 1, true))\n"
		"garbageShader = graphics.newShader(pixelShaderCode); garbageShader = nil; collectgarbage('collect')\n"
		"mrtShader = graphics.newShader([[void effect() { love_Canvases[0] = vec4(1, 0, 0, 1); love_Canvases[1] = vec4(0, 1, 0, 1); }]])\n"
		"arrayShader = graphics.newShader([[extern ArrayImage MainTex; void effect() { love_PixelColor = Texel(MainTex, VaryingTexCoord.xyz) * VaryingColor; }]])\n"
		"assert(arrayShader:hasUniform('MainTex')); arrayShader:send('MainTex', arrayImage); assert(not pcall(arrayShader.send, arrayShader, 'MainTex', image))\n"
		"function love.draw()\n"
		"  local w, h = graphics.getDimensions(); assert(w == 640 and h == 360)\n"
		"  assert(graphics.getWidth() == 640 and graphics.getHeight() == 360)\n"
		"  graphics.clear(0.1, 0.2, 0.3, 1)\n"
		"  graphics.discard(); graphics.discard(false, false); graphics.discard({true, false}, true); graphics.flushBatch()\n"
		"  graphics.setColor(1, 0.5, 0.25, 0.75)\n"
		"  graphics.setColor({0.2, 0.4, 0.6}); local tr,tg,tb,ta=graphics.getColor(); assert(math.abs(tr-0.2)<1e-6 and math.abs(tg-0.4)<1e-6 and math.abs(tb-0.6)<1e-6 and ta==1)\n"
		"  graphics.setColor(1, 0.5, 0.25, 0.75)\n"
		"  assert(graphics.getShader() == nil); graphics.setShader(shader); assert(graphics.getShader() == shader)\n"
		"  graphics.push('all'); graphics.setShader(alternateShader); assert(graphics.getShader() == alternateShader); graphics.pop(); assert(graphics.getShader() == shader)\n"
		"  graphics.setShader(); assert(graphics.getShader() == nil)\n"
		"  graphics.setShader(mrtShader); assert(not pcall(graphics.draw, image, 0, 0)); assert(not pcall(graphics.rectangle, 'fill', 0, 0, 2, 2))\n"
		"  graphics.setCanvas(canvas); assert(not pcall(graphics.draw, image, 0, 0)); assert(not pcall(graphics.points, 1, 1))\n"
		"  graphics.setCanvas({canvas, canvas2}); graphics.draw(image, 0, 0); graphics.rectangle('fill', 0, 0, 2, 2)\n"
		"  graphics.setShader(); graphics.setCanvas()\n"
		"  graphics.setShader(arrayShader); graphics.drawLayer(arrayImage, 2, 9, 10); graphics.draw(arrayImage, arrayQuad, 7, 8); assert(not pcall(graphics.print, '2D font atlas', 0, 0))\n"
		"  assert(not pcall(graphics.draw, image, 0, 0)); assert(not pcall(graphics.rectangle, 'fill', 0, 0, 2, 2)); graphics.setShader()\n"
		"  assert(graphics.getLineStyle() == 'smooth' and graphics.getLineJoin() == 'miter')\n"
		"  assert(not graphics.isWireframe()); graphics.setWireframe(true); assert(graphics.isWireframe())\n"
		"  graphics.push('all'); graphics.setWireframe(false); assert(not graphics.isWireframe()); graphics.pop(); assert(graphics.isWireframe())\n"
		"  graphics.setLineWidth(6)\n"
		"  graphics.setLineStyle('rough'); graphics.setLineJoin('bevel')\n"
		"  assert(graphics.getLineStyle() == 'rough' and graphics.getLineJoin() == 'bevel')\n"
		"  assert(not pcall(graphics.setLineStyle, 'invalid')); assert(not pcall(graphics.setLineJoin, 'invalid'))\n"
		"  assert(graphics.getPointSize() == 1); graphics.setPointSize(5); assert(graphics.getPointSize() == 5)\n"
		"  assert(not pcall(graphics.setPointSize, 0)); assert(not pcall(graphics.setPointSize, 0/0))\n"
		"  local blend, alphaMode = graphics.getBlendMode(); assert(blend == 'alpha' and alphaMode == 'alphamultiply')\n"
		"  graphics.setBlendMode('add', 'alphamultiply')\n"
		"  graphics.setScissor(12, 18, 90, 45)\n"
		"  local sx, sy, sw, sh = graphics.getScissor(); assert(sx == 12 and sy == 18 and sw == 90 and sh == 45)\n"
		"  local mr, mg, mb, ma = graphics.getColorMask(); assert(mr and mg and mb and ma)\n"
		"  graphics.setColorMask(true, false, true, false); mr, mg, mb, ma = graphics.getColorMask(); assert(mr and not mg and mb and not ma)\n"
		"  graphics.setScissor(0, 0, 8, 8); graphics.clear({0.7, 0.6, 0.5, 0.4}, false, false); graphics.setScissor(); graphics.clear(0.7, 0.6, 0.5, 0.4); graphics.setScissor(12, 18, 90, 45)\n"
		"  graphics.push('all'); graphics.setColorMask(false, true, false, true); graphics.pop()\n"
		"  mr, mg, mb, ma = graphics.getColorMask(); assert(mr and not mg and mb and not ma)\n"
		"  graphics.setColorMask()\n"
		"  local depthCompare, depthWrite = graphics.getDepthMode(); assert(depthCompare == 'always' and not depthWrite)\n"
		"  assert(graphics.getMeshCullMode() == 'none' and graphics.getFrontFaceWinding() == 'ccw')\n"
		"  graphics.setDepthMode('less', true); graphics.setMeshCullMode('back'); graphics.setFrontFaceWinding('cw')\n"
		"  graphics.push('all'); graphics.setDepthMode('greater', false); graphics.setMeshCullMode('front'); graphics.setFrontFaceWinding('ccw'); graphics.pop()\n"
		"  depthCompare, depthWrite = graphics.getDepthMode(); assert(depthCompare == 'less' and depthWrite)\n"
		"  assert(graphics.getMeshCullMode() == 'back' and graphics.getFrontFaceWinding() == 'cw')\n"
		"  assert(not pcall(graphics.setDepthMode, 'invalid', true)); assert(not pcall(graphics.setMeshCullMode, 'invalid')); assert(not pcall(graphics.setFrontFaceWinding, 'invalid'))\n"
		"  local stencilCompare, stencilValue = graphics.getStencilTest(); assert(stencilCompare == nil and stencilValue == nil)\n"
		"  graphics.stencil(function() end); graphics.setStencilTest('equal', 1)\n"
		"  stencilCompare, stencilValue = graphics.getStencilTest(); assert(stencilCompare == 'equal' and stencilValue == 1)\n"
		"  graphics.push('all'); graphics.setStencilTest('greater', 2); graphics.pop()\n"
		"  stencilCompare, stencilValue = graphics.getStencilTest(); assert(stencilCompare == 'equal' and stencilValue == 1)\n"
		"  graphics.stencil(function() end, 'increment', 3, true)\n"
		"  graphics.stencil(function() end, 'invert', 4, 7)\n"
		"  assert(not pcall(graphics.stencil, function() error('stencil callback failure') end))\n"
		"  graphics.stencil(function() assert(not pcall(graphics.stencil, function() end)) end)\n"
		"  assert(not pcall(graphics.stencil, function() end, 'invalid'))\n"
		"  assert(not pcall(graphics.setStencilTest, 'invalid', 1))\n"
		"  graphics.rectangle('fill', 10, 20, 30, 40)\n"
		"  graphics.circle('line', 50, 60, 20)\n"
		"  graphics.line(0, 0, 10, 20, 30, 40)\n"
		"  graphics.ellipse('fill', 200, 100, 30, 20, 12)\n"
		"  graphics.push()\n"
		"  graphics.translate(100, 50)\n"
		"  graphics.rotate(math.pi / 2)\n"
		"  graphics.scale(2, 3)\n"
		"  graphics.polygon('line', 0, 0, 10, 0, 0, 10)\n"
		"  graphics.points(1, 2, 3, 4)\n"
		"  graphics.present(); graphics.present()\n"
		"  graphics.pop()\n"
		"  graphics.push('all')\n"
		"  graphics.setColor(0, 0, 0, 0)\n"
		"  graphics.setLineWidth(2)\n"
		"  graphics.setLineStyle('smooth'); graphics.setLineJoin('none')\n"
		"  graphics.setPointSize(9)\n"
		"  graphics.setBlendMode('screen', 'premultiplied')\n"
		"  graphics.setScissor()\n"
		"  graphics.setScissor(nil, nil, nil, nil); assert(graphics.getScissor() == nil)\n"
		"  graphics.pop()\n"
		"  local r, g, b, a = graphics.getColor()\n"
		"  assert(r == 1 and g == 0.5 and b == 0.25 and a == 0.75)\n"
		"  assert(graphics.getLineWidth() == 6)\n"
		"  assert(graphics.getLineStyle() == 'rough' and graphics.getLineJoin() == 'bevel')\n"
		"  assert(graphics.getPointSize() == 5)\n"
		"  blend, alphaMode = graphics.getBlendMode(); assert(blend == 'add' and alphaMode == 'alphamultiply')\n"
		"  sx, sy, sw, sh = graphics.getScissor(); assert(sx == 12 and sy == 18 and sw == 90 and sh == 45)\n"
		"  graphics.setBlendMode('multiply', 'premultiplied')\n"
		"  graphics.draw(image, quad, 50, 120, 0, 1, 1, 5, 3)\n"
		"  graphics.draw(image, 300, 200, 0.5, 2, 3, 16, 8)\n"
		"  graphics.draw(mesh, 10, 20); graphics.draw(dataMesh, 0, 0); assert(dataMesh:detachAttribute('VertexPosition')); assert(dataMesh:detachAttribute('VertexColor')); assert(not dataMesh:detachAttribute('VertexColor')); graphics.draw(custom, 30, 40)\n"
		"  unormMesh:attachAttribute('Extra', custom, 'perinstance', 'Extra')\n"
		"  graphics.setShader(alternateShader)\n"
		"  graphics.rectangle('fill', 2, 2, 4, 4); graphics.circle('line', 10, 10, 3); graphics.line(1, 1, 3, 3)\n"
		"  graphics.ellipse('fill', 18, 10, 3, 2, 8); graphics.polygon('line', 22, 8, 26, 8, 24, 12); graphics.points(30, 10)\n"
		"  graphics.draw(unormMesh); graphics.draw(custom, 30, 40); graphics.setShader()\n"
		"  graphics.setDepthMode(); graphics.setMeshCullMode('none'); graphics.setFrontFaceWinding('ccw'); graphics.setWireframe(false)\n"
		"  graphics.setFont(imageFont); graphics.print('A猫', 1, 2); graphics.setFont(font)\n"
		"  graphics.print('plain', 15, 25); graphics.print('font overload', font, 16, 26)\n"
		"  graphics.printf('wrapped text', 30, 40, 120, 'center', 0.25, 2, 3)\n"
		"  graphics.setCanvas(canvas); assert(graphics.getCanvas() == canvas)\n"
		"  w, h = graphics.getDimensions(); assert(w == 640 and h == 360)\n"
		"  local defaultCanvas = graphics.newCanvas(); local dw, dh = defaultCanvas:getDimensions(); assert(dw == 640 and dh == 360)\n"
		"  assert(not pcall(graphics.draw, canvas, 0, 0))\n"
		"  graphics.clear(0, 0, 0, 0); graphics.rectangle('fill', 1, 2, 20, 10)\n"
		"  graphics.push('all'); graphics.setCanvas(canvas2); assert(graphics.getCanvas() == canvas2); graphics.pop(); assert(graphics.getCanvas() == canvas)\n"
		"  graphics.setCanvas({canvas, canvas2}); local firstCanvas, secondCanvas = graphics.getCanvas(); assert(firstCanvas == canvas and secondCanvas == canvas2)\n"
		"  graphics.setColorMask(false, true, false, true); graphics.clear({0.1, 0.2, 0.3, 0.4}, {0.5, 0.6, 0.7, 0.8}, false, false)\n"
		"  graphics.clear({}, {0.9, 0.8, 0.7, 0.6}, false, false); graphics.setColorMask()\n"
		"  assert(not pcall(graphics.setCanvas, {canvas, mismatchedCanvas})); assert(not pcall(graphics.setCanvas, {canvas, canvas}))\n"
		"  assert(not pcall(graphics.setCanvas, {canvas, hdrCanvas}))\n"
		"  firstCanvas, secondCanvas = graphics.getCanvas(); assert(firstCanvas == canvas and secondCanvas == canvas2)\n"
		"  graphics.setCanvas(); assert(graphics.getCanvas() == nil)\n"
		"  assert(not pcall(canvas.newImageData, canvas))\n"
		"  w, h = graphics.getDimensions(); assert(w == 640 and h == 360)\n"
		"  graphics.draw(canvas, canvasQuad, 8, 9, 0, 2, 3)\n"
		"  graphics.setCanvas(canvas); assert(not pcall(graphics.stencil, function() end))\n"
		"  graphics.setCanvas({canvas, depth = true, stencil = true}); graphics.stencil(function() end, 'replace', 5)\n"
		"  graphics.setCanvas({canvas, depthstencil = depthStencilCanvas}); targets = graphics.getCanvas(); assert(type(targets) == 'table' and targets[1][1] == canvas and targets.depthstencil[1] == depthStencilCanvas)\n"
		"  graphics.push('all'); graphics.setCanvas({canvas, depthstencil = depthOnlyCanvas}); graphics.pop(); targets = graphics.getCanvas(); assert(targets.depthstencil[1] == depthStencilCanvas)\n"
		"  graphics.stencil(function() end, 'replace', 6); graphics.setDepthMode('less', true); graphics.rectangle('fill', 0, 0, 2, 2); graphics.setDepthMode()\n"
		"  assert(not pcall(graphics.setCanvas, {canvas, depthstencil = canvas}))\n"
		"  assert(not pcall(graphics.setCanvas, {canvas, depthstencil = mismatchedDepthCanvas}))\n"
		"  graphics.setCanvas({depthstencil = depthOnlyCanvas}); targets = graphics.getCanvas(); assert(#targets == 0 and targets.depthstencil[1] == depthOnlyCanvas)\n"
		"  graphics.setCanvas(); graphics.setStencilTest()\n"
		"  stencilCompare, stencilValue = graphics.getStencilTest(); assert(stencilCompare == nil and stencilValue == nil)\n"
		"  graphics.setCanvas(writeOnlyCanvas); graphics.clear(0.25, 0, 0, 1); graphics.setCanvas()\n"
		"  assert(not pcall(graphics.draw, writeOnlyCanvas, 0, 0))\n"
		"  graphics.clear(false, false, false); graphics.clear()\n"
		"end\n",
		"@graphics.lua", error), error);
	require(graphical.draw(error), error);
	require(graphics.begins == 1 && graphics.ends == 1, "graphics frame was not bracketed once");
	require(graphics.modeChanges == 4 && graphics.pixelWidth == 640 && graphics.pixelHeight == 360,
		"virtual window setMode did not resize the instance backend");
	require(graphics.clears == 9 && graphics.rectangles == 5 && graphics.circles == 2 && graphics.lines == 2,
		"graphics command dispatch count mismatch");
	require(graphics.clearRequests.size() == 9
		&& !graphics.clearRequests[0].colorsPerAttachment
		&& graphics.clearRequests[0].colors.size() == 1
		&& graphics.clearRequests[0].colors[0].alpha == 1.0f
		&& graphics.clearRequests[0].clearStencil && graphics.clearRequests[0].clearDepth,
		"numeric clear did not retain Love's broadcast color and default depth/stencil semantics");
	require(graphics.clearRequests[1].colorsPerAttachment
		&& graphics.clearRequests[1].colors.size() == 1
		&& !graphics.clearRequests[1].clearStencil && !graphics.clearRequests[1].clearDepth,
		"table clear did not retain explicit color-only semantics");
	require(graphics.clearRequests[4].colorsPerAttachment
		&& graphics.clearRequests[4].colors.size() == 2
		&& graphics.clearRequests[4].colors[0].enabled
		&& graphics.clearRequests[4].colors[1].enabled
		&& !graphics.clearRequests[4].clearStencil && !graphics.clearRequests[4].clearDepth,
		"MRT clear did not preserve per-attachment colors or disabled depth/stencil");
	require(graphics.clearRequests[5].colors.size() == 2
		&& !graphics.clearRequests[5].colors[0].enabled
		&& graphics.clearRequests[5].colors[1].enabled,
		"MRT clear did not preserve an intentionally skipped color attachment");
	require(!graphics.clearRequests[7].colors.front().enabled
		&& !graphics.clearRequests[7].clearStencil && !graphics.clearRequests[7].clearDepth,
		"boolean clear overload did not disable all requested buffers");
	require(graphics.clearRequests[8].colors.front().enabled
		&& graphics.clearRequests[8].colors.front().alpha == 0.0f
		&& graphics.clearRequests[8].clearStencil && graphics.clearRequests[8].clearDepth,
		"no-argument clear did not use Love's transparent-black defaults");
	require(graphics.lastRectangleFilled && graphics.linePointCount == 6, "graphics command arguments mismatch");
	require(graphics.polygons == 4 && graphics.pointCalls == 2, "extended graphics command dispatch mismatch");
	require(graphics.shaderPrimitiveDraws == 7,
		"active Shader primitives or MRT primitive draw validation did not reach the expected backend calls");
	require(!graphics.lastPolygonFilled && graphics.lastPolygonPoints.size() == 6,
		"transformed polygon arguments mismatch");
	requireNear(graphics.lastPolygonPoints[0], 100.0f, "transformed polygon x0");
	requireNear(graphics.lastPolygonPoints[1], 50.0f, "transformed polygon y0");
	requireNear(graphics.lastPolygonPoints[2], 100.0f, "transformed polygon x1");
	requireNear(graphics.lastPolygonPoints[3], 70.0f, "transformed polygon y1");
	requireNear(graphics.lastPolygonPoints[4], 70.0f, "transformed polygon x2");
	requireNear(graphics.lastPolygonPoints[5], 50.0f, "transformed polygon y2");
	requireNear(graphics.lastPoints[0], 94.0f, "transformed point x");
	requireNear(graphics.lastPoints[1], 52.0f, "transformed point y");
	requireNear(graphics.lastPointSize, 5.0f, "point size dispatch");
	require(graphics.lastLineStyle == Dora::Love::GraphicsBackend::LineStyle::Rough
		&& graphics.lastLineJoin == Dora::Love::GraphicsBackend::LineJoin::Bevel,
		"line style/join state did not reach graphics primitive dispatch");
	require(graphics.ends == 1, "explicit embedded present submitted the RenderTarget pass more than once");
	execute(graphical, "assert(not pcall(love.graphics.present))", "@present-outside-draw.lua");
	require(graphics.imagesCreated == 26 && graphics.imagesReleased == 0
		&& graphics.imageDraws == 3 && graphics.lastImageHandle == 1,
		"Image creation/draw dispatch mismatch");
	int explicitMipmapImages = 0;
	for (const auto &[handle, image] : graphics.layeredImages)
	{
		(void)handle;
		if (image.levels.size() == 2) ++explicitMipmapImages;
	}
	require(explicitMipmapImages == 10,
		"2D/Array/Cube/Volume Image mipmap chains did not reach the graphics backend");
	require(graphics.imageReplacements == 4
		&& graphics.lastImageReplacement[1] == 1 && graphics.lastImageReplacement[2] == 0
		&& graphics.lastImageReplacement[3] == 1 && graphics.lastImageReplacement[4] == 1
		&& graphics.lastImageReplacement[5] == 1 && graphics.lastImageReplacement[6] == 1,
		"Image replacePixels did not preserve 1-based slice, mipmap, or replacement region semantics");
	const auto replacedImage = graphics.layeredImages.find(
		static_cast<Dora::Love::GraphicsBackend::ImageHandle>(graphics.lastImageReplacement[0]));
	require(replacedImage != graphics.layeredImages.end()
		&& replacedImage->second.pixels[((1 * 2 + 1) * 2 + 1) * 4 + 2] == 255,
		"Image replacePixels did not update the selected VolumeImage slice pixel");
	require(graphics.imageLayerDraws == 5 && graphics.lastImageLayer == 1
		&& graphics.getImageTextureType(graphics.lastImageLayerHandle)
			== Dora::Love::GraphicsBackend::TextureType::Array
		&& graphics.imageLayerSource == std::vector<float>({0.0f, 0.0f, 1.0f, 2.0f})
		&& graphics.imageLayerMatrix == std::vector<float>({1.0f, 0.0f, 0.0f, 1.0f, 7.0f, 8.0f}),
		"ArrayImage drawLayer or Quad layer dispatch mismatch");
	require(graphics.compressedImagesCreated == 6
		&& graphics.lastCompressedImageFormat == "DXT1"
		&& graphics.lastCompressedImageMipmaps == 2
		&& graphics.lastCompressedImageType == Dora::Love::GraphicsBackend::TextureType::Volume
		&& graphics.lastCompressedImageSlices == 1
		&& graphics.lastCompressedImageBytes == std::vector<std::uint8_t>(
			{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}),
		"CompressedImageData Image upload did not preserve format, mipmaps, or bytes");
	require(graphics.canvasesCreated == 13, "Canvas creation dispatch mismatch");
	require(graphics.canvasDraws == 1 && graphics.lastCanvasHandle == 100,
		"Canvas draw dispatch mismatch");
	require(graphics.canvasLayerDraws == 1 && graphics.lastCanvasLayer == 1,
		"array Canvas drawLayer dispatch mismatch");
	require(graphics.meshDraws == 5 && graphics.untexturedShaderMeshDraws == 2
		&& graphics.shaderPointMeshDraws == 1
		&& graphics.lastMeshVertices.size() == 3
		&& graphics.lastMeshIndices == std::vector<std::uint32_t>({0, 1, 2}),
		"Mesh indexed/non-indexed draw dispatch mismatch");
	require(graphics.shadersCreated == 6 && graphics.shadersReleased == 2
		&& graphics.currentShader == 0,
		"Shader creation, validation, garbage collection, or active state mismatch");
	require(graphics.shaderSelections.size() == 12
		&& graphics.shaderSelections[0] == 200 && graphics.shaderSelections[1] == 0
		&& graphics.shaderSelections[2] == 200 && graphics.shaderSelections[3] == 201
		&& graphics.shaderSelections[4] == 200 && graphics.shaderSelections[5] == 0
		&& graphics.shaderSelections[6] == 204 && graphics.shaderSelections[7] == 0
		&& graphics.shaderSelections[8] == 205 && graphics.shaderSelections[9] == 0
		&& graphics.shaderSelections[10] == 201 && graphics.shaderSelections[11] == 0,
		"Shader set/get or push-all/pop restoration did not reach the backend");
	require(graphics.lastShaderSendWasColor
		&& graphics.shaderUniforms.at(200).at("tint") == std::vector<float>({1.0f, 0.0f, 0.75f, 1.0f}),
		"Shader send/sendColor values were not validated and dispatched");
	const auto &shaderMode = graphics.shaderUniforms.at(200).at("mode");
	const auto &shaderFlags = graphics.shaderUniforms.at(200).at("flags");
	const auto &shaderOffsets = graphics.shaderUniforms.at(200).at("offsets");
	require(shaderMode.size() == 1 && std::bit_cast<std::int32_t>(shaderMode[0])
		== std::numeric_limits<std::int32_t>::min(), "Shader int bits were not preserved");
	require(shaderFlags.size() == 1 && std::bit_cast<std::uint32_t>(shaderFlags[0]) == 4000000000u,
		"Shader uint bits were not preserved");
	require(graphics.shaderUniforms.at(200).at("enabled") == std::vector<float>({1.0f})
		&& graphics.shaderUniforms.at(200).at("weights") == std::vector<float>({0.25f, 0.5f, 0.75f}),
		"Shader bool or scalar array values were not type-checked");
	require(shaderOffsets.size() == 4
		&& std::bit_cast<std::int32_t>(shaderOffsets[0]) == 1
		&& std::bit_cast<std::int32_t>(shaderOffsets[1]) == -2
		&& std::bit_cast<std::int32_t>(shaderOffsets[2]) == std::numeric_limits<std::int32_t>::max()
		&& std::bit_cast<std::int32_t>(shaderOffsets[3]) == std::numeric_limits<std::int32_t>::min(),
		"Shader integer vector array bits were not preserved");
	require(graphics.shaderUniforms.at(200).at("palette") == std::vector<float>({
		1.0f, 0.0f, 0.25f, 0.5f, 0.75f, 1.0f})
		&& graphics.shaderUniforms.at(200).at("transforms").size() == 32,
		"Shader vector/matrix array values were not flattened by element");
	require(graphics.shaderUniforms.at(200).at("basis")
		== std::vector<float>({1.0f, 2.0f, 3.0f, 4.0f})
		&& graphics.shaderUniforms.at(200).at("frames") == std::vector<float>({
			1,2,3,4,5,6,7,8,9, 9,8,7,6,5,4,3,2,1}),
		"Shader matrix row/column layout or nested table conversion mismatch");
	const auto &packedImageWord = graphics.shaderUniforms.at(200).at("imageWord");
	require(graphics.shaderUniforms.at(200).at("packedVecs")
		== std::vector<float>({1.25f, 2.5f, 3.75f, 4.5f})
		&& graphics.shaderUniforms.at(200).at("packedMatrices")
			== std::vector<float>({1,3,2,4, 5,7,6,8})
		&& packedImageWord.size() == 1
		&& std::bit_cast<std::uint32_t>(packedImageWord[0]) == 0x04030201u
		&& graphics.shaderUniforms.at(200).at("soundWord") == std::vector<float>({1.0f}),
		"Shader Data-backed float, matrix, offset/size, ImageData, or SoundData bytes mismatch");
	const auto &maskTexture = graphics.shaderTextures.at(200).at("mask");
	const auto &arrayTexture = graphics.shaderTextures.at(200).at("arrayTexture");
	const auto &cubeTexture = graphics.shaderTextures.at(200).at("cubeTexture");
	const auto &volumeTexture = graphics.shaderTextures.at(200).at("volumeTexture");
	require(maskTexture.image != 0
		&& graphics.shaderTextures.at(200).at("mask").filter == MockGraphics::TextureFilter::Nearest
		&& graphics.shaderTextures.at(200).at("mask").wrapU == MockGraphics::TextureWrap::Repeat
		&& graphics.shaderTextures.at(200).at("mask").wrapV == MockGraphics::TextureWrap::MirroredRepeat
		&& graphics.shaderTextures.at(200).at("overlay").canvas == 100
		&& graphics.shaderTextures.at(200).at("overlay").filter == MockGraphics::TextureFilter::Nearest
		&& graphics.shaderTextures.at(200).at("overlay").wrapU == MockGraphics::TextureWrap::Repeat
		&& graphics.shaderTextures.at(200).at("overlay").wrapV == MockGraphics::TextureWrap::ClampZero
		&& graphics.shaderTextures.at(200).at("layers[1]").image == maskTexture.image
		&& graphics.shaderTextures.at(200).at("layers[2]").canvas == 100
		&& graphics.shaderTextures.at(200).at("layers[3]").image != 0
		&& graphics.shaderTextures.at(200).at("layers[3]").image != maskTexture.image
		&& graphics.getImageTextureType(arrayTexture.image) == MockGraphics::TextureType::Array
		&& graphics.getImageTextureType(cubeTexture.image) == MockGraphics::TextureType::Cube
		&& graphics.getImageTextureType(volumeTexture.image) == MockGraphics::TextureType::Volume
		&& graphics.shaderTextures.at(200).at("volumeTexture").wrapW
			== MockGraphics::TextureWrap::MirroredRepeat,
		"Shader Image/Canvas sampler or sampler-array metadata did not reach the backend");
	require(graphics.attachedMeshVertices.size() == 3,
		"Data Mesh attached attribute draw was not dispatched");
	requireNear(graphics.attachedMeshVertices[0].x, 6.0f, "attached Mesh position x");
	requireNear(graphics.attachedMeshVertices[1].x, 30.0f, "attached Mesh per-vertex position x");
	requireNear(graphics.attachedMeshVertices[2].red, 1.0f, "attached Mesh per-instance color red");
	requireNear(graphics.attachedMeshVertices[2].green, 0.5f, "attached Mesh global color green");
	require(graphics.lastMeshDrawMode == "strip" && graphics.lastMeshImage == 0
		&& graphics.lastMeshCanvas == 0, "custom Mesh draw metadata mismatch");
	requireNear(graphics.lastMeshVertices[0].x, 34.0f, "custom Mesh transformed x");
	requireNear(graphics.lastMeshVertices[0].y, 45.0f, "custom Mesh transformed y");
	requireNear(graphics.lastMeshVertices[0].z, 0.2f, "custom Mesh z attribute");
	requireNear(graphics.lastMeshVertices[0].red, 1.0f, "custom Mesh color red");
	requireNear(graphics.lastMeshVertices[0].green, 0.5f, "custom Mesh global color green");
	require(graphics.lastMeshAttributes.size() == 1
		&& graphics.lastMeshAttributes[0].name == "Extra"
		&& graphics.lastMeshAttributes[0].components == 1
		&& graphics.lastMeshAttributes[0].values == std::vector<float>({12.0f, 8.0f, 7.0f}),
		"custom Mesh attribute values did not reach the graphics backend");
	require(graphics.shaderPointAttributes.size() == 1
		&& graphics.shaderPointAttributes[0].name == "Extra"
		&& graphics.shaderPointAttributes[0].values == std::vector<float>({12.0f}),
		"per-instance attached custom attribute did not reach the Shader point Mesh draw");
	require(graphics.depthModeChanges >= 5 && graphics.meshCullChanges >= 7
		&& graphics.lastDepthCompare == "always" && !graphics.depthWrite
		&& graphics.lastMeshCullMode == "none" && graphics.lastFrontFaceWinding == "ccw"
		&& graphics.wireframeChanges >= 5 && !graphics.wireframe,
		"Depth/cull/winding state dispatch or restoration mismatch");
	require(graphics.canvasReads == 6
		&& graphics.lastCanvasRead == std::vector<int>({0, 0, 0, 0, 2, 1}),
		"Canvas readback rectangle dispatch mismatch");
	require(graphics.canvasMipmapGenerations == 4 && graphics.lastGeneratedCanvas != 0
		&& graphics.canvasSettings.at(graphics.lastGeneratedCanvas).type
			== Dora::Love::GraphicsBackend::TextureType::Volume,
		"Canvas manual/auto mipmap generation dispatch mismatch");
	require(graphics.canvasSwitches == 26,
		"Canvas switch/restore dispatch mismatch: " + std::to_string(graphics.canvasSwitches));
	require(graphics.stencilClears == 6 && graphics.stencilWrites == 7
		&& graphics.stencilWriteEnds == 7 && !graphics.stencilWriting,
		"stencil clear/write/callback cleanup dispatch mismatch");
	require(graphics.lastStencilClearValue == 0 && graphics.lastStencilAction == "replace"
		&& graphics.lastStencilWriteValue == 6,
		"stencil action, clear value, or Canvas stencil dispatch mismatch");
	require(graphics.lastStencilCompare == "always" && graphics.lastStencilTestValue == 0
		&& !graphics.currentCanvasStencil,
		"stencil test disable or Canvas stencil ownership state mismatch");
	require(graphics.canvasSource.size() == 4 && graphics.canvasSource[0] == 4.0f
		&& graphics.canvasSource[1] == 2.0f && graphics.canvasSource[2] == 24.0f
		&& graphics.canvasSource[3] == 12.0f,
		"Canvas Quad source rectangle was not dispatched");
	require(graphics.imageDataDecodes == 13,
		"ImageData and auto-loaded BMFont page decode calls did not reach the injected backend");
	require(graphics.compressedImageDecodes == 11,
		"CompressedImageData probes did not reach the injected backend");
	require(graphics.imageDataEncodes == 4 && graphics.lastImageDataEncodeFormat == "tga"
		&& graphics.lastImageDataEncodeWidth == 2 && graphics.lastImageDataEncodeHeight == 2
		&& graphics.lastImageDataEncodePixels.size() == 16,
		"ImageData encode calls did not preserve rgba8 metadata");
	std::string savedImageData;
	require(imageDataFilesystem.load((imageDataSaveBase / "image-data/roundtrip.png").string(),
		savedImageData, error) && savedImageData == "encoded-png",
		"ImageData encode did not write through the filesystem backend");
	require(imageDataFilesystem.load((imageDataSaveBase / "image-data/roundtrip.tga").string(),
		savedImageData, error) && savedImageData == "encoded-tga",
		"ImageData TGA encode did not write through the filesystem backend");
	execute(graphical,
		"screenshotCallbackCount = 0\n"
		"screenshotChannel = love.thread.newChannel()\n"
		"love.graphics.captureScreenshot(function(data)\n"
		"  screenshotCallbackCount = screenshotCallbackCount + 1\n"
		"  screenshotWidth, screenshotHeight = data:getDimensions()\n"
		"  screenshotRed, screenshotGreen, screenshotBlue, screenshotAlpha = data:getPixel(1, 0)\n"
		"end)\n"
		"love.graphics.captureScreenshot('capture.png')\n"
		"love.graphics.captureScreenshot(screenshotChannel)\n"
		"assert(not pcall(love.graphics.captureScreenshot, 'capture.jpg'))\n"
		"assert(not pcall(love.graphics.captureScreenshot, 1))\n",
		"@screenshot-requests.lua");
	require(graphics.screenshotRequests.size() == 3,
		"captureScreenshot did not queue callback, filename, and Channel requests independently");
	const std::vector<std::uint8_t> screenshotPixels = {
		255, 0, 0, 255, 0, 255, 0, 128};
	require(graphical.completeScreenshot(graphics.screenshotRequests[0], 2, 1,
		screenshotPixels, error), error);
	execute(graphical,
		"assert(screenshotCallbackCount == 1 and screenshotWidth == 2 and screenshotHeight == 1)\n"
		"assert(screenshotRed == 0 and screenshotGreen == 1 and screenshotBlue == 0)\n"
		"assert(math.abs(screenshotAlpha - 128 / 255) < 0.0001)\n",
		"@verify-screenshot-callback.lua");
	require(graphical.completeScreenshot(graphics.screenshotRequests[1], 2, 1,
		screenshotPixels, error), error);
	std::string savedScreenshot;
	require(imageDataFilesystem.load((imageDataSaveBase / "image-data/capture.png").string(),
		savedScreenshot, error) && savedScreenshot == "encoded-png",
		"filename screenshot did not encode and save through the filesystem backend");
	require(graphics.lastImageDataEncodeWidth == 2 && graphics.lastImageDataEncodeHeight == 1
		&& graphics.lastImageDataEncodePixels == screenshotPixels,
		"filename screenshot did not preserve RGBA8 pixels through the image backend");
	require(graphical.completeScreenshot(graphics.screenshotRequests[2], 2, 1,
		screenshotPixels, error), error);
	execute(graphical,
		"local data = screenshotChannel:demand(0)\n"
		"assert(data:typeOf('ImageData'))\n"
		"local width, height = data:getDimensions()\n"
		"assert(width == 2 and height == 1)\n"
		"local red, green, blue, alpha = data:getPixel(0, 0)\n"
		"assert(red == 1 and green == 0 and blue == 0 and alpha == 1)\n",
		"@verify-screenshot-channel.lua");
	graphics.rejectScreenshot = true;
	execute(graphical,
		"local ok, message = pcall(love.graphics.captureScreenshot, function() end)\n"
		"assert(not ok and message:find('mock screenshot backend rejected', 1, true))\n",
		"@screenshot-rejected.lua");
	graphics.rejectScreenshot = false;
	require(graphics.lastImageFilter == Dora::Love::GraphicsBackend::TextureFilter::Anisotropic
		&& graphics.lastImageWrapU == Dora::Love::GraphicsBackend::TextureWrap::Repeat
		&& graphics.lastImageWrapV == Dora::Love::GraphicsBackend::TextureWrap::MirroredRepeat,
		"Image filter/wrap state was not dispatched to the Dora backend");
	require(graphics.imageSources.size() == 3 && graphics.imageSources[1].size() == 4,
		"Quad Image source rectangle was not dispatched");
	requireNear(graphics.imageSources[1][0], 6.0f, "Quad source x");
	requireNear(graphics.imageSources[1][1], 4.0f, "Quad source y");
	requireNear(graphics.imageSources[1][2], 10.0f, "Quad source width");
	requireNear(graphics.imageSources[1][3], 6.0f, "Quad source height");
	requireNear(graphics.imageSources[2][0], 0.0f, "full Image source x");
	requireNear(graphics.imageSources[2][2], 32.0f, "full Image source width");
	require(graphics.blendChanges >= 5 && graphics.lastBlendMode == "multiply"
		&& graphics.lastBlendAlphaMode == "premultiplied", "blend mode state/restore mismatch");
	require(graphics.scissorChanges >= 7 && graphics.scissorEnabled && graphics.lastScissor.size() == 4,
		"scissor state/restore mismatch");
	require(graphics.colorMaskChanges >= 5 && graphics.colorMask == std::array<bool, 4>{true, true, true, true},
		"color mask state/restore mismatch");
	requireNear(graphics.lastScissor[0], 12.0f, "restored scissor x");
	requireNear(graphics.lastScissor[3], 45.0f, "restored scissor height");
	require(graphics.lastImageFilename == "fixture.png", "Image filename dispatch mismatch");
	requireNear(graphics.imageMatrix[0], std::cos(0.5f) * 2.0f, "Image matrix a");
	requireNear(graphics.imageMatrix[1], std::sin(0.5f) * 2.0f, "Image matrix b");
	requireNear(graphics.imageMatrix[4], 300.0f, "Image matrix tx");
	requireNear(graphics.imageMatrix[5], 200.0f, "Image matrix ty");
	require(graphics.fontsCreated == 10 && graphics.bmFontsCreated == 3
		&& graphics.lastBMFontPageCount == 1 && graphics.lastBMFontGlyphCount == 1
		&& graphics.lastBMFontFilter == Dora::Love::GraphicsBackend::TextureFilter::Linear
		&& graphics.textDraws == 4 && graphics.lastTextFont == 19,
		"Font creation/current font/text dispatch mismatch");
	require(graphics.lastImageFontWidth == 8 && graphics.lastImageFontHeight == 2
		&& graphics.lastImageFontPixels.size() == 64
		&& std::all_of(graphics.lastImageFontPixels.begin(), graphics.lastImageFontPixels.begin() + 4,
			[](std::uint8_t value) { return value == 0; })
		&& graphics.lastImageFontPixels[4] == 255
		&& graphics.lastImageFontFilter == Dora::Love::GraphicsBackend::TextureFilter::Linear,
		"ImageFont atlas transparency, dimensions, or default filter mismatch");
	require(graphics.lastFontFallbacks.size() == 1 && graphics.lastFontFallbacks.front() == 18,
		"Font fallback list did not reach the graphics backend");
	require(graphics.lastText == "wrapped text" && graphics.lastTextWrapLimit == 120.0f
		&& graphics.lastTextAlign == "center", "printf arguments mismatch");
	requireNear(graphics.textMatrix[0], std::cos(0.25f) * 2.0f, "Text matrix a");
	requireNear(graphics.textMatrix[1], std::sin(0.25f) * 2.0f, "Text matrix b");
	execute(graphical,
		"love.graphics.printf('negative wrap', 0, 0, -5, 'left')\n",
		"@negative-printf-wrap.lua");
	require(graphics.lastTextWrapLimit == 0.0f,
		"printf did not clamp a negative wrap limit like LÖVE");
	execute(graphical,
		"function love.draw() love.graphics.polygon('fill', 0, 0, 10, 0, 0, 10) end\n",
		"@graphics-reset.lua");
	require(graphical.draw(error), error);
	requireNear(graphics.lastPolygonPoints[0], 0.0f, "frame transform reset x");
	requireNear(graphics.lastPolygonPoints[1], 0.0f, "frame transform reset y");
	graphical.close();
	require(graphics.shadersReleased == 6 && graphics.shaderUniforms.empty()
		&& graphics.shaderMainTextureTypes.empty(),
		"Shader userdata did not release all backend programs on state close");
	require(graphics.imagesReleased == 26 && graphics.layeredImages.empty(),
		"Image userdata did not release its backend resources on state close");
	require(graphics.canvasesReleased == 13 && graphics.canvases.empty() && graphics.canvasSettings.empty(),
		"Canvas userdata did not release its backend RenderTarget on state close");
	require(graphics.fontsReleased == 10 && graphics.fontSizes.empty(),
		"Font backend resources were not released on state close");

	MockGraphics handleGraphics;
	Dora::Love::LoveRuntime handleRuntime;
	handleRuntime.setGraphicsBackend(&handleGraphics);
	require(handleRuntime.open(error), error);
	execute(handleRuntime,
		"local graphics=require('love.graphics')\n"
		"local image=require('love.image')\n"
		"local texture=graphics.newImage(image.newImageData(2,2))\n"
		"local canvas=graphics.newCanvas(2,2)\n"
		"local shader=graphics.newShader([[vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc){ return c; }]])\n"
		"local font=graphics.newFont(12)\n"
		"local mesh=graphics.newMesh({{0,0},{1,0},{0,1}})\n"
		"mesh:setTexture(texture); graphics.setCanvas(canvas); graphics.setShader(shader); graphics.setFont(font)\n"
		"assert(texture:release() and canvas:release() and shader:release() and font:release())\n"
		"assert(mesh:getTexture():getWidth()==2 and graphics.getCanvas():getWidth()==2)\n"
		"assert(graphics.getShader():getWarnings()~=nil and graphics.getFont():getHeight()>0)\n"
		"local transform=require('love.math').newTransform(3,4); local captured=transform.transformPoint\n"
		"assert(transform:type()=='Transform' and transform:typeOf('Object') and transform:release())\n"
		"local ok,message=pcall(captured,transform,0,0); assert(not ok and message:find('Cannot use object after it has been released.',1,true))\n"
		"local attached=graphics.newMesh({{0,0},{1,0},{0,1}}); mesh:attachAttribute('VertexPosition',attached)\n"
		"assert(attached:release()); graphics.draw(mesh)\n"
		"local quad=graphics.newQuad(0,0,1,1,2,2); local particles=graphics.newParticleSystem(mesh:getTexture(),4)\n"
		"particles:setQuads(quad); assert(quad:release()); local retained=particles:getQuads()[1]\n"
		"local x,y,w,h=retained:getViewport(); assert(x==0 and y==0 and w==1 and h==1)\n"
		"assert(particles:typeOf('Drawable') and mesh:typeOf('Drawable'))\n"
		"graphics.reset(); particles=nil; retained=nil; attached=nil; mesh=nil; collectgarbage('collect')\n",
		"@handle-object-lifecycle.lua");
	require(handleGraphics.imagesReleased == 1 && handleGraphics.canvasesReleased == 1
		&& handleGraphics.shadersReleased == 1 && handleGraphics.fontsReleased == 1,
		"Dora handle wrappers did not retain parents or release each backend handle exactly once");
	handleRuntime.close();
	require(handleGraphics.imagesReleased == 1 && handleGraphics.canvasesReleased == 1
		&& handleGraphics.shadersReleased == 1 && handleGraphics.fontsReleased == 1,
		"Dora handle wrappers released backend handles more than once during Runtime close");
	std::error_code imageDataCleanupError;
	fs::remove_all(imageDataSaveBase, imageDataCleanupError);

	MockGraphics arcGraphics;
	Dora::Love::LoveRuntime arcRuntime;
	arcRuntime.setGraphicsBackend(&arcGraphics);
	require(arcRuntime.open(error), error);
	require(arcRuntime.boot(
		"local graphics = require('love.graphics')\n"
		"function love.draw()\n"
		"  graphics.translate(5, 7)\n"
		"  graphics.arc('fill', 'pie', 10, 20, 4, 0, math.pi / 2, 2)\n"
		"  graphics.arc('fill', 10, 20, 4, 0, math.pi / 2, 2)\n"
		"  graphics.arc('line', 'open', 0, 0, 2, 0, math.pi, 2)\n"
		"  graphics.arc('line', 'closed', 0, 0, 2, 0, math.pi, 2)\n"
		"  graphics.arc('line', 0, 0, 2, 0, math.pi * 2, 4)\n"
		"  graphics.arc('fill', 0, 0, 2, 0, 0, 4)\n"
		"  graphics.arc('line', 0, 0, 2, 0, 1, 0)\n"
		"  assert(not pcall(graphics.arc, 'fill', 'invalid', 0, 0, 1, 0, 1))\n"
		"  assert(not pcall(graphics.arc, 'invalid', 0, 0, 1, 0, 1))\n"
		"end\n", "@graphics-arc.lua", error), error);
	require(arcRuntime.draw(error), error);
	require(arcGraphics.polygons == 2 && arcGraphics.lines == 3,
		"arc mode dispatch or zero-segment no-op mismatch");
	require(arcGraphics.lastPolygonFilled && arcGraphics.lastPolygonPoints.size() == 8,
		"filled pie arc did not create center plus inclusive curve vertices");
	requireNear(arcGraphics.lastPolygonPoints[0], 15.0f, "transformed arc center x");
	requireNear(arcGraphics.lastPolygonPoints[1], 27.0f, "transformed arc center y");
	requireNear(arcGraphics.lastPolygonPoints[2], 19.0f, "transformed arc start x");
	requireNear(arcGraphics.lastPolygonPoints[3], 27.0f, "transformed arc start y");
	require(arcGraphics.lastLinePoints.size() == 10,
		"full-circle line arc did not close an explicit four-segment loop");
	requireNear(arcGraphics.lastLinePoints.front(), 7.0f, "transformed full arc start x");
	requireNear(arcGraphics.lastLinePoints[1], 7.0f, "transformed full arc start y");
	requireNear(arcGraphics.lastLinePoints[8], 7.0f, "closed full arc final x");
	requireNear(arcGraphics.lastLinePoints[9], 7.0f, "closed full arc final y");
	arcRuntime.close();

	MockGraphics spriteBatchGraphics;
	Dora::Love::LoveRuntime spriteBatchRuntime;
	spriteBatchRuntime.setGraphicsBackend(&spriteBatchGraphics);
	require(spriteBatchRuntime.open(error), error);
	require(spriteBatchRuntime.boot(
		"local graphics = require('love.graphics')\n"
		"local first = graphics.newImage('first.png')\n"
		"local second = graphics.newImage('second.png')\n"
		"local quad = graphics.newQuad(4, 2, 8, 6, 32, 16)\n"
		"batch = graphics.newSpriteBatch(first, 2, 'dynamic')\n"
		"assert(batch:getCount() == 0 and batch:getBufferSize() == 2)\n"
		"assert(select('#', batch:getColor()) == 0 and batch:getTexture() == first)\n"
		"batch:setColor({1, 0.5, 0.25, 0.75}); local r,g,b,a=batch:getColor(); assert(r==1 and g==0.5 and b==0.25 and a==0.75)\n"
		"assert(batch:add(quad, 10, 20) == 1)\n"
		"batch:setColor(); assert(select('#', batch:getColor()) == 0)\n"
		"assert(batch:add(0, 0) == 2 and batch:add(20, 30) == 3)\n"
		"assert(batch:getCount() == 3 and batch:getBufferSize() == 4)\n"
		"batch:set(2, quad, 40, 50); assert(batch:getCount() == 3)\n"
		"batch:setDrawRange(2, 1); local start,count=batch:getDrawRange(); assert(start==2 and count==1)\n"
		"batch:setTexture(second); assert(batch:getTexture() == second)\n"
		"local attachedVertices={}\n"
		"for index=1,12 do attachedVertices[index]={0,0,0,0,1,1,1,1,index} end\n"
		"attachedVertices[5]={40,50,0.25,0.375,0.2,0.4,0.6,0.8,105}\n"
		"attachedVertices[6]={48,50,0.5,0.375,0.3,0.5,0.7,0.9,106}\n"
		"attachedVertices[7]={48,56,0.5,0.75,0.4,0.6,0.8,1,107}\n"
		"attachedVertices[8]={40,56,0.25,0.75,0.5,0.7,0.9,1,108}\n"
		"local attached=graphics.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'Extra','float',1}},attachedVertices,'points')\n"
		"batch:attachAttribute('VertexPosition',attached); batch:attachAttribute('VertexTexCoord',attached); batch:attachAttribute('VertexColor',attached); batch:attachAttribute('Extra',attached)\n"
		"local tooShort=graphics.newMesh({{'Extra','float',1}},{{1},{2},{3},{4}},'points')\n"
		"assert(not pcall(batch.attachAttribute,batch,'Missing',attached)); assert(not pcall(batch.attachAttribute,batch,'Extra',tooShort))\n"
		"assert(not pcall(batch.set, batch, 5, 0, 0)); assert(not pcall(graphics.newSpriteBatch, first, 0))\n"
		"batch:flush(); first=nil; second=nil; attached=nil; collectgarbage('collect'); assert(batch:getTexture() ~= nil)\n"
		"function love.draw() graphics.draw(batch, 3, 4, 0, 2, 2) end\n",
		"@sprite-batch.lua", error), error);
	require(spriteBatchRuntime.draw(error), error);
	require(spriteBatchGraphics.meshDraws == 1
		&& spriteBatchGraphics.lastMeshDrawMode == "triangles"
		&& spriteBatchGraphics.lastMeshImage == 2
		&& spriteBatchGraphics.lastMeshCanvas == 0
		&& spriteBatchGraphics.lastMeshVertices.size() == 4
		&& spriteBatchGraphics.lastMeshIndices == std::vector<std::uint32_t>({0, 1, 2, 0, 2, 3}),
		"SpriteBatch did not submit the selected sprite as one indexed Mesh draw");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].x, 83.0f,
		"SpriteBatch set/draw transformed x");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].y, 104.0f,
		"SpriteBatch set/draw transformed y");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].u, 0.25f,
		"SpriteBatch attached VertexTexCoord u coordinate");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].v, 0.375f,
		"SpriteBatch attached VertexTexCoord v coordinate");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].red, 0.2f,
		"SpriteBatch attached VertexColor red component");
	requireNear(spriteBatchGraphics.lastMeshVertices[0].alpha, 0.8f,
		"SpriteBatch attached VertexColor alpha component");
	require(spriteBatchGraphics.lastMeshAttributes.size() == 1
		&& spriteBatchGraphics.lastMeshAttributes[0].name == "Extra"
		&& spriteBatchGraphics.lastMeshAttributes[0].components == 1
		&& spriteBatchGraphics.lastMeshAttributes[0].values
			== std::vector<float>({105.0f, 106.0f, 107.0f, 108.0f}),
		"SpriteBatch attached custom attribute did not honor the absolute draw range");
	execute(spriteBatchRuntime,
		"batch:add(0,0); function love.draw()\n"
		" local ok,message=pcall(love.graphics.draw,batch)\n"
		" assert(not ok and message:find('attached to this SpriteBatch has too few vertices',1,true))\n"
		"end\n",
		"@sprite-batch-attached-growth.lua");
	require(spriteBatchRuntime.draw(error) && spriteBatchGraphics.meshDraws == 1,
		"SpriteBatch did not revalidate attached Mesh size after growth");
	execute(spriteBatchRuntime,
		"local imageData=require('love.image').newImageData(2,2)\n"
		"local array=love.graphics.newArrayImage({imageData,imageData},{mipmaps=false})\n"
		"local layerQuad=love.graphics.newQuad(0,0,2,2,2,2); layerQuad:setLayer(2)\n"
		"arrayBatch=love.graphics.newSpriteBatch(array,2)\n"
		"assert(arrayBatch:add(layerQuad,0,0)==1)\n"
		"assert(arrayBatch:addLayer(1,2,0)==2)\n"
		"arrayBatch:setLayer(2,2,4,0)\n"
		"assert(arrayBatch:addLayer(1,6,0)==3 and arrayBatch:getBufferSize()==4)\n"
		"local arrayTexcoords={}\n"
		"for index=1,12 do arrayTexcoords[index]={0.25,0.5,(index>=5 and index<=8) and 1 or 0} end\n"
		"local arrayAttributes=love.graphics.newMesh({{'VertexTexCoord','float',3}},arrayTexcoords,'points')\n"
		"arrayBatch:attachAttribute('VertexTexCoord',arrayAttributes); arrayAttributes=nil; collectgarbage('collect')\n"
		"assert(not pcall(arrayBatch.addLayer,arrayBatch,0,0,0))\n"
		"assert(not pcall(arrayBatch.addLayer,arrayBatch,3,0,0))\n"
		"assert(not pcall(batch.addLayer,batch,1,0,0))\n"
		"assert(not pcall(arrayBatch.setTexture,arrayBatch,batch:getTexture()))\n"
		"function love.draw() love.graphics.draw(arrayBatch) end\n",
		"@sprite-batch-array.lua");
	require(spriteBatchRuntime.draw(error), error);
	require(spriteBatchGraphics.meshDraws == 2
		&& spriteBatchGraphics.lastMeshVertices.size() == 12
		&& spriteBatchGraphics.lastMeshImage == 3,
		"ArrayImage SpriteBatch did not submit one indexed layered Mesh draw");
	for (std::size_t index = 0; index < 4; ++index)
		requireNear(spriteBatchGraphics.lastMeshVertices[index].textureLayer, 0.0f,
			"ArrayImage SpriteBatch attached layer 1 coordinate");
	for (std::size_t index = 4; index < 8; ++index)
		requireNear(spriteBatchGraphics.lastMeshVertices[index].textureLayer, 1.0f,
			"ArrayImage SpriteBatch attached layer 2 coordinate");
	for (std::size_t index = 8; index < 12; ++index)
		requireNear(spriteBatchGraphics.lastMeshVertices[index].textureLayer, 0.0f,
			"ArrayImage SpriteBatch attached final layer 1 coordinate");
	execute(spriteBatchRuntime,
		"batch=love.graphics.newSpriteBatch(batch:getTexture(),2); batch:setColor()\n"
		"for index=1,1000 do batch:add((index % 40) * 8, math.floor(index / 40) * 8) end\n"
		"assert(batch:getCount()==1000 and batch:getBufferSize()==1024)\n"
		"function love.draw() love.graphics.draw(batch) end\n",
		"@sprite-batch-baseline.lua");
	require(spriteBatchRuntime.draw(error), error);
	require(spriteBatchGraphics.meshDraws == 3
		&& spriteBatchGraphics.lastMeshVertices.size() == 4000
		&& spriteBatchGraphics.lastMeshIndices.size() == 6000,
		"SpriteBatch 1000-sprite baseline was not submitted as one additional batch draw");
	execute(spriteBatchRuntime,
		"local canvas=love.graphics.newCanvas(32,16)\n"
		"local canvasBatch=love.graphics.newSpriteBatch(canvas,2); canvasBatch:add(0,0)\n"
		"function love.draw()\n"
		" love.graphics.setCanvas(canvas); assert(not pcall(love.graphics.draw,canvasBatch))\n"
		" love.graphics.setCanvas(); love.graphics.draw(canvasBatch)\n"
		"end\n",
		"@sprite-batch-canvas.lua");
	require(spriteBatchRuntime.draw(error), error);
	require(spriteBatchGraphics.meshDraws == 4
		&& spriteBatchGraphics.lastMeshCanvas == 100
		&& spriteBatchGraphics.lastMeshImage == 0,
		"SpriteBatch Canvas feedback rejection or subsequent Canvas texture draw failed");
	spriteBatchRuntime.close();
	require(spriteBatchGraphics.imagesCreated == 3 && spriteBatchGraphics.imagesReleased == 3,
		"SpriteBatch texture references did not preserve and release Image userdata ownership");
	require(spriteBatchGraphics.canvasesCreated == 1 && spriteBatchGraphics.canvasesReleased == 1,
		"SpriteBatch Canvas texture reference did not release with the Love state");

	MockGraphics particleGraphics;
	Dora::Love::LoveRuntime particleRuntime;
	particleRuntime.setGraphicsBackend(&particleGraphics);
	require(particleRuntime.open(error), error);
	require(particleRuntime.boot(
		"local g=love.graphics\n"
		"local image=g.newImage('particles.png')\n"
		"local quad1=g.newQuad(4,2,8,6,32,16); local quad2=g.newQuad(12,2,8,6,32,16)\n"
		"particles=g.newParticleSystem(image,3)\n"
		"assert(particles:getTexture()==image and particles:getBufferSize()==3 and particles:isActive() and particles:isEmpty())\n"
		"particles:setInsertMode('bottom'); assert(particles:getInsertMode()=='bottom')\n"
		"particles:setEmitterLifetime(5); particles:setParticleLifetime(2); particles:setPosition(10,20)\n"
		"particles:setAreaSpread('uniform',1,2); local area,x,y=particles:getAreaSpread(); assert(area=='uniform' and x==1 and y==2)\n"
		"particles:setEmissionArea('none'); particles:setDirection(0); particles:setSpread(0); particles:setSpeed(10)\n"
		"particles:setLinearAcceleration(0,0); particles:setRadialAcceleration(0); particles:setTangentialAcceleration(0); particles:setLinearDamping(0)\n"
		"particles:setSizes(1,2); particles:setSizeVariation(0); assert(not pcall(particles.setSizeVariation,particles,2)); particles:setRotation(0); particles:setSpin(0); particles:setSpinVariation(0)\n"
		"particles:setColors({1,0,0,1},{0,0,1,1}); particles:setQuads(quad1,quad2)\n"
		"particles:setRelativeRotation(false); assert(not particles:hasRelativeRotation())\n"
		"particles:emit(3); assert(particles:getCount()==3 and particles:isFull())\n"
		"particles:update(0.5); particles:pause(); assert(particles:isPaused() and not particles:isActive())\n"
		"local clone=particles:clone(); assert(clone:getCount()==0 and clone:getBufferSize()==3 and clone:getTexture()==image)\n"
		"clone:start(); clone:emit(1); assert(clone:getCount()==1); clone:stop(); assert(clone:isStopped())\n"
		"image=nil; collectgarbage('collect'); assert(particles:getTexture()~=nil)\n"
		"function love.draw() g.setBlendMode('add'); g.draw(particles,3,4,0,2,2); g.setBlendMode('alpha') end\n",
		"@particle-system.lua", error), error);
	require(particleRuntime.draw(error), error);
	require(particleGraphics.meshDraws == 1
		&& particleGraphics.lastMeshDrawMode == "triangles"
		&& particleGraphics.lastMeshImage == 1
		&& particleGraphics.lastMeshVertices.size() == 12
		&& particleGraphics.lastMeshIndices.size() == 18,
		"ParticleSystem did not submit all live particles as one indexed Mesh draw");
	requireNear(particleGraphics.lastMeshVertices[0].x, 23.0f,
		"ParticleSystem velocity/size/outer transform x");
	requireNear(particleGraphics.lastMeshVertices[0].y, 36.5f,
		"ParticleSystem size/outer transform y");
	requireNear(particleGraphics.lastMeshVertices[0].u, 0.125f,
		"ParticleSystem Quad u coordinate");
	requireNear(particleGraphics.lastMeshVertices[0].v, 0.125f,
		"ParticleSystem Quad v coordinate");
	requireNear(particleGraphics.lastMeshVertices[0].red, 0.75f,
		"ParticleSystem lifetime color interpolation red");
	requireNear(particleGraphics.lastMeshVertices[0].blue, 0.25f,
		"ParticleSystem lifetime color interpolation blue");
	execute(particleRuntime,
		"local baseline=love.graphics.newParticleSystem(particles:getTexture(),1000)\n"
		"baseline:setParticleLifetime(1); baseline:emit(1000); assert(baseline:isFull())\n"
		"function love.draw() love.graphics.draw(baseline) end\n",
		"@particle-system-baseline.lua");
	require(particleRuntime.draw(error), error);
	require(particleGraphics.meshDraws == 2
		&& particleGraphics.lastMeshVertices.size() == 4000
		&& particleGraphics.lastMeshIndices.size() == 6000,
		"ParticleSystem 1000-particle baseline was not submitted as one additional batch draw");
	execute(particleRuntime,
		"particles:start(); particles:update(2); assert(particles:isEmpty())\n"
		"particles:setBufferSize(2); assert(particles:getBufferSize()==2 and particles:isEmpty())\n"
		"local canvas=love.graphics.newCanvas(32,16); particles:setTexture(canvas); particles:setParticleLifetime(1); particles:emit(1)\n"
		"function love.draw() love.graphics.setCanvas(canvas); assert(not pcall(love.graphics.draw,particles)); love.graphics.setCanvas(); love.graphics.draw(particles) end\n",
		"@particle-system-canvas.lua");
	require(particleRuntime.draw(error), error);
	require(particleGraphics.meshDraws == 3 && particleGraphics.lastMeshCanvas == 100,
		"ParticleSystem Canvas feedback rejection or subsequent Canvas draw failed");
	particleRuntime.close();
	require(particleGraphics.imagesCreated == 1 && particleGraphics.imagesReleased == 1
		&& particleGraphics.canvasesCreated == 1 && particleGraphics.canvasesReleased == 1,
		"ParticleSystem texture references did not preserve and release backend resources");

	MockGraphics meshCacheGraphics;
	Dora::Love::LoveRuntime meshCacheRuntime;
	meshCacheRuntime.setGraphicsBackend(&meshCacheGraphics);
	require(meshCacheRuntime.open(error), error);
	require(meshCacheRuntime.boot(
		"local g=love.graphics; local image=g.newImage('cache.png')\n"
		"batch=g.newSpriteBatch(image,2); batch:add(0,0)\n"
		"mesh=g.newMesh({{0,0,0,0},{8,0,1,0},{0,8,0,1}},'triangles'); mesh:setTexture(image)\n"
		"particles=g.newParticleSystem(image,2); particles:setParticleLifetime(2); particles:emit(1)\n"
		"function love.draw() g.draw(batch); g.draw(mesh); g.draw(particles) end\n",
		"@mesh-buffer-cache.lua", error), error);
	require(meshCacheRuntime.draw(error) && meshCacheRuntime.draw(error), error);
	require(meshCacheGraphics.meshBufferRecords.size() == 6,
		"cached SpriteBatch, Mesh, and ParticleSystem did not use reusable Mesh buffers");
	for (std::size_t index = 0; index < 3; ++index)
	{
		require(meshCacheGraphics.meshBufferRecords[index].first
			== meshCacheGraphics.meshBufferRecords[index + 3].first,
			"repeated draw replaced a reusable Mesh buffer");
		require(meshCacheGraphics.meshBufferRecords[index].second
			== meshCacheGraphics.meshBufferRecords[index + 3].second,
			"unchanged SpriteBatch, Mesh, or ParticleSystem rebuilt its expanded geometry");
	}
	execute(meshCacheRuntime,
		"batch:set(1,2,3); mesh:setVertex(1,1,1,0,0); particles:update(0.1)\n",
		"@mesh-buffer-cache-mutate.lua");
	require(meshCacheRuntime.draw(error), error);
	require(meshCacheGraphics.meshBufferRecords.size() == 9, "mutated Mesh buffers were not redrawn");
	for (std::size_t index = 0; index < 3; ++index)
		require(meshCacheGraphics.meshBufferRecords[index + 6].second
			> meshCacheGraphics.meshBufferRecords[index + 3].second,
			"mutated SpriteBatch, Mesh, or ParticleSystem did not rebuild cached geometry");
	meshCacheRuntime.close();
	require(meshCacheRuntime.getAllocationBytes() == 0,
		"Mesh buffer cache test retained Lua allocations");

	MockGraphics textGraphics;
	Dora::Love::LoveRuntime textRuntime;
	textRuntime.setGraphicsBackend(&textGraphics);
	require(textRuntime.open(error), error);
	require(textRuntime.boot(
		"local g=love.graphics\n"
		"local font18=g.newFont(18); local font24=g.newFont(24)\n"
		"local empty=g.newText(font18); assert(empty:getWidth()==0 and empty:getHeight()==0)\n"
		"text=g.newText(font18,{{1,0,0,1},'AB',{0,0,1,0.5},'CD'})\n"
		"local w,h=text:getDimensions(); assert(w==36 and h==18 and text:getFont()==font18)\n"
		"assert(text:add('XY',30,40)==2)\n"
		"local transform=love.math.newTransform(5,6)\n"
		"assert(text:addf('a b',100,'justify',transform)==3)\n"
		"w,h=text:getDimensions(); assert(w==27 and h==18)\n"
		"g.setColor(0.5,1,0.5,0.5)\n"
		"function love.draw() g.draw(text,10,20,0,2,2) end\n"
		"text:setFont(font24); assert(text:getFont()==font24)\n"
		"w,h=text:getDimensions(1); assert(w==48 and h==24)\n",
		"@text-batch.lua", error), error);
	require(textRuntime.draw(error), error);
	require(textGraphics.textDrawRecords.size() == 5,
		"Text did not retain and submit all colored, appended, and justified layout runs");
	const auto &redRun = textGraphics.textDrawRecords[0];
	const auto &blueRun = textGraphics.textDrawRecords[1];
	const auto &appendedRun = textGraphics.textDrawRecords[2];
	const auto &justifiedTail = textGraphics.textDrawRecords[4];
	require(redRun.font == 11 && redRun.text == "AB" && blueRun.text == "CD",
		"Text did not draw colored fragments with its replacement Font");
	requireNear(redRun.matrix[0], 2.0f, "Text outer scale");
	requireNear(redRun.matrix[4], 10.0f, "Text outer translation x");
	requireNear(redRun.matrix[5], 20.0f, "Text outer translation y");
	requireNear(blueRun.matrix[4], 58.0f, "Text colored fragment x after Font replacement");
	requireNear(redRun.color[0], 0.5f, "Text global/fragment red multiplication");
	requireNear(redRun.color[3], 0.5f, "Text global/fragment alpha multiplication");
	requireNear(blueRun.color[2], 0.5f, "Text global/fragment blue multiplication");
	requireNear(blueRun.color[3], 0.25f, "Text fragment alpha multiplication");
	requireNear(appendedRun.matrix[4], 70.0f, "Text appended standard transform x");
	requireNear(appendedRun.matrix[5], 100.0f, "Text appended standard transform y");
	require(justifiedTail.text == "b", "Text justify did not split the tail after an expandable space");
	requireNear(justifiedTail.matrix[4], 196.0f, "Text justify extra spacing and Transform x");
	execute(textRuntime,
		"text:setf('hello world',80,'center'); local w,h=text:getDimensions(); assert(w==60 and h==48)\n"
		"text:clear(); assert(text:getWidth()==0 and text:getHeight()==0)\n",
		"@text-batch-update.lua");
	const int drawsBeforeClear = textGraphics.textDraws;
	require(textRuntime.draw(error), error);
	require(textGraphics.textDraws == drawsBeforeClear,
		"cleared Text unexpectedly retained drawable layout runs");
	textRuntime.close();
	require(textGraphics.fontsCreated == 2 && textGraphics.fontsReleased == 2
		&& textGraphics.fontSizes.empty(),
		"Text Font uservalue or setFont lifecycle did not release backend resources");

	MockPhysics firstPhysics;
	MockPhysics secondPhysics;
	Dora::Love::LoveRuntime firstPhysicsRuntime;
	Dora::Love::LoveRuntime secondPhysicsRuntime;
	firstPhysicsRuntime.setPhysicsBackend(&firstPhysics);
	secondPhysicsRuntime.setPhysicsBackend(&secondPhysics);
	require(firstPhysicsRuntime.open(error), error);
	require(secondPhysicsRuntime.open(error), error);
	execute(firstPhysicsRuntime,
		"local p=require('love.physics'); assert(p==love.physics and p.getMeter()==30)\n"
		"p.setMeter(64); assert(p.getMeter()==64)\n"
		"world=p.newWorld(0,10,true); local gx,gy=world:getGravity(); assert(gx==0 and gy==10)\n"
		"bodyA=p.newBody(world,10,20,'dynamic'); bodyB=p.newBody(world,40,20,'static')\n"
		"assert(world:isSleepingAllowed()); world:setSleepingAllowed(false); assert(not world:isSleepingAllowed() and not bodyA:isSleepingAllowed() and not bodyB:isSleepingAllowed()); world:setSleepingAllowed(true); assert(world:isSleepingAllowed() and bodyA:isSleepingAllowed())\n"
		"circle=p.newCircleShape(3,4,8); assert(circle:getType()=='circle' and circle:getRadius()==8 and circle:type()=='CircleShape' and circle:typeOf('CircleShape') and circle:typeOf('Shape') and circle:typeOf('Object') and not circle:typeOf('PolygonShape'))\n"
		"local cx,cy=circle:getPoints(); assert(cx==3 and cy==4)\n"
		"rectangle=p.newRectangleShape(20,10); assert(rectangle:getType()=='polygon'); local x1,y1,x2,y2,x3,y3,x4,y4=rectangle:getPoints(); assert(x1==-10 and y1==-5 and x2==10 and y2==-5 and x3==10 and y3==5 and x4==-10 and y4==5)\n"
		"polygon=p.newPolygonShape({0,0,20,0,10,15}); assert(polygon:getType()=='polygon' and polygon:validate()); local pgx,pgy=polygon:getPoints(); assert(pgx==0 and pgy==0)\n"
		"polygon2=p.newPolygonShape(0,0,12,0,6,9); assert(polygon2:validate())\n"
		"edge=p.newEdgeShape(-20,0,20,0); assert(edge:getType()=='edge'); local ex1,ey1,ex2,ey2=edge:getPoints(); assert(ex1==-20 and ey1==0 and ex2==20 and ey2==0)\n"
		"edge:setPreviousVertex(-30,5); edge:setNextVertex(30,5); local epx,epy=edge:getPreviousVertex(); local enx,eny=edge:getNextVertex(); assert(epx==-30 and epy==5 and enx==30 and eny==5); edge:setPreviousVertex(); assert(select('#',edge:getPreviousVertex())==0); edge:setPreviousVertex(-30,5)\n"
		"chain=p.newChainShape(false,{-20,0,0,-10,20,0}); chain:setPreviousVertex(-30,5); chain:setNextVertex(30,5); assert(chain:getType()=='chain' and chain:getVertexCount()==3); local chx,chy=chain:getPoint(2); assert(chx==0 and chy==-10); childEdge=chain:getChildEdge(1); local cpx,cpy=childEdge:getPreviousVertex(); assert(childEdge:getType()=='edge' and cpx==-30 and cpy==5); local cnx,cny=childEdge:getNextVertex(); assert(cnx==20 and cny==0); local lastEdge=chain:getChildEdge(2); local lnx,lny=lastEdge:getNextVertex(); assert(lnx==30 and lny==5); chain:setNextVertex(); assert(select('#',chain:getNextVertex())==0)\n"
		"loopChain=p.newChainShape(true,0,0,20,0,10,15); assert(loopChain:getVertexCount()==4); local lx,ly=loopChain:getPoint(4); assert(lx==0 and ly==0); local lpx,lpy=loopChain:getPreviousVertex(); local lnx,lny=loopChain:getNextVertex(); assert(lpx==10 and lpy==15 and lnx==20 and lny==0); loopEdge=loopChain:getChildEdge(3); local epx,epy=loopEdge:getPreviousVertex(); local elx,ely=loopEdge:getNextVertex(); assert(epx==20 and epy==0 and elx==20 and ely==0)\n"
		"assert(not pcall(p.newPolygonShape,0,0,10,0)); assert(not pcall(p.newPolygonShape,0,0,10,0,10,10,0,10,5,5,3,4,2,3,1,2,9,9)); assert(not pcall(p.newEdgeShape,0,0,0,0)); assert(not pcall(p.newChainShape,true,0,0,10,0))\n"
		"fixture=p.newFixture(bodyA,circle,2); fixtureB=p.newFixture(bodyB,rectangle,0); fixture:setFriction(0.6); fixture:setRestitution(0.4); fixture:setSensor(true)\n"
		"bodies=world:getBodies(); assert(#bodies==2 and ((bodies[1]==bodyA and bodies[2]==bodyB) or (bodies[1]==bodyB and bodies[2]==bodyA))); fixtures=bodyA:getFixtures(); assert(#fixtures==1 and fixtures[1]==fixture)\n"
		"assert(math.abs(fixture:getFriction()-0.6)<1e-5 and math.abs(fixture:getRestitution()-0.4)<1e-5 and fixture:isSensor())\n"
		"assert(fixture:getType()=='circle' and fixture:getBody()==bodyA and fixture:getShape()==circle and fixture:getDensity()==2); fixture:setDensity(3); assert(fixture:getDensity()==3 and fixture:testPoint(13,24) and not fixture:testPoint(30,40))\n"
		"local fnx,fny,ff=fixture:rayCast(0,24,30,24,1); assert(fnx==-1 and fny==0 and ff==0.25 and select('#',fixture:rayCast(0,24,30,24,0.2))==0); local fbx1,fby1,fbx2,fby2=fixture:getBoundingBox(); assert(fbx1==5 and fby1==16 and fbx2==21 and fby2==32); local fmx,fmy,fmm,fmi=fixture:getMassData(); assert(fmx==3 and fmy==4 and fmm==6 and fmi==9)\n"
		"local fc,fmask,fg=fixture:getFilterData(); assert(fc==1 and fmask==65535 and fg==0); fixture:setFilterData(5,10,-2); fc,fmask,fg=fixture:getFilterData(); assert(fc==5 and fmask==10 and fg==-2); fixture:setCategory(1,3,16); local c1,c2,c3=fixture:getCategory(); assert(c1==1 and c2==3 and c3==16); fixture:setMask({2,4}); local m1,m2=fixture:getMask(); assert(m1==2 and m2==4); fixture:setGroupIndex(32767); assert(fixture:getGroupIndex()==32767); fixture:setGroupIndex(-32768); assert(fixture:getGroupIndex()==-32768); local fixtureMarker={kind='fixture'}; fixture:setUserData(fixtureMarker); assert(fixture:getUserData()==fixtureMarker); fixture:setUserData(nil); assert(fixture:getUserData()==nil)\n"
		"assert(not pcall(fixture.setDensity,fixture,-1) and not pcall(fixture.setCategory,fixture,17) and not pcall(fixture.setGroupIndex,fixture,32768) and not pcall(fixture.setGroupIndex,fixture,-32769) and not pcall(fixture.getBoundingBox,fixture,2) and not pcall(fixture.rayCast,fixture,0,0,1,1,2))\n"
		"assert(bodyA:getMass()==2 and bodyA:getInertia()==3); local mdx,mdy,mdm,mdi=bodyA:getMassData(); assert(mdx==0 and mdy==0 and mdm==2 and mdi==3); bodyA:setMassData(1,2,5,40); mdx,mdy,mdm,mdi=bodyA:getMassData(); assert(mdx==1 and mdy==2 and mdm==5 and mdi==40); bodyA:setMass(6); bodyA:setInertia(50); assert(bodyA:getMass()==6 and bodyA:getInertia()==50); bodyA:resetMassData(); assert(bodyA:getMass()==2 and bodyA:getInertia()==3); assert(not pcall(bodyA.setMassData,bodyA,0,0,0/0,3))\n"
		"assert(bodyA:getGravityScale()==1); bodyA:setGravityScale(2); assert(bodyA:getGravityScale()==2)\n"
		"local lcx,lcy=bodyA:getLocalCenter(); local wcx,wcy=bodyA:getWorldCenter(); assert(lcx==0 and lcy==0 and wcx==10 and wcy==20)\n"
		"assert(bodyA:getX()==10 and bodyA:getY()==20); bodyA:setX(12); bodyA:setY(22); local tx,ty,ta=bodyA:getTransform(); assert(tx==12 and ty==22 and ta==0); bodyA:setTransform(10,20,math.pi/2); tx,ty,ta=bodyA:getTransform(); assert(math.abs(tx-10)<1e-5 and math.abs(ty-20)<1e-5 and math.abs(ta-math.pi/2)<1e-5)\n"
		"local wx,wy=bodyA:getWorldPoint(2,3); assert(math.abs(wx-7)<1e-4 and math.abs(wy-22)<1e-4); local wvx,wvy=bodyA:getWorldVector(2,3); assert(math.abs(wvx+3)<1e-4 and math.abs(wvy-2)<1e-4); local wx1,wy1,wx2,wy2=bodyA:getWorldPoints(2,3,-1,4); assert(math.abs(wx1-7)<1e-4 and math.abs(wy1-22)<1e-4 and math.abs(wx2-6)<1e-4 and math.abs(wy2-19)<1e-4)\n"
		"local lx,ly=bodyA:getLocalPoint(wx,wy); local lvx,lvy=bodyA:getLocalVector(wvx,wvy); local lx1,ly1,lx2,ly2=bodyA:getLocalPoints(wx1,wy1,wx2,wy2); assert(math.abs(lx-2)<1e-4 and math.abs(ly-3)<1e-4 and math.abs(lvx-2)<1e-4 and math.abs(lvy-3)<1e-4 and math.abs(lx1-2)<1e-4 and math.abs(ly1-3)<1e-4 and math.abs(lx2+1)<1e-4 and math.abs(ly2-4)<1e-4); assert(not pcall(bodyA.getWorldPoints,bodyA,1,2,3))\n"
		"bodyA:setLinearVelocity(4,5); bodyA:setAngularVelocity(2); local pvx,pvy=bodyA:getLinearVelocityFromWorldPoint(10,23); local plx,ply=bodyA:getLinearVelocityFromLocalPoint(3,0); assert(math.abs(pvx+2)<1e-4 and math.abs(pvy-5)<1e-4 and math.abs(plx+2)<1e-4 and math.abs(ply-5)<1e-4); bodyA:setTransform(10,20,0)\n"
		"bodyA:setLinearDamping(0.2); bodyA:setAngularDamping(0.3); assert(math.abs(bodyA:getLinearDamping()-0.2)<1e-5 and math.abs(bodyA:getAngularDamping()-0.3)<1e-5); bodyA:setFixedRotation(true); assert(bodyA:isFixedRotation()); bodyA:setFixedRotation(false); assert(not bodyA:isFixedRotation())\n"
		"assert(bodyA:isAwake() and bodyA:isSleepingAllowed() and bodyA:isActive() and not bodyA:isBullet()); bodyA:setAwake(false); assert(not bodyA:isAwake()); bodyA:setAwake(true); bodyA:setSleepingAllowed(false); assert(not bodyA:isSleepingAllowed()); bodyA:setSleepingAllowed(true); bodyA:setActive(false); assert(not bodyA:isActive()); bodyA:setActive(true); bodyA:setBullet(true); assert(bodyA:isBullet()); bodyA:setBullet(false); bodyA:setType('kinematic'); assert(bodyA:getType()=='kinematic'); bodyA:setType('dynamic'); assert(bodyA:getType()=='dynamic'); assert(not pcall(bodyA.setType,bodyA,'invalid'))\n"
		"assert(not pcall(bodyA.setLinearDamping,bodyA,-1) and not pcall(bodyA.setAngularDamping,bodyA,0/0))\n"
		"joint=p.newDistanceJoint(bodyA,bodyB,10,20,40,20,false); assert(joint:getType()=='distance' and joint:type()=='DistanceJoint' and joint:typeOf('DistanceJoint') and joint:typeOf('Joint') and joint:typeOf('Object') and not joint:typeOf('RevoluteJoint'))\n"
		"local ja,jb=joint:getBodies(); assert(ja==bodyA and jb==bodyB); local jx1,jy1,jx2,jy2=joint:getAnchors(); assert(jx1==10 and jy1==20 and jx2==40 and jy2==20 and not joint:getCollideConnected())\n"
		"local jfx,jfy=joint:getReactionForce(2); assert(jfx==4 and jfy==6 and joint:getReactionTorque(2)==8); joint:setLength(25); joint:setFrequency(3); joint:setDampingRatio(0.4); assert(joint:getLength()==25 and joint:getFrequency()==3 and math.abs(joint:getDampingRatio()-0.4)<1e-5); local marker={kind='joint'}; joint:setUserData(marker); assert(joint:getUserData()==marker); joint:setUserData(nil); assert(joint:getUserData()==nil); assert(not pcall(joint.setLength,joint,-1) and not pcall(joint.getReactionForce,joint,0/0))\n"
		"revolute=p.newRevoluteJoint(bodyA,bodyB,10,20,11,21,false,0.25); assert(revolute:getType()=='revolute'); local ra,rb=revolute:getBodies(); assert(ra==bodyA and rb==bodyB); local rx1,ry1,rx2,ry2=revolute:getAnchors(); assert(rx1==10 and ry1==20 and rx2==11 and ry2==21 and not revolute:getCollideConnected()); assert(math.abs(revolute:getReferenceAngle()-0.25)<1e-5 and math.abs(revolute:getJointAngle()+0.25)<1e-5 and math.abs(revolute:getJointSpeed()+2)<1e-5)\n"
		"assert(not revolute:isMotorEnabled()); revolute:setMotorEnabled(true); revolute:setMaxMotorTorque(64); revolute:setMotorSpeed(2); assert(revolute:isMotorEnabled() and revolute:getMaxMotorTorque()==64 and revolute:getMotorSpeed()==2 and revolute:getMotorTorque(3)==6); revolute:setLimits(-0.5,0.75); revolute:setLimitsEnabled(true); local lower,upper=revolute:getLimits(); assert(revolute:areLimitsEnabled() and revolute:hasLimitsEnabled() and lower==-0.5 and upper==0.75); revolute:setLowerLimit(-0.4); revolute:setUpperLimit(0.6); assert(math.abs(revolute:getLowerLimit()+0.4)<1e-5 and math.abs(revolute:getUpperLimit()-0.6)<1e-5)\n"
		"assert(not pcall(revolute.setMaxMotorTorque,revolute,-1) and not pcall(revolute.getMotorTorque,revolute,0/0) and not pcall(revolute.setLimits,revolute,1,-1) and not pcall(revolute.setUpperLimit,revolute,-1) and not pcall(revolute.getLength,revolute)); local shared=p.newRevoluteJoint(bodyA,bodyB,7,8,true); local sx1,sy1,sx2,sy2=shared:getAnchors(); assert(sx1==7 and sy1==8 and sx2==7 and sy2==8 and shared:getCollideConnected()); shared:destroy()\n"
		"prismatic=p.newPrismaticJoint(bodyA,bodyB,10,20,13,24,3,4,false,0.15); assert(prismatic:getType()=='prismatic'); local pax,pay=prismatic:getAxis(); assert(math.abs(pax-0.6)<1e-5 and math.abs(pay-0.8)<1e-5 and math.abs(prismatic:getJointTranslation()-5)<1e-5 and math.abs(prismatic:getJointSpeed()+6.4)<1e-5 and math.abs(prismatic:getReferenceAngle()-0.15)<1e-5); local pl,pu=prismatic:getLimits(); assert(prismatic:areLimitsEnabled() and pl==0 and pu==6400)\n"
		"prismatic:setMaxMotorForce(128); prismatic:setMotorSpeed(24); prismatic:setMotorEnabled(true); prismatic:setLimits(-20,80); assert(prismatic:isMotorEnabled() and prismatic:getMaxMotorForce()==128 and prismatic:getMotorSpeed()==24 and prismatic:getMotorForce(2)==6); prismatic:setLowerLimit(-10); prismatic:setUpperLimit(60); pl,pu=prismatic:getLimits(); assert(pl==-10 and pu==60); prismatic:setLimitsEnabled(false); assert(not prismatic:areLimitsEnabled() and not prismatic:hasLimitsEnabled())\n"
		"assert(not pcall(p.newPrismaticJoint,bodyA,bodyB,0,0,0,0,false) and not pcall(prismatic.setMaxMotorForce,prismatic,-1) and not pcall(prismatic.getMotorForce,prismatic,0/0) and not pcall(prismatic.getJointAngle,prismatic)); local sharedPrismatic=p.newPrismaticJoint(bodyA,bodyB,7,8,1,0,true); assert(sharedPrismatic:getType()=='prismatic' and sharedPrismatic:getCollideConnected()); sharedPrismatic:destroy()\n"
		"weld=p.newWeldJoint(bodyA,bodyB,10,20,12,22,false,0.2); assert(weld:getType()=='weld' and math.abs(weld:getReferenceAngle()-0.2)<1e-5 and weld:getFrequency()==0 and weld:getDampingRatio()==0); local wx1,wy1,wx2,wy2=weld:getAnchors(); assert(wx1==10 and wy1==20 and wx2==12 and wy2==22 and not weld:getCollideConnected()); weld:setFrequency(5); weld:setDampingRatio(0.6); assert(weld:getFrequency()==5 and math.abs(weld:getDampingRatio()-0.6)<1e-5)\n"
		"assert(not pcall(weld.setFrequency,weld,-1) and not pcall(weld.setDampingRatio,weld,0/0) and not pcall(weld.getLength,weld) and not pcall(weld.getJointAngle,weld)); local sharedWeld=p.newWeldJoint(bodyA,bodyB,7,8,true); assert(sharedWeld:getType()=='weld' and sharedWeld:getCollideConnected()); sharedWeld:destroy()\n"
		"friction=p.newFrictionJoint(bodyA,bodyB,10,20,12,22,false); assert(friction:getType()=='friction' and friction:getMaxForce()==0 and friction:getMaxTorque()==0); local fx1,fy1,fx2,fy2=friction:getAnchors(); assert(fx1==10 and fy1==20 and fx2==12 and fy2==22 and not friction:getCollideConnected()); friction:setMaxForce(128); friction:setMaxTorque(4096); assert(friction:getMaxForce()==128 and friction:getMaxTorque()==4096)\n"
		"assert(not pcall(friction.setMaxForce,friction,-1) and not pcall(friction.setMaxTorque,friction,0/0) and not pcall(friction.getFrequency,friction) and not pcall(friction.getMotorForce,friction,60)); local sharedFriction=p.newFrictionJoint(bodyA,bodyB,7,8,true); assert(sharedFriction:getType()=='friction' and sharedFriction:getCollideConnected()); sharedFriction:destroy()\n"
		"rope=p.newRopeJoint(bodyA,bodyB,10,20,12,22,128,true); assert(rope:getType()=='rope' and rope:getMaxLength()==128 and rope:getCollideConnected()); local rox1,roy1,rox2,roy2=rope:getAnchors(); assert(rox1==10 and roy1==20 and rox2==12 and roy2==22); rope:setMaxLength(64); assert(rope:getMaxLength()==64)\n"
		"assert(not pcall(p.newRopeJoint,bodyA,bodyB,0,0,0,0,-1) and not pcall(rope.setMaxLength,rope,-1) and not pcall(rope.setMaxLength,rope,0/0) and not pcall(rope.getLength,rope) and not pcall(friction.getMaxLength,friction)); rope:destroy(); assert(rope:isDestroyed() and not pcall(rope.getMaxLength,rope))\n"
		"pulley=p.newPulleyJoint(bodyA,bodyB,0,0,100,0,0,30,100,40,2); assert(pulley:getType()=='pulley' and pulley:getCollideConnected() and pulley:getRatio()==2 and pulley:getLengthA()==30 and pulley:getLengthB()==40); local pgx1,pgy1,pgx2,pgy2=pulley:getGroundAnchors(); assert(pgx1==0 and pgy1==0 and pgx2==100 and pgy2==0); local pax1,pay1,pax2,pay2=pulley:getAnchors(); assert(pax1==0 and pay1==30 and pax2==100 and pay2==40)\n"
		"local defaultPulley=p.newPulleyJoint(bodyA,bodyB,0,0,100,0,0,30,100,40); assert(defaultPulley:getRatio()==1 and defaultPulley:getCollideConnected()); defaultPulley:destroy(); assert(not pcall(p.newPulleyJoint,bodyA,bodyB,0,0,100,0,0,30,100,40,0) and not pcall(p.newPulleyJoint,bodyA,bodyB,0,0,100,0,0,30,100,40,0/0) and not pcall(friction.getRatio,friction)); pulley:destroy(); assert(pulley:isDestroyed() and not pcall(pulley.getLengthA,pulley))\n"
		"wheel=p.newWheelJoint(bodyA,bodyB,10,20,12,24,0,2,true); assert(wheel:getType()=='wheel' and wheel:getCollideConnected() and wheel:getJointTranslation()==4); local wax,way=wheel:getAxis(); assert(wax==0 and way==1 and not wheel:isMotorEnabled() and wheel:getMotorSpeed()==0 and wheel:getMaxMotorTorque()==0 and wheel:getSpringFrequency()==2 and math.abs(wheel:getSpringDampingRatio()-0.7)<0.001)\n"
		"bodyA:setAngularVelocity(1); bodyB:setAngularVelocity(3); assert(wheel:getJointSpeed()==128); wheel:setMotorEnabled(true); wheel:setMotorSpeed(2.5); wheel:setMaxMotorTorque(4096); wheel:setSpringFrequency(5); wheel:setSpringDampingRatio(0.4); assert(wheel:isMotorEnabled() and wheel:getMotorSpeed()==2.5 and wheel:getMaxMotorTorque()==4096 and wheel:getMotorTorque(60)==60 and wheel:getSpringFrequency()==5 and math.abs(wheel:getSpringDampingRatio()-0.4)<0.001)\n"
		"local sharedWheel=p.newWheelJoint(bodyA,bodyB,5,6,3,4,false); assert(sharedWheel:getType()=='wheel' and not sharedWheel:getCollideConnected()); sharedWheel:destroy(); assert(not pcall(p.newWheelJoint,bodyA,bodyB,0,0,0,0) and not pcall(wheel.setMaxMotorTorque,wheel,-1) and not pcall(wheel.setMotorSpeed,wheel,0/0) and not pcall(wheel.setSpringFrequency,wheel,-1) and not pcall(wheel.setSpringDampingRatio,wheel,0/0) and not pcall(friction.getSpringFrequency,friction)); wheel:destroy(); assert(wheel:isDestroyed() and not pcall(wheel.getAxis,wheel)); bodyA:setAngularVelocity(0); bodyB:setAngularVelocity(0)\n"
		"mouse=p.newMouseJoint(bodyA,10,20); assert(mouse:getType()=='mouse' and not mouse:getCollideConnected()); local mouseBody,mouseNil=mouse:getBodies(); assert(mouseBody==bodyA and mouseNil==nil); local mtx,mty=mouse:getTarget(); assert(mtx==10 and mty==20 and mouse:getMaxForce()==2000 and mouse:getFrequency()==5 and math.abs(mouse:getDampingRatio()-0.7)<0.001); local max1,max2,max3,max4=mouse:getAnchors(); assert(max1==10 and max2==20 and max3==10 and max4==20)\n"
		"mouse:setTarget(50,60); mouse:setMaxForce(3000); mouse:setFrequency(7); mouse:setDampingRatio(0.5); mtx,mty=mouse:getTarget(); assert(mtx==50 and mty==60 and mouse:getMaxForce()==3000 and mouse:getFrequency()==7 and mouse:getDampingRatio()==0.5); local kinematic=p.newBody(world,0,0,'kinematic'); assert(not pcall(p.newMouseJoint,kinematic,0,0) and not pcall(mouse.setTarget,mouse,0/0,0) and not pcall(mouse.setMaxForce,mouse,-1) and not pcall(mouse.setFrequency,mouse,0) and not pcall(friction.getTarget,friction)); mouse:destroy(); assert(mouse:isDestroyed() and not pcall(mouse.getTarget,mouse)); kinematic:destroy()\n"
		"local defaultMotor=p.newMotorJoint(bodyA,bodyB); assert(defaultMotor:getType()=='motor' and not defaultMotor:getCollideConnected() and math.abs(defaultMotor:getCorrectionFactor()-0.3)<1e-5 and defaultMotor:getMaxForce()==64 and defaultMotor:getMaxTorque()==4096); defaultMotor:destroy()\n"
		"motor=p.newMotorJoint(bodyA,bodyB,0.4,true); assert(motor:getType()=='motor' and motor:getCollideConnected()); local mbA,mbB=motor:getBodies(); assert(mbA==bodyA and mbB==bodyB); local mox,moy=motor:getLinearOffset(); assert(mox==30 and moy==0 and motor:getAngularOffset()==0 and math.abs(motor:getCorrectionFactor()-0.4)<1e-5); local ma1,may1,ma2,may2=motor:getAnchors(); assert(ma1==10 and may1==20 and ma2==40 and may2==20)\n"
		"motor:setLinearOffset(12,-8); motor:setAngularOffset(0.25); motor:setMaxForce(128); motor:setMaxTorque(8192); motor:setCorrectionFactor(0.6); mox,moy=motor:getLinearOffset(); assert(mox==12 and moy==-8 and motor:getAngularOffset()==0.25 and motor:getMaxForce()==128 and motor:getMaxTorque()==8192 and math.abs(motor:getCorrectionFactor()-0.6)<1e-5); assert(not pcall(p.newMotorJoint,bodyA,bodyB,-0.1) and not pcall(p.newMotorJoint,bodyA,bodyB,1.1) and not pcall(motor.setLinearOffset,motor,0/0,0) and not pcall(motor.setAngularOffset,motor,0/0) and not pcall(motor.setMaxForce,motor,-1) and not pcall(motor.setMaxTorque,motor,-1) and not pcall(motor.setCorrectionFactor,motor,1.1) and not pcall(friction.getLinearOffset,friction)); motor:destroy(); assert(motor:isDestroyed() and not pcall(motor.getLinearOffset,motor))\n"
		"do local gearGroundA=p.newBody(world,-100,0,'static'); local gearBodyA=p.newBody(world,-50,0,'dynamic'); local gearGroundB=p.newBody(world,100,0,'static'); local gearBodyB=p.newBody(world,150,0,'dynamic'); local gearRev=p.newRevoluteJoint(gearGroundA,gearBodyA,-50,0,false); local gearPris=p.newPrismaticJoint(gearGroundB,gearBodyB,150,0,1,0,false)\n"
		"local defaultGear=p.newGearJoint(gearRev,gearPris); assert(defaultGear:getType()=='gear' and defaultGear:getRatio()==1 and not defaultGear:getCollideConnected()); defaultGear:destroy(); local gear=p.newGearJoint(gearRev,gearPris,2,true); local gjA,gjB=gear:getJoints(); local gbA,gbB=gear:getBodies(); assert(gjA==gearRev and gjB==gearPris and gbA==gearBodyA and gbB==gearBodyB and gear:getRatio()==2 and gear:getCollideConnected()); gear:setRatio(-3); assert(gear:getRatio()==-3); assert(not pcall(p.newGearJoint,gearRev,gearRev) and not pcall(p.newGearJoint,gearRev,friction) and not pcall(p.newGearJoint,gearRev,gearPris,0/0) and not pcall(gear.setRatio,gear,0/0) and not pcall(friction.getJoints,friction)); gearRev:destroy(); assert(gear:isDestroyed() and not pcall(gear.getRatio,gear)) end\n"
		"local begins,ends,pres,posts=0,0,0,0; local savedContact\n"
		"local beginCallback=function(a,b,contact) begins=begins+1; assert(a==fixture and b==fixtureB and contact:isValid() and contact:isTouching()); local fa,fb=contact:getFixtures(); assert(fa==a and fb==b); local ca,cb=contact:getChildren(); assert(ca==1 and cb==1); savedContact=contact; local px1,py1,px2,py2=contact:getPositions(); assert(px1==10 and py1==20 and px2==11 and py2==21); local nx,ny=contact:getNormal(); assert(nx==0 and ny==-1) end\n"
		"local endCallback=function(a,b,contact) ends=ends+1; assert(a==fixture and b==fixtureB and contact==savedContact and contact:isValid()) end\n"
		"local preCallback=function(a,b,contact) pres=pres+1; assert(a==fixture and b==fixtureB and contact==savedContact); if pres==1 then assert(math.abs(contact:getFriction()-0.3)<1e-5); contact:setFriction(0.8); contact:setRestitution(0.7); contact:setTangentSpeed(12); contact:setEnabled(false); assert(not contact:isEnabled()); contact:setEnabled(true); assert(contact:isEnabled() and math.abs(contact:getTangentSpeed()-12)<1e-5) end end\n"
		"local postCallback=function(a,b,contact,n1,t1,n2,t2) posts=posts+1; assert(a==fixture and b==fixtureB and contact==savedContact and n1==3 and t1==1 and n2==2 and t2==0.5); assert(math.abs(contact:getFriction()-0.8)<1e-5 and math.abs(contact:getRestitution()-0.7)<1e-5) end\n"
		"world:setCallbacks(beginCallback,endCallback,preCallback,postCallback); local cb,ce,cp,co=world:getCallbacks(); assert(cb==beginCallback and ce==endCallback and cp==preCallback and co==postCallback)\n"
		"bodyA:setLinearVelocity(2,3); bodyA:applyLinearImpulse(1,2); world:update(0.5,8,3)\n"
		"assert(begins==1 and ends==0 and pres==1 and posts==1 and savedContact:isValid())\n"
		"local x,y=bodyA:getPosition(); assert(x==11.5 and y==27.5)\n"
		"local vx,vy=bodyA:getLinearVelocity(); assert(vx==3 and vy==15)\n"
		"bodyA:setAngularVelocity(0.5); bodyA:applyAngularImpulse(0.25); bodyA:applyTorque(0.25); assert(bodyA:getAngularVelocity()==1); bodyA:applyForce(2,4); bodyA:applyForce(1,1,10,20); vx,vy=bodyA:getLinearVelocity(); assert(vx==6 and vy==20)\n"
		"bodyA:setPosition(7,9); bodyA:setAngle(0.25); assert(bodyA:getType()=='dynamic')\n"
		"x,y=bodyA:getPosition(); assert(x==7 and y==9 and bodyA:getAngle()==0.25)\n"
		"local queried={}; world:queryBoundingBox(0,0,50,30,function(item) queried[#queried+1]=item; return true end); assert(#queried==2 and ((queried[1]==fixture and queried[2]==fixtureB) or (queried[1]==fixtureB and queried[2]==fixture)))\n"
		"local stopped=0; world:queryBoundingBox(0,0,50,30,function() stopped=stopped+1; return false end); assert(stopped==1)\n"
		"local clipped={}; world:rayCast(0,9,50,9,function(item,hx,hy,nx,ny,fraction) clipped[#clipped+1]=item; assert(hx>=0 and hx<=50 and ny==-1); return fraction end); assert(#clipped==1 and clipped[1]==fixture)\n"
		"local ignored={}; world:rayCast(0,9,50,9,function(item) ignored[#ignored+1]=item; return -1 end); assert(#ignored==2 and ignored[1]==fixture and ignored[2]==fixtureB)\n"
		"world:update(0,8,3); assert(begins==1 and ends==1 and pres==2 and posts==2 and not savedContact:isValid()); assert(not pcall(function() savedContact:getFriction() end))\n"
		"world:setCallbacks(); local cb2,ce2,cp2,co2=world:getCallbacks(); assert(cb2==nil and ce2==nil and cp2==nil and co2==nil)\n",
		"@physics-core.lua");
	execute(firstPhysicsRuntime,
		"world:setCallbacks(nil,nil,function() error('contact boom') end,nil)\n"
		"local ok,message=pcall(world.update,world,0,8,3); assert(not ok and message:find('contact boom',1,true))\n",
		"@physics-contact-error.lua");
	execute(firstPhysicsRuntime,
		"local p=love.physics; local w=p.newWorld(0,10,true); local a=p.newBody(w,0,0,'dynamic'); local b=p.newBody(w,0,0,'static')\n"
		"local f=p.newFixture(a,circle,1); local j=p.newDistanceJoint(a,b,0,0,0,0,false)\n"
		"assert(not w:isDestroyed() and not a:isDestroyed() and not f:isDestroyed() and not j:isDestroyed())\n"
		"f:destroy(); f:destroy(); assert(f:isDestroyed() and not pcall(f.getFriction,f))\n"
		"j:destroy(); j:destroy(); assert(j:isDestroyed() and not pcall(j.getType,j))\n"
		"local f2=p.newFixture(a,circle,1); local j2=p.newDistanceJoint(a,b,0,0,0,0,false)\n"
		"a:destroy(); a:destroy(); assert(a:isDestroyed() and f2:isDestroyed() and j2:isDestroyed() and not b:isDestroyed())\n"
		"assert(not pcall(a.getType,a) and not pcall(f2.isSensor,f2) and not pcall(j2.getBodies,j2))\n"
		"w:destroy(); w:destroy(); assert(w:isDestroyed() and b:isDestroyed()); assert(not pcall(w.getGravity,w))\n",
		"@physics-destroy.lua");
	execute(secondPhysicsRuntime,
		"local p=require('love.physics'); assert(p.getMeter()==30); p.setMeter(12); assert(p.getMeter()==12)\n"
		"assert(love.physics.getMeter()==12)\n",
		"@physics-second-state.lua");
	requireNear(firstPhysics.meter, 64.0f, "first Love physics meter isolation");
	requireNear(secondPhysics.meter, 12.0f, "second Love physics meter isolation");
	firstPhysicsRuntime.close();
	secondPhysicsRuntime.close();
	require(firstPhysics.worlds.empty() && firstPhysics.bodies.empty() && firstPhysics.shapes.empty()
		&& firstPhysics.fixtures.empty() && firstPhysics.joints.empty(),
		"physics userdata graph did not release every backend handle at state close");
	require(firstPhysics.worldsReleased == 2 && firstPhysics.bodiesReleased == 9
		&& firstPhysics.shapesReleased == 10 && firstPhysics.fixturesReleased == 4
		&& firstPhysics.jointsReleased == 23,
		"physics backend release counts did not match World/Body/Shape/Fixture/Joint ownership");

	MockPhysics retainedPhysics;
	Dora::Love::LoveRuntime retainedPhysicsRuntime;
	retainedPhysicsRuntime.setPhysicsBackend(&retainedPhysics);
	require(retainedPhysicsRuntime.open(error), error);
	execute(retainedPhysicsRuntime,
		"local p=require('love.physics'); local w=p.newWorld(); local a=p.newBody(w,0,0,'dynamic'); local b=p.newBody(w,10,0,'static')\n"
		"local s=p.newCircleShape(2); local f=p.newFixture(a,s,1); local j=p.newDistanceJoint(a,b,0,0,10,0,false)\n"
		"assert(w:release() and a:release() and b:release() and s:release())\n"
		"local keptBody=f:getBody(); local keptShape=f:getShape(); assert(keptBody:getX()==0 and keptShape:getRadius()==2)\n"
		"local ja,jb=j:getBodies(); assert(ja:getX()==0 and jb:getX()==10)\n"
		"assert(j:release() and f:release()); collectgarbage('collect')\n",
		"@physics-object-retention.lua");
	retainedPhysicsRuntime.close();
	require(retainedPhysics.worldsReleased == 1 && retainedPhysics.bodiesReleased == 2
		&& retainedPhysics.shapesReleased == 1 && retainedPhysics.fixturesReleased == 1
		&& retainedPhysics.jointsReleased == 1 && retainedPhysics.worlds.empty()
		&& retainedPhysics.bodies.empty() && retainedPhysics.shapes.empty()
		&& retainedPhysics.fixtures.empty() && retainedPhysics.joints.empty(),
		"physics Love Objects did not retain their native ownership graph or release handles exactly once");

	MockGraphics rejectingImageEncoder;
	rejectingImageEncoder.rejectImageDataEncode = true;
	Dora::Love::LoveRuntime imageEncodeFailure;
	imageEncodeFailure.setImageBackend(&rejectingImageEncoder);
	require(imageEncodeFailure.open(error), error);
	execute(imageEncodeFailure,
		"local image = require('love.image').newImageData(1, 1)\n"
		"local ok, message = pcall(image.encode, image, 'png')\n"
		"assert(not ok and message:find('mock image encoder rejected rgba8 data', 1, true))\n",
		"@image-encode-failure.lua");
	imageEncodeFailure.close();

	Dora::Love::LoveRuntime faulty;
	require(faulty.open(error), error);
	require(faulty.boot(
		"function love.update() attempts = (attempts or 0) + 1; error('update failed') end\n",
		"@faulty.lua", error), error);
	require(!faulty.update(0.1, error), "faulty update unexpectedly succeeded");
	require(error.find("faulty.lua") != std::string::npos, "traceback omitted the boot chunk name");
	require(faulty.getStatus() == Dora::Love::LoveRuntime::Status::Faulted, "runtime did not enter faulted state");
	require(!faulty.update(0.1, error), "faulted runtime executed another update");
	execute(faulty, "assert(attempts == 1)\n", "@verify-fault-stop.lua");
	faulty.close();
	require(faulty.getAllocationBytes() == 0, "faulty Love state retained Lua allocations after close");

	const auto requireMappedUpdateError = [&](std::string_view code,
		std::string_view generatedChunk, std::string_view expectedLocation,
		std::string_view marker)
	{
		Dora::Love::LoveRuntime mapped;
		require(mapped.open(error), error);
		require(mapped.boot(code, generatedChunk, error), error);
		require(!mapped.update(0.1, error), "generated callback unexpectedly succeeded");
		require(error.find(expectedLocation) != std::string::npos,
			"generated traceback did not map to the original source line");
		require(error.find(marker) != std::string::npos,
			"generated traceback lost the original error message");
		mapped.close();
		require(mapped.getAllocationBytes() == 0,
			"generated traceback state retained Lua allocations");
	};
	requireMappedUpdateError(
		"-- [ts]: /virtual/project/source/original-typescript-runtime.ts\n"
		"love.update = function() -- 4\n"
		"  error('TS_GENERATED_FAILURE') -- 19\n"
		"end -- 4\n",
		"@generated-typescript.lua",
		"/virtual/project/source/original-typescript-runtime.ts:19:",
		"TS_GENERATED_FAILURE");
	requireMappedUpdateError(
		"-- [yue]: scripts/original-runtime.yue\n"
		"love.update = function() -- 6\n"
		"  error('YUE_GENERATED_FAILURE') -- 23\n"
		"end -- 6\n",
		"@generated-yue.lua", "scripts/original-runtime.yue:23:",
		"YUE_GENERATED_FAILURE");
	requireMappedUpdateError(
		"-- [tl]: scripts/original-runtime.tl\n"
		"love.update = function()\n"
		"  error('TEAL_GENERATED_FAILURE')\n"
		"end\n",
		"@generated-teal.lua", "scripts/original-runtime.tl:2:",
		"TEAL_GENERATED_FAILURE");

	Dora::Love::LoveRuntime generatedSyntax;
	require(generatedSyntax.open(error), error);
	require(!generatedSyntax.execute(
		"-- [ts]: scripts/broken-runtime.ts\n"
		"local value = -- 7\n",
		"@generated-broken.lua", error),
		"generated syntax error unexpectedly loaded");
	require(error.find("scripts/broken-runtime.ts:7:") != std::string::npos,
		"generated syntax error did not map to the original source line");
	generatedSyntax.close();

	struct GeneratedFailureFixture
	{
		const char *luaFile;
		const char *expectedLocation;
		const char *marker;
	};
	for (const auto &fixture : std::array{
		GeneratedFailureFixture{"LanguageWorkflow/fault-ts.lua", "fault-ts.ts:4:",
			"LOVE_TS_SOURCE_MAP_FAILURE"},
		GeneratedFailureFixture{"LanguageWorkflow/fault-teal.lua", "fault-teal.tl:4:",
			"LOVE_TEAL_SOURCE_MAP_FAILURE"},
		GeneratedFailureFixture{"LanguageWorkflow/fault-yue.lua", "fault-yue.yue:4:",
			"LOVE_YUE_SOURCE_MAP_FAILURE"},
	})
	{
		Dora::Love::LoveRuntime generatedFailure;
		require(generatedFailure.open(error), error);
		const std::string generatedCode = readFixture(fixture.luaFile);
		require(generatedFailure.boot(generatedCode,
			std::string("@") + fixture.luaFile, error), error);
		require(!generatedFailure.update(0.1, error),
			"generated failure fixture unexpectedly succeeded");
		require(error.find(fixture.expectedLocation) != std::string::npos,
			"real generated fixture did not map to its source line");
		require(error.find(fixture.marker) != std::string::npos,
			"real generated fixture lost its error marker");
		generatedFailure.close();
	}

	TestFilesystemBackend generatedModuleFilesystem;
	Dora::Love::LoveRuntime generatedModuleFailure;
	generatedModuleFailure.setFilesystemBackend(&generatedModuleFilesystem);
	require(generatedModuleFailure.open(error), error);
	require(generatedModuleFailure.setSourceRoot(fixtureRoot, error), error);
	require(generatedModuleFailure.boot(
		"require('LanguageWorkflow.fault-yue')\n",
		"@generated-module-host.lua", error), error);
	require(!generatedModuleFailure.update(0.1, error),
		"required generated module unexpectedly succeeded");
	require(error.find("fault-yue.yue:4:") != std::string::npos,
		"required generated module did not map to its source line");
	require(error.find("LOVE_YUE_SOURCE_MAP_FAILURE") != std::string::npos,
		"required generated module lost its error marker");
	generatedModuleFailure.close();

	MockGraphics instancedGraphics;
	Dora::Love::LoveRuntime instancedRuntime;
	instancedRuntime.setGraphicsBackend(&instancedGraphics);
	instancedRuntime.setImageBackend(&instancedGraphics);
	require(instancedRuntime.open(error), error);
	execute(instancedRuntime,
		"local g = require('love.graphics')\n"
		"local mesh = g.newMesh({{0,0,0,0,1,1,1,1},{8,0,1,0,1,1,1,1},{0,8,0,1,1,1,1,1}}, 'triangles')\n"
		"local colors = g.newMesh({{'InstanceColor','float',4}}, {{1,0,0,1},{0,1,0,1},{0,0,1,1}}, 'points')\n"
		"mesh:attachAttribute('VertexColor', colors, 'perinstance', 'InstanceColor')\n"
		"g.drawInstanced(mesh, 0, 4, 5, 0, 1, 1, 0, 0, 0.25, 0.5)\n"
		"g.drawInstanced(mesh, -2)\n"
		"g.drawInstanced(mesh, 3, 4, 5)\n"
		"assert(not pcall(g.drawInstanced, mesh, 4))\n",
		"@draw-instanced.lua");
	require(instancedGraphics.meshDraws == 1,
		"drawInstanced did not use one backend submission or submitted a non-positive count");
	require(instancedGraphics.lastMeshVertices.size() == 9
		&& instancedGraphics.lastMeshIndices == std::vector<std::uint32_t>({0, 1, 2, 3, 4, 5, 6, 7, 8}),
		"drawInstanced did not expand indexed geometry once per instance");
	for (std::size_t instance = 0; instance < 3; ++instance)
	{
		const auto &vertex = instancedGraphics.lastMeshVertices[instance * 3];
		requireNear(vertex.red, instance == 0 ? 1.0f : 0.0f,
			"drawInstanced per-instance red progression");
		requireNear(vertex.green, instance == 1 ? 1.0f : 0.0f,
			"drawInstanced per-instance green progression");
		requireNear(vertex.blue, instance == 2 ? 1.0f : 0.0f,
			"drawInstanced per-instance blue progression");
	}
	execute(instancedRuntime,
		"local g = require('love.graphics')\n"
		"local fan = g.newMesh({{0,0},{8,0},{8,8},{0,8}}, 'fan')\n"
		"local positions = g.newMesh({{'InstancePosition','float',2}}, {{10,10},{30,10}}, 'points')\n"
		"fan:attachAttribute('VertexPosition', positions, 'perinstance', 'InstancePosition')\n"
		"g.drawInstanced(fan, 2)\n",
		"@draw-instanced-fan.lua");
	require(instancedGraphics.meshDraws == 2
		&& instancedGraphics.lastMeshDrawMode == "triangles"
		&& instancedGraphics.lastMeshIndices == std::vector<std::uint32_t>({
			0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7}),
		"drawInstanced did not isolate fan topology between instances");
	require(instancedGraphics.lastMeshVertices.size() == 8
		&& instancedGraphics.lastMeshVertices[0].x == 10.0f
		&& instancedGraphics.lastMeshVertices[4].x == 30.0f,
		"drawInstanced did not advance per-instance VertexPosition");
	execute(instancedRuntime,
		"local g = require('love.graphics')\n"
		"local mesh = g.newMesh({{0,0},{8,0},{0,8}}, 'triangles')\n"
		"local source = g.newMesh({{'Offset','float',2},{'InstanceColor','float',4}}, {\n"
		"  {0,0,1,0,0,1},{20,0,0,1,0,1},{40,0,0,0,1,1}}, 'points')\n"
		"mesh:attachAttribute('Offset', source, 'perinstance', 'Offset')\n"
		"mesh:attachAttribute('VertexColor', source, 'perinstance', 'InstanceColor')\n"
		"g.setShader(g.newShader([[attribute vec2 Offset; vec4 position(mat4 t, vec4 v) { v.xy = v.xy + Offset; return t * v; }]]))\n"
		"g.drawInstanced(mesh, 3)\n",
		"@draw-hardware-instanced.lua");
	require(instancedGraphics.meshDraws == 3
		&& instancedGraphics.lastMeshInstanceCount == 3
		&& instancedGraphics.lastMeshVertices.size() == 3
		&& instancedGraphics.lastMeshIndices == std::vector<std::uint32_t>({0, 1, 2}),
		"active Shader drawInstanced did not preserve base geometry for hardware instancing");
	const auto offsetAttribute = std::find_if(instancedGraphics.lastMeshAttributes.begin(),
		instancedGraphics.lastMeshAttributes.end(),
		[](const auto &attribute) { return attribute.name == "Offset"; });
	const auto colorAttribute = std::find_if(instancedGraphics.lastMeshAttributes.begin(),
		instancedGraphics.lastMeshAttributes.end(),
		[](const auto &attribute) { return attribute.name == "VertexColor"; });
	require(offsetAttribute != instancedGraphics.lastMeshAttributes.end()
		&& offsetAttribute->perInstance
		&& offsetAttribute->values == std::vector<float>({0, 0, 20, 0, 40, 0})
		&& colorAttribute != instancedGraphics.lastMeshAttributes.end()
		&& colorAttribute->perInstance && colorAttribute->values.size() == 12,
		"hardware drawInstanced did not preserve custom and built-in per-instance streams");
	instancedGraphics.meshInstancingSupported = false;
	execute(instancedRuntime,
		"local g = require('love.graphics')\n"
		"local mesh = g.newMesh({{0,0},{8,0},{0,8}}, 'triangles')\n"
		"g.setShader(g.newShader([[vec4 position(mat4 t, vec4 v) { return t * v; }]]))\n"
		"g.drawInstanced(mesh, 2)\n"
		"g.setShader(g.newShader([[#pragma language glsl3\nvec4 position(mat4 t, vec4 v) { v.x += float(love_InstanceID); return t * v; }]]))\n"
		"assert(not pcall(g.drawInstanced, mesh, 2))\n",
		"@draw-instanced-fallback.lua");
	require(instancedGraphics.meshDraws == 4
		&& instancedGraphics.lastMeshInstanceCount == 1
		&& instancedGraphics.lastMeshVertices.size() == 6,
		"unavailable hardware instancing did not CPU-expand an ordinary active Shader");
	instancedRuntime.close();
	require(instancedRuntime.getAllocationBytes() == 0,
		"drawInstanced state retained Lua allocations");

	MockGraphics vertexIDGraphics;
	Dora::Love::LoveRuntime vertexIDRuntime;
	vertexIDRuntime.setGraphicsBackend(&vertexIDGraphics);
	vertexIDRuntime.setImageBackend(&vertexIDGraphics);
	require(vertexIDRuntime.open(error), error);
	execute(vertexIDRuntime,
		"local g = require('love.graphics')\n"
		"local mesh = g.newMesh({{0,0},{8,0},{0,8}}, 'triangles')\n"
		"g.setShader(g.newShader([[#pragma language glsl3\nvec4 position(mat4 t, vec4 v) { v.x += float(love_VertexID); return t * v; }]]))\n"
		"g.draw(mesh)\n",
		"@draw-vertex-id.lua");
	const auto vertexIDAttribute = std::find_if(vertexIDGraphics.lastMeshAttributes.begin(),
		vertexIDGraphics.lastMeshAttributes.end(),
		[](const auto &attribute) { return attribute.name == "__DoraLoveVertexID"; });
	require(vertexIDAttribute != vertexIDGraphics.lastMeshAttributes.end()
		&& !vertexIDAttribute->perInstance && vertexIDAttribute->components == 1
		&& vertexIDAttribute->values == std::vector<float>({0, 1, 2}),
		"love_VertexID did not produce a draw-local Mesh attribute stream");
	vertexIDRuntime.close();
	require(vertexIDRuntime.getAllocationBytes() == 0,
		"love_VertexID state retained Lua allocations");

	MockGraphics largeMeshGraphics;
	Dora::Love::LoveRuntime largeMeshRuntime;
	largeMeshRuntime.setGraphicsBackend(&largeMeshGraphics);
	largeMeshRuntime.setImageBackend(&largeMeshGraphics);
	require(largeMeshRuntime.open(error), error);
	execute(largeMeshRuntime,
		"local g = require('love.graphics')\n"
		"local mesh = g.newMesh(65538, 'triangles')\n"
		"mesh:setVertex(65536, 2, 2, 0, 0, 1, 0, 0, 1)\n"
		"mesh:setVertex(65537, 10, 2, 0, 0, 0, 1, 0, 1)\n"
		"mesh:setVertex(65538, 2, 10, 0, 0, 0, 0, 1, 1)\n"
		"mesh:setVertexMap(65536, 65537, 65538)\n"
		"g.draw(mesh)\n"
		"g.setShader(g.newShader([[#pragma language glsl3\nvec4 position(mat4 t, vec4 v) { v.x += float(love_VertexID) * 0.0; return t * v; }]]))\n"
		"g.draw(mesh)\n",
		"@draw-large-mesh.lua");
	const auto largeVertexIDs = std::find_if(largeMeshGraphics.lastMeshAttributes.begin(),
		largeMeshGraphics.lastMeshAttributes.end(),
		[](const auto &attribute) { return attribute.name == "__DoraLoveVertexID"; });
	require(largeMeshGraphics.meshDraws == 2
		&& largeMeshGraphics.lastMeshVertices.size() == 65538
		&& largeMeshGraphics.lastMeshIndices == std::vector<std::uint32_t>({65535, 65536, 65537})
		&& largeVertexIDs != largeMeshGraphics.lastMeshAttributes.end()
		&& largeVertexIDs->values.size() == 65538
		&& largeVertexIDs->values.front() == 0.0f
		&& largeVertexIDs->values.back() == 65537.0f,
		"32-bit Mesh indices or love_VertexID stream were truncated at 65535 vertices");
	execute(largeMeshRuntime,
		"local g = require('love.graphics')\n"
		"g.setShader()\n"
		"local mesh = g.newMesh(65538, 'triangles')\n"
		"mesh:setVertexMap(65536, 65537, 65538)\n"
		"g.drawInstanced(mesh, 2)\n",
		"@draw-large-instanced-mesh.lua");
	require(largeMeshGraphics.meshDraws == 3
		&& largeMeshGraphics.lastMeshVertices.size() == 131076
		&& largeMeshGraphics.lastMeshIndices == std::vector<std::uint32_t>({
			65535, 65536, 65537, 131073, 131074, 131075}),
		"CPU-instanced Mesh indices were truncated while expanding past 65535 vertices");
	largeMeshRuntime.close();
	require(largeMeshRuntime.getAllocationBytes() == 0,
		"32-bit Mesh state retained Lua allocations");

	TestFilesystemBackend generatedFilesystem;
	MockGraphics generatedGraphics;
	const fs::path generatedSaveBase = fs::temp_directory_path()
		/ ("dora-love-generated-" + std::to_string(
			std::chrono::steady_clock::now().time_since_epoch().count()));
	for (const char *generatedFile : {
			 "LanguageWorkflow/love-teal.lua",
			 "LanguageWorkflow/love-yue.lua",
		 })
	{
		Dora::Love::LoveRuntime generated;
		generated.setFilesystemBackend(&generatedFilesystem);
		generated.setGraphicsBackend(&generatedGraphics);
		generated.setImageBackend(&generatedGraphics);
		require(generated.open(error), error);
		require(generated.setSourceRoot(fixtureRoot + "/LanguageWorkflow", error), error);
		require(generated.setSaveBaseRoot(generatedSaveBase.string(), error), error);
		const std::string generatedCode = readFixture(generatedFile);
		require(generated.boot(generatedCode, std::string("@") + generatedFile, error), error);
		require(generated.update(0.5, error), error);
		require(generated.draw(error), error);
		generated.close();
		require(generated.getAllocationBytes() == 0, "generated-language state retained Lua allocations");
	}
	fs::remove_all(generatedSaveBase, symlinkError);

	first.close();
	second.close();
	require(first.getAllocationBytes() == 0, "first Love state retained Lua allocations after close");
	require(second.getAllocationBytes() == 0, "second Love state retained Lua allocations after close");

	const int imagesReleasedBeforeSoak = graphics.imagesReleased;
	const int canvasesReleasedBeforeSoak = graphics.canvasesReleased;
	const int fontsReleasedBeforeSoak = graphics.fontsReleased;
	const int audioReleasedBeforeSoak = audioBackend.released;
	const std::string resourceSoakCode =
		"resources = {}\n"
		"for i = 1, 8 do\n"
		"  local image = love.graphics.newImage('pig.png')\n"
		"  local canvas = love.graphics.newCanvas(16, 16)\n"
		"  image:setFilter(i % 2 == 0 and 'nearest' or 'linear')\n"
		"  image:setWrap('repeat', 'mirroredrepeat')\n"
		"  local pixels = love.image.newImageData(8, 8)\n"
		"  pixels:setPixel(i - 1, i - 1, 1, 0.5, 0.25, 1)\n"
		"  local font = love.graphics.newFont(10 + i)\n"
		"  local pcm = love.sound.newSoundData(64, 22050, 16, 2)\n"
		"  pcm:setSample(0, 1, 0.5)\n"
		"  local fileSource = love.audio.newSource('pig.png', 'static')\n"
		"  local pcmSource = love.audio.newSource(pcm)\n"
		"  resources[i] = {image, canvas, pixels, font, pcm, fileSource, pcmSource}\n"
		"end\n"
		"resources[2] = nil; resources[4] = nil; resources[6] = nil; resources[8] = nil\n"
		"collectgarbage('collect')\n"
		"function love.update() end\n";
	for (int iteration = 0; iteration < 50; ++iteration)
	{
		Dora::Love::LoveRuntime runtime;
		runtime.setFilesystemBackend(&audioFilesystem);
		runtime.setGraphicsBackend(&graphics);
		runtime.setImageBackend(&graphics);
		runtime.setSoundBackend(&soundBackend);
		runtime.setAudioBackend(&audioBackend);
		require(runtime.open(error), error);
		require(runtime.setSourceRoot(fixtureRoot + "/RuntimeScene", error), error);
		require(runtime.boot(resourceSoakCode, "@resource-soak.lua", error), error);
		require(runtime.restart(error), error);
		runtime.close();
		require(runtime.getAllocationBytes() == 0, "resource soak retained Love Lua allocations");
		require(audioBackend.sources.empty(), "resource soak retained Dora AudioSource handles");
		require(graphics.fontSizes.empty(), "resource soak retained Dora Font handles");
	}
	require(graphics.imagesReleased - imagesReleasedBeforeSoak == 800,
		"resource soak did not release every Love Image backend handle");
	require(graphics.canvasesReleased - canvasesReleasedBeforeSoak == 800 && graphics.canvases.empty(),
		"resource soak did not release every Love Canvas backend handle");
	require(graphics.fontsReleased - fontsReleasedBeforeSoak == 800,
		"resource soak did not release every Love Font backend handle");
	require(audioBackend.released - audioReleasedBeforeSoak == 1600,
		"resource soak did not release every filename/SoundData AudioSource backend handle");

	for (int i = 0; i < 500; ++i)
	{
		Dora::Love::LoveRuntime runtime;
		require(runtime.open(error), error);
		execute(runtime,
			"local instance = require('love')\n"
			"instance.iteration = {}\n"
			"for i = 1, 64 do instance.iteration[i] = tostring(i) end\n",
			"@stress.lua");
		runtime.close();
		require(runtime.getAllocationBytes() == 0, "Love state retained Lua allocations in stress loop");
	}

	lua_getglobal(doraState, "love");
	require(lua_isnil(doraState, -1), "Love states polluted the control Dora state");
	lua_pop(doraState, 1);
	lua_close(doraState);

	std::cout << "PASS: Lua " << LUA_VERSION_MAJOR << "." << LUA_VERSION_MINOR
		<< ", two isolated Love states, 500 clean lifecycle iterations" << std::endl;
	return 0;
}
