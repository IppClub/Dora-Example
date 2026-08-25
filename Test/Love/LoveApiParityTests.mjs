#!/usr/bin/env node

import {createRequire} from "node:module";
import {readFileSync} from "node:fs";
import nodePath from "node:path";
import {doraSSRRoot} from "./TestPaths.mjs";

const require = createRequire(import.meta.url);
const ts = require(nodePath.join(doraSSRRoot, "Tools/dora-dora/node_modules/typescript"));
const readSource = path => readFileSync(path, "utf8").replace(/\r\n?/g, "\n");
const runtimeCore = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveRuntime.cpp"));
const runtimeAdapters = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveRuntimeAdapters.inc"));
const runtime = `${runtimeAdapters}\n${runtimeCore}`;
const graphicsAdapter = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveGraphicsAdapter.h"));
const loveNode = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveNode.cpp"));
const standardTransformParser = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsTransform.h"));
const graphicsDrawWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsDraw.cpp"));
const canvasWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Canvas.cpp"));
const canvasConstructorWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsCanvasConstructor.cpp"));
const graphicsStateWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsState.cpp"));
const graphicsDisplayStateWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsDisplayState.cpp"));
const graphicsInfoWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsInfo.cpp"));
const graphicsCapabilitiesWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsCapabilities.cpp"));
const graphicsPrimitivesWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsPrimitives.cpp"));
const graphicsQuadWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsQuad.cpp"));
const graphicsShaderStateWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsShaderState.cpp"));
const graphicsShaderConstructorWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsShaderConstructor.cpp"));
const graphicsFontStateWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsFontState.cpp"));
const graphicsFontConstructorWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsFontConstructor.cpp"));
const graphicsImageConstructorWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsImageConstructor.cpp"));
const graphicsScreenshotWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsScreenshot.cpp"));
const graphicsPrintWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_GraphicsPrint.cpp"));
const meshObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/Mesh.h"));
const meshWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Mesh.cpp"));
const spriteBatchObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/SpriteBatch.h"));
const spriteBatchWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_SpriteBatch.cpp"));
const particleSystemObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/ParticleSystem.h"));
const particleSystemWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_ParticleSystem.cpp"));
const graphicsFontObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/Font.h"));
const graphicsFontWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Font.cpp"));
const textObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/Text.h"));
const textWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Text.cpp"));
const shaderObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/Shader.h"));
const shaderWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Shader.cpp"));
const audioSourceObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/audio/Source.h"));
const audioSourceWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/audio/wrap_Source.cpp"));
const videoObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/Video.h"));
const videoWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/graphics/wrap_Video.cpp"));
const videoStreamObject = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/video/VideoStream.h"));
const videoStreamWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/video/wrap_VideoStream.cpp"));
const threadModuleWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/thread/wrap_ThreadModule.cpp"));
const threadObjectWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/thread/wrap_LuaThread.cpp"));
const channelObjectWrapper = readSource(nodePath.join(doraSSRRoot,
	"Source/3rdParty/Love/src/modules/thread/wrap_Channel.cpp"));

function upstreamMethods(path) {
	const source = readFileSync(nodePath.join(doraSSRRoot, "Source/3rdParty/Love/src/modules", path), "utf8");
	const text = source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
	return new Set([...text.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,\s*w_/g)].map(value => value[1]));
}

function upstreamGraphicsMethods(type) {
	return upstreamMethods(`graphics/wrap_${type}.cpp`);
}

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

assert(runtimeCore.includes('#include "LoveRuntimeAdapters.inc"')
	&& runtimeCore.split("\n").length <= 1500
	&& !runtimeCore.includes("int LoveRuntime::graphicsDrawCommand(")
	&& !runtimeCore.includes("int LoveRuntime::physicsNewWorld("),
	"LoveRuntime.cpp must remain the compact state/boot/dispatch shell; adapters belong in LoveRuntimeAdapters.inc");

assert(runtime.includes("class Base = ::love::Object>")
	&& runtime.includes("struct DoraHandleObject : Base"),
	"Dora backend handles must share the Love Object-backed polymorphic handle wrapper");
for (const type of ["Image", "Canvas", "Cursor", "Font", "Shader", "AudioSource",
	"Video", "RecordingDevice", "PhysicsWorld", "PhysicsBody", "PhysicsShape",
	"PhysicsFixture", "PhysicsJoint"]) {
	assert(new RegExp(`struct ${type}Userdata final\\s*\\n\\s*: DoraHandleObject<`).test(runtime),
		`${type} userdata bypasses the shared Dora handle wrapper`);
}
assert(!/int LoveRuntime::[A-Za-z0-9_]+GC\s*\(/.test(runtime),
	"legacy per-type GC callbacks must not coexist with Love's common Object runtime");
assert(!/->~[A-Za-z0-9_]+Userdata\s*\(/.test(runtime),
	"Love userdata must not be destroyed manually outside Object::release");
assert(runtime.includes("void adoptDoraHandle(Handle valueHandle) noexcept")
	&& runtime.includes("void invalidateDoraHandle() noexcept")
	&& runtime.includes("void replaceDoraHandle(Handle valueHandle) noexcept")
	&& runtime.includes("(runtime->*Retain)(handle)")
	&& runtime.includes("(runtime->*Forget)(handle)"),
	"Dora handle adoption, invalidation, and replacement must stay inside the shared wrapper");

assert(!runtime.includes('Type LoveDrawableType("Drawable"'),
	"Dora must not keep a parallel Drawable Type beside Love's original object");
assert(!runtime.includes("::love::Type LoveTextureType")
	&& /&LoveRuntime::forgetLoveCanvasHandle,\s*::love::graphics::Canvas>/.test(runtime)
	&& runtime.includes("::love::Type &CanvasUserdata::type = ::love::graphics::Canvas::type;"),
	"Canvas must use Love's original Canvas -> Texture -> Drawable object and Type chain");
assert(runtime.includes("::love::graphics::luax_checkstandardtransform(state, index,")
	&& standardTransformParser.includes("if (luax_istype(L, idx, math::Transform::type))")
	&& standardTransformParser.includes("func(Matrix4(x, y, a, sx, sy, ox, oy, kx, ky));"),
	"Dora Graphics dispatch must reuse Love 11.5's standard Transform/numeric overload parser");
const standardTransformBridge = runtime.match(
	/void readStandardTransform\([\s\S]*?\n\}/)?.[0] ?? "";
assert(standardTransformBridge && !standardTransformBridge.includes("luaL_optnumber"),
	"LoveRuntime must not keep a parallel numeric standard-transform parser");
assert(graphicsAdapter.includes("class DoraLoveGraphics final : public ::love::Module")
	&& graphicsAdapter.includes("return M_GRAPHICS;")
	&& runtime.includes("::love::luax_register_module(_state, wrappedGraphics);")
	&& runtime.includes("graphicsModule, \"graphics\", &DoraLoveGraphics::type")
	&& !runtime.includes("Module::registerInstance(graphicsModule)"),
	"Graphics must be a real state-local Love module backed only by the Dora adapter");
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsDrawCommand")
	&& graphicsDrawWrapper.includes("auto *module = luax_getmodule(L, Module::M_GRAPHICS);")
	&& graphicsDrawWrapper.includes("texture = luax_checktexture(L, 1);")
	&& graphicsDrawWrapper.includes("drawable = luax_checktype<Drawable>(L, 1);")
	&& graphicsDrawWrapper.includes("luax_checkstandardtransform(L, startidx")
	&& graphicsDrawWrapper.includes("drawCommand(L)->draw(L, drawable, texture, quad, m);")
	&& graphicsDrawWrapper.includes("drawCommand(L)->drawLayer(L, texture, layer, quad, m);")
	&& runtime.includes('{"draw", ::love::graphics::w_draw}')
	&& runtime.includes('{"drawLayer", ::love::graphics::w_drawLayer}')
	&& !runtime.includes('{"draw", graphicsDraw}')
	&& !runtime.includes('{"drawLayer", graphicsDrawLayer}'),
	"draw/drawLayer must use the split original wrapper and state-local Graphics command adapter");
assert(!runtime.includes("int LoveRuntime::graphicsDrawLayer("),
	"the parallel LoveRuntime graphicsDrawLayer binding must stay deleted");
const canvasRegistration = runtime.match(
	/void LoveRuntime::registerCanvasType\(\)\s*\{[\s\S]*?\n\}/)?.[0] ?? "";
assert(runtime.includes("::love::graphics::luaopen_canvas(_state);")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsCanvasCommand")
	&& canvasWrapper.includes("auto *module = luax_getmodule(L, Module::M_GRAPHICS);")
	&& canvasWrapper.includes("command->renderTo(L, canvas, slice, startidx);")
	&& canvasWrapper.includes("command->setCanvas(L, targets);")
	&& canvasWrapper.includes("auto targets = canvasCommand(L)->getCanvas();")
	&& canvasWrapper.includes("command->clear(color, stencil, depth);")
	&& canvasWrapper.includes("canvasCommand(L)->discard(colorBuffers, depthStencil);")
	&& runtime.includes('{"setCanvas", ::love::graphics::w_setCanvas}')
	&& runtime.includes('{"getCanvas", ::love::graphics::w_getCanvas}')
	&& runtime.includes('{"clear", ::love::graphics::w_clear}')
	&& runtime.includes('{"discard", ::love::graphics::w_discard}')
	&& !canvasRegistration.includes("luax_register_type")
	&& !runtime.includes("int LoveRuntime::canvasGetWidth(")
	&& !runtime.includes("int LoveRuntime::canvasNewImageData(")
	&& !runtime.includes("int LoveRuntime::canvasSetFilter(")
	&& !runtime.includes("int LoveRuntime::graphicsSetCanvas(")
	&& !runtime.includes("int LoveRuntime::graphicsGetCanvas(")
	&& !runtime.includes("int LoveRuntime::graphicsClear(")
	&& !runtime.includes("int LoveRuntime::graphicsDiscard("),
	"Canvas target, clear and discard APIs must use the original wrappers and state-local adapter");
for (const method of ["push", "pop", "getStackDepth", "origin", "translate",
	"rotate", "scale", "shear", "applyTransform", "replaceTransform",
	"transformPoint", "inverseTransformPoint"]) {
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the original state wrapper`);
}
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsStateCommand")
	&& graphicsStateWrapper.includes("auto *module = luax_getmodule(L, Module::M_GRAPHICS);")
	&& graphicsStateWrapper.includes("stateCommand(L)->reset(L);")
	&& graphicsStateWrapper.includes("stateCommand(L)->present(L);")
	&& graphicsStateWrapper.includes("stateCommand(L)->flushBatch();")
	&& graphicsStateWrapper.includes("luax_istype(L, 2, math::Transform::type)")
	&& runtime.includes('{"reset", ::love::graphics::w_reset}')
	&& runtime.includes('{"present", ::love::graphics::w_present}')
	&& runtime.includes('{"flushBatch", ::love::graphics::w_flushBatch}')
	&& !runtime.includes("int LoveRuntime::graphicsReset(")
	&& !runtime.includes("int LoveRuntime::graphicsPresent(")
	&& !runtime.includes("int LoveRuntime::graphicsFlushBatch(")
	&& !runtime.includes("int LoveRuntime::graphicsGetStackDepth(")
	&& !runtime.includes("int LoveRuntime::graphicsApplyTransform("),
	"Graphics reset, pass barriers, and transform stack must use the split original wrapper and state-local command adapter");
for (const method of ["getWidth", "getHeight", "getDimensions", "getPixelWidth",
	"getPixelHeight", "getPixelDimensions", "getDPIScale", "isActive", "isCreated",
	"isGammaCorrect"]) {
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the state-local original info wrapper`);
}
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsInfoCommand")
	&& graphicsInfoWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& graphicsInfoWrapper.includes("dynamic_cast<GraphicsInfoCommand *>(module)")
	&& !runtime.includes("int LoveRuntime::graphicsGetDimensions(")
	&& !runtime.includes("int LoveRuntime::graphicsGetDPIScale(")
	&& !runtime.includes("int LoveRuntime::graphicsIsActive(")
	&& !runtime.includes("int LoveRuntime::graphicsIsCreated(")
	&& !runtime.includes("int LoveRuntime::graphicsIsGammaCorrect("),
	"Graphics surface and active-state queries must resolve the current state's Dora Graphics adapter");
