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
function ____exports.makeBody3D(world, node, fixture, ____type) -- 12
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
		error( -- 26
			__TS__New(Error, "failed to attach FixtureDef3D"), -- 26
			0 -- 26
		) -- 26
	end -- 26
	local body = Body3D(def, world, position, angles) -- 27
	body:addChild(node) -- 28
	if parent ~= nil then -- 28
		parent:addChild(body) -- 29
	end -- 29
	return body -- 30
end -- 12
function ____exports.makeBoxBody3D(world, node, halfExtent, ____type) -- 33
	if ____type == nil then -- 33
		____type = 2 -- 33
	end -- 33
	return ____exports.makeBody3D( -- 34
		world, -- 34
		node, -- 34
		FixtureDef3D:box(halfExtent), -- 34
		____type -- 34
	) -- 34
end -- 33
function ____exports.makeSphereBody3D(world, node, radius, ____type) -- 37
	if ____type == nil then -- 37
		____type = 2 -- 37
	end -- 37
	return ____exports.makeBody3D( -- 38
		world, -- 38
		node, -- 38
		FixtureDef3D:sphere(radius), -- 38
		____type -- 38
	) -- 38
end -- 37
function ____exports.makeCapsuleBody3D(world, node, halfHeight, radius, ____type) -- 41
	if ____type == nil then -- 41
		____type = 2 -- 46
	end -- 46
	return ____exports.makeBody3D( -- 48
		world, -- 48
		node, -- 48
		FixtureDef3D:capsule(halfHeight, radius), -- 48
		____type -- 48
	) -- 48
end -- 41
return ____exports -- 41