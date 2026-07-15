-- [ts]: PhysicsBody3D.ts
local ____lualib = require("lualib_bundle") -- 1
local Error = ____lualib.Error -- 1
local RangeError = ____lualib.RangeError -- 1
local ReferenceError = ____lualib.ReferenceError -- 1
local SyntaxError = ____lualib.SyntaxError -- 1
local TypeError = ____lualib.TypeError -- 1
local URIError = ____lualib.URIError -- 1
local __TS__New = ____lualib.__TS__New -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Body3D = ____Dora.Body3D -- 2
local BodyDef3D = ____Dora.BodyDef3D -- 4
local FixtureDef3D = ____Dora.FixtureDef3D -- 5
local Vec3 = ____Dora.Vec3 -- 9
local function tryMakeBody3D(world, node, fixture, ____type) -- 12
	if ____type == nil then -- 12
		____type = 2 -- 16
	end -- 16
	local parent = node.parent -- 18
	local position = node.position -- 19
	local angles = node.angles -- 20
	node:removeFromParent(false) -- 21
	node.position = Vec3(0, 0, 0) -- 22
	node.angles = Vec3(0, 0, 0) -- 23
	local def = BodyDef3D() -- 24
	def.type = ____type -- 25
	if not def:attach(fixture) then -- 25
		node.position = position -- 27
		node.angles = angles -- 28
		if parent ~= nil then -- 28
			parent:addChild(node) -- 29
		end -- 29
		return nil -- 30
	end -- 30
	local body = Body3D(def, world, position, angles) -- 32
	if not body then -- 32
		node.position = position -- 34
		node.angles = angles -- 35
		if parent ~= nil then -- 35
			parent:addChild(node) -- 36
		end -- 36
		return nil -- 37
	end -- 37
	body:addChild(node) -- 39
	if parent ~= nil then -- 39
		parent:addChild(body) -- 40
	end -- 40
	return body -- 41
end -- 12
function ____exports.makeBody3D(world, node, fixture, ____type) -- 44
	if ____type == nil then -- 44
		____type = 2 -- 48
	end -- 48
	local body = tryMakeBody3D(world, node, fixture, ____type) -- 50
	if not body then -- 50
		error( -- 51
			__TS__New(Error, "failed to create Body3D"), -- 51
			0 -- 51
		) -- 51
	end -- 51
	return body -- 52
end -- 44
function ____exports.makeBoxBody3D(world, node, halfExtent, ____type) -- 55
	if ____type == nil then -- 55
		____type = 2 -- 55
	end -- 55
	return ____exports.makeBody3D( -- 56
		world, -- 56
		node, -- 56
		FixtureDef3D:box(halfExtent), -- 56
		____type -- 56
	) -- 56
end -- 55
function ____exports.makeSphereBody3D(world, node, radius, ____type) -- 59
	if ____type == nil then -- 59
		____type = 2 -- 59
	end -- 59
	return ____exports.makeBody3D( -- 60
		world, -- 60
		node, -- 60
		FixtureDef3D:sphere(radius), -- 60
		____type -- 60
	) -- 60
end -- 59
function ____exports.makeCapsuleBody3D(world, node, halfHeight, radius, ____type) -- 63
	if ____type == nil then -- 63
		____type = 2 -- 68
	end -- 68
	return ____exports.makeBody3D( -- 70
		world, -- 70
		node, -- 70
		FixtureDef3D:capsule(halfHeight, radius), -- 70
		____type -- 70
	) -- 70
end -- 63
return ____exports -- 63