for (const method of ["getSupported", "getTextureTypes", "getImageFormats",
	"getCanvasFormats", "getRendererInfo", "getSystemLimits", "getStats"]) {
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the state-local capabilities wrapper`);
}
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsCapabilitiesCommand")
	&& graphicsCapabilitiesWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& graphicsCapabilitiesWrapper.includes("dynamic_cast<GraphicsCapabilitiesCommand *>(module)")
	&& graphicsCapabilitiesWrapper.includes("if (lua_istable(L, 1)) lua_pushvalue(L, 1)")
	&& !runtime.includes("int LoveRuntime::graphicsGetSupported(")
	&& !runtime.includes("int LoveRuntime::graphicsGetTextureTypes(")
	&& !runtime.includes("int LoveRuntime::graphicsGetImageFormats(")
	&& !runtime.includes("int LoveRuntime::graphicsGetCanvasFormats(")
	&& !runtime.includes("int LoveRuntime::graphicsGetRendererInfo(")
	&& !runtime.includes("int LoveRuntime::graphicsGetSystemLimits(")
	&& !runtime.includes("int LoveRuntime::graphicsGetStats("),
	"Graphics capability and stats queries must use wrapper-owned table semantics over the state-local Dora adapter");
for (const method of ["points", "line", "rectangle", "circle", "ellipse", "arc", "polygon"]) {
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the state-local primitives wrapper`);
	assert(!runtime.includes(`int LoveRuntime::graphics${method[0].toUpperCase()}${method.slice(1)}(`),
		`graphics.${method} must not retain a duplicate LoveRuntime Lua parser`);
}
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsPrimitivesCommand")
	&& graphicsPrimitivesWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& graphicsPrimitivesWrapper.includes("dynamic_cast<GraphicsPrimitivesCommand *>(module)")
	&& graphicsPrimitivesWrapper.includes("Number of vertex components must be a multiple of two")
	&& graphicsPrimitivesWrapper.includes("tableOfTables"),
	"Graphics primitives must keep Love wrapper overload parsing over the state-local Dora adapter");
assert(runtime.includes('{"drawInstanced", ::love::graphics::w_drawInstanced}')
	&& graphicsDrawWrapper.includes("int w_drawInstanced(lua_State *L)")
	&& graphicsDrawWrapper.includes("luax_checkstandardtransform(L, 3")
	&& graphicsDrawWrapper.includes("drawCommand(L)->drawInstanced")
	&& !runtime.includes("int LoveRuntime::graphicsDraw("),
	"drawInstanced and Video draw must consume the original wrapper matrix instead of reparsing the Lua stack");
assert(runtime.includes('{"newQuad", ::love::graphics::w_newQuad}')
	&& !runtime.includes("int LoveRuntime::graphicsNewQuad(")
	&& graphicsQuadWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& graphicsQuadWrapper.includes("luax_istype(L, 5, Texture::type)")
	&& graphicsQuadWrapper.includes("luax_istype(L, 6, Texture::type)")
	&& graphicsQuadWrapper.includes("quad->setLayer(layer)"),
	"newQuad must retain original Texture/layer/dimension overload parsing outside LoveRuntime");
assert(runtime.includes('{"newCanvas", ::love::graphics::w_newCanvas}')
	&& !runtime.includes("int LoveRuntime::graphicsNewCanvas(")
	&& canvasConstructorWrapper.includes("luax_checktablefields<Canvas::SettingType>")
	&& canvasConstructorWrapper.includes("command->newCanvas(settings)")
	&& graphicsAdapter.includes("Canvas *newCanvas("),
	"newCanvas must use Love's settings parser over the state-local Dora Canvas factory");
assert(runtime.includes('{"setShader", ::love::graphics::w_setShader}')
	&& runtime.includes('{"getShader", ::love::graphics::w_getShader}')
	&& !runtime.includes("int LoveRuntime::graphicsSetShader(")
	&& !runtime.includes("int LoveRuntime::graphicsGetShader(")
	&& !runtime.includes("_graphicsShaderReference")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsShaderStateCommand")
	&& graphicsShaderStateWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)"),
	"Shader selection must use state-local wrapper dispatch and Love StrongRef ownership");
assert(runtime.includes('{"newShader", ::love::graphics::w_newShader}')
	&& runtime.includes('{"validateShader", ::love::graphics::w_validateShader}')
	&& !runtime.includes("int LoveRuntime::graphicsNewShader(")
	&& !runtime.includes("int LoveRuntime::graphicsValidateShader(")
	&& !runtime.includes("bool loadShaderArgument(")
	&& !runtime.includes("bool classifyShaderSources(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsShaderConstructorCommand")
	&& graphicsShaderConstructorWrapper.includes("luax_cangetfiledata(L, index)")
	&& graphicsShaderConstructorWrapper.includes("luax_getmodule(L, Module::M_FILESYSTEM)")
	&& graphicsShaderConstructorWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& graphicsShaderConstructorWrapper.includes("luax_checkboolean(L, 1)"),
	"Shader construction and validation must retain Love argument parsing over state-local Filesystem and Graphics adapters");
assert(runtime.includes('{"setFont", ::love::graphics::w_setFont}')
	&& runtime.includes('{"getFont", ::love::graphics::w_getFont}')
	&& !runtime.includes("int LoveRuntime::graphicsSetFont(")
	&& !runtime.includes("int LoveRuntime::graphicsGetFont(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsFontStateCommand")
	&& graphicsFontStateWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)"),
	"Font selection must use state-local wrapper dispatch and Love StrongRef ownership");
assert(runtime.includes('{"newFont", ::love::graphics::w_newFont}')
	&& runtime.includes('{"newImageFont", ::love::graphics::w_newImageFont}')
	&& runtime.includes('{"setNewFont", ::love::graphics::w_setNewFont}')
	&& !runtime.includes("int LoveRuntime::graphicsNewFont(")
	&& !runtime.includes("int LoveRuntime::graphicsNewImageFont(")
	&& !runtime.includes("int LoveRuntime::graphicsSetNewFont(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsFontConstructorCommand")
	&& graphicsFontConstructorWrapper.includes('luax_convobj(L, indices, "font", conversion)')
	&& graphicsFontConstructorWrapper.includes("newDefaultFont(size)")
	&& graphicsFontConstructorWrapper.includes("GraphicsFontStateCommand"),
	"Font constructors must retain Love Rasterizer conversion and state selection over the state-local Dora factory");
