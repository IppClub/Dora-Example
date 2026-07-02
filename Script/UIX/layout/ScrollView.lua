-- [tsx]: ScrollView.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 1
local Mouse = ____Dora.Mouse -- 1
local Size = ____Dora.Size -- 1
local Vec2 = ____Dora.Vec2 -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local useCallback = ____DoraX.useCallback -- 3
local useRef = ____DoraX.useRef -- 3
local useSignal = ____DoraX.useSignal -- 3
local ____clip = require("UIX.paint.clip") -- 4
local registerClip = ____clip.registerClip -- 4
local unregisterClip = ____clip.unregisterClip -- 4
local ____helpers = require("UIX.layout.helpers") -- 5
local mergeStyle = ____helpers.mergeStyle -- 5
local ____types = require("UIX.types") -- 7
local clamp = ____types.clamp -- 7
function ____exports.ScrollView(props) -- 21
	local localOffset = useSignal(props.defaultOffsetY or 0) -- 22
	local localRef = useRef() -- 23
	local contentRef = useRef() -- 24
	local inputRef = useRef() -- 25
	local dragRef = useRef() -- 26
	local dragging = useRef(false) -- 27
	local scrollActive = useRef(false) -- 28
	local dragDistance = useRef(0) -- 29
	local lastDragY = useRef(0) -- 30
	local rootRef = props.ref or localRef -- 31
	local ____opt_0 = props.style -- 31
	local styleWidth = ____opt_0 and ____opt_0.width -- 32
	local ____opt_2 = props.style -- 32
	local styleHeight = ____opt_2 and ____opt_2.height -- 33
	local width = props.width or styleWidth or 240 -- 34
	local height = props.height or styleHeight or 160 -- 35
	local maxOffset = math.max(0, props.contentHeight - height) -- 36
	local offset = clamp(localOffset.value, 0, maxOffset) -- 37
	local contentYForOffset = useCallback( -- 39
		function(next) return next + height - props.contentHeight / 2 end, -- 39
		{height, props.contentHeight} -- 39
	) -- 39
	local applyContentOffset = useCallback( -- 40
		function(next) -- 40
			local node = contentRef.current -- 41
			if node ~= nil then -- 41
				node.y = contentYForOffset(next) -- 43
			end -- 43
		end, -- 40
		{contentYForOffset} -- 45
	) -- 45
	local setOffset = useCallback( -- 46
		function(value) -- 46
			local next = clamp(value, 0, maxOffset) -- 47
			localOffset.value = next -- 48
			applyContentOffset(next) -- 49
			local ____opt_4 = props.onScroll -- 49
			if ____opt_4 ~= nil then -- 49
				____opt_4(next) -- 50
			end -- 50
		end, -- 46
		{localOffset.value, maxOffset, props.onScroll, applyContentOffset} -- 51
	) -- 51
	local scrollByWheel = useCallback( -- 52
		function(deltaY) -- 52
			setOffset(offset + deltaY * (props.wheelSpeed or 24)) -- 53
		end, -- 52
		{offset, props.wheelSpeed, setOffset} -- 54
	) -- 54
	local mouseRootLocation = useCallback( -- 55
		function() -- 55
			local root = rootRef.current -- 56
			if root == nil then -- 56
				return nil -- 57
			end -- 57
			local ____App_bufferSize_6 = App.bufferSize -- 58
			local bw = ____App_bufferSize_6.width -- 58
			local bh = ____App_bufferSize_6.height -- 58
			local ____App_visualSize_7 = App.visualSize -- 59
			local vw = ____App_visualSize_7.width -- 59
			local pos = Mouse.position:mul(bw / vw) -- 60
			pos = Vec2(pos.x - bw / 2, bh / 2 - pos.y) -- 61
			return root:convertToNodeSpace(pos) -- 62
		end, -- 55
		{} -- 63
	) -- 63
	local touchRootLocation = useCallback( -- 64
		function(touch) -- 64
			local root = rootRef.current -- 65
			if root ~= nil and touch.worldLocation ~= nil then -- 65
				return root:convertToNodeSpace(touch.worldLocation) -- 67
			end -- 67
			return touch.location -- 69
		end, -- 64
		{} -- 70
	) -- 70
	local isInsideTouch = useCallback( -- 71
		function(touch) -- 71
			local location = touchRootLocation(touch) -- 72
			return location.x >= 0 and location.x <= width and location.y >= 0 and location.y <= height -- 73
		end, -- 71
		{height, touchRootLocation, width} -- 74
	) -- 74
	local filterDrag = useCallback( -- 75
		function(touch) -- 75
			if not touch.first or not isInsideTouch(touch) then -- 75
				touch.enabled = false -- 77
			end -- 77
		end, -- 75
		{isInsideTouch} -- 79
	) -- 79
	local moveDrag = useCallback( -- 80
		function(touch) -- 80
			local nextDistance = (dragDistance.current or 0) + touch.delta.length -- 81
			dragDistance.current = nextDistance -- 82
			if scrollActive.current or nextDistance > 10 then -- 82
				scrollActive.current = true -- 84
				setOffset(offset + touch.delta.y) -- 85
			end -- 85
		end, -- 80
		{dragDistance, offset, scrollActive, setOffset} -- 87
	) -- 87
	local beginDrag = useCallback( -- 88
		function(touch) -- 88
			local location = touchRootLocation(touch) -- 89
			dragging.current = true -- 90
			scrollActive.current = false -- 91
			dragDistance.current = 0 -- 92
			lastDragY.current = location.y -- 93
		end, -- 88
		{ -- 94
			dragDistance, -- 94
			dragging, -- 94
			lastDragY, -- 94
			scrollActive, -- 94
			touchRootLocation -- 94
		} -- 94
	) -- 94
	local endDrag = useCallback( -- 95
		function() -- 95
			dragging.current = false -- 96
			scrollActive.current = false -- 97
			dragDistance.current = 0 -- 98
		end, -- 95
		{dragDistance, dragging, scrollActive} -- 99
	) -- 99
	local syncClip = useCallback( -- 100
		function(node, clipWidth, clipHeight) -- 100
			if node ~= nil then -- 100
				node.size = Size(clipWidth, clipHeight) -- 102
				registerClip(node, clipWidth, clipHeight) -- 103
			end -- 103
		end, -- 100
		{} -- 105
	) -- 105
	local syncInputSize = useCallback( -- 106
		function(node, inputWidth, inputHeight) -- 106
			if node ~= nil then -- 106
				node.size = Size(inputWidth, inputHeight) -- 107
			end -- 107
		end, -- 106
		{} -- 108
	) -- 108
	local syncContentNode = useCallback( -- 109
		function(node) -- 109
			if node ~= nil then -- 109
				node.size = Size(width, props.contentHeight) -- 111
				node.y = contentYForOffset(offset) -- 112
			end -- 112
		end, -- 109
		{contentYForOffset, offset, props.contentHeight, width} -- 114
	) -- 114
	local onRootLayout = useCallback( -- 115
		function(w, h) return syncClip(rootRef.current, w, h) end, -- 115
		{syncClip} -- 115
	) -- 115
	local onRootUnmount = useCallback( -- 116
		function(node) -- 116
			unregisterClip(node) -- 117
		end, -- 116
		{} -- 118
	) -- 118
	local onContentLayout = useCallback( -- 119
		function() return syncContentNode(contentRef.current) end, -- 119
		{syncContentNode} -- 119
	) -- 119
	local onInputLayout = useCallback( -- 120
		function(w, h) return syncInputSize(inputRef.current, w, h) end, -- 120
		{syncInputSize} -- 120
	) -- 120
	local onWheel = useCallback( -- 121
		function(delta) return scrollByWheel(delta.y) end, -- 121
		{scrollByWheel} -- 121
	) -- 121
	local onDragLayout = useCallback( -- 122
		function(w, h) return syncInputSize(dragRef.current, w, h) end, -- 122
		{syncInputSize} -- 122
	) -- 122
	local ____React_createElement_16 = React.createElement -- 122
	local ____temp_14 = { -- 122
		key = props.key, -- 122
		ref = rootRef, -- 122
		style = mergeStyle({position = "relative", width = width, height = height}, props.style), -- 122
		visible = props.visible, -- 122
		opacity = props.opacity, -- 122
		onLayout = onRootLayout, -- 122
		onUnmount = onRootUnmount -- 122
	} -- 122
	local ____React_createElement_result_15 = React.createElement( -- 122
		"menu", -- 122
		{anchorX = 0, anchorY = 0, width = width, height = height}, -- 122
		React.createElement("align-node", { -- 122
			key = "content", -- 122
			ref = contentRef, -- 122
			style = { -- 122
				width = width, -- 142
				height = props.contentHeight, -- 143
				flexDirection = "column", -- 144
				alignItems = "flex-start", -- 145
				justifyContent = "flex-start" -- 146
			}, -- 146
			anchorX = 0, -- 146
			onLayout = onContentLayout -- 146
		}, props.children) -- 146
	) -- 146
	local ____temp_8 -- 154
	if props.inputOverlay ~= false then -- 154
		____temp_8 = React.createElement("align-node", { -- 154
			key = "input-overlay", -- 154
			ref = inputRef, -- 154
			style = { -- 154
				position = "absolute", -- 159
				left = 0, -- 160
				top = 0, -- 161
				width = width, -- 162
				height = height -- 163
			}, -- 163
			touchEnabled = not props.disabled, -- 163
			swallowTouches = props.dragOverlay == true, -- 163
			swallowMouseWheel = true, -- 163
			onLayout = onInputLayout, -- 163
			onMouseWheel = onWheel -- 163
		}) -- 163
	else -- 163
		____temp_8 = nil -- 170
	end -- 170
	local ____temp_13 -- 172
	if props.inputOverlay ~= false then -- 172
		local ____React_createElement_12 = React.createElement -- 172
		local ____temp_10 = { -- 176
			position = "absolute", -- 177
			left = 0, -- 178
			top = 0, -- 179
			width = width, -- 180
			height = height -- 181
		} -- 181
		local ____temp_11 = not props.disabled -- 183
		local ____props_swallowDrag_9 = props.swallowDrag -- 184
		if ____props_swallowDrag_9 == nil then -- 184
			____props_swallowDrag_9 = false -- 184
		end -- 184
		____temp_13 = ____React_createElement_12("align-node", { -- 184
			key = "drag-capture", -- 184
			ref = dragRef, -- 184
			style = ____temp_10, -- 184
			touchEnabled = ____temp_11, -- 184
			swallowTouches = ____props_swallowDrag_9, -- 184
			onLayout = onDragLayout, -- 184
			onTapBegan = beginDrag, -- 184
			onTapMoved = moveDrag, -- 184
			onTapEnded = endDrag -- 184
		}) -- 184
	else -- 184
		____temp_13 = nil -- 189
	end -- 189
	return ____React_createElement_16( -- 123
		"align-node", -- 123
		____temp_14, -- 123
		____React_createElement_result_15, -- 123
		____temp_8, -- 123
		____temp_13 -- 123
	) -- 123
end -- 21
return ____exports -- 21