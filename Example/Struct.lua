-- [yue]: Example/Struct.yue
local Struct = require("Utils").Struct -- 2
local print <const> = print -- 3
local tostring <const> = tostring -- 3
local Unit = Struct.My.Name.Space.Unit("name", "group", "tag", "actions") -- 6
local Action = Struct.Action("name", "id") -- 7
local Array = Struct.Array() -- 8
local unit = Unit({ -- 12
	name = "abc", -- 12
	group = 123, -- 13
	tag = "tagX", -- 14
	actions = Array({ -- 16
		Action({ -- 16
			name = "walk", -- 16
			id = "a1" -- 16
		}), -- 16
		Action({ -- 17
			name = "run", -- 17
			id = "a2" -- 17
		}), -- 17
		Action({ -- 18
			name = "sleep", -- 18
			id = "a3" -- 18
		}) -- 18
	}) -- 15
}) -- 11
unit.__modified = function(key, value) -- 21
	return print("Value of name \"" .. tostring(key) .. "\" changed to " .. tostring(value) .. ".") -- 21
end -- 21
unit.__updated = function() -- 22
	return print("Values updated.") -- 22
end -- 22
do -- 25
	local _with_0 = unit.actions -- 25
	_with_0.__added = function(index, item) -- 26
		return print("Add item " .. tostring(item) .. " at index " .. tostring(index) .. ".") -- 26
	end -- 26
	_with_0.__removed = function(index, item) -- 27
		return print("Remove item " .. tostring(item) .. " at index " .. tostring(index) .. ".") -- 27
	end -- 27
	_with_0.__changed = function(index, item) -- 28
		return print("Change item to " .. tostring(item) .. " at index " .. tostring(index) .. ".") -- 28
	end -- 28
	_with_0.__updated = function() -- 29
		return print("Items updated.") -- 29
	end -- 29
end -- 25
unit.name = "pig" -- 31
unit.actions:insert(Action({ -- 32
	name = "idle", -- 32
	id = "a4" -- 32
})) -- 32
unit.actions:removeAt(1) -- 33
local structStr = tostring(unit) -- 35
print(structStr) -- 36
local loadedUnit = Struct:load(structStr) -- 38
for i = 1, loadedUnit.actions:count() do -- 39
	print(loadedUnit.actions:get(i)) -- 40
end -- 39
print(Struct) -- 42
return Struct:clear() -- 45
