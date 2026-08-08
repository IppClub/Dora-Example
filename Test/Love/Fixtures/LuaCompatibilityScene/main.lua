local frames = 0

local function makeReaders()
	local function isolated()
		return compatibility_value
	end
	local function untouched()
		return compatibility_value
	end
	return isolated, untouched
end

function love.load()
	compatibility_value = "global"
	local isolated, untouched = makeReaders()
	local environment = setmetatable({compatibility_value = "isolated"}, {__index = _G})
	assert(setfenv(isolated, environment) == isolated)
	assert(isolated() == "isolated" and untouched() == "global")
	assert(getfenv(isolated) == environment and getfenv(untouched) == _G)

	local function stackLevel()
		local stackEnvironment = setmetatable({stack_value = 55}, {__index = _G})
		assert(setfenv(1, stackEnvironment) == 1)
		return stack_value, getfenv()
	end
	local value, stackEnvironment = stackLevel()
	assert(value == 55 and stackEnvironment.stack_value == 55)
	local function stackLevelTwo()
		local function replaceOuter()
			local outerEnvironment = setmetatable({outer_value = 89}, {__index = _G})
			assert(setfenv(2, outerEnvironment) == 2)
			return outerEnvironment
		end
		local outerEnvironment = replaceOuter()
		return outer_value, getfenv(), outerEnvironment
	end
	local outerValue, currentEnvironment, outerEnvironment = stackLevelTwo()
	assert(outerValue == 89 and currentEnvironment == outerEnvironment)

	local ok, message = pcall(setfenv, 0, {})
	assert(not ok and message:find("Lua 5.5", 1, true))
	assert(getfenv(0) == _G)
	math.randomseed(1234.75)
	local firstRandom = math.random()
	math.randomseed(1234.75)
	assert(math.random() == firstRandom)
	math.randomseed(-1234.75)
	assert(type(math.random()) == "number")
	assert(math.abs(math.atan2(1, 0) - math.pi / 2) < 0.000001)
	print("LOVE_LUA55_FENV_PASS", isolated(), untouched(), value, outerValue)
end

function love.update()
	frames = frames + 1
	if frames == 3 then
		love.event.quit()
	end
end
