import fs from "node:fs";
import path from "node:path";
import {doraSSRRoot, testRoot} from "./TestPaths.mjs";
const repositoryRoot = doraSSRRoot;
const loveAdapterSources = [
	"LoveRuntime.cpp",
	"LoveDataAlgorithms.cpp",
	"LoveLZ4.c",
	"LoveLZ4HC.c",
	"LoveNode.cpp",
	"LoveVideoSources.cpp",
];

const oggSource = "Source/3rdParty/ogg/OggSources.c";
const theoraSource = "Source/3rdParty/theora/TheoraSources.c";

if (fs.existsSync(path.join(repositoryRoot, "Source/Audio/OggSources.c")))
	throw new Error("legacy Source/Audio/OggSources.c must stay removed; libogg belongs to Source/3rdParty/ogg");

function read(relativePath) {
	return fs.readFileSync(path.join(repositoryRoot, relativePath), "utf8");
}

function readTest(relativePath) {
	return fs.readFileSync(path.join(testRoot, relativePath), "utf8");
}

function requireContains(content, relativePath, needle) {
	if (!content.includes(needle))
		throw new Error(`${relativePath} is missing Love platform build contract: ${needle}`);
}

function requireCount(content, relativePath, needle, expected) {
	const actual = content.split(needle).length - 1;
	if (actual !== expected)
		throw new Error(`${relativePath} expected ${expected} occurrence(s) of ${needle}, got ${actual}`);
}

function requireAtLeast(content, relativePath, needle, minimum) {
	const actual = content.split(needle).length - 1;
	if (actual < minimum)
		throw new Error(`${relativePath} expected at least ${minimum} occurrence(s) of ${needle}, got ${actual}`);
}

const linuxPath = "Projects/Linux/CMakeLists.txt";
const linux = read(linuxPath);
requireContains(linux, linuxPath, "${DORA_SOURCE_ROOT}/3rdParty/Love/src");
for (const source of loveAdapterSources)
	requireCount(linux, linuxPath, `../../Source/Love/${source}`, 1);
requireContains(linux, linuxPath, "add_library(LOVE-lib STATIC IMPORTED)");
requireContains(linux, linuxPath, "${DORA_LOVE_BUILD_DIR}/liblove.a");
requireContains(linux, linuxPath, "add_library(THEORA-lib STATIC IMPORTED)");
requireContains(linux, linuxPath, "3rdParty/theora/Lib/Linux/${DORA_RUNTIME_ARCH}");
requireContains(linux, linuxPath, "LOVE-lib THEORA-lib BGFX-lib");
requireCount(linux, linuxPath, "LoveObjectRuntimeSupport.cpp", 0);
requireCount(linux, linuxPath, `../../${oggSource}`, 1);
requireCount(linux, linuxPath, `../../${theoraSource}`, 0);
requireCount(linux, linuxPath, "h264bsd", 0);

const windowsPath = "Projects/Windows/Dora/Dora.vcxproj";
const windows = read(windowsPath);
requireAtLeast(windows, windowsPath, "../../../Source/3rdParty/Love/src", 2);
for (const source of loveAdapterSources)
	requireCount(windows, windowsPath, `..\\..\\..\\Source\\Love\\${source}`, 1);
requireAtLeast(windows, windowsPath, "Source\\3rdParty\\Love\\Artifacts\\Windows", 2);
requireAtLeast(windows, windowsPath, "love.lib;", 2);
requireAtLeast(windows, windowsPath, "Source\\3rdParty\\theora\\Lib\\Windows", 2);
requireAtLeast(windows, windowsPath, "theoradec.lib;", 2);
requireCount(windows, windowsPath, "LoveObjectRuntimeSupport.cpp", 0);
requireCount(windows, windowsPath, "..\\..\\..\\Source\\3rdParty\\ogg\\OggSources.c", 1);
requireCount(windows, windowsPath, "..\\..\\..\\Source\\3rdParty\\theora\\TheoraSources.c", 0);
requireCount(windows, windowsPath, "h264bsd", 0);
for (const source of ["LoveRuntime.cpp", "LoveDataAlgorithms.cpp", "LoveLZ4.c", "LoveLZ4HC.c"]) {
	const start = windows.indexOf(`<ClCompile Include="..\\..\\..\\Source\\Love\\${source}">`);
	const end = windows.indexOf("</ClCompile>", start);
	if (start < 0 || end < 0)
		throw new Error(`${windowsPath} has no expanded item for ${source}`);
	const item = windows.slice(start, end);
	requireCount(item, windowsPath, ">NotUsing</PrecompiledHeader>", 2);
	if (source === "LoveRuntime.cpp")
		requireContains(item, windowsPath, "../../../Source/3rdParty/Lua");
}
for (const header of ["LoveRuntime.h", "LoveNode.h"])
	requireCount(windows, windowsPath, `..\\..\\..\\Source\\Love\\${header}`, 1);

