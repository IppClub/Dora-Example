local loveMath = require("love.math")

function love.load()
	loveMath.setRandomSeed(12345)
	assert(loveMath.getRandomState() == "0x6a484838548f8a63")
	assert(math.abs(loveMath.random() - 0.888946119490527) < 1e-15)

	local generator = loveMath.newRandomGenerator(1, 2)
	local low, high = generator:getSeed()
	assert(low == 1 and high == 2)
	local saved = generator:getState()
	local value = generator:random()
	generator:setState(saved)
	assert(generator:random() == value)

	local triangles = loveMath.triangulate({0, 0, 10, 0, 10, 10, 5, 5, 0, 10})
	assert(#triangles == 3 and not loveMath.isConvex({0, 0, 10, 0, 5, 5, 10, 10, 0, 10}))
	local red, green, blue, alpha = loveMath.colorToBytes({1, 0.5, 0, 0.25})
	assert(red == 255 and green == 128 and blue == 0 and alpha == 64)
	local linear = loveMath.gammaToLinear(0.5)
	assert(math.abs(loveMath.linearToGamma(linear) - 0.5) < 1e-7)
	local noise = loveMath.noise(0.125, 0.25, 0.5, 1)
	assert(noise >= 0 and noise <= 1 and noise == loveMath.noise(0.125, 0.25, 0.5, 1))
	local transform = loveMath.newTransform(10, 20, 0, 2, 3)
	local transformedX, transformedY = transform:transformPoint(4, 5)
	local originalX, originalY = transform:inverseTransformPoint(transformedX, transformedY)
	assert(transformedX == 18 and transformedY == 35)
	assert(math.abs(originalX - 4) < 1e-6 and math.abs(originalY - 5) < 1e-6)
	local curve = loveMath.newBezierCurve({0, 0, 10, 20, 20, 0})
	local curveX, curveY = curve:evaluate(0.5)
	assert(curveX == 10 and curveY == 10 and #curve:render(3) == 34)
	print("LOVE_MATH_OBJECTS_PASS", loveMath.getRandomState(), #triangles,
		red, green, blue, alpha, string.format("%.9f", noise), transformedX, transformedY, curveX, curveY)
end

local frames = 0
function love.update()
	frames = frames + 1
	if frames == 2 then love.event.quit() end
end

function love.quit()
	print("LOVE_MATH_RELEASE_PASS")
	return false
end
