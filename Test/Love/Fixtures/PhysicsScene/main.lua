local physics = require("love.physics")
local graphics = require("love.graphics")

local world
local ball
local ground
local pendulum
local anchor
local joint
local ballFixture
local groundFixture
local chainFixture
local probeFixture
local chainChildSeen = false
local elapsed = 0
local requested = false
local captured = false
local finished = false
local contactBegins, contactEnds, contactPres, contactPosts = 0, 0, 0, 0
local savedContact
local separationFrames = 0
local deferredBody, deferredFixture, deferredJoint
local deferredDestroyRequested = false
local deferredDestroyVerified = false

local function verifyDeferredDestroy()
	if deferredDestroyRequested and not deferredDestroyVerified then
		assert(deferredBody:isDestroyed() and deferredFixture:isDestroyed() and deferredJoint:isDestroyed())
		assert(not pcall(function() deferredBody:getPosition() end))
		assert(not pcall(function() deferredFixture:getFriction() end))
		assert(not pcall(function() deferredJoint:getBodies() end))
		deferredDestroyVerified = true
		print("LOVE_PHYSICS_DEFERRED_DESTROY_PASS")
	end
end

local function verifyRopeJoint()
	local ropeWorld = physics.newWorld(0, 0, true)
	local ropeAnchor = physics.newBody(ropeWorld, 0, 0, "static")
	local ropeBody = physics.newBody(ropeWorld, 128, 0, "dynamic")
	local ropeFixture = physics.newFixture(ropeBody, physics.newCircleShape(8), 1)
	local rope = physics.newRopeJoint(
		ropeAnchor, ropeBody, 0, 0, 128, 0, 64, true)
	assert(rope:getType() == "rope" and rope:getCollideConnected()
		and math.abs(rope:getMaxLength() - 64) < 0.001)
	local ropeX1, ropeY1, ropeX2, ropeY2 = rope:getAnchors()
	assert(math.abs(ropeX1) < 0.01 and math.abs(ropeY1) < 0.01
		and math.abs(ropeX2 - 128) < 0.01 and math.abs(ropeY2) < 0.01)
	ropeBody:setLinearVelocity(120, 0)
	ropeWorld:update(1 / 60, 8, 3)
	local ropeForceX, ropeForceY = rope:getReactionForce(60)
	assert(ropeForceX < 0 and math.abs(ropeForceY) < 0.01)
	for _ = 2, 30 do ropeWorld:update(1 / 60, 8, 3) end
	local constrainedX, constrainedY = ropeBody:getPosition()
	assert(constrainedX <= 64.1 and math.abs(constrainedY) < 0.01)
	rope:setMaxLength(96)
	assert(math.abs(rope:getMaxLength() - 96) < 0.001)
	ropeBody:setPosition(32, 0)
	ropeBody:setLinearVelocity(0, 0)
	for _ = 1, 10 do ropeWorld:update(1 / 60, 8, 3) end
	local slackX, slackY = ropeBody:getPosition()
	assert(math.abs(slackX - 32) < 0.01 and math.abs(slackY) < 0.01)
	ropeBody:setLinearVelocity(300, 0)
	for _ = 1, 60 do ropeWorld:update(1 / 60, 8, 3) end
	local cappedX, cappedY = ropeBody:getPosition()
	assert(cappedX <= 96.1 and math.abs(cappedY) < 0.01)
	assert(not pcall(rope.setMaxLength, rope, -1))
	ropeWorld:destroy()
	assert(ropeWorld:isDestroyed() and ropeAnchor:isDestroyed()
		and ropeBody:isDestroyed() and ropeFixture:isDestroyed() and rope:isDestroyed())
	print("LOVE_PHYSICS_ROPE_JOINT_PASS", constrainedX, constrainedY,
		ropeForceX, ropeForceY, slackX, slackY, cappedX, cappedY)
end

local function verifyPulleyJoint()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local bodyA = physics.newBody(world, 0, 100, "dynamic")
	local bodyB = physics.newBody(world, 200, 100, "dynamic")
	physics.newFixture(bodyA, physics.newRectangleShape(16, 16), 1)
	physics.newFixture(bodyB, physics.newRectangleShape(16, 16), 1)
	local pulley = physics.newPulleyJoint(
		bodyA, bodyB, 0, 0, 200, 0, 0, 100, 200, 100, 2)
	assert(pulley:getType() == "pulley" and pulley:getCollideConnected())
	local groundX1, groundY1, groundX2, groundY2 = pulley:getGroundAnchors()
	assert(math.abs(groundX1) < 0.001 and math.abs(groundY1) < 0.001
		and math.abs(groundX2 - 200) < 0.001 and math.abs(groundY2) < 0.001)
	assert(math.abs(pulley:getLengthA() - 100) < 0.001
		and math.abs(pulley:getLengthB() - 100) < 0.001
		and math.abs(pulley:getRatio() - 2) < 0.001)
	bodyA:setLinearVelocity(0, 120)
	for _ = 1, 30 do world:update(1 / 60, 8, 3) end
	local lengthA, lengthB = pulley:getLengthA(), pulley:getLengthB()
	local velocityAX, velocityAY = bodyA:getLinearVelocity()
	local velocityBX, velocityBY = bodyB:getLinearVelocity()
	assert(lengthA > 100 and lengthB < 100
		and lengthA + 2 * lengthB <= 300.05
		and velocityAY > 0 and velocityBY < 0)
	assert(not pcall(physics.newPulleyJoint,
		bodyA, bodyB, 0, 0, 200, 0, 0, 100, 200, 100, 0))
	world:destroy()
	assert(pulley:isDestroyed() and not pcall(pulley.getRatio, pulley))
	print("LOVE_PHYSICS_PULLEY_JOINT_PASS", lengthA, lengthB,
		lengthA + 2 * lengthB, velocityAX, velocityAY, velocityBX, velocityBY)
end

local function verifyWheelJoint()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local chassis = physics.newBody(world, 0, 0, "static")
	local wheelBody = physics.newBody(world, 0, 32, "dynamic")
	physics.newFixture(wheelBody, physics.newCircleShape(8), 1)
	local wheel = physics.newWheelJoint(
		chassis, wheelBody, 0, 0, 0, 32, 0, 1, false)
	assert(wheel:getType() == "wheel" and not wheel:getCollideConnected())
	local anchorX1, anchorY1, anchorX2, anchorY2 = wheel:getAnchors()
	local axisX, axisY = wheel:getAxis()
	assert(math.abs(anchorX1) < 0.001 and math.abs(anchorY1) < 0.001
		and math.abs(anchorX2) < 0.001 and math.abs(anchorY2 - 32) < 0.001
		and math.abs(axisX) < 0.001 and math.abs(axisY - 1) < 0.001)
	assert(math.abs(wheel:getJointTranslation() - 32) < 0.001
		and not wheel:isMotorEnabled()
		and math.abs(wheel:getSpringFrequency() - 2) < 0.001
		and math.abs(wheel:getSpringDampingRatio() - 0.7) < 0.001)
	wheel:setSpringFrequency(4)
	wheel:setSpringDampingRatio(0.6)
	wheel:setMotorEnabled(true)
	wheel:setMotorSpeed(2)
	wheel:setMaxMotorTorque(409600)
	world:update(1 / 60, 8, 3)
	local firstTorque = wheel:getMotorTorque(60)
	for _ = 2, 60 do world:update(1 / 60, 8, 3) end
	local translation = wheel:getJointTranslation()
	local jointSpeed = wheel:getJointSpeed()
	local angularVelocity = wheelBody:getAngularVelocity()
	assert(math.abs(translation) < 2
		and math.abs(angularVelocity - 2) < 0.05
		and math.abs(jointSpeed - angularVelocity * physics.getMeter()) < 0.05
		and math.abs(firstTorque) > 0)
	local sharedWheel = physics.newWheelJoint(chassis, wheelBody, 0, 0, 0, 1, true)
	assert(sharedWheel:getCollideConnected())
	sharedWheel:destroy()
	assert(not pcall(physics.newWheelJoint, chassis, wheelBody, 0, 0, 0, 0)
		and not pcall(wheel.setMaxMotorTorque, wheel, -1)
		and not pcall(wheel.setSpringFrequency, wheel, -1))
	world:destroy()
	assert(wheel:isDestroyed() and not pcall(wheel.getJointSpeed, wheel))
	print("LOVE_PHYSICS_WHEEL_JOINT_PASS", translation, jointSpeed,
		angularVelocity, firstTorque, axisX, axisY)