const windowsFiltersPath = "Projects/Windows/Dora/Dora.vcxproj.filters";
const windowsFilters = read(windowsFiltersPath);
requireContains(windowsFilters, windowsFiltersPath, '<Filter Include="Love">');
for (const source of loveAdapterSources)
	requireCount(windowsFilters, windowsFiltersPath, `..\\..\\..\\Source\\Love\\${source}`, 1);
requireCount(windowsFilters, windowsFiltersPath, "LoveObjectRuntimeSupport.cpp", 0);
for (const header of ["LoveRuntime.h", "LoveNode.h"])
	requireCount(windowsFilters, windowsFiltersPath, `..\\..\\..\\Source\\Love\\${header}`, 1);

const doraCSWindowsPath = "Tools/dora-cs/Dora/Dora.vcxproj";
const doraCSWindows = read(doraCSWindowsPath);
requireCount(doraCSWindows, doraCSWindowsPath,
	"..\\..\\..\\Source\\3rdParty\\ogg\\OggSources.c", 1);
requireCount(doraCSWindows, doraCSWindowsPath,
	"..\\..\\..\\Source\\3rdParty\\theora\\TheoraSources.c", 0);
requireAtLeast(doraCSWindows, doraCSWindowsPath, "Source\\3rdParty\\theora\\Lib\\Windows", 2);
requireAtLeast(doraCSWindows, doraCSWindowsPath, "theoradec.lib;", 2);
requireCount(doraCSWindows, doraCSWindowsPath, "h264bsd", 0);

const doraCSWindowsFiltersPath = "Tools/dora-cs/Dora/Dora.vcxproj.filters";
const doraCSWindowsFilters = read(doraCSWindowsFiltersPath);
requireCount(doraCSWindowsFilters, doraCSWindowsFiltersPath,
	"..\\..\\..\\Source\\3rdParty\\ogg\\OggSources.c", 1);
requireCount(doraCSWindowsFilters, doraCSWindowsFiltersPath,
	"..\\..\\..\\Source\\3rdParty\\theora\\TheoraSources.c", 0);
requireCount(doraCSWindowsFilters, doraCSWindowsFiltersPath, "h264bsd", 0);

const androidPath = "Projects/Android/Dora/app/CMakeLists.txt";
const android = read(androidPath);
requireContains(android, androidPath, "src/main/cpp/3rdParty/Love/src");
for (const source of loveAdapterSources)
	requireCount(android, androidPath, `src/main/cpp/Love/${source}`, 1);
requireContains(android, androidPath, "add_library(LOVE-lib STATIC IMPORTED)");
requireContains(android, androidPath, "Artifacts/Android/${ANDROID_ABI}/liblove.a");
requireContains(android, androidPath, "add_library(THEORA-lib STATIC IMPORTED)");
requireContains(android, androidPath, "theora/Lib/Android/${ANDROID_ABI}/libtheoradec.a");
requireContains(android, androidPath, "LOVE-lib THEORA-lib BGFX-lib");
requireCount(android, androidPath, "LoveObjectRuntimeSupport.cpp", 0);
requireCount(android, androidPath, "src/main/cpp/3rdParty/ogg/OggSources.c", 1);
requireCount(android, androidPath, "src/main/cpp/3rdParty/theora/TheoraSources.c", 0);
requireCount(android, androidPath, "h264bsd", 0);

