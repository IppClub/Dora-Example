local flatCanvas
local smoothCanvas
local blockCanvas
local matrixCanvas
local arrayCanvas
local nestedCanvas
local multiCanvas
local integerCanvas
local inlineCanvas
local mesh
local flatShader
local smoothShader
local blockShader
local matrixShader
local arrayShader
local nestedShader
local multiShader
local integerShader
local inlineShader
local frame = 0

local function shaderSources(qualifier)
	local vertex = ([[
#pragma language glsl3
		%s out vec4 Shade;
		vec4 position(mat4 transform, vec4 vertex) {
			Shade = VertexColor;
			return transform * vertex;
		}
	]]):format(qualifier)
	local pixel = ([[
#pragma language glsl3
		%s in vec4 Shade;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Shade;
		}
	]]):format(qualifier)
	return vertex, pixel
end

local function validateQualifier(qualifier)
	local vertex, pixel = shaderSources(qualifier)
	local valid, message = love.graphics.validateShader(false, vertex, pixel)
	assert(valid and message == nil,
		qualifier .. " interpolation Shader should compile: " .. tostring(message))
end

function love.load()
	flatCanvas = love.graphics.newCanvas(64, 64)
	smoothCanvas = love.graphics.newCanvas(64, 64)
	mesh = love.graphics.newMesh({
		{4, 4, 0, 0, 1, 0, 0, 1},
		{60, 4, 0, 0, 0, 1, 0, 1},
		{4, 60, 0, 0, 0, 0, 1, 1},
	}, "triangles")

	local flatVertex, flatPixel = shaderSources("flat")
	flatShader = love.graphics.newShader(flatVertex, flatPixel)
	local smoothVertex, smoothPixel = shaderSources("smooth")
	smoothShader = love.graphics.newShader(smoothVertex, smoothPixel)
	blockShader = love.graphics.newShader([[
#pragma language glsl3
		out ShadeBlock {
			flat vec4 FlatShade;
			/* An interpolation qualifier and centroid auxiliary qualifier can combine. */
			noperspective centroid vec2 Gradient;
		} vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.FlatShade = VertexColor;
			vertexOutput.Gradient = VertexTexCoord.xy;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in ShadeBlock {
			flat vec4 FlatShade;
			noperspective centroid vec2 Gradient;
		} pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return pixelInput.FlatShade * vec4(1.0, 1.0 - pixelInput.Gradient.x * 0.25, 1.0, 1.0);
		}
	]])
	blockCanvas = love.graphics.newCanvas(64, 64)
	matrixShader = love.graphics.newShader([[
#pragma language glsl3
		out MatrixBlock {
			mat2 Basis;
			mat3 Tone;
			mat4 Transform;
		} vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Basis = mat2(vec2(0.75, 0.125), vec2(0.25, 0.875));
			vertexOutput.Tone = mat3(vec3(0.1, 0.2, 0.3), vec3(0.4, 0.5, 0.6), vec3(0.7, 0.8, 0.9));
			vertexOutput.Transform = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 0.75, 0.0, 0.0), vec4(0.0, 0.0, 0.25, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in MatrixBlock {
			mat2 Basis;
			mat3 Tone;
			mat4 Transform;
		} pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Basis[0][0], pixelInput.Tone[1][1], pixelInput.Transform[2][2], 1.0);
		}
	]])
	matrixCanvas = love.graphics.newCanvas(64, 64)
	arrayShader = love.graphics.newShader([[
#pragma language glsl3
		out ArrayBlock {
			vec2 Shades[2];
			mat2 Basis;
		} vertexOutput[2];
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput[0].Shades[0] = vec2(0.2, 0.4);
			vertexOutput[0].Shades[1] = vec2(0.1, 0.3);
			vertexOutput[0].Basis = mat2(vec2(0.15, 0.0), vec2(0.0, 0.2));
			vertexOutput[1].Shades[0] = vec2(0.7, 0.5);
			vertexOutput[1].Shades[1] = vec2(0.6, 0.4);
			vertexOutput[1].Basis = mat2(vec2(0.8, 0.0), vec2(0.0, 0.9));
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in ArrayBlock {
			vec2 Shades[2];
			mat2 Basis;
		} pixelInput[2];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			int blockIndex = int(screen.x >= 32.0);
			int memberIndex = 1 - blockIndex;
			return vec4(pixelInput[blockIndex].Shades[memberIndex],
				pixelInput[blockIndex].Basis[0][0], 1.0);
		}
	]])
	arrayCanvas = love.graphics.newCanvas(64, 64)
	nestedShader = love.graphics.newShader([[
#pragma language glsl3
		struct NestedLeaf {
			vec2 Shades[2];
		};
		struct NestedPayload {
			NestedLeaf Lighting[2];
			float Alpha;
		};
		out NestedBlock {
			NestedPayload Data;
		} vertexOutput[2];
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput[0].Data.Lighting[0].Shades[0] = vec2(0.1, 0.2);
			vertexOutput[0].Data.Lighting[0].Shades[1] = vec2(0.3, 0.4);
			vertexOutput[0].Data.Lighting[1].Shades[0] = vec2(0.2, 0.3);
			vertexOutput[0].Data.Lighting[1].Shades[1] = vec2(0.4, 0.5);
			vertexOutput[0].Data.Alpha = 0.5;
			vertexOutput[1].Data.Lighting[0].Shades[0] = vec2(0.6, 0.7);
			vertexOutput[1].Data.Lighting[0].Shades[1] = vec2(0.8, 0.9);
			vertexOutput[1].Data.Lighting[1].Shades[0] = vec2(0.7, 0.8);
			vertexOutput[1].Data.Lighting[1].Shades[1] = vec2(0.9, 1.0);
			vertexOutput[1].Data.Alpha = 1.0;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		struct NestedLeaf {
			vec2 Shades[2];
		};
		struct NestedPayload {
			NestedLeaf Lighting[2];
			float Alpha;
		};
		in NestedBlock {
			NestedPayload Data;
		} pixelInput[2];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			int blockIndex = int(screen.x >= 32.0);
			int lightIndex = int(screen.y >= 16.0);
			int shadeIndex = 1 - blockIndex;
			return vec4(pixelInput[blockIndex].Data.Lighting[lightIndex].Shades[shadeIndex],
				pixelInput[blockIndex].Data.Alpha, 1.0);
		}
	]])
	nestedCanvas = love.graphics.newCanvas(64, 64)
	multiShader = love.graphics.newShader([[
#pragma language glsl3
		out vec2 DirectFirst, DirectSecond[2];
		struct MultiPayload {
			vec2 First, Second[2];
		};
		out MultiBlock {
			MultiPayload Data;
			float Alpha, Beta;
		} vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			DirectFirst = vec2(0.05, 0.1);
			DirectSecond[0] = vec2(0.15, 0.2);
			DirectSecond[1] = vec2(0.25, 0.3);
			vertexOutput.Data.First = vec2(0.1, 0.2);
			vertexOutput.Data.Second[0] = vec2(0.3, 0.4);
			vertexOutput.Data.Second[1] = vec2(0.5, 0.6);
			vertexOutput.Alpha = 0.2;
			vertexOutput.Beta = 0.5;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in vec2 DirectFirst, DirectSecond[2];
		struct MultiPayload {
			vec2 First, Second[2];
		};
		in MultiBlock {
			MultiPayload Data;
			float Alpha, Beta;
		} pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Data.First.x + pixelInput.Data.Second[0].x + DirectFirst.x,
				pixelInput.Data.Second[1].y + DirectSecond[0].x,
				pixelInput.Alpha + pixelInput.Beta + DirectSecond[1].x, 1.0);
		}
	]])
	multiCanvas = love.graphics.newCanvas(64, 64)
	integerShader = love.graphics.newShader([[
#pragma language glsl3
		flat out ivec4 DirectInteger;
		flat out ivec2 DirectArray[2];
		struct IntegerPayload {
			uvec4 UnsignedValues;
			bvec4 Flags;
		};
		flat out IntegerBlock {
			IntegerPayload Data;
			int Scalar;
			uint Unsigned;
			bool Flag;
		} vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			DirectInteger = ivec4(-7, 123456789, -2147483647, 2147483646);
			DirectArray[0] = ivec2(42, -900000001);
			DirectArray[1] = ivec2(-2147483647, 2147483646);
			vertexOutput.Data.UnsignedValues = uvec4(
				0xf1234567u, 4000000000u, 0xffffffffu, 0x80000001u);
			vertexOutput.Data.Flags = bvec4(true, false, true, false);
			vertexOutput.Scalar = -123456789;
			vertexOutput.Unsigned = 0xf7654321u;
			vertexOutput.Flag = true;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		flat in ivec4 DirectInteger;
		flat in ivec2 DirectArray[2];
		struct IntegerPayload {
			uvec4 UnsignedValues;
			bvec4 Flags;
		};
		flat in IntegerBlock {
			IntegerPayload Data;
			int Scalar;
			uint Unsigned;
			bool Flag;
		} pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			int index = int(screen.x >= 32.0);
			bool directValid = all(equal(DirectInteger,
				ivec4(-7, 123456789, -2147483647, 2147483646)));
			bool arrayValid = index == 0
				? all(equal(DirectArray[index], ivec2(42, -900000001)))
				: all(equal(DirectArray[index], ivec2(-2147483647, 2147483646)));
			bool blockValid = all(equal(pixelInput.Data.UnsignedValues,
				uvec4(0xf1234567u, 4000000000u, 0xffffffffu, 0x80000001u)))
				&& all(equal(pixelInput.Data.Flags, bvec4(true, false, true, false)))
				&& pixelInput.Scalar == -123456789
				&& pixelInput.Unsigned == 0xf7654321u
				&& pixelInput.Flag;
			vec3 expected = index == 0 ? vec3(0.2, 0.8, 0.4) : vec3(0.7, 0.3, 0.9);
			return vec4(directValid ? expected.r : 1.0,
				arrayValid ? expected.g : 0.0,
				blockValid ? expected.b : 0.0, 1.0);
		}
	]])
	integerCanvas = love.graphics.newCanvas(64, 64)
	inlineShader = love.graphics.newShader([[
#pragma language glsl3
		out InlineBlock {
			struct {
				vec2 Offset;
				struct {
					vec3 Shade;
					float Alpha;
				} Layers[2];
			} Payload[2];
		} vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Payload[0].Offset = vec2(0.05, 0.1);
			vertexOutput.Payload[0].Layers[0].Shade = vec3(0.1, 0.2, 0.3);
			vertexOutput.Payload[0].Layers[0].Alpha = 0.4;
			vertexOutput.Payload[0].Layers[1].Shade = vec3(0.2, 0.3, 0.1);
			vertexOutput.Payload[0].Layers[1].Alpha = 0.2;
			vertexOutput.Payload[1].Offset = vec2(0.1, 0.2);
			vertexOutput.Payload[1].Layers[0].Shade = vec3(0.4, 0.1, 0.2);
			vertexOutput.Payload[1].Layers[0].Alpha = 0.3;
			vertexOutput.Payload[1].Layers[1].Shade = vec3(0.2, 0.4, 0.3);
			vertexOutput.Payload[1].Layers[1].Alpha = 0.1;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in InlineBlock {
			struct {
				vec2 Offset;
				struct {
					vec3 Shade;
					float Alpha;
				} Layers[2];
			} Payload[2];
		} pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			int outer = int(screen.x >= 32.0);
			int layer = int((screen.x >= 16.0 && screen.x < 32.0) || screen.x >= 48.0);
			vec3 shade = pixelInput.Payload[outer].Layers[layer].Shade;
			float alpha = pixelInput.Payload[outer].Layers[layer].Alpha;
			vec2 offset = pixelInput.Payload[outer].Offset;
			return vec4(shade + vec3(offset, alpha), 1.0);
		}
	]])
	inlineCanvas = love.graphics.newCanvas(64, 64)
	local valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out vec2 DirectValues[1];
		vec4 position(mat4 transform, vec4 vertex) {
			DirectValues[0] = VertexTexCoord.xy;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in vec2 DirectValues[1];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(DirectValues[0], 0.0, 1.0);
		}
	]])
	assert(valid and message == nil,
		"one-element direct varying arrays should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
		varying vec2 LegacyFirst, LegacySecond;
		vec4 position(mat4 transform, vec4 vertex) {
			LegacyFirst = VertexTexCoord.xy;
			LegacySecond = VertexColor.xy;
			return transform * vertex;
		}
	]], [[
		varying vec2 LegacyFirst, LegacySecond;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(LegacyFirst + LegacySecond, 0.0, 1.0);
		}
	]])
	assert(valid and message == nil,
		"GLSL1 direct varying multi-declarators should compile: " .. tostring(message))
	validateQualifier("noperspective")
	validateQualifier("centroid")
	validateQualifier("smooth centroid")
	validateQualifier("noperspective centroid")

	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out AnonymousBlock { vec4 Shade; };
		vec4 position(mat4 transform, vec4 vertex) { Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in AnonymousBlock { vec4 Shade; };
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Shade; }
	]])
	assert(valid and message == nil, "anonymous interface block should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct AnonymousPayload { vec4 Shade; };
		out AnonymousNestedBlock { AnonymousPayload Data; };
		vec4 position(mat4 transform, vec4 vertex) {
			Data.Shade = VertexColor;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		struct AnonymousPayload { vec4 Shade; };
		in AnonymousNestedBlock { AnonymousPayload Data; };
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Data.Shade; }
	]])
	assert(valid and message == nil,
		"anonymous nested interface block should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		flat out BlockQualified { vec4 Shade; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		flat in BlockQualified { vec4 Shade; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return pixelInput.Shade; }
	]])
	assert(valid and message == nil, "block interpolation qualifier should compile: " .. tostring(message))

	valid, message = love.graphics.validateShader(false, flatVertex, smoothPixel)
	assert(not valid and message:find("mismatched vertex/pixel interpolation qualifiers", 1, true),
		"mismatched interpolation qualifiers need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		smooth noperspective out vec4 Shade;
		vec4 position(mat4 transform, vec4 vertex) { Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		smooth noperspective in vec4 Shade;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Shade; }
	]])
	assert(not valid and message:find("conflicting interpolation qualifiers", 1, true),
		"conflicting interpolation qualifiers need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		centroid smooth out vec4 Shade;
		vec4 position(mat4 transform, vec4 vertex) { Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		centroid smooth in vec4 Shade;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Shade; }
	]])
	assert(not valid and message:find("must precede centroid", 1, true),
		"misordered interpolation and centroid qualifiers need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		flat centroid out vec4 Shade;
		vec4 position(mat4 transform, vec4 vertex) { Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		flat centroid in vec4 Shade;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return Shade; }
	]])
	assert(not valid and message:find("flat interpolation cannot be combined with centroid", 1, true),
		"meaningless flat centroid combination needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		in WrongDirection { vec4 Shade; } value;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("vertex out / pixel in", 1, true),
		"unsupported interface block direction needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out BrokenBlock { sampler2D Unsupported; } value;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("unsupported member declaration", 1, true),
		"unsupported interface member needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		flat out DoublyQualified { smooth vec4 Shade; } value;
		vec4 position(mat4 transform, vec4 vertex) { value.Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("both the block and a member", 1, true),
		"block/member double interpolation needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out TypeBlock { vec4 Shade; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in TypeBlock { vec3 Shade; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return vec4(pixelInput.Shade, 1.0); }
	]])
	assert(not valid and message:find("mismatched vertex/pixel types", 1, true),
		"interface member type mismatch needs the existing varying diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out MatrixTypeBlock { mat3 Value; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Value = mat3(1.0); return transform * vertex; }
	]], [[
#pragma language glsl3
		in MatrixTypeBlock { mat4 Value; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return pixelInput.Value[0]; }
	]])
	assert(not valid and message:find("mismatched vertex/pixel types", 1, true),
		"matrix interface member type mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out TooWideBlock { mat4 First; mat4 Second; mat3 Third; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.First = mat4(1.0); vertexOutput.Second = mat4(1.0); vertexOutput.Third = mat3(1.0);
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in TooWideBlock { mat4 First; mat4 Second; mat3 Third; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return pixelInput.First[0] + pixelInput.Second[0] + vec4(pixelInput.Third[0], 1.0);
		}
	]])
	assert(not valid and message:find("more custom varying semantic slots", 1, true),
		"matrix varying capacity needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		layout(location = 0) out LayoutBlock { vec4 Shade; } value;
		vec4 position(mat4 transform, vec4 vertex) { value.Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("only layout(location=N)", 1, true),
		"layout qualifier needs a directed subset diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out OneBlock { vec4 Shade; } values[1];
		vec4 position(mat4 transform, vec4 vertex) {
			values[0].Shade = VertexColor;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in OneBlock { vec4 Shade; } values[1];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return values[0].Shade; }
	]])
	assert(valid and message == nil,
		"one-element interface block arrays should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out InstanceSizeBlock { vec4 Shade; } values[2];
		vec4 position(mat4 transform, vec4 vertex) { values[0].Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in InstanceSizeBlock { vec4 Shade; } values[3];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return values[0].Shade; }
	]])
	assert(not valid and message:find("mismatched vertex/pixel instance array sizes", 1, true),
		"interface block instance array size mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out InstanceShapeBlock { vec4 Shade; } value;
		vec4 position(mat4 transform, vec4 vertex) { value.Shade = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in InstanceShapeBlock { vec4 Shade; } values[1];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return values[0].Shade; }
	]])
	assert(not valid and message:find("mismatched vertex/pixel instance array sizes", 1, true),
		"interface block scalar/array shape mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out ArraySizeBlock { vec4 Shade[2]; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Shade[0] = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in ArraySizeBlock { vec4 Shade[3]; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return pixelInput.Shade[0]; }
	]])
	assert(not valid and message:find("mismatched vertex/pixel array sizes", 1, true),
		"interface member array size mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out TooManyArrayVaryings { vec4 Shade[11]; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Shade[0] = VertexColor; return transform * vertex; }
	]], [[
#pragma language glsl3
		in TooManyArrayVaryings { vec4 Shade[11]; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return pixelInput.Shade[0]; }
	]])
	assert(not valid and message:find("more custom varying semantic slots", 1, true),
		"interface member arrays must count every element against varying capacity")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out TooManyBlockInstances { mat4 Transform; vec2 Extra; } values[3];
		vec4 position(mat4 transform, vec4 vertex) {
			values[0].Transform = mat4(1.0); values[0].Extra = vec2(1.0); return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in TooManyBlockInstances { mat4 Transform; vec2 Extra; } values[3];
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return values[0].Transform[0] + vec4(values[0].Extra, 0.0, 0.0);
		}
	]])
	assert(not valid and message:find("more custom varying semantic slots", 1, true),
		"interface block instances must count every member and matrix column")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct NestedShape { vec2 Shades[2]; };
		out NestedShapeBlock { NestedShape Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Data.Shades[0] = vec2(0.0); return transform * vertex;
		}
	]], [[
#pragma language glsl3
		struct NestedShape { vec2 Shades[1]; };
		in NestedShapeBlock { NestedShape Data; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Data.Shades[0], 0.0, 1.0);
		}
	]])
	assert(not valid and message:find("mismatched vertex/pixel array shapes", 1, true),
		"nested struct array shape mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct VertexPayload { vec2 Shade; };
		out NestedTypeBlock { VertexPayload Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Data.Shade = vec2(0.0); return transform * vertex;
		}
	]], [[
#pragma language glsl3
		struct PixelPayload { vec2 Shade; };
		in NestedTypeBlock { PixelPayload Data; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Data.Shade, 0.0, 1.0);
		}
	]])
	assert(not valid and message:find("mismatched vertex/pixel struct types", 1, true),
		"nested struct type mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct UnsupportedPayload { sampler2D Shade; };
		out NestedUnsupportedBlock { UnsupportedPayload Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("unsupported type 'sampler2D'", 1, true),
		"unsupported nested struct leaf needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct RecursivePayload { RecursivePayload Self; };
		out RecursiveBlock { RecursivePayload Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("recursive struct type", 1, true),
		"recursive nested struct needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out DuplicateDeclaratorBlock { vec2 Shade, Shade; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("duplicate Love Shader interface block member", 1, true),
		"duplicate interface multi-declarator needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		struct DuplicateStruct { vec2 Shade, Shade; };
		out DuplicateStructBlock { DuplicateStruct Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("duplicate Love Shader struct member", 1, true),
		"duplicate struct multi-declarator needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out vec2 DirectShade, DirectShade;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("duplicate Love vertex Shader varying", 1, true),
		"duplicate direct multi-declarator needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out MultiShapeBlock { vec2 First, Second[2]; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.First = vec2(0.0); vertexOutput.Second[0] = vec2(0.0);
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in MultiShapeBlock { vec2 First, Second[3]; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.First + pixelInput.Second[0], 0.0, 1.0);
		}
	]])
	assert(not valid and message:find("mismatched vertex/pixel array sizes", 1, true),
		"multi-declarator array shape mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		flat out ivec3 SignedThree;
		flat out uvec3 UnsignedThree;
		flat out bvec3 BooleanThree;
		vec4 position(mat4 transform, vec4 vertex) {
			SignedThree = ivec3(-1, 0, 1);
			UnsignedThree = uvec3(0u, 1u, 0xffffffffu);
			BooleanThree = bvec3(true, false, true);
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		flat in ivec3 SignedThree;
		flat in uvec3 UnsignedThree;
		flat in bvec3 BooleanThree;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			bool validValues = all(equal(SignedThree, ivec3(-1, 0, 1)))
				&& all(equal(UnsignedThree, uvec3(0u, 1u, 0xffffffffu)))
				&& all(equal(BooleanThree, bvec3(true, false, true)));
			return validValues ? color : vec4(0.0);
		}
	]])
	assert(valid and message == nil,
		"three-component integer and boolean varyings should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out InlineGroupingBlock { struct { vec2 First, Second; } Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Data.First = vec2(0.1);
			vertexOutput.Data.Second = vec2(0.2);
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in InlineGroupingBlock { struct { vec2 First; vec2 Second; } Data; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Data.First + pixelInput.Data.Second, 0.0, 1.0);
		}
	]])
	assert(valid and message == nil,
		"equivalent inline struct declarator grouping should link: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out int IntegerValue;
		vec4 position(mat4 transform, vec4 vertex) { IntegerValue = 1; return transform * vertex; }
	]], [[
#pragma language glsl3
		in int IntegerValue;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return IntegerValue == 1 ? color : vec4(0.0);
		}
	]])
	assert(not valid and message:find("requires flat interpolation", 1, true),
		"integer varying without flat needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		flat out IntegerTypeBlock { int Value; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { vertexOutput.Value = 1; return transform * vertex; }
	]], [[
#pragma language glsl3
		flat in IntegerTypeBlock { uint Value; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return pixelInput.Value == 1u ? color : vec4(0.0);
		}
	]])
	assert(not valid and message:find("mismatched vertex/pixel types", 1, true),
		"integer varying signedness mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out InlineTypeBlock { struct { vec2 Shade; } Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) {
			vertexOutput.Data.Shade = vec2(0.0); return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in InlineTypeBlock { struct { vec3 Shade; } Data; } pixelInput;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(pixelInput.Data.Shade, 1.0);
		}
	]])
	assert(not valid and message:find("mismatched vertex/pixel types", 1, true),
		"inline anonymous struct leaf mismatch needs a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		out InlineDuplicateBlock { struct { vec2 Shade, Shade; } Data; } vertexOutput;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
#pragma language glsl3
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("duplicate Love Shader struct member", 1, true),
		"inline anonymous struct duplicate member needs a directed diagnostic")