end

local function verifyMouseJoint()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local body = physics.newBody(world, 0, 0, "dynamic")
	physics.newFixture(body, physics.newCircleShape(8), 1)
	local mass = body:getMass()
	local mouse = physics.newMouseJoint(body, 0, 0)
	assert(mouse:getType() == "mouse" and not mouse:getCollideConnected())
	local attached, absent = mouse:getBodies()
	assert(attached == body and absent == nil)
	local targetX, targetY = mouse:getTarget()
	local anchorX1, anchorY1, anchorX2, anchorY2 = mouse:getAnchors()
	assert(math.abs(targetX) < 0.001 and math.abs(targetY) < 0.001
		and math.abs(anchorX1) < 0.001 and math.abs(anchorY1) < 0.001
		and math.abs(anchorX2) < 0.001 and math.abs(anchorY2) < 0.001
		and math.abs(mouse:getMaxForce() - 1000 * mass) < 0.05
		and math.abs(mouse:getFrequency() - 5) < 0.001
		and math.abs(mouse:getDampingRatio() - 0.7) < 0.001)
	mouse:setTarget(96, 32)
	mouse:setMaxForce(5000 * mass)
	mouse:setFrequency(7)
	mouse:setDampingRatio(0.8)
	for _ = 1, 60 do world:update(1 / 60, 8, 3) end
	local x, y = body:getPosition()
	targetX, targetY = mouse:getTarget()
	assert(math.abs(targetX - 96) < 0.001 and math.abs(targetY - 32) < 0.001
		and math.abs(mouse:getMaxForce() - 5000 * mass) < 0.05
		and math.abs(mouse:getFrequency() - 7) < 0.001
		and math.abs(mouse:getDampingRatio() - 0.8) < 0.001
		and x > 90 and y > 28)
	local kinematic = physics.newBody(world, 0, 0, "kinematic")
	assert(not pcall(physics.newMouseJoint, kinematic, 0, 0)
		and not pcall(mouse.setTarget, mouse, 0 / 0, 0)
		and not pcall(mouse.setMaxForce, mouse, -1)
		and not pcall(mouse.setFrequency, mouse, 0))
	kinematic:destroy()
	body:destroy()
	assert(mouse:isDestroyed() and not pcall(mouse.getTarget, mouse))
	world:destroy()
	print("LOVE_PHYSICS_MOUSE_JOINT_PASS", x, y, targetX, targetY, mass)
end

local function verifyMotorJoint()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local anchor = physics.newBody(world, 10, 20, "static")
	local body = physics.newBody(world, 70, 50, "dynamic")
	body:setAngle(0.4)
	physics.newFixture(body, physics.newRectangleShape(24, 12), 1)
	local defaultMotor = physics.newMotorJoint(anchor, body)
	local defaultX, defaultY = defaultMotor:getLinearOffset()
	assert(defaultMotor:getType() == "motor" and not defaultMotor:getCollideConnected()
		and math.abs(defaultX - 60) < 0.001 and math.abs(defaultY - 30) < 0.001
		and math.abs(defaultMotor:getAngularOffset() - 0.4) < 0.001
		and math.abs(defaultMotor:getMaxForce() - 64) < 0.001
		and math.abs(defaultMotor:getMaxTorque() - 4096) < 0.01
		and math.abs(defaultMotor:getCorrectionFactor() - 0.3) < 0.001)
	defaultMotor:destroy()
	local motor = physics.newMotorJoint(anchor, body, 0.8, true)
	assert(motor:getType() == "motor" and motor:getCollideConnected())
	local bodyA, bodyB = motor:getBodies()
	local anchorX1, anchorY1, anchorX2, anchorY2 = motor:getAnchors()
	assert(bodyA == anchor and bodyB == body
		and math.abs(anchorX1 - 10) < 0.001 and math.abs(anchorY1 - 20) < 0.001
		and math.abs(anchorX2 - 70) < 0.001 and math.abs(anchorY2 - 50) < 0.001)
	motor:setLinearOffset(20, -10)
	motor:setAngularOffset(0.25)
	motor:setMaxForce(1000000)
	motor:setMaxTorque(10000000)
	motor:setCorrectionFactor(0.8)
	world:update(1 / 60, 8, 3)
	local reactionX, reactionY = motor:getReactionForce(60)
	local reactionTorque = motor:getReactionTorque(60)
	for _ = 2, 90 do world:update(1 / 60, 8, 3) end
	local x, y = body:getPosition()
	local angle = body:getAngle()
	local offsetX, offsetY = motor:getLinearOffset()
	assert(math.abs(offsetX - 20) < 0.001 and math.abs(offsetY + 10) < 0.001
		and math.abs(motor:getAngularOffset() - 0.25) < 0.001
		and math.abs(motor:getMaxForce() - 1000000) < 1
		and math.abs(motor:getMaxTorque() - 10000000) < 1
		and math.abs(motor:getCorrectionFactor() - 0.8) < 0.001
		and math.abs(x - 30) < 0.2 and math.abs(y - 10) < 0.2
		and math.abs(angle - 0.25) < 0.01
		and math.abs(reactionX) + math.abs(reactionY) > 0
		and math.abs(reactionTorque) > 0)
	assert(not pcall(physics.newMotorJoint, anchor, body, -0.1)
		and not pcall(physics.newMotorJoint, anchor, body, 1.1)
		and not pcall(motor.setLinearOffset, motor, 0 / 0, 0)
		and not pcall(motor.setAngularOffset, motor, 0 / 0)
		and not pcall(motor.setMaxForce, motor, -1)
		and not pcall(motor.setMaxTorque, motor, -1)
		and not pcall(motor.setCorrectionFactor, motor, 1.1))
	body:destroy()
	assert(motor:isDestroyed() and not pcall(motor.getLinearOffset, motor))
	world:destroy()
	print("LOVE_PHYSICS_MOTOR_JOINT_PASS", x, y, angle,
		reactionX, reactionY, reactionTorque, offsetX, offsetY)
end