assert(runtime.includes('{"newImage", ::love::graphics::w_newImage}')
	&& runtime.includes('{"newArrayImage", ::love::graphics::w_newArrayImage}')
	&& runtime.includes('{"newCubeImage", ::love::graphics::w_newCubeImage}')
	&& runtime.includes('{"newVolumeImage", ::love::graphics::w_newVolumeImage}')
	&& !runtime.includes("int LoveRuntime::graphicsNewImage(")
	&& !runtime.includes("int LoveRuntime::graphicsNewArrayImage(")
	&& !runtime.includes("int LoveRuntime::graphicsNewCubeImage(")
	&& !runtime.includes("int LoveRuntime::graphicsNewVolumeImage(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsImageConstructorCommand")
	&& graphicsImageConstructorWrapper.includes("luax_checktablefields<Image::SettingType>")
	&& graphicsImageConstructorWrapper.includes("luax_getmodule(L, Module::M_IMAGE)")
	&& graphicsImageConstructorWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)")
	&& runtime.includes("slices.validate()"),
	"Image constructors must retain Love source, settings, mipmap, cube, array, and volume parsing over the state-local Dora factory");
assert(runtime.includes('{"captureScreenshot", ::love::graphics::w_captureScreenshot}')
	&& !runtime.includes("int LoveRuntime::graphicsCaptureScreenshot(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsScreenshotCommand")
	&& graphicsScreenshotWrapper.includes("lua_isfunction(L, 1)")
	&& graphicsScreenshotWrapper.includes("image::ImageData::getConstant")
	&& graphicsScreenshotWrapper.includes("luax_istype(L, 1, thread::Channel::type)")
	&& graphicsScreenshotWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)"),
	"captureScreenshot must retain Love function, filename, format, and Channel parsing over the state-local Dora backend");
assert(runtime.includes('{"print", ::love::graphics::w_print}')
	&& runtime.includes('{"printf", ::love::graphics::w_printf}')
	&& !runtime.includes("int LoveRuntime::graphicsPrint(")
	&& !runtime.includes("int LoveRuntime::graphicsPrintf(")
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsPrintCommand")
	&& graphicsPrintWrapper.includes("luax_checkcoloredstring(L, 1, text)")
	&& graphicsPrintWrapper.includes("luax_checkstandardtransform(L, startIndex")
	&& graphicsPrintWrapper.includes("luax_istype(L, startIndex, math::Transform::type)")
	&& graphicsPrintWrapper.includes("Font::getConstant(value, align)")
	&& graphicsPrintWrapper.includes("luax_getmodule(L, Module::M_GRAPHICS)"),
	"print and printf must retain Love colored-text, Font, Transform, and alignment parsing over the state-local Dora adapter");
for (const method of ["setColor", "getColor", "setBackgroundColor", "getBackgroundColor",
	"setLineWidth", "getLineWidth", "setLineStyle", "getLineStyle", "setLineJoin",
	"getLineJoin", "setPointSize", "getPointSize", "setColorMask", "getColorMask",
	"setWireframe", "isWireframe", "setScissor", "getScissor", "intersectScissor",
	"setDefaultFilter", "getDefaultFilter", "setDefaultMipmapFilter",
	"getDefaultMipmapFilter", "setBlendMode", "getBlendMode"]) {
	// extended below with depth/cull state to keep this list readable
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the original display state wrapper`);
}
for (const method of ["setDepthMode", "getDepthMode", "setMeshCullMode",
	"getMeshCullMode", "setFrontFaceWinding", "getFrontFaceWinding",
	"setStencilTest", "getStencilTest", "stencil"]) {
	assert(runtime.includes(`{"${method}", ::love::graphics::w_${method}}`),
		`graphics.${method} must register the original display state wrapper`);
}
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsDisplayStateCommand")
	&& graphicsDisplayStateWrapper.includes("auto *module = luax_getmodule(L, Module::M_GRAPHICS);")
	&& graphicsDisplayStateWrapper.includes("if (lua_istable(L, 1))")
	&& graphicsDisplayStateWrapper.includes("luax_enumerror(L, \"line style\"")
	&& !runtime.includes("int LoveRuntime::graphicsSetColor(")
	&& !runtime.includes("int LoveRuntime::graphicsSetBackgroundColor(")
	&& !runtime.includes("int LoveRuntime::graphicsSetLineWidth(")
	&& !runtime.includes("int LoveRuntime::graphicsSetPointSize(")
	&& !runtime.includes("int LoveRuntime::graphicsSetColorMask(")
	&& !runtime.includes("int LoveRuntime::graphicsSetWireframe(")
	&& !runtime.includes("int LoveRuntime::graphicsSetScissor(")
	&& !runtime.includes("int LoveRuntime::graphicsIntersectScissor(")
	&& !runtime.includes("int LoveRuntime::graphicsSetDefaultFilter(")
	&& !runtime.includes("int LoveRuntime::graphicsSetDefaultMipmapFilter(")
	&& !runtime.includes("int LoveRuntime::graphicsSetBlendMode(")
	&& !runtime.includes("int LoveRuntime::graphicsSetDepthMode(")
	&& !runtime.includes("int LoveRuntime::graphicsSetMeshCullMode(")
	&& !runtime.includes("int LoveRuntime::graphicsSetFrontFaceWinding(")
	&& !runtime.includes("int LoveRuntime::graphicsSetStencilTest(")
	&& !runtime.includes("int LoveRuntime::graphicsStencil(")
	&& graphicsDisplayStateWrapper.includes("command->beginStencilWrite(action, value, shouldClear, clearValue, error)")
	&& graphicsDisplayStateWrapper.includes("command->endStencilWrite();"),
	"Graphics display state must preserve original wrapper parsing through the state-local adapter");
assert(runtime.includes("struct MeshUserdata final : ::love::graphics::Mesh")
	&& meshObject.includes("class Mesh : public Drawable")
	&& runtime.includes("::love::graphics::luaopen_mesh(_state);")
	&& meshWrapper.includes("luax_pushtype(L, t);")
	&& runtime.includes("{\"newMesh\", ::love::graphics::w_newMesh}")
	&& runtime.includes("_runtime->graphicsDrawCommand(state, mesh, &transform);")
	&& runtime.includes("const auto drawTransform = transformOverride ? *transformOverride")
	&& meshWrapper.includes("static Mesh *newStandardMesh(lua_State *L)")
	&& meshWrapper.includes("static Mesh *newCustomMesh(lua_State *L)")
	&& meshWrapper.includes("meshCommand(L)->newMesh(vertexformat, data->getData(), data->getSize(), drawmode, usage)")
	&& meshWrapper.includes("Mesh *luax_checkmesh(lua_State *L, int idx)")
	&& meshWrapper.includes("return luax_checktype<Mesh>(L, idx);")
	&& meshWrapper.includes("return luax_register_type(L, &Mesh::type, w_Mesh_functions, nullptr);")
	&& meshWrapper.includes("luax_catchexcept(L, [&](){ t->attachAttribute(name, mesh, attachname, step); });")
	&& meshWrapper.includes("luax_istype(L, 2, Data::type)")
	&& meshWrapper.includes("IndexDataType indextype = INDEX_UINT16;")
	&& meshWrapper.includes("PrimitiveType mode = PRIMITIVE_TRIANGLES;")
	&& !runtime.includes("::love::Type MeshLoveType")
	&& !runtime.includes("int LoveRuntime::graphicsNewMesh(")
	&& !runtime.includes("int LoveRuntime::meshSetVertices(")
	&& !runtime.includes("int LoveRuntime::meshSetTexture(")
	&& !runtime.includes("int LoveRuntime::meshSetVertexMap("),
	"Mesh must use Love's original Type and Lua wrapper over Dora-owned storage and draw submission");
assert(runtime.includes("struct SpriteBatchUserdata final : ::love::graphics::SpriteBatch")
	&& spriteBatchObject.includes("class SpriteBatch : public Drawable")
	&& runtime.includes("::love::graphics::luaopen_spritebatch(_state);")
	&& runtime.includes("{\"newSpriteBatch\", ::love::graphics::w_newSpriteBatch}")
	&& runtime.includes("_runtime->graphicsDrawCommand(state, batch, &transform);")
	&& spriteBatchWrapper.includes("spriteBatchCommand(L)->newSpriteBatch(texture, size, usage)")
	&& spriteBatchWrapper.includes("return luax_register_type(L, &SpriteBatch::type, w_SpriteBatch_functions, nullptr);")
	&& spriteBatchWrapper.includes("luax_checkstandardtransform(L, startidx")
	&& !runtime.includes("::love::Type SpriteBatchLoveType")
	&& !runtime.includes("int LoveRuntime::graphicsNewSpriteBatch(")
	&& !runtime.includes("int LoveRuntime::spriteBatchAdd(")
	&& !runtime.includes("int LoveRuntime::spriteBatchSetTexture("),
	"SpriteBatch must use Love's original Type, constructor/method wrappers, and Matrix4 draw dispatch over Dora storage");
assert(runtime.includes("struct ParticleSystemUserdata final : ::love::graphics::ParticleSystem")
	&& particleSystemObject.includes("class ParticleSystem : public Drawable")
	&& runtime.includes("::love::graphics::luaopen_particlesystem(_state);")
	&& runtime.includes("{\"newParticleSystem\", ::love::graphics::w_newParticleSystem}")
	&& runtime.includes("_runtime->graphicsDrawCommand(state, particles, &transform);")
	&& particleSystemWrapper.includes("particleSystemCommand(L)->newParticleSystem(texture, int(size))")
	&& particleSystemWrapper.includes("return luax_register_type(L, &ParticleSystem::type, w_ParticleSystem_functions, nullptr);")
	&& !runtime.includes("::love::Type ParticleSystemLoveType")
	&& !runtime.includes("int LoveRuntime::graphicsNewParticleSystem(")
	&& !runtime.includes("int LoveRuntime::particleSystemSetTexture(")
	&& !runtime.includes("int LoveRuntime::particleSystemUpdate("),
	"ParticleSystem must use Love's Type, constructor/method wrappers, and Matrix4 draw dispatch over Dora storage");
assert(/struct FontUserdata final\s*\n\s*: DoraHandleObject<[\s\S]*?::love::graphics::Font>/.test(runtime)
	&& graphicsFontObject.includes("class Font : public Object")
	&& functionBody("registerFontType").includes("::love::graphics::luaopen_font(_state);")
	&& graphicsFontWrapper.includes("return luax_register_type(L, &Font::type, w_Font_functions, nullptr);")
	&& !runtime.includes("::love::Type FontUserdata::type")
	&& !functionBody("registerFontType").includes("luax_register_type"),
	"Font must use Love's original Type and method wrapper over Dora's state-local font backend");
assert(runtime.includes("struct TextUserdata final : ::love::graphics::Text")
	&& textObject.includes("class Text : public Drawable")
	&& functionBody("registerTextType").includes("::love::graphics::luaopen_text(_state);")
	&& runtime.includes('{"newText", ::love::graphics::w_newText}')
	&& graphicsAdapter.includes("public ::love::graphics::GraphicsTextCommand")
	&& textWrapper.includes("textCommand(L)->newText(font, text)")
	&& textWrapper.includes("return luax_register_type(L, &Text::type, w_Text_functions, nullptr);")
	&& runtime.includes("_runtime->graphicsDrawCommand(state, text, &transform);")
	&& !runtime.includes("::love::Type TextLoveType")
	&& !runtime.includes("int LoveRuntime::graphicsNewText(")
	&& !runtime.includes("int LoveRuntime::textSet("),
	"Text must use Love's original Type, constructor/method wrappers, and Matrix4 draw dispatch over Dora layout storage");
assert(/struct ShaderUserdata final\s*\n\s*: DoraHandleObject<[\s\S]*?::love::graphics::Shader>/.test(runtime)
	&& shaderObject.includes("class Shader : public Object")
	&& functionBody("registerShaderType").includes("::love::graphics::luaopen_shader(_state);")
	&& shaderWrapper.includes("return luax_register_type(L, &Shader::type, w_Shader_functions, nullptr);")
	&& runtime.includes("runtime->getGraphicsBackend()->getShaderUniformInfo(handle, name, backendInfo)")
	&& runtime.includes("runtime->getGraphicsBackend()->sendShaderFloats(handle, info->name,")
	&& !runtime.includes("::love::Type &ShaderUserdata::type")
	&& !runtime.includes("int LoveRuntime::shaderGetWarnings(")
	&& !runtime.includes("int LoveRuntime::shaderSendValues("),
	"Shader must use Love's original Type and method wrapper over Dora reflection and uniform submission");
assert(runtime.includes("struct VideoStreamUserdata final : ::love::video::VideoStream")
	&& /struct VideoUserdata final\s*\n\s*: DoraHandleObject<[\s\S]*?::love::graphics::Video>/.test(runtime)
	&& videoObject.includes("class Video : public Drawable")
	&& videoStreamObject.includes("class VideoStream : public Stream")
	&& functionBody("registerVideoTypes").includes("::love::video::luaopen_videostream(_state);")
	&& functionBody("registerVideoTypes").includes("::love::graphics::luaopen_video(_state);")
	&& videoWrapper.includes("luax_register_type(L, &Video::type, functions, nullptr)")
	&& videoStreamWrapper.includes("return luax_register_type(L, &VideoStream::type, videostream_functions, nullptr);")
	&& runtime.includes("::love::video::VideoStream *getStream() override { return stream; }")
	&& !runtime.includes("::love::Type &VideoUserdata::type")
	&& !runtime.includes("VideoStreamLoveType")
	&& !runtime.includes("int LoveRuntime::graphicsNewVideo(")
	&& !runtime.includes("int LoveRuntime::videoStreamPlay(")
	&& !runtime.includes("int LoveRuntime::videoGetStream("),
	"Video and VideoStream must use Love's original object Types and method wrappers over Dora decoding and drawing");
assert(graphicsAdapter.includes("public ::love::graphics::GraphicsVideoCommand")
	&& videoWrapper.includes("luax_convobj(L, 1, \"video\", \"newVideoStream\")")
	&& videoWrapper.includes("videoCommand(L)->newVideo(stream, dpiScale)")
	&& runtime.includes('{"_newVideo", ::love::graphics::w_newVideo}')
	&& runtime.includes("::love::graphics::installVideoConstructorWrapper(_state);")
	&& videoWrapper.includes("function love.graphics.newVideo(file, settings)")
	&& videoWrapper.includes("settings.audio ~= false")
	&& videoWrapper.includes("settings.dpiscale"),
	"love.graphics.newVideo must use Love's constructor semantics and the state-local Dora Video factory");
for (const type of ["ImageUserdata", "CanvasUserdata", "MeshUserdata", "SpriteBatchUserdata",
	"ParticleSystemUserdata", "TextUserdata", "VideoUserdata"]) {
	assert(runtime.includes(`std::is_base_of_v<::love::graphics::Drawable, ${type}>`),
		`${type} must derive from Love's real C++ Drawable base`);
}

