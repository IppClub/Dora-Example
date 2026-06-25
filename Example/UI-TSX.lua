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
local useCallback = ____DoraX.useCallback -- 2
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
local function Button(props) -- 23
	local ____props_0 = props -- 24
	local text = ____props_0.text -- 24
	local onClick = ____props_0.onClick -- 24
	local createButton = useCallback( -- 25
		function() -- 25
			local btn = ButtonCreate({text = text, width = 50, height = 50}) -- 26
			btn:onTapped(onClick) -- 31
			return btn -- 32
		end, -- 25
		{text, onClick} -- 33
	) -- 33
	return React.createElement("custom-node", {key = props.key, onMount = props.onMount, onCreate = createButton, children = props.children}) -- 34
end -- 23
local function ScrollArea(props) -- 53
	return React.createElement( -- 54
		"custom-node", -- 54
		{onCreate = function() -- 54
			local ____props_1 = props -- 55
			local width = ____props_1.width -- 55
			local height = ____props_1.height -- 55
			local scrollArea = ScrollAreaCreate(props) -- 56
			if props.ref then -- 56
				props.ref.current = scrollArea -- 58
			end -- 58
			if props.children then -- 58
				for ____, child in ipairs(props.children) do -- 61
					local ____opt_2 = toNode(child) -- 61
					if ____opt_2 ~= nil then -- 61
						____opt_2:addTo(scrollArea.view) -- 62
					end -- 62
				end -- 62
				scrollArea:adjustSizeWithAlign( -- 64
					"Auto", -- 64
					10, -- 64
					Size(width, height) -- 64
				) -- 64
			end -- 64
			return scrollArea -- 66
		end} -- 54
	) -- 54
end -- 53
local scrollArea = reference() -- 78
local items = signal({}) -- 79
local listRoot -- 80
local function adjustScrollArea() -- 82
	local current = scrollArea.current -- 82
	if not current then -- 82
		return -- 84
	end -- 84
	current:adjustSizeWithAlign("Auto") -- 85
end -- 82
local function scheduleAdjustScrollArea() -- 88
	Director.scheduler:schedule(once(function() -- 89
		sleep() -- 90
		adjustScrollArea() -- 91
	end)) -- 89
end -- 88
local function setItems(nextItems) -- 95
	items.value = nextItems -- 96
	scheduleAdjustScrollArea() -- 97
end -- 95
local function removeItem(target) -- 100
	local nextItems = {} -- 101
	for ____, item in ipairs(items.value) do -- 102
		if item ~= target then -- 102
			nextItems[#nextItems + 1] = item -- 104
		end -- 104
	end -- 104
	setItems(nextItems) -- 107
end -- 100
local function appendItem(item) -- 110
	local nextItems = {} -- 111
	for ____, current in ipairs(items.value) do -- 112
		nextItems[#nextItems + 1] = current -- 113
	end -- 113
	nextItems[#nextItems + 1] = item -- 115
	setItems(nextItems) -- 116
end -- 110
local function createItem(id) -- 119
	local item = {} -- 120
	item.id = id -- 121
	item.name = "btn " .. tostring(id) -- 122
	item.value = id -- 123
	item.remove = function() -- 124
		thread(function() -- 125
			sleep(0.5) -- 126
			removeItem(item) -- 127
		end) -- 125
	end -- 124
	item.mountButton = function(node) -- 130
		local btn = node -- 131
		btn:once(function() -- 132
			btn.face:perform(toAction(React.createElement("scale", {time = 0.3, start = 0, stop = 1, easing = Ease.OutBack}))) -- 133
			sleep() -- 136
			adjustScrollArea() -- 137
		end) -- 132
	end -- 130
	return item -- 140
end -- 119
local function renderItems() -- 143
	return __TS__ArrayMap( -- 144
		items.value, -- 144
		function(____, item) return React.createElement(Button, { -- 144
			key = item.id, -- 144
			text = item.name, -- 144
			width = 50, -- 144
			height = 50, -- 144
			onClick = item.remove, -- 144
			onMount = item.mountButton -- 144
		}) end -- 144
	) -- 144
end -- 143
local function mountItemRoot() -- 156
	local current = scrollArea.current -- 156
	if not current or listRoot then -- 156
		return -- 158
	end -- 158
	listRoot = createRoot(current.view) -- 159
	listRoot:render(renderItems) -- 160
	adjustScrollArea() -- 161
end -- 156
local function updateScrollLayout(width, height) -- 164
	local current = scrollArea.current -- 164
	if not current then -- 164
		return -- 166
	end -- 166
	current.position = Vec2(width / 2, height / 2) -- 167
	current:adjustSizeWithAlign( -- 168
		"Auto", -- 168
		10, -- 168
		Size(width, height) -- 168
	) -- 168
	local ____opt_4 = current:getChildByTag("border") -- 168
	if ____opt_4 ~= nil then -- 168
		____opt_4:removeFromParent() -- 169
	end -- 169
	local border = LineRectCreate({ -- 170
		x = -width / 2, -- 170
		y = -height / 2, -- 170
		width = width, -- 170
		height = height, -- 170
		color = 4294967295 -- 170
	}) -- 170
	current:addChild(border, 0, "border") -- 171
	mountItemRoot() -- 172
end -- 164
local function startAddingItems() -- 175
	thread(function() -- 176
		for i = 1, 30 do -- 176
			appendItem(createItem(i)) -- 178
			sleep(1) -- 179
		end -- 179
	end) -- 176
end -- 175
local function App() -- 184
	return React.createElement( -- 185
		"align-node", -- 185
		{windowRoot = true, style = {alignItems = "center", justifyContent = "center"}}, -- 185
		React.createElement( -- 185
			"align-node", -- 185
			{style = {width = "50%", height = "50%"}, onLayout = updateScrollLayout}, -- 185
			React.createElement(ScrollArea, {ref = scrollArea, width = 250, height = 300, paddingX = 0}) -- 185
		) -- 185
	) -- 185
end -- 184
local appNode = toNode(React.createElement(App, nil)) -- 194
if appNode then -- 194
	appNode:onCleanup(function() -- 196
		if listRoot then -- 196
			listRoot:unmount() -- 198
			listRoot = nil -- 199
		end -- 199
	end) -- 196
	startAddingItems() -- 202
end -- 202
return ____exports -- 202