for (const [projectPath, theoraSearchPaths] of [
	["Projects/macOS/Dora.xcodeproj/project.pbxproj", ["Source/3rdParty/theora/Lib/macOS"]],
	["Projects/iOS/Dora.xcodeproj/project.pbxproj", [
		"Source/3rdParty/theora/Lib/iOS-Simulator",
		"Source/3rdParty/theora/Lib/iOS",
	]],
]) {
	const project = read(projectPath);
	requireContains(project, projectPath, "Source/3rdParty/Love/src");
	for (const source of loveAdapterSources)
		requireContains(project, projectPath, `${source} in Sources`);
	for (const source of ["LoveRuntime.cpp"]) {
		const buildLines = project.split("\n").filter(line =>
			line.includes(`${source} in Sources`) && line.includes("isa = PBXBuildFile"));
		if (buildLines.length === 0 || buildLines.some(line => !line.includes("-I../../Source/3rdParty/Lua")))
			throw new Error(`${projectPath} ${source} must add Lua as an angle-bracket include path`);
	}
	requireContains(project, projectPath, "OggSources.c in Sources");
	requireCount(project, projectPath, "TheoraSources.c in Sources", 0);
	requireContains(project, projectPath, "libtheoradec.a in Frameworks");
	for (const searchPath of theoraSearchPaths)
		requireContains(project, projectPath, searchPath);
	requireContains(project, projectPath, "liblove.a in Frameworks");
	requireContains(project, projectPath, "Source/3rdParty/Love/Artifacts/");
	requireCount(project, projectPath, "LoveObjectRuntimeSupport.cpp", 0);
	requireCount(project, projectPath, "h264bsd", 0);
}

const loveCMakePath = "Dora-Example/Test/Love/CMakeLists.txt";
const loveCMake = fs.readFileSync(path.join(testRoot, "CMakeLists.txt"), "utf8");
for (const source of ["Object.cpp", "types.cpp", "Reference.cpp", "Module.cpp", "Exception.cpp", "deprecation.cpp", "runtime.cpp"])
	requireCount(loveCMake, loveCMakePath, `src/common/${source}`, 1);
requireContains(loveCMake, loveCMakePath, "LOVE_PROXY_USERVALUES=5");
requireCount(loveCMake, loveCMakePath, "LoveObjectRuntimeSupport.cpp", 0);
requireCount(loveCMake, loveCMakePath, '"${DORA_SOURCE_ROOT}/3rdParty/ogg/OggSources.c"', 1);
requireCount(loveCMake, loveCMakePath, '"${DORA_THEORA_ROOT}/TheoraSources.c"', 1);
requireContains(loveCMake, loveCMakePath, '"${DORA_THEORA_ROOT}/Source"');
requireCount(loveCMake, loveCMakePath, "Source/Audio/OggSources.c", 0);

const loveApiParityPath = "Dora-Example/Test/Love/LoveApiParityTests.mjs";
const loveApiParity = fs.readFileSync(path.join(testRoot, "LoveApiParityTests.mjs"), "utf8");
requireContains(loveApiParity, loveApiParityPath, '.replace(/\\r\\n?/g, "\\n")');

const bimgImagePath = "Source/3rdParty/bimg/src/image.cpp";
const bimgImage = read(bimgImagePath);
for (const [name, value, format] of [
	["PVR3_ETC2_RGB", "22", "ETC2"],
	["PVR3_ETC2_RGBA", "23", "ETC2A"],
	["PVR3_ETC2_RGBA1", "24", "ETC2A1"],
]) {
	requireContains(bimgImage, bimgImagePath, `#define ${name}`);
	requireContains(bimgImage, bimgImagePath,
		`{ ${name},`);
	requireContains(bimgImage, bimgImagePath, `TextureFormat::${format}`);
	const definition = bimgImage.match(new RegExp(`#define ${name}\\s+(\\d+)`));
	if (!definition || definition[1] !== value)
		throw new Error(`${bimgImagePath} maps ${name} to the wrong PVR3 standard id`);
}
for (const contract of [
	"const uint16_t logicalWidth = _width;",
	"const uint16_t logicalHeight = _height;",
	"_format == TextureFormat::PTC12",
	"_format == TextureFormat::PTC14",
	"_format == TextureFormat::PTC12A",
	"_format == TextureFormat::PTC14A",
	"output->m_size = parsedSize;",
	"output->m_width = imageContainer.m_width;",
	"output->m_height = imageContainer.m_height;",
	"output->m_depth = bx::max<uint32_t>(1, imageContainer.m_depth);",
	"output->m_numMips = imageContainer.m_numMips;",
]) requireContains(bimgImage, bimgImagePath, contract);