local function verifyGearJoint()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local groundA = physics.newBody(world, -60, 0, "static")
	local bodyA = physics.newBody(world, -60, 0, "dynamic")
	local groundB = physics.newBody(world, 60, 0, "static")
	local bodyB = physics.newBody(world, 60, 0, "dynamic")
	physics.newFixture(bodyA, physics.newCircleShape(16), 1)
	physics.newFixture(bodyB, physics.newCircleShape(16), 1)
	local revolute = physics.newRevoluteJoint(groundA, bodyA, -60, 0, false)
	local prismatic = physics.newPrismaticJoint(groundB, bodyB, 60, 0, 1, 0, false)
	prismatic:setLimitsEnabled(false)
	local defaultGear = physics.newGearJoint(revolute, prismatic)
	assert(defaultGear:getType() == "gear" and defaultGear:getRatio() == 1
		and not defaultGear:getCollideConnected())
	defaultGear:destroy()
	local gear = physics.newGearJoint(revolute, prismatic, 2, true)
	local sourceA, sourceB = gear:getJoints()
	local drivenA, drivenB = gear:getBodies()
	assert(sourceA == revolute and sourceB == prismatic
		and drivenA == bodyA and drivenB == bodyB
		and gear:getRatio() == 2 and gear:getCollideConnected())
	bodyA:setAngularVelocity(4)
	world:update(1 / 60, 8, 3)
	local reactionX, reactionY = gear:getReactionForce(60)
	local reactionTorque = gear:getReactionTorque(60)
	for _ = 2, 90 do world:update(1 / 60, 8, 3) end
	local angularVelocity = bodyA:getAngularVelocity()
	local linearVelocity = bodyB:getLinearVelocity()
	assert(math.abs(angularVelocity + 2 * linearVelocity / physics.getMeter()) < 0.1
		and math.abs(angularVelocity) + math.abs(linearVelocity) > 0.1
		and math.abs(reactionTorque) > 0)
	gear:setRatio(-1.5)
	assert(math.abs(gear:getRatio() + 1.5) < 0.001
		and not pcall(physics.newGearJoint, revolute, revolute)
		and not pcall(physics.newGearJoint, revolute, gear)
		and not pcall(physics.newGearJoint, revolute, prismatic, 0 / 0)
		and not pcall(gear.setRatio, gear, 0 / 0))
	revolute:destroy()
	assert(gear:isDestroyed() and not pcall(gear.getRatio, gear))
	world:destroy()
	print("LOVE_PHYSICS_GEAR_JOINT_PASS", angularVelocity, linearVelocity,
		reactionX, reactionY, reactionTorque)
end

local function verifyConnectedEdgeContinuousContact()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local chainBody = physics.newBody(world, 0, 0, "static")
	local chainShape = physics.newChainShape(false, {-128, 16, 0, 0, 128, 16})
	chainShape:setPreviousVertex(-256, 48)
	chainShape:setNextVertex(256, 48)
	local chain = physics.newFixture(chainBody, chainShape, 0)
	local bulletBody = physics.newBody(world, 0, -80, "dynamic")
	local bullet = physics.newFixture(bulletBody, physics.newCircleShape(6), 1)
	bulletBody:setBullet(true)
	bulletBody:setLinearVelocity(0, 12000)
	local begins = 0
	local childSeen = false
	world:setCallbacks(function(first, second, contact)
		if (first == chain and second == bullet) or (first == bullet and second == chain) then
			begins = begins + 1
			local childA, childB = contact:getChildren()
			local child = first == chain and childA or childB
			assert(child == 1 or child == 2)
			childSeen = true
		end
	end)
	world:update(1 / 60, 8, 3)
	local x, y = bulletBody:getPosition()
	local velocityX, velocityY = bulletBody:getLinearVelocity()
	assert(bulletBody:isBullet() and begins > 0 and childSeen,
		"continuous connected-edge collision did not create a Chain contact")
	assert(math.abs(x) < 0.1 and y < 8,
		"bullet tunneled through the connected Chain vertex")
	world:destroy()
	assert(chainBody:isDestroyed() and bulletBody:isDestroyed()
		and chain:isDestroyed() and bullet:isDestroyed())
	print("LOVE_PHYSICS_CONNECTED_EDGE_CCD_PASS", x, y,
		velocityX, velocityY, begins)
end

local function verifyFixtureGroupFiltering()
	local physics = love.physics
	local world = physics.newWorld(0, 0, true)
	local positiveBodyA = physics.newBody(world, -64, 0, "dynamic")
	local positiveBodyB = physics.newBody(world, -64, 0, "dynamic")
	local positiveA = physics.newFixture(positiveBodyA, physics.newCircleShape(8), 1)
	local positiveB = physics.newFixture(positiveBodyB, physics.newCircleShape(8), 1)
	positiveA:setFilterData(1, 0, 300)
	positiveB:setFilterData(1, 0, 300)
	local negativeBodyA = physics.newBody(world, 64, 0, "dynamic")
	local negativeBodyB = physics.newBody(world, 64, 0, "dynamic")
	local negativeA = physics.newFixture(negativeBodyA, physics.newCircleShape(8), 1)
	local negativeB = physics.newFixture(negativeBodyB, physics.newCircleShape(8), 1)
	negativeA:setFilterData(1, 65535, -300)
	negativeB:setFilterData(1, 65535, -300)
	local positiveBegins, negativeBegins = 0, 0
	world:setCallbacks(function(first, second)
		if (first == positiveA and second == positiveB)
			or (first == positiveB and second == positiveA) then
			positiveBegins = positiveBegins + 1
		elseif (first == negativeA and second == negativeB)
			or (first == negativeB and second == negativeA) then
			negativeBegins = negativeBegins + 1
		end
	end)
	world:update(1 / 60, 8, 3)
	assert(positiveBegins > 0,
		"positive group did not override disabled category masks")
	assert(negativeBegins == 0,
		"negative group did not override enabled category masks")
	local positiveGroup = positiveA:getGroupIndex()
	local negativeGroup = negativeA:getGroupIndex()
	world:destroy()
	print("LOVE_PHYSICS_GROUP_FILTER_PASS", positiveBegins, negativeBegins,
		positiveGroup, negativeGroup)
end

