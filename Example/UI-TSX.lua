-- [tsx]: UI-TSX.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local createRoot = ____DoraX.createRoot -- 2
local reference = ____DoraX.reference -- 2
local signal = ____DoraX.signal -- 2
local toAction = ____DoraX.toAction -- 2
local toNode = ____DoraX.toNode -- 2
local ____Dora = require("Dora") -- 3
local Director = ____Dora.Director -- 3
local Ease = ____Dora.Ease -- 3
local Size = ____Dora.Size -- 3
local sleep = ____Dora.sleep -- 3
local thread = ____Dora.thread -- 3
local Vec2 = ____Dora.Vec2 -- 3
local once = ____Dora.once -- 3
local LineRectCreate = require("UI.View.Shape.LineRect") -- 6
local ButtonCreate = require("UI.Control.Basic.Button") -- 7
local ScrollAreaCreate = require("UI.Control.Basic.ScrollArea") -- 9
local function Button(props) -- 24
	return React.createElement( -- 25
		"custom-node", -- 25
		{ -- 25
			key = props.key, -- 25
			onMount = props.onMount, -- 25
			onCreate = props.onCreate or (function() -- 25
				local btn = ButtonCreate({text = props.text, width = props.width, height = props.height}) -- 26
				btn:onTapped(function() -- 31
					props.onClick() -- 32
				end) -- 31
				if props.ref then -- 31
					props.ref.current = btn -- 35
				end -- 35
				return btn -- 37
			end), -- 25
			children = props.children -- 25
		} -- 25
	) -- 25
end -- 24
local function ScrollArea(props) -- 57
	return React.createElement( -- 58
		"custom-node", -- 58
		{onCreate = function() -- 58
			local ____props_0 = props -- 59
			local width = ____props_0.width -- 59
			local height = ____props_0.height -- 59
			local scrollArea = ScrollAreaCreate(props) -- 60
			if props.ref then -- 60
				props.ref.current = scrollArea -- 62
			end -- 62
			if props.children then -- 62
				for ____, child in ipairs(props.children) do -- 65
					local ____opt_1 = toNode(child) -- 65
					if ____opt_1 ~= nil then -- 65
						____opt_1:addTo(scrollArea.view) -- 66
					end -- 66
				end -- 66
				scrollArea:adjustSizeWithAlign( -- 68
					"Auto", -- 68
					10, -- 68
					Size(width, height) -- 68
				) -- 68
			end -- 68
			return scrollArea -- 70
		end} -- 58
	) -- 58
end -- 57
local scrollArea = reference() -- 83
local items = signal({}) -- 84
local listRoot -- 85
local function adjustScrollArea() -- 87
	local current = scrollArea.current -- 87
	if not current then -- 87
		return -- 89
	end -- 89
	current:adjustSizeWithAlign("Auto") -- 90
end -- 87
local function scheduleAdjustScrollArea() -- 93
	Director.scheduler:schedule(once(function() -- 94
		sleep() -- 95
		adjustScrollArea() -- 96
	end)) -- 94
end -- 93
local function setItems(nextItems) -- 100
	items.value = nextItems -- 101
	scheduleAdjustScrollArea() -- 102
end -- 100
local function removeItem(target) -- 105
	local nextItems = {} -- 106
	for ____, item in ipairs(items.value) do -- 107
		if item ~= target then -- 107
			nextItems[#nextItems + 1] = item -- 109
		end -- 109
	end -- 109
	setItems(nextItems) -- 112
end -- 105
local function appendItem(item) -- 115
	local nextItems = {} -- 116
	for ____, current in ipairs(items.value) do -- 117
		nextItems[#nextItems + 1] = current -- 118
	end -- 118
	nextItems[#nextItems + 1] = item -- 120
	setItems(nextItems) -- 121
end -- 115
local function createItem(id) -- 124
	local item = {} -- 125
	item.id = id -- 126
	item.name = "btn " .. tostring(id) -- 127
	item.value = id -- 128
	item.remove = function() -- 129
		thread(function() -- 130
			sleep(0.5) -- 131
			removeItem(item) -- 132
		end) -- 130
	end -- 129
	item.createButton = function() -- 135
		local btn = ButtonCreate({text = item.name, width = 50, height = 50}) -- 136
		btn:onTapped(item.remove) -- 141
		return btn -- 142
	end -- 135
	item.mountButton = function(node) -- 144
		local btn = node -- 145
		btn:once(function() -- 146
			btn.face:perform(toAction(React.createElement("scale", {time = 0.3, start = 0, stop = 1, easing = Ease.OutBack}))) -- 147
			sleep() -- 150
			adjustScrollArea() -- 151
		end) -- 146
	end -- 144
	return item -- 154
end -- 124
local function renderItems() -- 157
	return __TS__ArrayMap( -- 158
		items.value, -- 158
		function(____, item) return React.createElement(Button, { -- 158
			key = item.id, -- 158
			text = item.name, -- 158
			width = 50, -- 158
			height = 50, -- 158
			onClick = item.remove, -- 158
			onCreate = item.createButton, -- 158
			onMount = item.mountButton -- 158
		}) end -- 158
	) -- 158
end -- 157
local function mountItemRoot() -- 171
	local current = scrollArea.current -- 171
	if not current or listRoot then -- 171
		return -- 173
	end -- 173
	listRoot = createRoot(current.view) -- 174
	listRoot:render(renderItems) -- 175
	adjustScrollArea() -- 176
end -- 171
local function updateScrollLayout(width, height) -- 179
	local current = scrollArea.current -- 179
	if not current then -- 179
		return -- 181
	end -- 181
	current.position = Vec2(width / 2, height / 2) -- 182
	current:adjustSizeWithAlign( -- 183
		"Auto", -- 183
		10, -- 183
		Size(width, height) -- 183
	) -- 183
	local ____opt_3 = current:getChildByTag("border") -- 183
	if ____opt_3 ~= nil then -- 183
		____opt_3:removeFromParent() -- 184
	end -- 184
	local border = LineRectCreate({ -- 185
		x = -width / 2, -- 185
		y = -height / 2, -- 185
		width = width, -- 185
		height = height, -- 185
		color = 4294967295 -- 185
	}) -- 185
	current:addChild(border, 0, "border") -- 186
	mountItemRoot() -- 187
end -- 179
local function startAddingItems() -- 190
	thread(function() -- 191
		for i = 1, 30 do -- 191
			appendItem(createItem(i)) -- 193
			sleep(1) -- 194
		end -- 194
	end) -- 191
end -- 190
local function App() -- 199
	return React.createElement( -- 200
		"align-node", -- 200
		{windowRoot = true, style = {alignItems = "center", justifyContent = "center"}}, -- 200
		React.createElement( -- 200
			"align-node", -- 200
			{style = {width = "50%", height = "50%"}, onLayout = updateScrollLayout}, -- 200
			React.createElement(ScrollArea, {ref = scrollArea, width = 250, height = 300, paddingX = 0}) -- 200
		) -- 200
	) -- 200
end -- 199
local appNode = toNode(React.createElement(App, nil)) -- 209
if appNode then -- 209
	appNode:onCleanup(function() -- 211
		if listRoot then -- 211
			listRoot:unmount() -- 213
			listRoot = nil -- 214
		end -- 214
	end) -- 211
	startAddingItems() -- 217
end -- 217
return ____exports -- 217