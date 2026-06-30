-- [yue]: Example/Entity Move.yue
local _ENV = Dora -- 2
local sceneGroup = Group({ -- 4
	"scene" -- 4
}) -- 4
local positionGroup = Group({ -- 5
	"position" -- 5
}) -- 5
do -- 7
	local _with_0 = Observer("Add", { -- 7
		"scene" -- 7
	}) -- 7
	_with_0:watch(function(self, scene) -- 8
		scene:onTapEnded(function(touch) -- 9
			local location = touch.location -- 10
			return positionGroup:each(function(entity) -- 11
				entity.target = location -- 12
			end) -- 11
		end) -- 9
		return false -- 8
	end) -- 8
end -- 7
do -- 14
	local _with_0 = Observer("Add", { -- 14
		"image" -- 14
	}) -- 14
	_with_0:watch(function(self, image) -- 15
		sceneGroup:each(function(e) -- 15
			do -- 16
				local _with_1 = Sprite(image) -- 16
				self.sprite = _with_1 -- 16
				_with_1:addTo(e.scene) -- 17
				_with_1:runAction(Scale(0.5, 0, 0.5, Ease.OutBack)) -- 18
			end -- 16
			return true -- 19
		end) -- 15
		return false -- 15
	end) -- 15
end -- 14
do -- 21
	local _with_0 = Observer("Remove", { -- 21
		"sprite" -- 21
	}) -- 21
	_with_0:watch(function(self) -- 22
		return self.oldValues.sprite:removeFromParent() -- 22
	end) -- 22
end -- 21
do -- 24
	local _with_0 = Observer("Remove", { -- 24
		"target" -- 24
	}) -- 24
	_with_0:watch(function(self) -- 25
		return print("remove target from entity " .. tostring(self.index)) -- 25
	end) -- 25
end -- 24
do -- 27
	local _with_0 = Group({ -- 27
		"position", -- 27
		"direction", -- 27
		"speed", -- 27
		"target" -- 27
	}) -- 27
	_with_0:watch(function(self, position, direction, speed, target) -- 28
		if target == position then -- 29
			return -- 29
		end -- 29
		local dir = target - position -- 30
		dir = dir:normalize() -- 31
		local angle = math.deg(math.atan(dir.x, dir.y)) -- 32
		local newPos = position + dir * speed -- 33
		newPos = newPos:clamp(position, target) -- 34
		self.position = newPos -- 35
		self.direction = angle -- 36
		if newPos == target then -- 37
			self.target = nil -- 37
		end -- 37
		return false -- 28
	end) -- 28
end -- 27
do -- 39
	local _with_0 = Observer("AddOrChange", { -- 39
		"position", -- 39
		"direction", -- 39
		"sprite" -- 39
	}) -- 39
	_with_0:watch(function(self, position, direction, sprite) -- 40
		sprite.position = position -- 41
		local lastDirection = self.oldValues.direction or sprite.angle -- 42
		if math.abs(direction - lastDirection) > 1 then -- 43
			sprite:runAction(Roll(0.3, lastDirection, direction)) -- 44
		end -- 43
		return false -- 40
	end) -- 40
end -- 39
Entity({ -- 47
	scene = Node() -- 47
}) -- 46
Entity({ -- 50
	image = "Image/logo.png", -- 50
	position = Vec2.zero, -- 51
	direction = 45.0, -- 52
	speed = 4.0 -- 53
}) -- 49
Entity({ -- 56
	image = "Image/logo.png", -- 56
	position = Vec2(-100, 200), -- 57
	direction = 90.0, -- 58
	speed = 10.0 -- 59
}) -- 55
local windowFlags = { -- 64
	"NoDecoration", -- 64
	"AlwaysAutoResize", -- 64
	"NoSavedSettings", -- 64
	"NoFocusOnAppearing", -- 64
	"NoMove" -- 64
} -- 64
return threadLoop(function() -- 71
	local width -- 72
	width = App.visualSize.width -- 72
	ImGui.SetNextWindowBgAlpha(0.35) -- 73
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 74
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 75
	return ImGui.Begin("ECS System", windowFlags, function() -- 76
		ImGui.Text("ECS System (YueScript)") -- 77
		ImGui.Separator() -- 78
		ImGui.TextWrapped("Tap any place to move entities.") -- 79
		if ImGui.Button("Create Random Entity") then -- 80
			Entity({ -- 82
				image = "Image/logo.png", -- 82
				position = Vec2(6 * math.random(1, 100), 6 * math.random(1, 100)), -- 83
				direction = 1.0 * math.random(0, 360), -- 84
				speed = 1.0 * math.random(1, 20) -- 85
			}) -- 81
		end -- 80
		if ImGui.Button("Destroy An Entity") then -- 86
			return Group({ -- 87
				"sprite", -- 87
				"position" -- 87
			}):each(function(entity) -- 87
				entity.position = nil -- 88
				do -- 89
					local _with_0 = entity.sprite -- 89
					_with_0:runAction(Sequence(Scale(0.5, 0.5, 0, Ease.InBack), Event("Destroy"))) -- 90
					_with_0:slot("Destroy", function() -- 91
						return entity:destroy() -- 91
					end) -- 91
				end -- 89
				return true -- 92
			end) -- 87
		end -- 86
	end) -- 76
end) -- 71