function love.load()
	physics.setMeter(64)
	assert(physics.getMeter() == 64)
	world = physics.newWorld(0, 9.81 * 64, true)
	local gx, gy = world:getGravity()
	assert(gx == 0 and math.abs(gy - 9.81 * 64) < 0.001)

	ball = physics.newBody(world, 150, 45, "dynamic")
	local circle = physics.newCircleShape(14)
	assert(circle:getType() == "circle" and circle:getRadius() == 14)
	ballFixture = physics.newFixture(ball, circle, 1)
	ballFixture:setFriction(0.65)
	ballFixture:setRestitution(0.15)
	assert(math.abs(ballFixture:getFriction() - 0.65) < 0.001)
	assert(ballFixture:getType() == "circle" and ballFixture:getBody() == ball
		and ballFixture:getShape() == circle and ballFixture:getDensity() == 1)
	ballFixture:setDensity(2)
	assert(ballFixture:getDensity() == 2 and ballFixture:testPoint(150, 45)
		and not ballFixture:testPoint(180, 45))
	local fixtureNormalX, fixtureNormalY, fixtureFraction = ballFixture:rayCast(100, 45, 200, 45, 1)
	assert(math.abs(fixtureNormalX + 1) < 0.001 and math.abs(fixtureNormalY) < 0.001
		and fixtureFraction > 0.3 and fixtureFraction < 0.4)
	local fixtureX1, fixtureY1, fixtureX2, fixtureY2 = ballFixture:getBoundingBox()
	assert(math.abs(fixtureX1 - 136) < 0.01 and math.abs(fixtureY1 - 31) < 0.01
		and math.abs(fixtureX2 - 164) < 0.01 and math.abs(fixtureY2 - 59) < 0.01)
	local fixtureMassX, fixtureMassY, fixtureMass, fixtureInertia = ballFixture:getMassData()
	assert(math.abs(fixtureMassX) < 0.001 and math.abs(fixtureMassY) < 0.001
		and fixtureMass > 0 and fixtureInertia > 0)
	local categoryBits, maskBits, groupIndex = ballFixture:getFilterData()
	assert(categoryBits == 1 and maskBits == 65535 and groupIndex == 0)
	ballFixture:setFilterData(5, 10, -2)
	categoryBits, maskBits, groupIndex = ballFixture:getFilterData()
	assert(categoryBits == 5 and maskBits == 10 and groupIndex == -2)
	ballFixture:setCategory(1, 3, 16)
	local category1, category2, category3 = ballFixture:getCategory()
	assert(category1 == 1 and category2 == 3 and category3 == 16)
	ballFixture:setMask({2, 4})
	local mask1, mask2 = ballFixture:getMask()
	assert(mask1 == 2 and mask2 == 4)
	ballFixture:setGroupIndex(32767)
	assert(ballFixture:getGroupIndex() == 32767)
	ballFixture:setGroupIndex(-32768)
	assert(ballFixture:getGroupIndex() == -32768)
	local fixtureData = {kind = "ball"}
	ballFixture:setUserData(fixtureData)
	assert(ballFixture:getUserData() == fixtureData)
	ballFixture:setUserData(nil)
	ballFixture:setFilterData(1, 65535, 0)
	ballFixture:setDensity(1)
	assert(not pcall(ballFixture.setGroupIndex, ballFixture, 32768)
		and not pcall(ballFixture.setGroupIndex, ballFixture, -32769)
		and not pcall(ballFixture.setCategory, ballFixture, 17)
		and not pcall(ballFixture.getBoundingBox, ballFixture, 2)
		and not pcall(ballFixture.rayCast, ballFixture, 100, 45, 200, 45, 2))
	print("LOVE_PHYSICS_FIXTURE_API_PASS", fixtureX1, fixtureY1, fixtureX2, fixtureY2,
		fixtureMass, fixtureInertia, fixtureFraction)

	ground = physics.newBody(world, 320, 300, "static")
	local groundShape = physics.newRectangleShape(560, 30)
	groundFixture = physics.newFixture(ground, groundShape, 0)

	local shapeTestBody = physics.newBody(world, -1000, -1000, "static")
	local polygonShape = physics.newPolygonShape({0, 0, 30, 0, 15, 20})
	assert(polygonShape:getType() == "polygon" and polygonShape:validate())
	assert(select("#", polygonShape:getPoints()) == 6)
	physics.newFixture(shapeTestBody, polygonShape, 0)
	local edgeShape = physics.newEdgeShape(-20, 0, 20, 0)
	assert(edgeShape:getType() == "edge")
	edgeShape:setPreviousVertex(-30, 10)
	edgeShape:setNextVertex(30, 10)
	local edgePreviousX, edgePreviousY = edgeShape:getPreviousVertex()
	local edgeNextX, edgeNextY = edgeShape:getNextVertex()
	assert(edgePreviousX == -30 and edgePreviousY == 10)
	assert(edgeNextX == 30 and edgeNextY == 10)
	physics.newFixture(shapeTestBody, edgeShape, 0)
	local chainBody = physics.newBody(world, 800, 300, "static")
	local chainShape = physics.newChainShape(false, {-60, 0, 0, -20, 60, 0})
	chainShape:setPreviousVertex(-90, 20)
	chainShape:setNextVertex(90, 20)
	assert(chainShape:getType() == "chain" and chainShape:getVertexCount() == 3)
	local chainX, chainY = chainShape:getPoint(2)
	assert(chainX == 0 and chainY == -20)
	local firstChildEdge = chainShape:getChildEdge(1)
	assert(firstChildEdge:getType() == "edge")
	local childPreviousX, childPreviousY = firstChildEdge:getPreviousVertex()
	assert(childPreviousX == -90 and childPreviousY == 20)
	local childNextX, childNextY = firstChildEdge:getNextVertex()
	assert(childNextX == 60 and childNextY == 0)
	local lastChildEdge = chainShape:getChildEdge(2)
	local lastChildNextX, lastChildNextY = lastChildEdge:getNextVertex()
	assert(lastChildNextX == 90 and lastChildNextY == 20)
	chainFixture = physics.newFixture(chainBody, chainShape, 0)
	local probeBody = physics.newBody(world, 800, 190, "dynamic")
	probeFixture = physics.newFixture(probeBody, physics.newCircleShape(10), 1)
	local loopShape = physics.newChainShape(true, 0, 0, 20, 0, 10, 15)
	assert(loopShape:getVertexCount() == 4)
	local loopX, loopY = loopShape:getPoint(4)
	assert(loopX == 0 and loopY == 0)
	local loopPreviousX, loopPreviousY = loopShape:getPreviousVertex()
	local loopNextX, loopNextY = loopShape:getNextVertex()
	assert(loopPreviousX == 10 and loopPreviousY == 15 and loopNextX == 20 and loopNextY == 0)

	local apiWorld = physics.newWorld(0, 0, true)
	local apiBody = physics.newBody(apiWorld, 100, 100, "dynamic")
	local apiShape = physics.newCircleShape(5, 0, 10)
	local apiFixture = physics.newFixture(apiBody, apiShape, 2)
	local localCenterX, localCenterY = apiBody:getLocalCenter()
	local worldCenterX, worldCenterY = apiBody:getWorldCenter()
	assert(math.abs(localCenterX - 5) < 0.01 and math.abs(localCenterY) < 0.01)
	assert(math.abs(worldCenterX - 105) < 0.01 and math.abs(worldCenterY - 100) < 0.01)
	assert(apiBody:getMass() > 0 and apiBody:getInertia() > 0)
	local originalMass = apiBody:getMass()
	local originalInertia = apiBody:getInertia()
	local massCenterX, massCenterY, massValue, inertiaValue = apiBody:getMassData()
	assert(math.abs(massCenterX - 5) < 0.01 and math.abs(massCenterY) < 0.01)
	assert(math.abs(massValue - originalMass) < 0.0001 and math.abs(inertiaValue - originalInertia) < 0.01)
	apiBody:setMassData(4, 0, 2, 100)
	massCenterX, massCenterY, massValue, inertiaValue = apiBody:getMassData()
	assert(math.abs(massCenterX - 4) < 0.01 and math.abs(massCenterY) < 0.01)
	assert(math.abs(massValue - 2) < 0.0001 and math.abs(inertiaValue - 100) < 0.01)
	apiBody:setMass(3)
	apiBody:setInertia(120)
	assert(math.abs(apiBody:getMass() - 3) < 0.0001 and math.abs(apiBody:getInertia() - 120) < 0.01)
	apiBody:resetMassData()
	assert(math.abs(apiBody:getMass() - originalMass) < 0.0001
		and math.abs(apiBody:getInertia() - originalInertia) < 0.01)
	assert(not pcall(apiBody.setMassData, apiBody, 4, 0, 2, 20))

	local gravityWorld = physics.newWorld(0, 64, true)
	local gravityShape = physics.newCircleShape(8)
	local gravityZero = physics.newBody(gravityWorld, 0, 0, "dynamic")
	local gravityDouble = physics.newBody(gravityWorld, 100, 0, "dynamic")
	local gravityReverse = physics.newBody(gravityWorld, 200, 0, "dynamic")
	local gravityFixtureZero = physics.newFixture(gravityZero, gravityShape, 1)
	local gravityFixtureDouble = physics.newFixture(gravityDouble, gravityShape, 1)
	local gravityFixtureReverse = physics.newFixture(gravityReverse, gravityShape, 1)
	gravityZero:setGravityScale(0)
	gravityDouble:setGravityScale(2)
	gravityReverse:setGravityScale(-1)
	assert(gravityZero:getGravityScale() == 0 and gravityDouble:getGravityScale() == 2
		and gravityReverse:getGravityScale() == -1)
	gravityZero:applyForce(100, 0)
	gravityWorld:setGravity(0, 32)
	gravityWorld:update(0.5, 8, 3)
	local zeroVX, zeroVY = gravityZero:getLinearVelocity()
	local _, doubleVY = gravityDouble:getLinearVelocity()
	local _, reverseVY = gravityReverse:getLinearVelocity()
	assert(zeroVX > 0 and math.abs(zeroVY) < 0.001)
	assert(math.abs(doubleVY - 32) < 0.01 and math.abs(reverseVY + 16) < 0.01)
	gravityWorld:destroy()
	assert(gravityWorld:isDestroyed() and gravityZero:isDestroyed() and gravityDouble:isDestroyed()
		and gravityReverse:isDestroyed() and gravityFixtureZero:isDestroyed()
		and gravityFixtureDouble:isDestroyed() and gravityFixtureReverse:isDestroyed())

	local destroyWorld = physics.newWorld(0, 0, true)
	local destroyBodyA = physics.newBody(destroyWorld, 0, 0, "dynamic")
	local destroyBodyB = physics.newBody(destroyWorld, 20, 0, "static")
	local destroyFixture = physics.newFixture(destroyBodyA, physics.newCircleShape(4), 1)
	local destroyJoint = physics.newDistanceJoint(destroyBodyA, destroyBodyB, 0, 0, 20, 0, false)
	destroyFixture:destroy()
	destroyJoint:destroy()
	assert(destroyFixture:isDestroyed() and destroyJoint:isDestroyed())
	local cascadedFixture = physics.newFixture(destroyBodyA, physics.newCircleShape(5), 1)
	local cascadedJoint = physics.newDistanceJoint(destroyBodyA, destroyBodyB, 0, 0, 20, 0, false)
	destroyBodyA:destroy()
	assert(destroyBodyA:isDestroyed() and cascadedFixture:isDestroyed() and cascadedJoint:isDestroyed())
	destroyWorld:destroy()
	assert(destroyWorld:isDestroyed() and destroyBodyB:isDestroyed())
	print("LOVE_PHYSICS_MASS_GRAVITY_DESTROY_PASS", massValue, inertiaValue,
		zeroVX, zeroVY, doubleVY, reverseVY)
	assert(apiWorld:isSleepingAllowed())
	apiWorld:setSleepingAllowed(false)
	assert(not apiWorld:isSleepingAllowed() and not apiBody:isSleepingAllowed())
	apiWorld:setSleepingAllowed(true)
	assert(apiWorld:isSleepingAllowed() and apiBody:isSleepingAllowed())
	assert(apiBody:getX() == 100 and apiBody:getY() == 100)
	apiBody:setX(102)
	apiBody:setY(98)
	local transformX, transformY, transformAngle = apiBody:getTransform()
	assert(math.abs(transformX - 102) < 0.01 and math.abs(transformY - 98) < 0.01
		and math.abs(transformAngle) < 0.0001)
	apiBody:setTransform(100, 100, math.pi / 2)
	local worldPointX, worldPointY = apiBody:getWorldPoint(10, 0)
	local worldVectorX, worldVectorY = apiBody:getWorldVector(10, 0)
	local originX, originY = apiBody:getWorldPoint(0, 0)
	local bodyX, bodyY = apiBody:getPosition()
	local rotatedCenterX, rotatedCenterY = apiBody:getWorldCenter()
	assert(math.abs(worldPointX - 100) < 0.01 and math.abs(worldPointY - 110) < 0.01)
	assert(math.abs(worldVectorX) < 0.01 and math.abs(worldVectorY - 10) < 0.01)
	assert(math.abs(originX - 100) < 0.01 and math.abs(originY - 100) < 0.01)
	assert(math.abs(bodyX - 100) < 0.01 and math.abs(bodyY - 100) < 0.01)
	assert(math.abs(rotatedCenterX - 100) < 0.01 and math.abs(rotatedCenterY - 105) < 0.01)
	local worldX1, worldY1, worldX2, worldY2 = apiBody:getWorldPoints(10, 0, 0, 10)
	local localX1, localY1, localX2, localY2 = apiBody:getLocalPoints(worldX1, worldY1, worldX2, worldY2)
	local localVectorX, localVectorY = apiBody:getLocalVector(worldVectorX, worldVectorY)
	assert(math.abs(localX1 - 10) < 0.01 and math.abs(localY1) < 0.01)
	assert(math.abs(localX2) < 0.01 and math.abs(localY2 - 10) < 0.01)
	assert(math.abs(localVectorX - 10) < 0.01 and math.abs(localVectorY) < 0.01)
	apiBody:setLinearVelocity(20, 30)
	apiBody:setAngularVelocity(1)
	local worldVelocityX, worldVelocityY = apiBody:getLinearVelocityFromWorldPoint(100, 110)
	local localVelocityX, localVelocityY = apiBody:getLinearVelocityFromLocalPoint(10, 0)
	assert(math.abs(worldVelocityX - 15) < 0.02 and math.abs(worldVelocityY - 30) < 0.02)
	assert(math.abs(localVelocityX - worldVelocityX) < 0.01 and math.abs(localVelocityY - worldVelocityY) < 0.01)
	print("LOVE_PHYSICS_COORDINATE_PASS", transformX, transformY,
		worldPointX, worldPointY, rotatedCenterX, rotatedCenterY, worldVelocityX, worldVelocityY)
	apiBody:setTransform(100, 100, 0)
	apiBody:setLinearVelocity(0, 0)
	apiBody:setAngularVelocity(0)
	apiBody:setLinearDamping(0)
	apiBody:setAngularDamping(0)
	assert(apiBody:getLinearDamping() == 0 and apiBody:getAngularDamping() == 0)
	apiBody:setFixedRotation(true)
	assert(apiBody:isFixedRotation())
	apiBody:setFixedRotation(false)
	assert(not apiBody:isFixedRotation())
	assert(apiBody:isAwake() and apiBody:isSleepingAllowed() and apiBody:isActive())
	assert(not apiBody:isBullet())
	apiBody:setAwake(false)
	assert(not apiBody:isAwake())
	apiBody:setAwake(true)
	apiBody:setSleepingAllowed(false)
	assert(not apiBody:isSleepingAllowed())
	apiBody:setSleepingAllowed(true)
	apiBody:setActive(false)
	assert(not apiBody:isActive())
	apiBody:setActive(true)
	apiBody:setBullet(true)
	assert(apiBody:isBullet())
	apiBody:setBullet(false)
	apiBody:setType("kinematic")
	assert(apiBody:getType() == "kinematic")
	apiBody:setType("dynamic")
	assert(apiBody:getType() == "dynamic")
	apiBody:setAngularVelocity(0.5)
	apiBody:applyAngularImpulse(100)
	local impulseAngularVelocity = apiBody:getAngularVelocity()
	assert(impulseAngularVelocity > 0.5)
	apiBody:applyForce(1000, 0)
	apiBody:applyTorque(10000)
	apiWorld:update(1 / 60, 8, 3)
	local firstForceVelocity = apiBody:getLinearVelocity()
	local firstTorqueVelocity = apiBody:getAngularVelocity()
	assert(firstForceVelocity > 0 and firstTorqueVelocity > impulseAngularVelocity)
	apiWorld:update(1 / 60, 8, 3)
	local secondForceVelocity = apiBody:getLinearVelocity()
	local secondTorqueVelocity = apiBody:getAngularVelocity()
	assert(math.abs(secondForceVelocity - firstForceVelocity) < 0.001)
	assert(math.abs(secondTorqueVelocity - firstTorqueVelocity) < 0.001)
	print("LOVE_PHYSICS_BODY_API_PASS", apiBody:getMass(), apiBody:getInertia(),
		firstForceVelocity, firstTorqueVelocity)

	local revoluteWorld = physics.newWorld(0, 0, true)
	local revoluteAnchor = physics.newBody(revoluteWorld, 0, 0, "static")
	local revoluteBody = physics.newBody(revoluteWorld, 0, 0, "dynamic")
	local revoluteFixture = physics.newFixture(
		revoluteBody, physics.newRectangleShape(48, 12), 1)
	local revolute = physics.newRevoluteJoint(
		revoluteAnchor, revoluteBody, 0, 0, 0, 0, false, 0.25)
	assert(revolute:getType() == "revolute")
	local revoluteX1, revoluteY1, revoluteX2, revoluteY2 = revolute:getAnchors()
	assert(math.abs(revoluteX1) < 0.01 and math.abs(revoluteY1) < 0.01
		and math.abs(revoluteX2) < 0.01 and math.abs(revoluteY2) < 0.01)
	assert(math.abs(revolute:getReferenceAngle() - 0.25) < 0.001
		and math.abs(revolute:getJointAngle() + 0.25) < 0.001)
	revolute:setMaxMotorTorque(409600)
	revolute:setMotorSpeed(2)
	revolute:setMotorEnabled(true)
	revolute:setLimits(-0.5, 0.5)
	revolute:setLimitsEnabled(true)
	assert(revolute:isMotorEnabled() and revolute:areLimitsEnabled()
		and revolute:hasLimitsEnabled())
	assert(math.abs(revolute:getMaxMotorTorque() - 409600) < 1
		and math.abs(revolute:getMotorSpeed() - 2) < 0.001)
	revolute:setLowerLimit(-0.4)
	revolute:setUpperLimit(0.45)
	local revoluteLower, revoluteUpper = revolute:getLimits()
	assert(math.abs(revoluteLower + 0.4) < 0.001
		and math.abs(revoluteUpper - 0.45) < 0.001)
	for _ = 1, 20 do revoluteWorld:update(1 / 60, 8, 3) end
	local drivenAngle = revolute:getJointAngle()
	local drivenSpeed = revolute:getJointSpeed()
	local drivenTorque = revolute:getMotorTorque(60)
	assert(drivenAngle > -0.24 and drivenAngle <= 0.46)
	assert(type(drivenSpeed) == "number" and type(drivenTorque) == "number")
	local sharedRevolute = physics.newRevoluteJoint(
		revoluteAnchor, revoluteBody, 0, 0, false)
	assert(sharedRevolute:getType() == "revolute")
	sharedRevolute:destroy()
	revoluteWorld:destroy()
	assert(revoluteWorld:isDestroyed() and revoluteAnchor:isDestroyed()
		and revoluteBody:isDestroyed() and revoluteFixture:isDestroyed()
		and revolute:isDestroyed() and sharedRevolute:isDestroyed())
	print("LOVE_PHYSICS_REVOLUTE_JOINT_PASS", drivenAngle, drivenSpeed, drivenTorque,
		revoluteLower, revoluteUpper)

	local prismaticWorld = physics.newWorld(0, 0, true)
	local prismaticAnchor = physics.newBody(prismaticWorld, 0, 0, "static")
	local prismaticBody = physics.newBody(prismaticWorld, 0, 0, "dynamic")
	local prismaticFixture = physics.newFixture(
		prismaticBody, physics.newRectangleShape(24, 16), 1)
	local prismatic = physics.newPrismaticJoint(
		prismaticAnchor, prismaticBody, 0, 0, 0, 0, 2, 0, false, 0.1)
	assert(prismatic:getType() == "prismatic")
	local axisX, axisY = prismatic:getAxis()
	assert(math.abs(axisX - 1) < 0.001 and math.abs(axisY) < 0.001)
	assert(math.abs(prismatic:getJointTranslation()) < 0.001
		and math.abs(prismatic:getReferenceAngle() - 0.1) < 0.001)
	local defaultLower, defaultUpper = prismatic:getLimits()
	assert(defaultLower == 0 and math.abs(defaultUpper - 6400) < 0.01
		and prismatic:areLimitsEnabled())
	prismatic:setMaxMotorForce(64000)
	prismatic:setMotorSpeed(120)
	prismatic:setMotorEnabled(true)
	prismatic:setLimits(-20, 60)
	assert(prismatic:isMotorEnabled() and prismatic:areLimitsEnabled()
		and math.abs(prismatic:getMaxMotorForce() - 64000) < 1
		and math.abs(prismatic:getMotorSpeed() - 120) < 0.001)
	local sharedPrismatic = physics.newPrismaticJoint(
		prismaticAnchor, prismaticBody, 0, 0, 1, 0, true)
	assert(sharedPrismatic:getType() == "prismatic"
		and sharedPrismatic:getCollideConnected())
	sharedPrismatic:destroy()
	for _ = 1, 40 do prismaticWorld:update(1 / 60, 8, 3) end
	local drivenTranslation = prismatic:getJointTranslation()
	local prismaticSpeed = prismatic:getJointSpeed()
	local prismaticForce = prismatic:getMotorForce(60)
	assert(drivenTranslation > 20 and drivenTranslation <= 61)
	assert(type(prismaticSpeed) == "number" and type(prismaticForce) == "number")
	prismatic:setLowerLimit(-10)
	prismatic:setUpperLimit(55)
	local prismaticLower, prismaticUpper = prismatic:getLimits()
	assert(math.abs(prismaticLower + 10) < 0.001
		and math.abs(prismaticUpper - 55) < 0.001)
	prismaticWorld:destroy()
	assert(prismaticWorld:isDestroyed() and prismaticAnchor:isDestroyed()
		and prismaticBody:isDestroyed() and prismaticFixture:isDestroyed()
		and prismatic:isDestroyed() and sharedPrismatic:isDestroyed())
	print("LOVE_PHYSICS_PRISMATIC_JOINT_PASS", drivenTranslation, prismaticSpeed,
		prismaticForce, axisX, axisY, prismaticLower, prismaticUpper)

	local weldWorld = physics.newWorld(0, 0, true)
	local weldAnchor = physics.newBody(weldWorld, 0, 0, "static")
	local weldBody = physics.newBody(weldWorld, 0, 0, "dynamic")
	weldBody:setAngle(0.3)
	local weldFixture = physics.newFixture(
		weldBody, physics.newRectangleShape(32, 12), 1)
	local weld = physics.newWeldJoint(
		weldAnchor, weldBody, 0, 0, 0, 0, false, 0.3)
	assert(weld:getType() == "weld"
		and math.abs(weld:getReferenceAngle() - 0.3) < 0.001
		and weld:getFrequency() == 0 and weld:getDampingRatio() == 0)
	weld:setFrequency(5)
	weld:setDampingRatio(0.6)
	assert(math.abs(weld:getFrequency() - 5) < 0.001
		and math.abs(weld:getDampingRatio() - 0.6) < 0.001)
	weld:setFrequency(0)
	local sharedWeld = physics.newWeldJoint(weldAnchor, weldBody, 0, 0, true)
	assert(sharedWeld:getType() == "weld" and sharedWeld:getCollideConnected())
	sharedWeld:destroy()
	weldBody:setLinearVelocity(100, 50)
	weldBody:setAngularVelocity(3)
	for _ = 1, 60 do weldWorld:update(1 / 60, 8, 3) end
	local weldX, weldY = weldBody:getPosition()
	local weldAngle = weldBody:getAngle()
	local weldForceX, weldForceY = weld:getReactionForce(60)
	local weldTorque = weld:getReactionTorque(60)
	assert(math.abs(weldX) < 0.1 and math.abs(weldY) < 0.1
		and math.abs(weldAngle - 0.3) < 0.01)
	weldWorld:destroy()
	assert(weldWorld:isDestroyed() and weldAnchor:isDestroyed()
		and weldBody:isDestroyed() and weldFixture:isDestroyed()
		and weld:isDestroyed() and sharedWeld:isDestroyed())
	print("LOVE_PHYSICS_WELD_JOINT_PASS", weldX, weldY, weldAngle,
		weldForceX, weldForceY, weldTorque)

	local frictionWorld = physics.newWorld(0, 0, true)
	local frictionAnchor = physics.newBody(frictionWorld, 0, 0, "static")
	local frictionBody = physics.newBody(frictionWorld, 0, 0, "dynamic")
	local frictionFixture = physics.newFixture(
		frictionBody, physics.newRectangleShape(32, 16), 1)
	local friction = physics.newFrictionJoint(
		frictionAnchor, frictionBody, 0, 0, 0, 0, false)
	assert(friction:getType() == "friction"
		and friction:getMaxForce() == 0 and friction:getMaxTorque() == 0)
	friction:setMaxForce(64)
	friction:setMaxTorque(256)
	assert(math.abs(friction:getMaxForce() - 64) < 0.001
		and math.abs(friction:getMaxTorque() - 256) < 0.001)
	local sharedFriction = physics.newFrictionJoint(
		frictionAnchor, frictionBody, 0, 0, true)
	assert(sharedFriction:getType() == "friction"
		and sharedFriction:getCollideConnected())
	sharedFriction:destroy()
	frictionBody:setLinearVelocity(120, 0)
	frictionBody:setAngularVelocity(3)
	frictionWorld:update(1 / 60, 8, 3)
	local reactionX, reactionY = friction:getReactionForce(60)
	local reactionTorque = friction:getReactionTorque(60)
	for _ = 1, 59 do frictionWorld:update(1 / 60, 8, 3) end
	local frictionVelocityX, frictionVelocityY = frictionBody:getLinearVelocity()
	local frictionAngularVelocity = frictionBody:getAngularVelocity()
	assert(math.abs(reactionX) > 0 and math.abs(reactionY) < 0.01
		and math.abs(reactionTorque) > 0)
	assert(math.abs(frictionVelocityX) < 1 and math.abs(frictionVelocityY) < 0.01
		and math.abs(frictionAngularVelocity) < 0.01)
	frictionWorld:destroy()
	assert(frictionWorld:isDestroyed() and frictionAnchor:isDestroyed()
		and frictionBody:isDestroyed() and frictionFixture:isDestroyed()
		and friction:isDestroyed() and sharedFriction:isDestroyed())
	print("LOVE_PHYSICS_FRICTION_JOINT_PASS", reactionX, reactionY, reactionTorque,
		frictionVelocityX, frictionVelocityY, frictionAngularVelocity)

	assert(not pcall(friction.getMaxLength, friction))
	verifyRopeJoint()
	verifyPulleyJoint()
	verifyWheelJoint()
	verifyMouseJoint()
	verifyMotorJoint()
	verifyGearJoint()
	verifyConnectedEdgeContinuousContact()
	verifyFixtureGroupFiltering()

	local function isBallGround(first, second)
		return (first == ballFixture and second == groundFixture)
			or (first == groundFixture and second == ballFixture)
	end
	local function beginContact(first, second, contact)
		if (first == probeFixture and second == chainFixture)
			or (first == chainFixture and second == probeFixture) then
			local childA, childB = contact:getChildren()
			local chainChild = first == chainFixture and childA or childB
			assert(chainChild >= 1 and chainChild <= 2)
			chainChildSeen = true
			return
		end
		if not isBallGround(first, second) then return end
		if not deferredDestroyRequested then
			deferredBody:destroy()
			deferredDestroyRequested = true
		end
		contactBegins = contactBegins + 1
		assert(not contact:isDestroyed() and contact:isTouching())
		local contactFixtureA, contactFixtureB = contact:getFixtures()
		assert(contactFixtureA == first and contactFixtureB == second)
		local childA, childB = contact:getChildren()
		assert(childA == 1 and childB == 1)
		local x, y = contact:getPositions()
		assert(type(x) == "number" and type(y) == "number")
		local nx, ny = contact:getNormal()
		assert(math.abs(math.sqrt(nx * nx + ny * ny) - 1) < 0.01)
		savedContact = contact
	end
	local function endContact(first, second, contact)
		if not isBallGround(first, second) then return end
		contactEnds = contactEnds + 1
		assert(contact == savedContact and not contact:isDestroyed())
	end
	local function preSolve(first, second, contact)
		if not isBallGround(first, second) then return end
		contactPres = contactPres + 1
		assert(contact == savedContact)
		if contactPres == 1 then
			contact:setFriction(0.65)
			contact:setRestitution(0.15)
			contact:setTangentSpeed(12)
			assert(math.abs(contact:getFriction() - 0.65) < 0.001)
			assert(math.abs(contact:getRestitution() - 0.15) < 0.001)
			assert(math.abs(contact:getTangentSpeed() - 12) < 0.001)
			contact:setTangentSpeed(0)
			contact:setEnabled(false)
			assert(not contact:isEnabled())
			contact:setEnabled(true)
		end
	end
	local function postSolve(first, second, contact, ...)
		if not isBallGround(first, second) then return end
		contactPosts = contactPosts + 1
		assert(contact == savedContact and select("#", ...) >= 2)
	end
	world:setCallbacks(beginContact, endContact, preSolve, postSolve)
	local beginValue, endValue, preValue, postValue = world:getCallbacks()
	assert(beginValue == beginContact and endValue == endContact
		and preValue == preSolve and postValue == postSolve)

	anchor = physics.newBody(world, 420, 70, "static")
	pendulum = physics.newBody(world, 500, 70, "dynamic")
	local pendulumShape = physics.newCircleShape(11)
	physics.newFixture(pendulum, pendulumShape, 1)
	joint = physics.newDistanceJoint(anchor, pendulum, 420, 70, 500, 70, false)
	assert(joint:getType() == "distance")
	local first, second = joint:getBodies()
	assert(first == anchor and second == pendulum)
	local jointX1, jointY1, jointX2, jointY2 = joint:getAnchors()
	assert(math.abs(jointX1 - 420) < 0.01 and math.abs(jointY1 - 70) < 0.01
		and math.abs(jointX2 - 500) < 0.01 and math.abs(jointY2 - 70) < 0.01)
	assert(not joint:getCollideConnected() and math.abs(joint:getLength() - 80) < 0.01)
	joint:setLength(90)
	joint:setFrequency(3)
	joint:setDampingRatio(0.4)
	assert(math.abs(joint:getLength() - 90) < 0.01 and math.abs(joint:getFrequency() - 3) < 0.001
		and math.abs(joint:getDampingRatio() - 0.4) < 0.001)
	joint:setLength(80)
	joint:setFrequency(0)
	joint:setDampingRatio(0)
	local jointData = {kind = "distance"}
	joint:setUserData(jointData)
	assert(joint:getUserData() == jointData)
	local reactionX, reactionY = joint:getReactionForce(60)
	assert(reactionX == 0 and reactionY == 0 and joint:getReactionTorque(60) == 0)
	assert(not pcall(joint.setLength, joint, -1)
		and not pcall(joint.getReactionForce, joint, 0 / 0))
	print("LOVE_PHYSICS_DISTANCE_JOINT_PASS", jointX1, jointY1, jointX2, jointY2,
		joint:getLength(), joint:getFrequency(), joint:getDampingRatio())
	deferredBody = physics.newBody(world, -2000, -2000, "dynamic")
	deferredFixture = physics.newFixture(deferredBody, physics.newCircleShape(6), 1)
	local deferredAnchor = physics.newBody(world, -1980, -2000, "static")
	deferredJoint = physics.newDistanceJoint(
		deferredBody, deferredAnchor, -2000, -2000, -1980, -2000, false)
	print("LOVE_PHYSICS_STATE_PASS", physics.getMeter(), ball:getType(), circle:getType(), joint:getType())