assert(runtime.includes("void pushNewDoraHandleObject(lua_State *state, ::love::Type &type, Object *object)")
	&& runtime.includes("::love::luax_pushtype(state, type, object);")
	&& runtime.includes("object->release();"),
	"new Dora handle wrappers must hand their constructor reference to Love's Lua Proxy");
const doraHandleAllocations = [...runtime.matchAll(
	/auto \*(\w+) = new (Image|Canvas|Cursor|Font|Shader|AudioSource|Video|RecordingDevice|PhysicsWorld|PhysicsBody|PhysicsShape|PhysicsFixture|PhysicsJoint)Userdata\b/g)];
assert(doraHandleAllocations.length === 28
	&& runtime.includes("return new ShaderUserdata(_runtime, handle, std::move(warnings));"),
	`expected 28 direct Lua/factory handoffs plus the state-local Shader factory handoff, found ${doraHandleAllocations.length}`);
for (const allocation of doraHandleAllocations) {
	const [_, variable, type] = allocation;
	const tail = runtime.slice(allocation.index, allocation.index + 1200);
	const proxyHandoff = new RegExp(`pushNewDoraHandleObject\\(state, [^;]+, ${variable}\\);`).test(tail);
	const nativeHandoff = (type === "Font"
		&& tail.includes(`_graphicsFontObject.set(${variable}, ::love::Acquire::NORETAIN);`))
		|| (type === "Cursor" && tail.includes(
			`::love::StrongRef<::love::mouse::Cursor>(${variable}, ::love::Acquire::NORETAIN)`));
	const factoryHandoff = (type === "Canvas" || type === "Image")
		&& tail.includes(`return ${variable};`);
	const fontFactoryHandoff = type === "Font" && tail.includes(`return ${variable};`);
	const shapeFactoryHandoff = type === "PhysicsShape" && variable === "edge"
		&& tail.includes(`return ${variable};`);
	assert(proxyHandoff || nativeHandoff || factoryHandoff || fontFactoryHandoff || shapeFactoryHandoff,
		`${type} wrapper allocation '${variable}' does not transfer its initial native reference`);
}
assert(!/luax_pushtype\([^;]+(?:Image|Canvas|Cursor|Font|Shader|AudioSource|Video|RecordingDevice|Physics(?:World|Body|Shape|Fixture|Joint))(?:Userdata::type|LoveType)[^;]*\);\s*\w+->release\(\);/.test(runtime),
	"Dora handle Proxy ownership handoff must use pushNewDoraHandleObject instead of an open-coded pair");

