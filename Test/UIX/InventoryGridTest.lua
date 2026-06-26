-- [tsx]: InventoryGridTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local Vec2 = ____Dora.Vec2 -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local InventoryGrid = ____UIX.InventoryGrid -- 4
local resultFile = Path(Content.writablePath, "UIXInventoryGridTest.result") -- 7
Content:save(resultFile, "running") -- 8
local function fail(message) -- 10
	Content:save(resultFile, "failed: " .. message) -- 11
	error("[UIXInventoryGridTest] " .. message) -- 12
end -- 10
local function expect(condition, message) -- 15
	if not condition then -- 15
		fail(message) -- 16
	end -- 16
end -- 15
local host = DNode() -- 19
Director.ui:addChild(host) -- 20
local root = createRoot(host) -- 21
local selected = signal("sword") -- 22
local items = signal({{id = "sword", icon = "warning", quality = "rare"}, {id = "potion", icon = "heart", quality = "common", count = 3}, {id = "gem", icon = "mana", quality = "epic", count = 2}}) -- 23
local gridRef = reference() -- 28
root:render(function() return React.createElement( -- 30
	"align-node", -- 30
	{windowRoot = true, style = {padding = 8}}, -- 30
	React.createElement( -- 30
		InventoryGrid, -- 32
		{ -- 32
			ref = gridRef, -- 32
			items = items.value, -- 32
			columns = 3, -- 32
			rows = 2, -- 32
			slotSize = 42, -- 32
			gap = 6, -- 32
			selectedId = selected.value, -- 32
			onSelect = function(id) -- 32
				local ____id_0 = id -- 40
				selected.value = ____id_0 -- 40
				return ____id_0 -- 40
			end -- 40
		} -- 40
	) -- 40
) end) -- 40
Director.systemScheduler:schedule(once(function() -- 45
	expect(gridRef.current ~= nil, "grid did not mount") -- 46
	expect(gridRef.current.children ~= nil and gridRef.current.children.count == 2, "grid did not render two rows") -- 47
	local firstRow = gridRef.current.children:get(1) -- 48
	expect(firstRow.children ~= nil and firstRow.children.count == 3, "grid first row did not render three slots") -- 49
	local potionSlot = firstRow.children:get(2) -- 50
	potionSlot:emit("TapBegan") -- 51
	potionSlot:emit( -- 52
		"TapMoved", -- 52
		{delta = Vec2(0, 12)} -- 52
	) -- 52
	potionSlot:emit("Tapped") -- 53
	expect(selected.value == "sword", "dragged slot should not select item") -- 54
	potionSlot:emit("TapBegan") -- 55
	potionSlot:emit("Tapped") -- 56
	expect(selected.value == "potion", "slot tap did not select item") -- 57
	items.value = {{id = "potion", icon = "heart", quality = "common", count = 4}, {id = "gem", icon = "mana", quality = "epic", count = 2}, {id = "coin", icon = "coin", quality = "legendary", count = 9}} -- 58
	Director.systemScheduler:schedule(once(function() -- 63
		expect(selected.value == "potion", "selected id should survive item reorder") -- 64
		expect(gridRef.current.children ~= nil and gridRef.current.children.count == 2, "grid row count changed after reorder") -- 65
		Content:save(resultFile, "passed") -- 66
		Log("Info", "[UIXInventoryGridTest] passed") -- 67
		host:removeFromParent(true) -- 68
		root:unmount() -- 69
	end)) -- 63
end)) -- 45
return ____exports -- 45