end

function love.update(dt)
	if captured then
		if separationFrames == 0 then
			assert(chainChildSeen)
			print("LOVE_PHYSICS_SHAPES_PASS")
			ball:setPosition(150, 150)
			ball:setLinearVelocity(0, 0)
		end
		world:update(dt, 8, 3)
		verifyDeferredDestroy()
		separationFrames = separationFrames + 1
		if contactEnds > 0 then
			assert(contactBegins >= 1 and contactEnds >= 1 and contactPres > 0 and contactPosts > 0)
			assert(savedContact and savedContact:isDestroyed())
			assert(not pcall(function() savedContact:getNormal() end))
			print("LOVE_PHYSICS_CONTACT_PASS", contactBegins, contactEnds, contactPres, contactPosts)
			finished = true
			print("LOVE_PHYSICS_QUIT_PASS")
			love.event.quit()
		elseif separationFrames > 10 then
			error("ball-ground endContact did not arrive after separation")
		end
		return
	end
	world:update(dt, 8, 3)
	verifyDeferredDestroy()
	elapsed = elapsed + dt
	if elapsed >= 2.5 and not requested then
		local bx, by = ball:getPosition()
		local ax, ay = anchor:getPosition()
		local px, py = pendulum:getPosition()
		local distance = math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
		assert(bx > 145 and bx < 155 and by > 265 and by < 292, "ball did not settle on the ground")
		assert(math.abs(distance - 80) < 2.0, "distance joint did not preserve its length")
		local queried = {}
		world:queryBoundingBox(132, 252, 168, 282, function(fixture)
			queried[#queried + 1] = fixture
			return true
		end)
		assert(#queried == 2 and ((queried[1] == ballFixture and queried[2] == groundFixture)
			or (queried[1] == groundFixture and queried[2] == ballFixture)),
			"queryBoundingBox did not return the ball and nearby ground Fixture AABBs")
		local rayHits = {}
		world:rayCast(150, 200, 150, 330, function(fixture, x, y, normalX, normalY, fraction)
			rayHits[#rayHits + 1] = {fixture, x, y, normalX, normalY, fraction}
			return -1
		end)
		assert(#rayHits >= 2 and rayHits[1][1] == ballFixture and rayHits[2][1] == groundFixture,
			"rayCast did not return the ball and ground in fraction order")
		local clipped = 0
		world:rayCast(150, 200, 150, 330, function(_, _, _, _, _, fraction)
			clipped = clipped + 1
			return fraction
		end)
		assert(clipped == 1, "rayCast fraction clipping did not exclude farther hits")
		print("LOVE_PHYSICS_QUERY_PASS", #queried, #rayHits, rayHits[1][6], rayHits[2][6])
		print("LOVE_PHYSICS_SIM_PASS", bx, by, px, py, distance)
		requested = true
		graphics.captureScreenshot("physics.png")
		graphics.captureScreenshot(function(image)
			local green, yellow = 0, 0
			for y = 0, image:getHeight() - 1 do
				for x = 0, image:getWidth() - 1 do
					local r, g, b, a = image:getPixel(x, y)
					if a > 0.5 and g > 0.55 and g > r * 1.25 and g > b * 1.25 then green = green + 1 end
					if a > 0.5 and r > 0.65 and g > 0.55 and b < 0.35 then yellow = yellow + 1 end
				end
			end
			assert(green > 250 and yellow > 100, "physics screenshot did not contain both bodies")
			print("LOVE_PHYSICS_PIXEL_PASS", green, yellow)
			captured = true
		end)
	end
end

function love.draw()
	if finished then return end
	graphics.clear(0.025, 0.03, 0.045, 1)
	graphics.setColor(0.18, 0.75, 0.35, 1)
	graphics.rectangle("fill", 40, 285, 560, 30)
	local bx, by = ball:getPosition()
	graphics.setColor(0.2, 0.85, 0.95, 1)
	graphics.circle("fill", bx, by, 14)
	local ax, ay = anchor:getPosition()
	local px, py = pendulum:getPosition()
	graphics.setColor(0.7, 0.75, 0.85, 1)
	graphics.setLineWidth(3)
	graphics.line(ax, ay, px, py)
	graphics.setColor(1, 0.78, 0.12, 1)
	graphics.circle("fill", px, py, 11)
	graphics.setColor(0.9, 0.25, 0.3, 1)
	graphics.circle("fill", ax, ay, 6)
end