for (const [set, retain] of [
	["_imageHandles", "retainLoveImageHandle"],
	["_canvasHandles", "retainLoveCanvasHandle"],
	["_fontHandles", "retainLoveFontHandle"],
	["_shaderHandles", "retainLoveShaderHandle"],
	["_audioHandles", "retainLoveAudioSourceHandle"],
	["_mouseCursorHandles", "retainLoveCursorHandle"],
	["_recordingHandles", "retainLoveRecordingHandle"],
	["_physicsWorldHandles", "retainLovePhysicsWorldHandle"],
	["_physicsBodyHandles", "retainLovePhysicsBodyHandle"],
	["_physicsShapeHandles", "retainLovePhysicsShapeHandle"],
	["_physicsFixtureHandles", "retainLovePhysicsFixtureHandle"],
	["_physicsJointHandles", "retainLovePhysicsJointHandle"],
]) {
	assert(runtime.split(`${set}.insert(`).length - 1 === 1
		&& runtime.includes(`void LoveRuntime::${retain}(`),
		`${set} ownership adoption bypasses the shared Dora handle wrapper`);
}
assert(loveNode.includes("format == bgfx::TextureFormat::ETC2A1")
	&& loveNode.includes("BGFX_CAPS_FORMAT_TEXTURE_2D_EMULATED")
	&& loveNode.split("isLoveCompressedTextureValid(").length - 1 === 4,
	"compressed image query and both creation paths must share the ETC2A1 emulation guard");

for (const [call, expected] of [
	["_graphicsBackend->releaseImage(", 1],
	["_graphicsBackend->releaseCanvas(", 1],
	["_graphicsBackend->releaseFont(", 1],
	["_graphicsBackend->releaseShader(", 1],
	["_audioBackend->releaseSource(", 1],
	["_audioBackend->stopRecording(", 1],
	["_mouseBackend->releaseCursor(", 1],
	["_physicsBackend->releaseWorld(", 1],
	["_physicsBackend->releaseBody(", 1],
	["_physicsBackend->releaseShape(", 1],
	["_physicsBackend->releaseFixture(", 1],
	["_physicsBackend->releaseJoint(", 1],
]) {
	assert(runtime.split(call).length - 1 === expected,
		`${call.slice(0, -1)} bypasses or duplicates the centralized Dora handle release path`);
}

for (const functionName of ["physicsWorldDestroy", "recordingDeviceStop"]) {
	const start = runtime.indexOf(`int LoveRuntime::${functionName}(`);
	const end = runtime.indexOf("\nint LoveRuntime::", start + 1);
	assert(start >= 0 && runtime.slice(start, end < 0 ? runtime.length : end)
		.includes("releaseDoraHandle()"),
		`${functionName} bypasses the shared Dora handle wrapper`);
}
const jointDestroyStart = runtime.indexOf("void LoveRuntime::destroyPhysicsJointObject(");
const jointDestroyEnd = runtime.indexOf("\nfloat PhysicsJointUserdata::getScalar(", jointDestroyStart);
assert(jointDestroyStart >= 0 && runtime.slice(jointDestroyStart, jointDestroyEnd)
	.includes("releaseDoraHandle()"),
	"destroyPhysicsJointObject bypasses the shared Dora handle wrapper");

function functionBody(name) {
	const match = runtime.match(new RegExp(`void LoveRuntime::${name}\\(\\)\\n\\{([\\s\\S]*?)(?=\\nvoid LoveRuntime::)`));
	assert(match, `runtime registration function ${name} was not found`);
	return match[1];
}

function namesInRegistrationFunction(name) {
	const body = functionBody(name);
	const names = new Set([...body.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)]
		.map(value => value[1]).filter(value => !value.startsWith("__")));
	for (const match of body.matchAll(/lua_setfield\(_state,\s*-2,\s*"([A-Za-z_]\w*)"\)/g)) {
		if (!match[1].startsWith("__")) names.add(match[1]);
	}
	if (body.includes("addLoveObjectMethods") || body.includes("luax_register_type")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

function methodsInRegistrationArray(registrationName, arrayName) {
	const body = functionBody(registrationName);
	const match = body.match(new RegExp(`${arrayName}\\[\\]\\s*=\\s*\\{([\\s\\S]*?)\\n\\s*\\};`));
	assert(match, `${registrationName} registration array ${arrayName} was not found`);
	return new Set([
		...[...match[1].matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)]
			.map(value => value[1]).filter(value => !value.startsWith("__")),
		"type", "typeOf", "release",
	]);
}

function union(...sets) {
	return new Set(sets.flatMap(set => [...set]));
}

function moduleRegistrationNames(moduleName) {
	const body = functionBody("registerLoveModule");
	if (moduleName === "graphics") {
		assert(body.includes("::love::luax_register_module(_state, wrappedGraphics);"),
			"runtime state-local Graphics module registration was not found");
		const match = body.match(/graphicsFunctions\[\]\s*=\s*\{([\s\S]*?)\n\s*\};/);
		assert(match, "runtime Graphics function array was not found");
		const names = new Set([...match[1].matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)]
			.map(value => value[1]));
		names.add("drawInstanced");
		return names;
	}
	const marker = `lua_setfield(_state, -2, "${moduleName}");`;
	const end = body.indexOf(marker);
	assert(end >= 0, `runtime module registration ${moduleName} was not found`);
	const start = body.lastIndexOf("lua_newtable(_state);", end);
	assert(start >= 0, `runtime module table ${moduleName} was not found`);
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	for (const match of block.matchAll(/lua_setfield\(_state,\s*-[23],\s*"([A-Za-z_]\w*)"\)/g)) {
		if (!match[1].startsWith("_")) names.add(match[1]);
	}
	return names;
}

function filesystemWrapperMethods() {
	const methods = upstreamMethods("filesystem/wrap_Filesystem.cpp");
	for (const name of ["init", "setFused", "setSource", "_setAndroidSaveExternal",
		"setSymlinksEnabled", "areSymlinksEnabled", "getCRequirePath", "setCRequirePath"])
		methods.delete(name);
	return methods;
}

function eventWrapperMethods() {
	const methods = upstreamMethods("event/wrap_Event.cpp");
	methods.delete("poll_i");
	methods.add("poll");
	return methods;
}

function windowWrapperMethods() {
	return union(upstreamMethods("window/wrap_Window.cpp"),
		new Set(["getWidth", "getHeight", "getDimensions"]));
}

const runtimeModules = new Map([
	["Graphics", moduleRegistrationNames("graphics")],
	["ImageModule", upstreamMethods("image/wrap_Image.cpp")],
	["FontModule", upstreamMethods("font/wrap_Font.cpp")],
	["SoundModule", upstreamMethods("sound/wrap_Sound.cpp")],
	["DataModule", upstreamMethods("data/wrap_DataModule.cpp")],
	["MathModule", union(
		upstreamMethods("math/wrap_Math.cpp"),
		new Set(["random", "randomNormal", "setRandomSeed", "getRandomSeed",
			"setRandomState", "getRandomState", "colorToBytes", "colorFromBytes",
			"compress", "decompress"]))],
	["Window", windowWrapperMethods()],
	["Event", eventWrapperMethods()],
	["Filesystem", filesystemWrapperMethods()],
	["Keyboard", upstreamMethods("keyboard/wrap_Keyboard.cpp")],
	["Mouse", upstreamMethods("mouse/wrap_Mouse.cpp")],
	["Touch", upstreamMethods("touch/wrap_Touch.cpp")],
	["JoystickModule", upstreamMethods("joystick/wrap_JoystickModule.cpp")],
	["Timer", upstreamMethods("timer/wrap_Timer.cpp")],
	["Audio", moduleRegistrationNames("audio")],
	["System", upstreamMethods("system/wrap_System.cpp")],
	["ThreadModule", upstreamMethods("thread/wrap_ThreadModule.cpp")],
	["VideoModule", moduleRegistrationNames("video")],
	["Physics", moduleRegistrationNames("physics")],
]);
// Internal closure capture used by module-level RNG methods, not an upstream
// Love Lua API and intentionally absent from editor declarations.
runtimeModules.get("MathModule").delete("_getRandomGenerator");
runtimeModules.get("ImageModule").delete("newCubeFaces");