const loveNodePath = "Source/Love/LoveNode.cpp";
const loveNode = read(loveNodePath);
requireContains(loveNode, loveNodePath, "#if BX_PLATFORM_OSX");
requireContains(loveNode, loveNodePath, "format == bgfx::TextureFormat::PTC12");
requireContains(loveNode, loveNodePath, "format == bgfx::TextureFormat::PTC12A");
requireAtLeast(loveNode, loveNodePath, "isLoveCompressedTextureValid(", 4);

const playRhoFilterPath = "Source/3rdParty/playrho/Filter.hpp";
const playRhoFilter = read(playRhoFilterPath);
requireContains(playRhoFilter, playRhoFilterPath, "using index_type = std::int16_t;");
requireCount(playRhoFilter, playRhoFilterPath,
	"filterA.groupIndex == filterB.groupIndex", 0);
const lovePhysicsFilterPath = "Source/Love/LovePhysicsFilter.h";
const lovePhysicsFilter = read(lovePhysicsFilterPath);
requireContains(lovePhysicsFilter, lovePhysicsFilterPath,
	"a.groupIndex != 0 && a.groupIndex == b.groupIndex");
requireContains(lovePhysicsFilter, lovePhysicsFilterPath,
	"return a.groupIndex > 0;");
for (const contract of [
	"LoveGroupCandidateBit = 1u << 16",
	"Love::shouldPhysicsFiltersCollide(fixtureA->filter, fixtureB->filter)",
	"pd::UnsetEnabled(*nativeWorld, contact)",
]) requireContains(loveNode, loveNodePath, contract);

const oggXmakePath = "Source/3rdParty/ogg/xmake.lua";
const oggXmake = read(oggXmakePath);
requireContains(oggXmake, oggXmakePath, 'target("ogg")');
requireContains(oggXmake, oggXmakePath, 'add_files("OggSources.c")');
requireContains(oggXmake, oggXmakePath, 'add_includedirs(".", {public = true})');

const loveXmakePath = "Source/3rdParty/Love/xmake.lua";
const loveXmake = read(loveXmakePath);
requireContains(loveXmake, loveXmakePath, 'target("love")');
requireContains(loveXmake, loveXmakePath, 'set_kind("static")');
requireContains(loveXmake, loveXmakePath, 'add_defines("_ITERATOR_DEBUG_LEVEL=0")');
requireContains(windows, windowsPath, "_ITERATOR_DEBUG_LEVEL=0");
requireContains(doraCSWindows, doraCSWindowsPath, "_ITERATOR_DEBUG_LEVEL=0");
requireContains(loveXmake, loveXmakePath, 'add_defines("LOVE_PROXY_USERVALUES=5")');
for (const source of ["Object.cpp", "types.cpp", "Reference.cpp", "Module.cpp", "Exception.cpp", "deprecation.cpp", "runtime.cpp"])
	requireCount(loveXmake, loveXmakePath, `"src/common/${source}"`, 1);
for (const rejected of ["Box2D", "modules/physics", "platform/", "src/love.cpp"])
	requireCount(loveXmake, loveXmakePath, rejected, rejected === "Box2D" ? 1 : 0);

const theoraXmakePath = "Source/3rdParty/theora/xmake.lua";
const theoraXmake = read(theoraXmakePath);
requireContains(theoraXmake, theoraXmakePath, 'target("theoradec")');
requireContains(theoraXmake, theoraXmakePath, 'set_kind("static")');
requireContains(theoraXmake, theoraXmakePath, 'add_files("TheoraSources.c")');
requireContains(theoraXmake, theoraXmakePath, '"Source"');
requireCount(theoraXmake, theoraXmakePath, '"lib"', 0);

for (const buildScriptPath of [
	"Tools/build-scripts/build_lib_macos.sh",
	"Tools/build-scripts/build_lib_ios.sh",
	"Tools/build-scripts/build_lib_android.sh",
	"Tools/build-scripts/build_lib_linux.sh",
]) requireContains(read(buildScriptPath), buildScriptPath, "build_lib_love.sh");
for (const buildScriptPath of [
	"Tools/build-scripts/build_lib_macos.sh",
	"Tools/build-scripts/build_lib_ios.sh",
	"Tools/build-scripts/build_lib_android.sh",
	"Tools/build-scripts/build_lib_linux.sh",
]) requireContains(read(buildScriptPath), buildScriptPath, "build_lib_theora.sh");
requireContains(read("Tools/build-scripts/build_lib_windows.bat"),
	"Tools/build-scripts/build_lib_windows.bat", "build_lib_love_windows.bat");