end

function love.draw()
	love.graphics.setCanvas(flatCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(flatShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(smoothCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(smoothShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(blockCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(blockShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(matrixCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(matrixShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(arrayCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(arrayShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(nestedCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(nestedShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(multiCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(multiShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(integerCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(integerShader)
	love.graphics.draw(mesh)

	love.graphics.setCanvas(inlineCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(inlineShader)
	love.graphics.draw(mesh)
	love.graphics.setShader()
	love.graphics.setCanvas()
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local flat = flatCanvas:newImageData()
	local fr, fg, fb, fa = flat:getPixel(20, 20)
	local primary = (fr > 0.98 and fg < 0.02 and fb < 0.02)
		or (fg > 0.98 and fr < 0.02 and fb < 0.02)
		or (fb > 0.98 and fr < 0.02 and fg < 0.02)
	assert(primary and fa > 0.98,
		("flat interpolation blended: %.3f,%.3f,%.3f,%.3f"):format(fr, fg, fb, fa))

	local smooth = smoothCanvas:newImageData()
	local sr, sg, sb, sa = smooth:getPixel(20, 20)
	assert(sr > 0.1 and sg > 0.1 and sb > 0.1 and math.max(sr, sg, sb) < 0.8 and sa > 0.98,
		("smooth interpolation was not blended: %.3f,%.3f,%.3f,%.3f"):format(sr, sg, sb, sa))
	local block = blockCanvas:newImageData()
	local br, bg, bb, ba = block:getPixel(20, 20)
	local blockPrimary = (br > 0.98 and bg < 0.8 and bb < 0.02)
		or (bg > 0.7 and br < 0.02 and bb < 0.02)
		or (bb > 0.98 and br < 0.02 and bg < 0.8)
	assert(blockPrimary and ba > 0.98,
		("interface block interpolation failed: %.3f,%.3f,%.3f,%.3f"):format(br, bg, bb, ba))
	local matrix = matrixCanvas:newImageData()
	local mr, mg, mb, ma = matrix:getPixel(20, 20)
	assert(math.abs(mr - 0.75) < 0.03 and math.abs(mg - 0.5) < 0.03
		and math.abs(mb - 0.25) < 0.03 and ma > 0.98,
		("interface block matrices failed: %.3f,%.3f,%.3f,%.3f"):format(mr, mg, mb, ma))
	local array = arrayCanvas:newImageData()
	local ar0, ag0, ab0, aa0 = array:getPixel(20, 10)
	local ar1, ag1, ab1, aa1 = array:getPixel(40, 10)
	assert(math.abs(ar0 - 0.1) < 0.03 and math.abs(ag0 - 0.3) < 0.03
		and math.abs(ab0 - 0.15) < 0.03 and aa0 > 0.98,
		("interface block array element 0 failed: %.3f,%.3f,%.3f,%.3f")
			:format(ar0, ag0, ab0, aa0))
	assert(math.abs(ar1 - 0.7) < 0.03 and math.abs(ag1 - 0.5) < 0.03
		and math.abs(ab1 - 0.8) < 0.03 and aa1 > 0.98,
		("interface block dynamic array element 1 failed: %.3f,%.3f,%.3f,%.3f")
			:format(ar1, ag1, ab1, aa1))
	local nested = nestedCanvas:newImageData()
	local nr0, ng0, nb0, na0 = nested:getPixel(20, 10)
	local nr2, ng2, nb2, na2 = nested:getPixel(20, 20)
	local nr1, ng1, nb1, na1 = nested:getPixel(40, 10)
	local nr3, ng3, nb3, na3 = nested:getPixel(40, 20)
	assert(math.abs(nr0 - 0.3) < 0.03 and math.abs(ng0 - 0.4) < 0.03
		and math.abs(nb0 - 0.5) < 0.03 and na0 > 0.98,
		("nested interface block element 0 failed: %.3f,%.3f,%.3f,%.3f")
			:format(nr0, ng0, nb0, na0))
	assert(math.abs(nr2 - 0.4) < 0.03 and math.abs(ng2 - 0.5) < 0.03
		and math.abs(nb2 - 0.5) < 0.03 and na2 > 0.98,
		("nested interface block struct-array element failed: %.3f,%.3f,%.3f,%.3f")
			:format(nr2, ng2, nb2, na2))
	assert(math.abs(nr1 - 0.6) < 0.03 and math.abs(ng1 - 0.7) < 0.03
		and nb1 > 0.98 and na1 > 0.98,
		("nested interface block dynamic element 1 failed: %.3f,%.3f,%.3f,%.3f")
			:format(nr1, ng1, nb1, na1))
	assert(math.abs(nr3 - 0.7) < 0.03 and math.abs(ng3 - 0.8) < 0.03
		and nb3 > 0.98 and na3 > 0.98,
		("nested interface block dynamic struct-array element failed: %.3f,%.3f,%.3f,%.3f")
			:format(nr3, ng3, nb3, na3))
	local multi = multiCanvas:newImageData()
	local ur, ug, ub, ua = multi:getPixel(20, 20)
	assert(math.abs(ur - 0.45) < 0.03 and math.abs(ug - 0.75) < 0.03
		and math.abs(ub - 0.95) < 0.03 and ua > 0.98,
		("multi-declarator interface block failed: %.3f,%.3f,%.3f,%.3f")
			:format(ur, ug, ub, ua))
	local integer = integerCanvas:newImageData()
	local ir0, ig0, ib0, ia0 = integer:getPixel(20, 10)
	local ir1, ig1, ib1, ia1 = integer:getPixel(40, 10)
	assert(math.abs(ir0 - 0.2) < 0.03 and math.abs(ig0 - 0.8) < 0.03
		and math.abs(ib0 - 0.4) < 0.03 and ia0 > 0.98,
		("integer varying element 0 failed: %.3f,%.3f,%.3f,%.3f")
			:format(ir0, ig0, ib0, ia0))
	assert(math.abs(ir1 - 0.7) < 0.03 and math.abs(ig1 - 0.3) < 0.03
		and math.abs(ib1 - 0.9) < 0.03 and ia1 > 0.98,
		("integer varying dynamic element 1 failed: %.3f,%.3f,%.3f,%.3f")
			:format(ir1, ig1, ib1, ia1))
	local inline = inlineCanvas:newImageData()
	local xr0, xg0, xb0, xa0 = inline:getPixel(8, 8)
	local xr1, xg1, xb1, xa1 = inline:getPixel(24, 8)
	local xr2, xg2, xb2, xa2 = inline:getPixel(40, 8)
	local xr3, xg3, xb3, xa3 = inline:getPixel(52, 8)
	local function expectInline(actualR, actualG, actualB, actualA, r, g, b, label)
		assert(math.abs(actualR - r) < 0.03 and math.abs(actualG - g) < 0.03
			and math.abs(actualB - b) < 0.03 and actualA > 0.98,
			("inline struct %s failed: %.3f,%.3f,%.3f,%.3f")
				:format(label, actualR, actualG, actualB, actualA))
	end
	expectInline(xr0, xg0, xb0, xa0, 0.15, 0.3, 0.7, "0/0")
	expectInline(xr1, xg1, xb1, xa1, 0.25, 0.4, 0.3, "0/1")
	expectInline(xr2, xg2, xb2, xa2, 0.5, 0.3, 0.5, "1/0")
	expectInline(xr3, xg3, xb3, xa3, 0.3, 0.6, 0.4, "1/1")
	print("LOVE_SHADER_INTERPOLATION_PASS",
		("flat=%.3f,%.3f,%.3f smooth=%.3f,%.3f,%.3f block=%.3f,%.3f,%.3f matrix=%.3f,%.3f,%.3f arrays=%.3f,%.3f nested=%.3f,%.3f multi=%.3f,%.3f,%.3f integer=%.3f,%.3f inline=%.3f,%.3f")
			:format(fr, fg, fb, sr, sg, sb, br, bg, bb, mr, mg, mb, ab0, ab1, nb0, nb1,
				ur, ug, ub, ir0, ir1, xr0, xr3))
	love.event.quit()
end