const runtimeObjects = new Map([
	["Image", new Set()],
	["Canvas", new Set()],
	["ImageData", union(upstreamMethods("image/wrap_ImageData.cpp"),
		upstreamMethods("data/wrap_Data.cpp"), new Set(["type", "typeOf", "release"]))],
	["CompressedImageData", union(upstreamMethods("image/wrap_CompressedImageData.cpp"),
		upstreamMethods("data/wrap_Data.cpp"), new Set(["type", "typeOf", "release"]))],
	["Rasterizer", union(upstreamMethods("font/wrap_Rasterizer.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["GlyphData", union(upstreamMethods("font/wrap_GlyphData.cpp"),
		upstreamMethods("data/wrap_Data.cpp"), new Set(["type", "typeOf", "release"]))],
	["SoundData", union(upstreamMethods("sound/wrap_SoundData.cpp"),
		upstreamMethods("data/wrap_Data.cpp"), new Set(["type", "typeOf", "release"]))],
	["Decoder", union(upstreamMethods("sound/wrap_Decoder.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["RandomGenerator", union(upstreamMethods("math/wrap_RandomGenerator.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["Transform", union(upstreamMethods("math/wrap_Transform.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["BezierCurve", union(upstreamMethods("math/wrap_BezierCurve.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["ByteData", union(upstreamMethods("data/wrap_Data.cpp"),
		upstreamMethods("data/wrap_ByteData.cpp"), new Set(["type", "typeOf", "release"]))],
	["DataView", union(upstreamMethods("data/wrap_Data.cpp"),
		upstreamMethods("data/wrap_DataView.cpp"), new Set(["type", "typeOf", "release"]))],
	["CompressedData", union(upstreamMethods("data/wrap_Data.cpp"),
		upstreamMethods("data/wrap_CompressedData.cpp"), new Set(["type", "typeOf", "release"]))],
	["Quad", union(upstreamMethods("graphics/wrap_Quad.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["Mesh", namesInRegistrationFunction("registerMeshType")],
	["SpriteBatch", namesInRegistrationFunction("registerSpriteBatchType")],
	["ParticleSystem", namesInRegistrationFunction("registerParticleSystemType")],
	["Text", namesInRegistrationFunction("registerTextType")],
	["Shader", namesInRegistrationFunction("registerShaderType")],
	["Font", namesInRegistrationFunction("registerFontType")],
	["Source", namesInRegistrationFunction("registerAudioSourceType")],
	["RecordingDevice", namesInRegistrationFunction("registerRecordingDeviceType")],
	["Cursor", union(upstreamMethods("mouse/wrap_Cursor.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["Joystick", union(upstreamMethods("joystick/wrap_Joystick.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["File", union(upstreamMethods("filesystem/wrap_File.cpp"),
		new Set(["type", "typeOf", "release"]))],
	["FileData", union(upstreamMethods("data/wrap_Data.cpp"),
		upstreamMethods("filesystem/wrap_FileData.cpp"), new Set(["type", "typeOf", "release"]))],
]);
runtimeObjects.get("RandomGenerator").delete("_random");
runtimeObjects.get("RandomGenerator").add("random");
runtimeObjects.get("Transform").delete("__mul");
runtimeObjects.get("ImageData").delete("_mapPixelUnsafe");
runtimeObjects.get("ImageData").delete("_performAtomic");
runtimeObjects.get("ImageData").add("mapPixel");
assert(/struct AudioSourceUserdata final\s*\n\s*: DoraHandleObject<[\s\S]*?::love::audio::Source>/.test(runtime)
	&& audioSourceObject.includes("class Source : public Object")
	&& functionBody("registerAudioSourceType").includes("::love::audio::luaopen_source(_state);")
	&& audioSourceWrapper.includes(
		"return luax_register_type(L, &love::audio::Source::type, w_Source_functions, nullptr);")
	&& runtime.includes("::love::Type &AudioSourceUserdata::type = ::love::audio::Source::type;")
	&& !runtime.includes("int LoveRuntime::audioSourceClone(")
	&& !runtime.includes("int LoveRuntime::audioSourceSetVolume("),
	"Source must use Love's original Type and method wrapper over Dora's state-local audio backend");
runtimeObjects.set("Source", union(upstreamMethods("audio/wrap_Source.cpp"),
	new Set(["type", "typeOf", "release"])));
assert(runtime.includes("::love::math::luaopen_love_math(_state);")
	&& !runtime.includes("registerRandomGeneratorType"),
	"RandomGenerator must be registered through the compiled Love 11.5 math wrapper only");
assert(runtime.includes("::love::math::luaopen_love_math(_state);")
	&& !runtime.includes("registerTransformType"),
	"Transform must be registered through the compiled Love 11.5 math wrapper only");
assert(runtime.includes("::love::math::luaopen_love_math(_state);")
	&& !runtime.includes("registerBezierCurveType"),
	"BezierCurve must be registered through the compiled Love 11.5 math wrapper only");
assert(runtime.includes("::love::data::luaopen_love_data(_state);")
	&& !runtime.includes("registerByteDataType")
	&& !runtime.includes("registerDataViewType")
	&& !runtime.includes("registerCompressedDataType"),
	"DataModule, ByteData, DataView, and CompressedData must use the compiled Love 11.5 wrappers only");
assert(runtime.includes("::love::filesystem::luaopen_love_filesystem(_state);")
	&& !runtime.includes("int LoveRuntime::fileOpen(")
	&& !runtime.includes("int LoveRuntime::fileDataClone("),
	"File and FileData must be registered by the compiled Love 11.5 filesystem wrapper only");
assert(runtime.includes("::love::filesystem::luaopen_love_filesystem(_state);")
	&& runtime.includes("new Dora::Love::DoraLoveFilesystem(runtime)")
	&& !runtime.includes("lua_pushcclosure(_state, filesystemRead, 1)"),
	"Filesystem must use the compiled Love 11.5 wrapper with the Dora Content adapter");
assert(runtime.includes("::love::sound::luaopen_love_sound(_state);")
	&& !runtime.includes("registerSoundDataType")
	&& !runtime.includes("int LoveRuntime::soundDataClone("),
	"SoundData must be registered by the compiled Love 11.5 wrapper only");
assert(runtime.includes("new Dora::Love::DoraLoveSound(runtime)")
	&& runtime.includes("struct DecoderUserdata final : ::love::sound::Decoder")
	&& !runtime.includes("registerDecoderType")
	&& !runtime.includes("int LoveRuntime::decoderDecode("),
	"Sound and Decoder must use the compiled Love 11.5 wrappers with the Dora SoLoud adapter");
assert(runtime.includes("::love::font::luaopen_love_font(_state);")
	&& !runtime.includes("registerGlyphDataType")
	&& !runtime.includes("int LoveRuntime::glyphDataClone("),
	"GlyphData must be registered by the compiled Love 11.5 font wrapper only");
assert(runtime.includes("::love::font::luaopen_love_font(_state);")
	&& !runtime.includes("registerRasterizerType")
	&& !runtime.includes("int LoveRuntime::rasterizerGetHeight("),
	"Rasterizer must be registered by the compiled Love 11.5 font wrapper only");
assert(runtime.includes("::love::font::luaopen_love_font(_state);")
	&& runtime.includes("new Dora::Love::DoraLoveFont(runtime)")
	&& !runtime.includes("int LoveRuntime::fontNewImageRasterizer("),
	"Font module must use the compiled Love 11.5 wrapper with the Dora font adapter");
assert(runtime.includes("::love::image::luaopen_imagedata(_state);")
	&& !runtime.includes("registerImageDataType")
	&& !runtime.includes("int LoveRuntime::imageDataClone("),
	"ImageData must be registered by the compiled Love 11.5 wrapper only");
assert(runtime.includes("::love::graphics::luaopen_quad(_state);")
	&& !runtime.includes("int LoveRuntime::quadSetViewport(")
	&& !runtime.includes("QuadLoveType"),
	"Quad must use the compiled Love 11.5 object and wrapper only");
assert(runtime.includes("::love::image::luaopen_compressedimagedata(_state);")
	&& !runtime.includes("int LoveRuntime::compressedImageDataClone(")
	&& runtime.includes("class DoraCompressedImageData final"),
	"CompressedImageData must use the compiled Love 11.5 wrapper with the Dora parser adapter");
assert(runtime.includes("::love::image::luaopen_love_image(_state);")
	&& runtime.includes("new Dora::Love::DoraLoveImage(runtime)")
	&& !runtime.includes("int LoveRuntime::imageNewImageData("),
	"Image module must use the compiled Love 11.5 wrapper with the Dora image adapter");

function methodsInMetatableBlock(registrationName, metatable, nextMetatable = null) {
	const body = functionBody(registrationName);
	const marker = `if (luaL_newmetatable(_state, ${metatable}))`;
	const start = body.indexOf(marker);
	assert(start >= 0, `${registrationName} registration ${metatable} was not found`);
	let end = nextMetatable
		? body.indexOf(`if (luaL_newmetatable(_state, ${nextMetatable}))`, start + marker.length)
		: body.length;
	if (end < 0) end = body.length;
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	if (block.includes("addLoveObjectMethods")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

runtimeObjects.set("VideoStream", union(upstreamMethods("video/wrap_VideoStream.cpp"),
	new Set(["type", "typeOf", "release"])));

function threadMethods(metatable) {
	const body = functionBody("registerThreadTypes");
	const marker = `if (luaL_newmetatable(_state, ${metatable}))`;
	const start = body.indexOf(marker);
	assert(start >= 0, `thread registration ${metatable} was not found`);
	let end = body.indexOf("\n\tif (luaL_newmetatable", start + marker.length);
	if (end < 0) end = body.length;
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	if (block.includes("addLoveObjectMethods")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

runtimeObjects.set("Thread", union(upstreamMethods("thread/wrap_LuaThread.cpp"),
	new Set(["type", "typeOf", "release"])));
runtimeObjects.set("Channel", union(upstreamMethods("thread/wrap_Channel.cpp"),
	new Set(["type", "typeOf", "release"])));

assert(functionBody("registerThreadTypes").includes("::love::thread::luaopen_thread(_state);")
	&& functionBody("registerThreadTypes").includes("::love::thread::luaopen_channel(_state);")
	&& functionBody("registerLoveModule").includes("::love::thread::luaopen_love_thread(_state);")
	&& threadModuleWrapper.includes("luax_getmodule<ThreadModule>(L, Module::M_THREAD)")
	&& threadModuleWrapper.includes("instance = newDoraThreadModule(L)")
	&& threadObjectWrapper.includes("return luax_register_type(L, &LuaThread::type")
	&& channelObjectWrapper.includes("return luax_register_type(L, &Channel::type")
	&& runtime.includes("class DoraLoveThreadModule final")
	&& runtime.includes("class DoraLoveLuaThread final")
	&& runtime.includes("class DoraLoveChannel final")
	&& !runtime.includes("ThreadUserdata")
	&& !runtime.includes("ChannelUserdata")
	&& !runtime.includes("int LoveRuntime::threadNewThread(")
	&& !runtime.includes("int LoveRuntime::channelPush("),
	"Thread and Channel must use Love's original Types and wrappers over Dora's state-local Lua 5.5 worker backend");

runtimeObjects.set("Joint", union(upstreamMethods("physics/wrap_Joint.cpp"),
	new Set(["type", "typeOf", "release"])));

assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_body(_state);")
	&& !runtime.includes("int LoveRuntime::physicsBodyDestroy(")
	&& /struct PhysicsBodyUserdata final[\s\S]*?::love::physics::Body>/.test(runtime),
	"Body must use Love's original Type and wrapper over Dora's state-local physics backend");
runtimeObjects.set("Body", union(upstreamMethods("physics/wrap_Body.cpp"),
	new Set(["type", "typeOf", "release"])));
const worldMethods = upstreamMethods("physics/wrap_World.cpp");
worldMethods.delete("setContactFilter");
worldMethods.delete("getContactFilter");
runtimeObjects.set("World", union(worldMethods, new Set(["type", "typeOf", "release"])));
runtimeObjects.set("Contact", union(upstreamMethods("physics/wrap_Contact.cpp"),
	new Set(["type", "typeOf", "release"])));
runtimeObjects.set("Fixture", union(upstreamMethods("physics/wrap_Fixture.cpp"),
	new Set(["type", "typeOf", "release"])));
runtimeObjects.set("Shape", union(upstreamMethods("physics/wrap_Shape.cpp"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_world(_state);")
	&& !functionBody("registerPhysicsTypes").includes("registerType(&::love::physics::World::type")
	&& /struct PhysicsWorldUserdata final[\s\S]*?::love::physics::World>/.test(runtime),
	"World must use Love's original Type and wrapper over Dora's state-local physics backend");
assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_contact(_state);")
	&& !functionBody("registerPhysicsTypes").includes("registerType(&::love::physics::Contact::type")
	&& !runtime.includes("int LoveRuntime::physicsContactGetPositions(")
	&& /struct PhysicsContactUserdata final\s*:\s*::love::physics::Contact/.test(runtime),
	"Contact must use Love's original Type and wrapper over Dora's state-local physics backend");
assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_fixture(_state);")
	&& !functionBody("registerPhysicsTypes").includes("registerType(&::love::physics::Fixture::type")
	&& !runtime.includes("int LoveRuntime::physicsFixtureDestroy(")
	&& /struct PhysicsFixtureUserdata final[\s\S]*?::love::physics::Fixture>/.test(runtime),
	"Fixture must use Love's original Type and wrapper over Dora's state-local physics backend");
assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_shape(_state);")
	&& !functionBody("registerPhysicsTypes").includes("registerType(&::love::physics::Shape::type")
	&& !runtime.includes("int LoveRuntime::physicsShapeGetType(")
	&& /struct PhysicsShapeUserdata final[\s\S]*?::love::physics::Shape>/.test(runtime),
	"Shape must use Love's adapted original wrappers over Dora's state-local physics backend");
assert(functionBody("registerPhysicsTypes").includes("::love::physics::luaopen_joint(_state);")
	&& !functionBody("registerPhysicsTypes").includes("registerType(&::love::physics::Joint::type")
	&& !runtime.includes("int LoveRuntime::physicsDistanceJointGetLength(")
	&& /struct PhysicsJointUserdata final[\s\S]*?::love::physics::Joint>/.test(runtime),
	"Joint methods must use Love's adapted original wrappers over Dora's state-local physics backend");

const upstreamGraphicsModule = upstreamGraphicsMethods("Graphics");
upstreamGraphicsModule.delete("_setDefaultShaderCode");
// The original Lua constructor replaces the internal C++ _newVideo hook.
runtimeModules.get("Graphics").add("newVideo");
const missingGraphicsModuleMethods = [...upstreamGraphicsModule]
	.filter(name => !runtimeModules.get("Graphics").has(name)).sort();
assert(missingGraphicsModuleMethods.length === 0,
	`runtime Graphics is missing Love 11.5 wrapper methods: ${missingGraphicsModuleMethods.join(", ")}`);

const upstreamTextureMethods = upstreamGraphicsMethods("Texture");
runtimeObjects.set("Image", union(upstreamTextureMethods,
	upstreamGraphicsMethods("Image"), new Set(["type", "typeOf", "release"])));
runtimeObjects.set("Canvas", union(upstreamTextureMethods,
	upstreamGraphicsMethods("Canvas"), new Set(["type", "typeOf", "release"])));
assert(runtime.includes("::love::graphics::luaopen_image(_state);")
	&& !functionBody("registerImageType").includes("luax_register_type")
	&& !runtime.includes("int LoveRuntime::imageGetWidth(")
	&& !runtime.includes("int LoveRuntime::imageReplacePixels("),
	"Image and inherited Texture methods must use Love 11.5's compiled graphics wrappers");
const upstreamGraphicsObjects = new Map([
	["Image", union(upstreamTextureMethods, upstreamGraphicsMethods("Image"))],
	["Canvas", union(upstreamTextureMethods, upstreamGraphicsMethods("Canvas"))],
	["Font", upstreamGraphicsMethods("Font")],
	["Mesh", upstreamGraphicsMethods("Mesh")],
	["ParticleSystem", upstreamGraphicsMethods("ParticleSystem")],
	["Quad", upstreamGraphicsMethods("Quad")],
	["Shader", upstreamGraphicsMethods("Shader")],
	["SpriteBatch", upstreamGraphicsMethods("SpriteBatch")],
	["Text", upstreamGraphicsMethods("Text")],
	["Video", upstreamGraphicsMethods("Video")],
]);
assert(functionBody("registerMeshType").includes("::love::graphics::luaopen_mesh(_state);"),
	"Mesh type registration must call Love's compiled wrapper");
runtimeObjects.set("Mesh", union(upstreamGraphicsObjects.get("Mesh"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerSpriteBatchType").includes(
	"::love::graphics::luaopen_spritebatch(_state);"),
	"SpriteBatch type registration must call Love's compiled wrapper");
runtimeObjects.set("SpriteBatch", union(upstreamGraphicsObjects.get("SpriteBatch"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerParticleSystemType").includes(
	"::love::graphics::luaopen_particlesystem(_state);"),
	"ParticleSystem type registration must call Love's compiled wrapper");
runtimeObjects.set("ParticleSystem", union(upstreamGraphicsObjects.get("ParticleSystem"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerFontType").includes("::love::graphics::luaopen_font(_state);"),
	"Font type registration must call Love's compiled wrapper");
runtimeObjects.set("Font", union(upstreamGraphicsObjects.get("Font"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerTextType").includes("::love::graphics::luaopen_text(_state);"),
	"Text type registration must call Love's compiled wrapper");
runtimeObjects.set("Text", union(upstreamGraphicsObjects.get("Text"),
	new Set(["type", "typeOf", "release"])));
assert(functionBody("registerShaderType").includes("::love::graphics::luaopen_shader(_state);"),
	"Shader type registration must call Love's compiled wrapper");
runtimeObjects.set("Shader", union(upstreamGraphicsObjects.get("Shader"),
	new Set(["type", "typeOf", "release"])));
// Love's Lua wrapper exposes these public helpers over the C _setSource hook.
upstreamGraphicsObjects.get("Video").delete("_setSource");
for (const method of ["setSource", "play", "pause", "seek", "rewind", "tell", "isPlaying"])
	upstreamGraphicsObjects.get("Video").add(method);
runtimeObjects.set("Video", union(upstreamGraphicsObjects.get("Video"),
	new Set(["type", "typeOf", "release"])));
let upstreamGraphicsMethodChecks = upstreamGraphicsModule.size;
for (const [type, expected] of upstreamGraphicsObjects) {
	const actual = runtimeObjects.get(type);
	assert(actual, `runtime Graphics object registration ${type} was not found`);
	const missing = [...expected].filter(name => !actual.has(name)).sort();
	assert(missing.length === 0,
		`runtime ${type} is missing Love 11.5 wrapper methods: ${missing.join(", ")}`);
	upstreamGraphicsMethodChecks += expected.size;
}

const upstreamModuleFiles = new Map([
	["Audio", "audio/wrap_Audio.cpp"],
	["DataModule", "data/wrap_DataModule.cpp"],
	["Event", "event/wrap_Event.cpp"],
	["Filesystem", "filesystem/wrap_Filesystem.cpp"],
	["FontModule", "font/wrap_Font.cpp"],
	["ImageModule", "image/wrap_Image.cpp"],
	["JoystickModule", "joystick/wrap_JoystickModule.cpp"],
	["Keyboard", "keyboard/wrap_Keyboard.cpp"],
	["MathModule", "math/wrap_Math.cpp"],
	["Mouse", "mouse/wrap_Mouse.cpp"],
	["SoundModule", "sound/wrap_Sound.cpp"],
	["System", "system/wrap_System.cpp"],
	["ThreadModule", "thread/wrap_ThreadModule.cpp"],
	["Timer", "timer/wrap_Timer.cpp"],
	["Touch", "touch/wrap_Touch.cpp"],
	["VideoModule", "video/wrap_Video.cpp"],
	["Window", "window/wrap_Window.cpp"],
]);

const upstreamObjectFiles = new Map([
	["RecordingDevice", ["audio/wrap_RecordingDevice.cpp"]],
	["Source", ["audio/wrap_Source.cpp"]],
	["ByteData", ["data/wrap_ByteData.cpp", "data/wrap_Data.cpp"]],
	["CompressedData", ["data/wrap_CompressedData.cpp", "data/wrap_Data.cpp"]],
	["DataView", ["data/wrap_DataView.cpp", "data/wrap_Data.cpp"]],
	["File", ["filesystem/wrap_File.cpp"]],
	["FileData", ["filesystem/wrap_FileData.cpp", "data/wrap_Data.cpp"]],
	["GlyphData", ["font/wrap_GlyphData.cpp", "data/wrap_Data.cpp"]],
	["Rasterizer", ["font/wrap_Rasterizer.cpp"]],
	["CompressedImageData", ["image/wrap_CompressedImageData.cpp", "data/wrap_Data.cpp"]],
	["ImageData", ["image/wrap_ImageData.cpp", "data/wrap_Data.cpp"]],
	["Joystick", ["joystick/wrap_Joystick.cpp"]],
	["BezierCurve", ["math/wrap_BezierCurve.cpp"]],
	["RandomGenerator", ["math/wrap_RandomGenerator.cpp"]],
	["Transform", ["math/wrap_Transform.cpp"]],
	["Cursor", ["mouse/wrap_Cursor.cpp"]],
	["Decoder", ["sound/wrap_Decoder.cpp"]],
	["SoundData", ["sound/wrap_SoundData.cpp", "data/wrap_Data.cpp"]],
	["Channel", ["thread/wrap_Channel.cpp"]],
	["Thread", ["thread/wrap_LuaThread.cpp"]],
	["VideoStream", ["video/wrap_VideoStream.cpp"]],
]);

const intentionalModuleGaps = new Map([
	["Filesystem", new Set(["areSymlinksEnabled", "getCRequirePath", "setCRequirePath", "setSymlinksEnabled"])],
]);
const internalUpstreamModuleMethods = new Map([
	["Filesystem", new Set(["_setAndroidSaveExternal", "init", "setFused", "setSource"])],
	["ImageModule", new Set(["newCubeFaces"])],
	["MathModule", new Set(["_getRandomGenerator"])],
]);

let upstreamCoreMethodChecks = 0;
for (const [type, path] of upstreamModuleFiles) {
	const expected = type === "Event" ? eventWrapperMethods()
		: type === "Window" ? windowWrapperMethods() : upstreamMethods(path);
	for (const name of expected) if (name.startsWith("_")) expected.delete(name);
	for (const name of internalUpstreamModuleMethods.get(type) ?? []) expected.delete(name);
	const actual = runtimeModules.get(type);
	assert(actual, `runtime module registration ${type} was not found`);
	const missing = new Set([...expected].filter(name => !actual.has(name)));
	const allowed = intentionalModuleGaps.get(type) ?? new Set();
	assert([...missing].sort().join(",") === [...allowed].sort().join(","),
		`runtime ${type} Love 11.5 module gaps changed: missing=[${[...missing].sort().join(", ")}], expected=[${[...allowed].sort().join(", ")}]`);
	upstreamCoreMethodChecks += expected.size;
}

for (const [type, paths] of upstreamObjectFiles) {
	const expected = union(...paths.map(upstreamMethods));
	for (const name of expected) if (name.startsWith("_")) expected.delete(name);
	const actual = runtimeObjects.get(type);
	assert(actual, `runtime object registration ${type} was not found`);
	const missing = [...expected].filter(name => !actual.has(name)).sort();
	assert(missing.length === 0,
		`runtime ${type} is missing Love 11.5 wrapper methods: ${missing.join(", ")}`);
	upstreamCoreMethodChecks += expected.size;
}

function parseTypeScriptDeclarations(text, fileName) {
	const source = ts.createSourceFile(fileName, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
	const own = new Map();
	const bases = new Map();
	function visit(node) {
		if (ts.isInterfaceDeclaration(node)) {
			const name = node.name.text;
			if (!own.has(name)) own.set(name, new Set());
			for (const member of node.members) {
				if ((ts.isMethodSignature(member) || ts.isPropertySignature(member)) && member.name) {
					const value = member.name.getText(source).replace(/^['"]|['"]$/g, "");
					if (/^[A-Za-z_]\w*$/.test(value) && (ts.isMethodSignature(member)
						|| member.type && ts.isFunctionTypeNode(member.type))) own.get(name).add(value);
				}
			}
			bases.set(name, (node.heritageClauses ?? []).flatMap(clause =>
				clause.types.map(type => type.expression.getText(source))));
		}
		ts.forEachChild(node, visit);
	}
	visit(source);
	const flattened = new Map();
	function methods(name, visiting = new Set()) {
		if (flattened.has(name)) return flattened.get(name);
		assert(!visiting.has(name), `${fileName} has cyclic interface inheritance at ${name}`);
		visiting.add(name);
		const result = new Set(own.get(name) ?? []);
		for (const base of bases.get(name) ?? []) for (const method of methods(base, visiting)) result.add(method);
		visiting.delete(name);
		flattened.set(name, result);
		return result;
	}
	for (const name of own.keys()) methods(name);
	return flattened;
}

function parseTealDeclarations(text, fileName) {
	const records = new Map();
	const stack = [];
	for (const [lineNumber, line] of text.split(/\r?\n/).entries()) {
		const record = line.match(/^(\s*)(?:local\s+)?record\s+([A-Za-z_]\w*)\s*$/);
		if (record) {
			const indent = record[1].replace(/\t/g, "    ").length;
			stack.push({indent, name: record[2]});
			if (!records.has(record[2])) records.set(record[2], new Set());
			continue;
		}
		const end = line.match(/^(\s*)end\s*$/);
		if (end && stack.length) {
			const indent = end[1].replace(/\t/g, "    ").length;
			if (indent === stack.at(-1).indent) stack.pop();
			continue;
		}
		if (!stack.length) continue;
		const field = line.match(/^\s*([A-Za-z_]\w*):\s*function\b/);
		if (field) records.get(stack.at(-1).name).add(field[1]);
		if (/^\s*[^-\s]/.test(line) && line.includes(": function") && !field)
			throw new Error(`${fileName}:${lineNumber + 1} has an unparsed function field`);
	}
	return records;
}

function compareSurface(label, runtimeSurface, declarations, aliases = new Map()) {
	const failures = [];
	let methodCount = 0;
	for (const [runtimeName, runtimeMethods] of runtimeSurface) {
		const declarationNames = aliases.get(runtimeName) ?? [runtimeName];
		const declared = union(...declarationNames.map(name => declarations.get(name) ?? new Set()));
		assert(declarationNames.some(name => declarations.has(name)),
			`${label} is missing declaration record ${declarationNames.join(" or ")}`);
		methodCount += runtimeMethods.size;
		const missing = [...runtimeMethods].filter(name => !declared.has(name)).sort();
		const phantom = [...declared].filter(name => !runtimeMethods.has(name)).sort();
		if (missing.length || phantom.length) failures.push(
			`${runtimeName}: missing=[${missing.join(", ")}] phantom=[${phantom.join(", ")}]`);
	}
	assert(failures.length === 0, `${label} API parity failed:\n${failures.join("\n")}`);
	return methodCount;
}

const objectAliases = new Map([
	["Shape", ["Shape", "CircleShape", "PolygonShape", "EdgeShape", "ChainShape"]],
	["Joint", ["Joint", "DistanceJoint", "RevoluteJoint", "PrismaticJoint", "WeldJoint",
		"FrictionJoint", "RopeJoint", "PulleyJoint", "WheelJoint", "MouseJoint", "MotorJoint", "GearJoint"]],
]);

const declarationFiles = [
	["English TypeScript", "Assets/Script/Lib/Dora/en/love.d.ts", parseTypeScriptDeclarations],
	["Chinese TypeScript", "Assets/Script/Lib/Dora/zh-Hans/love.d.ts", parseTypeScriptDeclarations],
	["English Teal", "Assets/Script/Lib/Dora/en/love.d.tl", parseTealDeclarations],
	["Chinese Teal", "Assets/Script/Lib/Dora/zh-Hans/love.d.tl", parseTealDeclarations],
];

let checkedMethods = 0;
for (const [label, path, parser] of declarationFiles) {
	const text = readFileSync(nodePath.join(doraSSRRoot, path), "utf8");
	const declarations = parser(text, path);
	checkedMethods += compareSurface(`${label} modules`, runtimeModules, declarations);
	checkedMethods += compareSurface(`${label} objects`, runtimeObjects, declarations, objectAliases);
}

console.log(`PASS: Love 11.5 wrapper parity (${upstreamGraphicsMethodChecks} Graphics + ${upstreamCoreMethodChecks} core method checks); runtime API parity across English/Chinese TypeScript/Teal declarations (${checkedMethods} method checks)`);
