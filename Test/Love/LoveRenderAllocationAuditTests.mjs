#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {doraSSRRoot} from "./TestPaths.mjs";

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

const loveNode = fs.readFileSync(path.join(doraSSRRoot, "Source/Love/LoveNode.cpp"), "utf8");
const loveNodeHeader = fs.readFileSync(path.join(doraSSRRoot, "Source/Love/LoveNode.h"), "utf8");
const loveRuntime = fs.readFileSync(path.join(doraSSRRoot, "Source/Love/LoveRuntime.cpp"), "utf8");
const loveRuntimeHeader = fs.readFileSync(path.join(doraSSRRoot, "Source/Love/LoveRuntime.h"), "utf8");
const renderTarget = fs.readFileSync(path.join(doraSSRRoot, "Source/Render/RenderTarget.cpp"), "utf8");
const bgfxGL = fs.readFileSync(path.join(doraSSRRoot, "Source/3rdParty/bgfx/src/renderer_gl.cpp"), "utf8");
const bgfxGLHeader = fs.readFileSync(path.join(doraSSRRoot, "Source/3rdParty/bgfx/src/renderer_gl.h"), "utf8");
const audioBoundary = loveNode.indexOf("Love::AudioBackend::SourceHandle LoveNode::newSource(");
const graphicsImplementation = loveNode.slice(0, audioBoundary);

assert(!loveNode.includes("Label::create("),
	"TrueType/SDF Love text regressed to allocating Dora Labels");
assert(!loveNode.includes("DrawNode::create("),
	"Love primitive drawing regressed to allocating Dora DrawNodes");
assert(!loveNode.includes("Sprite::create("),
	"Love drawing regressed to allocating Dora Sprites");
assert(loveNode.includes("class LoveRenderCommand")
	&& loveNode.includes("class LovePrimitiveCommand final : public LoveRenderCommand")
	&& loveNode.includes("class LoveTexturedMeshCommand final : public LoveRenderCommand")
	&& loveNode.includes("class LoveBufferedMeshCommand final : public LoveRenderCommand")
	&& loveNode.includes("class LoveDynamicMeshCommand final : public LoveRenderCommand")
	&& !loveNode.includes("LoveRenderStateNode")
	&& !loveNode.includes("LoveNodeRenderCommand")
	&& !loveNode.includes("LoveTexturedMeshNode")
	&& !loveNode.includes("LoveBufferedMeshNode")
	&& !loveNode.includes("LoveDynamicMeshNode")
	&& !loveNode.includes("recordNode(")
	&& !loveNodeHeader.includes("_drawNode")
	&& !loveNode.includes("ensureCommandRoot"),
	"Love rendering regressed from flat commands to Dora scene nodes");
assert(loveNodeHeader.includes("std::vector<std::unique_ptr<LoveRenderCommand>> commands")
	&& loveNodeHeader.includes("LoveRenderCommand *_imageBatchCommand = nullptr")
	&& !loveNodeHeader.includes("std::shared_ptr<LoveRenderCommand>"),
	"flat Love commands must retain single ownership without scene-style shared nodes");
assert(loveNodeHeader.includes("class LoveNode : public Sprite")
	&& loveNode.includes("setTexture(_renderTarget->getTexture())")
	&& audioBoundary >= 0
	&& !graphicsImplementation.includes("addChild("),
	"LoveNode must be the sole graphics host node around its completed render target");
const childArguments = [...loveNode.matchAll(/\baddChild\(([^)]+)\)/g)].map(match => match[1]);
assert(childArguments.length > 0 && childArguments.every(argument => argument === "audioNode"),
	"only Dora AudioSource lifetime/spatial semantics may introduce LoveNode children");
assert(loveNode.includes("bgfx::submit(SharedView.getId(), SharedDrawRenderer.getDefaultPass()->apply())")
	&& loveNode.match(/bgfx::submit\(SharedView\.getId\(\), pass->apply\(\)/g)?.length >= 3,
	"Love draw commands no longer submit directly through the Dora/bgfx renderer boundary");
assert(renderTarget.includes("void RenderTarget::submitAfterClear(")
	&& renderTarget.includes("if (commands) commands();"),
	"RenderTarget no longer accepts direct renderer command submission");
assert(loveRuntime.includes("if (batch->geometryDirty || !batch->attachments.empty())")
	&& loveRuntime.includes("if (particleSystem->geometryDirty)")
	&& loveRuntime.includes("preparedParticleCount != particleSystem->particles.size()")
	&& loveRuntime.includes("preparedRevision == mesh->geometryRevision"),
	"Love SpriteBatch, ParticleSystem, or Mesh reusable geometry cache is missing");
assert(loveRuntimeHeader.includes("mutable std::shared_ptr<void> gpuBuffer")
	&& loveNode.includes("class LoveGpuBufferPool")
	&& loveNode.includes("BGFX_BUFFER_ALLOW_RESIZE")
	&& loveNode.includes("struct LoveMeshGpuBuffer")
	&& loveNode.includes("bgfx::createDynamicVertexBuffer")
	&& loveNode.includes("uploadedIndexRevision != _buffer->revision")
	&& !loveNode.includes("bgfx::allocTransientBuffers")
	&& !loveNode.includes("not enough transient buffer for Love buffered Mesh"),
	"Love cached Mesh geometry no longer owns persistent bgfx buffers");
assert(renderTarget.includes("case bgfx::RendererType::OpenGLES:")
	&& renderTarget.includes("caps->supported & BGFX_CAPS_TEXTURE_BLIT")
	&& renderTarget.includes("caps->supported & BGFX_CAPS_TEXTURE_READ_BACK")
	&& renderTarget.includes("BGFX_TEXTURE_READ_BACK")
	&& renderTarget.includes("BGFX_TEXTURE_BLIT_DST"),
	"RenderTarget readback no longer selects direct or staging paths from runtime capabilities");
assert(bgfxGLHeader.includes("#\tdefine BGFX_GL_CONFIG_BLIT_EMULATION (BGFX_CONFIG_RENDERER_OPENGLES != 0)")
	&& bgfxGL.includes("emulateReadBackBlit")
	&& bgfxGL.includes("glFramebufferTextureLayer")
	&& bgfxGL.includes("glCopyTexSubImage2D"),
	"OpenGLES bgfx readback blit emulation is missing");

console.log("LOVE_RENDER_ALLOCATION_AUDIT_PASS");
