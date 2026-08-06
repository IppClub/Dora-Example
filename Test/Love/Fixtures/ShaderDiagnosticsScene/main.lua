local completed = false

function love.load()
	local valid, compileError = love.graphics.validateShader(false, [[
#pragma language glsl3
extern number KeptDeclaration;

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
	return MissingLoveSymbol * color;
}
]])
	assert(not valid, "invalid Love Shader unexpectedly compiled")
	assert(type(compileError) == "string" and #compileError > 0,
		"invalid Love Shader did not return a compiler diagnostic")
	assert(compileError:find("Love pixel Shader source line 5", 1, true),
		"Love Shader compiler diagnostic did not map to source line 5: " .. compileError)

	local shader = love.graphics.newShader([[
#pragma language glsl3
extern number UnusedWarningUniform;
vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
	return Texel(texture, uv) * color;
}
]])
	local warnings = shader:getWarnings()
	assert(type(warnings) == "string"
		and warnings:find("UnusedWarningUniform", 1, true)
		and warnings:find("Dora pixel Shader translator", 1, true),
		"Dora translator warning was not propagated through Shader:getWarnings(): "
			.. tostring(warnings))
	completed = true
	print("LOVE_SHADER_DIAGNOSTICS_PASS", compileError, warnings)
	love.event.quit()
end

function love.update()
	assert(completed)
end
