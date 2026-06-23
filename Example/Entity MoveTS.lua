-- [ts]: Entity MoveTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Ease = ____Dora.Ease -- 4
local Entity = ____Dora.Entity -- 4
local Event = ____Dora.Event -- 4
local Group = ____Dora.Group -- 4
local Node = ____Dora.Node -- 4
local Observer = ____Dora.Observer -- 4
local Roll = ____Dora.Roll -- 4
local Scale = ____Dora.Scale -- 4
local Sequence = ____Dora.Sequence -- 4
local Sprite = ____Dora.Sprite -- 4
local Vec2 = ____Dora.Vec2 -- 4
local tolua = ____Dora.tolua -- 4
local sceneGroup = Group({"scene"}) -- 6
local positionGroup = Group({"position"}) -- 7
Observer("Add", {"scene"}):watch(function(_entity, scene) -- 9
	scene:onTapEnded(function(touch) -- 10
		local ____touch_0 = touch -- 11
		local location = ____touch_0.location -- 11
		positionGroup:each(function(entity) -- 12
			entity.target = location -- 13
			return false -- 14
		end) -- 12
	end) -- 10
	return false -- 17
end) -- 9
Observer("Add", {"image"}):watch(function(entity, image) -- 20
	sceneGroup:each(function(e) -- 21
		local scene = tolua.cast(e.scene, "Node") -- 22
		if scene then -- 22
			local sprite = Sprite(image) -- 24
			if sprite then -- 24
				sprite:addTo(scene) -- 26
				sprite:runAction(Scale(0.5, 0, 0.5, Ease.OutBack)) -- 27
				entity.sprite = sprite -- 28
			end -- 28
			return true -- 30
		end -- 30
		return false -- 32
	end) -- 21
	return false -- 34
end) -- 20
Observer("Remove", {"sprite"}):watch(function(entity) -- 37
	local sprite = tolua.cast(entity.oldValues.sprite, "Sprite") -- 38
	if sprite ~= nil then -- 38
		sprite:removeFromParent() -- 39
	end -- 39
	return false -- 40
end) -- 37
Observer("Remove", {"target"}):watch(function(entity) -- 43
	print("remove target from entity " .. tostring(entity.index)) -- 44
	return false -- 45
end) -- 43
Group({"position", "direction", "speed", "target"}):watch(function(entity, position, _direction, speed, target) -- 48
	if target:equals(position) then -- 48
		return false -- 50
	end -- 50
	local dir = target:sub(position):normalize() -- 51
	local angle = math.deg(math.atan(dir.x, dir.y)) -- 52
	local newPos = position:add(dir:mul(speed)) -- 53
	entity.position = newPos:clamp(position, target) -- 54
	entity.direction = angle -- 55
	if newPos:equals(target) then -- 55
		entity.target = nil -- 57
	end -- 57
	return false -- 59
end) -- 49
Observer("AddOrChange", {"position", "direction", "sprite"}):watch(function(entity, position, direction, sprite) -- 62
	sprite.position = position -- 64
	local ____entity_oldValues_direction_3 = entity.oldValues.direction -- 65
	if ____entity_oldValues_direction_3 == nil then -- 65
		____entity_oldValues_direction_3 = sprite.angle -- 65
	end -- 65
	local lastDirection = ____entity_oldValues_direction_3 -- 65
	if type(lastDirection) == "number" then -- 65
		if math.abs(direction - lastDirection) > 1 then -- 65
			sprite:runAction(Roll(0.3, lastDirection, direction)) -- 68
		end -- 68
	end -- 68
	return false -- 71
end) -- 63
Entity({scene = Node()}) -- 74
Entity({image = "Image/logo.png", position = Vec2.zero, direction = 45, speed = 4}) -- 83
Entity({ -- 90
	image = "Image/logo.png", -- 91
	position = Vec2(-100, 200), -- 92
	direction = 90, -- 93
	speed = 10 -- 94
}) -- 94
local windowFlags = { -- 97
	"NoDecoration", -- 98
	"AlwaysAutoResize", -- 99
	"NoSavedSettings", -- 100
	"NoFocusOnAppearing", -- 101
	"NoMove" -- 102
} -- 102
Observer("Add", {"scene"}):watch(function(entity) -- 104
	local scene = tolua.cast(entity.scene, "Node") -- 105
	if scene then -- 105
		scene:schedule(function() -- 107
			local ____App_visualSize_4 = App.visualSize -- 108
			local width = ____App_visualSize_4.width -- 108
			ImGui.SetNextWindowBgAlpha(0.35) -- 109
			ImGui.SetNextWindowPos( -- 110
				Vec2(width - 10, 10), -- 110
				"Always", -- 110
				Vec2(1, 0) -- 110
			) -- 110
			ImGui.SetNextWindowSize( -- 111
				Vec2(240, 0), -- 111
				"FirstUseEver" -- 111
			) -- 111
			ImGui.Begin( -- 112
				"ECS System", -- 112
				windowFlags, -- 112
				function() -- 112
					ImGui.Text("ECS System (Typescript)") -- 113
					ImGui.Separator() -- 114
					ImGui.TextWrapped("Tap any place to move entities.") -- 115
					if ImGui.Button("Create Random Entity") then -- 115
						Entity({ -- 117
							image = "Image/logo.png", -- 118
							position = Vec2( -- 119
								6 * math.random(1, 100), -- 119
								6 * math.random(1, 100) -- 119
							), -- 119
							direction = 1 * math.random(0, 360), -- 120
							speed = 1 * math.random(1, 20) -- 121
						}) -- 121
					end -- 121
					if ImGui.Button("Destroy An Entity") then -- 121
						Group({"sprite", "position"}):each(function(e) -- 125
							e.position = nil -- 126
							local sprite = tolua.cast(e.sprite, "Sprite") -- 127
							if sprite then -- 127
								sprite:runAction(Sequence( -- 129
									Scale(0.5, 0.5, 0, Ease.InBack), -- 131
									Event("Destroy") -- 132
								)) -- 132
								sprite:slot( -- 135
									"Destroy", -- 135
									function() -- 135
										e:destroy() -- 136
									end -- 135
								) -- 135
							end -- 135
							return true -- 139
						end) -- 125
					end -- 125
				end -- 112
			) -- 112
			return false -- 143
		end) -- 107
	end -- 107
	return false -- 146
end) -- 104
return ____exports -- 104