requireContains(read("Tools/build-scripts/build_lib_windows.bat"),
	"Tools/build-scripts/build_lib_windows.bat", "build_lib_theora_windows.bat");

const theoraBuildScriptPath = "Tools/build-scripts/build_lib_theora.sh";
const theoraBuildScript = read(theoraBuildScriptPath);
requireContains(theoraBuildScript, theoraBuildScriptPath,
	"libogg is already built by Source/3rdParty/ogg/OggSources.c");
requireContains(theoraBuildScript, theoraBuildScriptPath, "$THEORA_DIR/Lib");
requireCount(theoraBuildScript, theoraBuildScriptPath, "$THEORA_DIR/Artifacts", 0);

const theoraWindowsBuildScriptPath = "Tools/build-scripts/build_lib_theora_windows.bat";
const theoraWindowsBuildScript = read(theoraWindowsBuildScriptPath);
requireContains(theoraWindowsBuildScript, theoraWindowsBuildScriptPath, "Lib\\Windows");
requireCount(theoraWindowsBuildScript, theoraWindowsBuildScriptPath, "Artifacts\\Windows", 0);

const windowsCrossToolchainPath = "Dora-Example/Test/Love/Toolchains/ZigWindowsX86.cmake";
const windowsCrossToolchain = fs.readFileSync(path.join(testRoot, "Toolchains/ZigWindowsX86.cmake"), "utf8");
requireContains(windowsCrossToolchain, windowsCrossToolchainPath, "set(CMAKE_SYSTEM_NAME Windows)");
requireContains(windowsCrossToolchain, windowsCrossToolchainPath,
	'set(DORA_LOVE_ZIG_WINDOWS_TARGET "x86-windows-gnu")');
requireContains(windowsCrossToolchain, windowsCrossToolchainPath, "zig-ar.sh");
requireContains(windowsCrossToolchain, windowsCrossToolchainPath, "zig-ranlib.sh");

const windowsCrossBuildScriptPath = "Dora-Example/Test/Love/build-windows-cross.sh";
const windowsCrossBuildScript = fs.readFileSync(path.join(testRoot, "build-windows-cross.sh"), "utf8");
requireContains(windowsCrossBuildScript, windowsCrossBuildScriptPath,
	"Toolchains/ZigWindowsX86.cmake");
for (const executable of [
	"dora_love_runtime_tests.exe",
	"dora_playrho_ghost_topology_tests.exe",
	"dora_soloud_filter_response_tests.exe",
	"dora_soloud_voice_budget_tests.exe",
]) requireContains(windowsCrossBuildScript, windowsCrossBuildScriptPath, executable);

const windowsWorkflowPath = ".github/workflows/windows.yml";
const windowsWorkflow = read(windowsWorkflowPath);
for (const removedLoveTestContract of [
	"repository: ippclub/Dora-Example",
	"pnpm --dir Tools/dora-dora install --frozen-lockfile",
	"cmake -S Dora-Example\\Test\\Love",
	"ctest --test-dir Dora-Example\\Test\\Love",
]) requireCount(windowsWorkflow, windowsWorkflowPath, removedLoveTestContract, 0);

const exampleAttributesPath = "Dora-Example/.gitattributes";
const exampleAttributes = fs.readFileSync(path.join(testRoot, "../../.gitattributes"), "utf8");
requireContains(exampleAttributes, exampleAttributesPath, "*.mock binary");

const shadercHeaderPath = "Source/3rdParty/bgfx/dora/DoraShaderc.h";
const shadercHeader = read(shadercHeaderPath);
requireContains(shadercHeader, shadercHeaderPath, "#define DORA_SHADERC_VERSION_MAJOR 1");
requireContains(shadercHeader, shadercHeaderPath, "#define DORA_SHADERC_VERSION_MINOR 1");
requireContains(shadercHeader, shadercHeaderPath, "#define DORA_SHADERC_VERSION_PATCH 0");

const shaderCompilerPath = "Source/Shader/ShaderCompiler.cpp";
const shaderCompiler = read(shaderCompilerPath);
requireContains(shaderCompiler, shaderCompilerPath, "DoraShadercGetVersion(&shadercMajor, &shadercMinor, &shadercPatch)");
requireContains(shaderCompiler, shaderCompilerPath, "DoraShaderc ABI mismatch:");
requireContains(shaderCompiler, shaderCompilerPath, "rebuild the platform bgfx/shaderc libraries");

requireContains(loveNode, loveNodePath,
	'customMain += "vec4 " + output + " = vec4_splat(0.0); ";');
requireCount(loveNode, loveNodePath,
	'customMain += "vec4 " + output + " = vec4(0.0); ";', 0);
for (const contract of [
	"rewriteLoveSingleArgumentConstructors(body, singleArgumentConstructors)",
	"rewriteLoveSingleArgumentConstructors(declarations, singleArgumentConstructors)",
	"rewriteLoveSingleArgumentConstructors(customVaryingLocals, singleArgumentConstructors)",
	"rewriteLoveSingleArgumentConstructors(customVaryingStores, singleArgumentConstructors)",
	"loveSingleArgumentConstructorHelpers(singleArgumentConstructors)",
	"renderer == bgfx::RendererType::Direct3D11",
	"renderer == bgfx::RendererType::Direct3D12",
	'? "transpose(" + storage + ")" : storage;',
	'"#define VertexColor loveVertexColor\\n#define ConstantColor vec4_splat(1.0)\\n"',
]) requireContains(loveNode, loveNodePath, contract);

const d3d11RendererPath = "Source/3rdParty/bgfx/src/renderer_d3d11.cpp";
const d3d11Renderer = read(d3d11RendererPath);
for (const contract of [
	"if (NULL != texture.m_srv)",
	"texture.m_srv->GetDesc(&srvDesc);",
	"CreateShaderResourceView(texture.m_ptr, &srvDesc, &m_srv[m_num])",
]) requireContains(d3d11Renderer, d3d11RendererPath, contract);

// Appending texture formats changes bgfx::Caps and therefore requires every
// prebuilt bgfx archive and language binding to agree on the exact enum ABI.
const bgfxHeaderPath = "Source/3rdParty/bgfx/include/bgfx/bgfx.h";
const bgfxHeader = read(bgfxHeaderPath);
for (const contract of [
	"EACR,         //!< EAC R11",
	"EACRS,        //!< EAC signed R11",
	"EACRG,        //!< EAC RG11",
	"EACRGS,       //!< EAC signed RG11",
	"uint16_t formats[TextureFormat::Count];",
]) requireContains(bgfxHeader, bgfxHeaderPath, contract);

const bgfxImplementationPath = "Source/3rdParty/bgfx/src/bgfx.cpp";
const bgfxImplementation = read(bgfxImplementationPath);
for (const contract of [
	"static_assert(uint32_t(bgfx::TextureFormat::Unknown) == 34);",
	"static_assert(uint32_t(bgfx::TextureFormat::RGBA8) == 67);",
	"static_assert(uint32_t(bgfx::TextureFormat::D0S8) == 95);",
	"static_assert(uint32_t(bgfx::TextureFormat::EACR) == 96);",
	"static_assert(uint32_t(bgfx::TextureFormat::Count) == 100);",
]) requireContains(bgfxImplementation, bgfxImplementationPath, contract);

const rustBgfxFfiPath = "Source/Rust/src/bgfx_rs/bgfx_sys/ffi.rs";
const rustBgfxFfi = read(rustBgfxFfiPath);
for (const [name, value] of [
	["EACR", 96], ["EACRS", 97], ["EACRG", 98], ["EACRGS", 99], ["COUNT", 100],
]) requireContains(rustBgfxFfi, rustBgfxFfiPath,
	`pub const BGFX_TEXTURE_FORMAT_${name}: bgfx_texture_format = ${value};`);

const rustBgfxSafePath = "Source/Rust/src/bgfx_rs/static_lib.rs";
const rustBgfxSafe = read(rustBgfxSafePath);
const textureFormatStart = rustBgfxSafe.indexOf("pub enum TextureFormat {");
const textureFormatEnd = rustBgfxSafe.indexOf("\n}", textureFormatStart);
if (textureFormatStart < 0 || textureFormatEnd < 0)
	throw new Error(`${rustBgfxSafePath} has no TextureFormat enum`);
const rustTextureFormat = rustBgfxSafe.slice(textureFormatStart, textureFormatEnd);
const rustTextureFormatOrder = ["D0S8", "EACR", "EACRS", "EACRG", "EACRGS", "Count"];
for (const name of rustTextureFormatOrder)
	requireContains(rustTextureFormat, rustBgfxSafePath, `\t${name},`);
for (let index = 1; index < rustTextureFormatOrder.length; index++) {
	if (rustTextureFormat.indexOf(`\t${rustTextureFormatOrder[index - 1]},`) >=
		rustTextureFormat.indexOf(`\t${rustTextureFormatOrder[index]},`))
		throw new Error(`${rustBgfxSafePath} TextureFormat ABI order is incorrect`);
}

for (const buildScriptPath of [
	"Tools/build-scripts/build_lib_macos.sh",
	"Tools/build-scripts/build_lib_ios.sh",
	"Tools/build-scripts/build_lib_android.sh",
	"Tools/build-scripts/build_lib_linux.sh",
]) {
	const buildScript = read(buildScriptPath);
	requireContains(buildScript, buildScriptPath, "build_lib_bgfx.sh");
}
const windowsBuildScriptPath = "Tools/build-scripts/build_lib_windows.bat";
const windowsBuildScript = read(windowsBuildScriptPath);
requireContains(windowsBuildScript, windowsBuildScriptPath, "build_lib_bgfx_windows.bat");

const windowsDirect3DWorkflowPath = "Dora-Example/Test/Love/WindowsDirect3DWorkflowTests.ps1";
const windowsDirect3DWorkflow = readTest("WindowsDirect3DWorkflowTests.ps1");
for (const contract of [
	"Fixtures/PhysicsScene/main.lua",
	"Fixtures/MobilePhysicsScene/host.lua",
	"LOVE_WINDOWS_DIRECT3D_PHYSICS_PASS",
	"joints=11 ccd=pass pixels=pass content=pass",
	"Fixtures/MobileRuntimeScene/first.lua",
	"Fixtures/MobileRuntimeScene/second.lua",
	"LOVE_WINDOWS_MULTI_RUNTIME_PASS",
	"Fixtures/SystemScene/host.lua",
	"LOVE_WINDOWS_SYSTEM_PASS",
	"clipboard=roundtrip power=pass url-policy=pass",
]) requireContains(windowsDirect3DWorkflow, windowsDirect3DWorkflowPath, contract);
requireAtLeast(windowsDirect3DWorkflow, windowsDirect3DWorkflowPath, "Stage-TextFile", 4);

const mobileRuntimeWorkflowPath = "Dora-Example/Test/Love/MobileRuntimeWorkflowTests.mjs";
const mobileRuntimeWorkflow = readTest("MobileRuntimeWorkflowTests.mjs");
requireContains(mobileRuntimeWorkflow, mobileRuntimeWorkflowPath,
	'["iOS", "Android", "Linux", "Windows"]');

const desktopSystemScenePath = "Dora-Example/Test/Love/Fixtures/SystemScene/main.lua";
const desktopSystemScene = readTest("Fixtures/SystemScene/main.lua");
requireContains(desktopSystemScene, desktopSystemScenePath,
	'system.getOS() == "OS X" or system.getOS() == "Windows"');

const applicationPath = "Source/Basic/Application.cpp";
const application = read(applicationPath);
const linuxRendererBoundary = application.match(
	/#if BX_PLATFORM_LINUX[\s\S]*?if \(data\.context\)[\s\S]*?init\.type = bgfx::RendererType::OpenGLES;[\s\S]*?#endif \/\/ BX_PLATFORM_LINUX/);
if (!linuxRendererBoundary)
	throw new Error(`${applicationPath} changed the documented Linux renderer selection boundary`);

console.log("LOVE_PLATFORM_BUILD_MANIFEST_AUDIT_PASS love=xmake-7-source-static+5-platform-artifacts adapters=6-per-platform windows=msvc-build+standalone-tests+zig-x86+direct3d-full dora-cs=ogg+linked-theora ogg=shared+xmake theora=portable+xmake+linked bimg=pvr3-etc2+pvrtc-logical-mips shaderc-abi=1.1.0 texture-format-abi=100+rust+platform-rebuild");
