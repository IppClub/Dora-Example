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
	local ____props_width_2 = props.width -- 32
	if ____props_width_2 == nil then -- 32
		local ____opt_0 = props.style -- 32
		____props_width_2 = ____opt_0 and ____opt_0.width -- 32
	end -- 32
	local width = ____props_width_2 or 240 -- 32
	local ____props_height_5 = props.height -- 33
	if ____props_height_5 == nil then -- 33
		local ____opt_3 = props.style -- 33
		____props_height_5 = ____opt_3 and ____opt_3.height -- 33
	end -- 33
	local height = ____props_height_5 or 160 -- 33
	local maxOffset = math.max(0, props.contentHeight - height) -- 34
	local offset = clamp(localOffset.value, 0, maxOffset) -- 35
	local contentYForOffset = useCallback( -- 37
		function(next) return next + height - props.contentHeight / 2 end, -- 37
		{height, props.contentHeight} -- 37
	) -- 37
	local applyContentOffset = useCallback( -- 38
		function(next) -- 38
			local node = contentRef.current -- 39
			if node ~= nil then -- 39
				node.y = contentYForOffset(next) -- 41
			end -- 41
		end, -- 38
		{contentYForOffset} -- 43
	) -- 43
	local setOffset = useCallback( -- 44
		function(value) -- 44
			local next = clamp(value, 0, maxOffset) -- 45
			localOffset.value = next -- 46
			applyContentOffset(next) -- 47
			local ____opt_6 = props.onScroll -- 47
			if ____opt_6 ~= nil then -- 47
				____opt_6(next) -- 48
			end -- 48
		end, -- 44
		{localOffset.value, maxOffset, props.onScroll, applyContentOffset} -- 49
	) -- 49
	local scrollByWheel = useCallback( -- 50
		function(deltaY) -- 50
			setOffset(offset + deltaY * (props.wheelSpeed or 24)) -- 51
		end, -- 50
		{offset, props.wheelSpeed, setOffset} -- 52
	) -- 52
	local mouseRootLocation = useCallback( -- 53
		function() -- 53
			local root = rootRef.current -- 54
			if root == nil then -- 54
				return nil -- 55
			end -- 55
			local ____App_bufferSize_8 = App.bufferSize -- 56
			local bw = ____App_bufferSize_8.width -- 56
			local bh = ____App_bufferSize_8.height -- 56
			local ____App_visualSize_9 = App.visualSize -- 57
			local vw = ____App_visualSize_9.width -- 57
			local pos = Mouse.position:mul(bw / vw) -- 58
			pos = Vec2(pos.x - bw / 2, bh / 2 - pos.y) -- 59
			return root:convertToNodeSpace(pos) -- 60
		end, -- 53
		{} -- 61
	) -- 61
	local touchRootLocation = useCallback( -- 62
		function(touch) -- 62
			local root = rootRef.current -- 63
			if root ~= nil and touch.worldLocation ~= nil then -- 63
				return root:convertToNodeSpace(touch.worldLocation) -- 65
			end -- 65
			return touch.location -- 67
		end, -- 62
		{} -- 68
	) -- 68
	local isInsideTouch = useCallback( -- 69
		function(touch) -- 69
			local location = touchRootLocation(touch) -- 70
			return location.x >= 0 and location.x <= width and location.y >= 0 and location.y <= height -- 71
		end, -- 69
		{height, touchRootLocation, width} -- 72
	) -- 72
	local filterDrag = useCallback( -- 73
		function(touch) -- 73
			if not touch.first or not isInsideTouch(touch) then -- 73
				touch.enabled = false -- 75
			end -- 75
		end, -- 73
		{isInsideTouch} -- 77
	) -- 77
	local moveDrag = useCallback( -- 78
		function(touch) -- 78
			local nextDistance = (dragDistance.current or 0) + touch.delta.length -- 79
			dragDistance.current = nextDistance -- 80
			if scrollActive.current or nextDistance > 10 then -- 80
				scrollActive.current = true -- 82
				setOffset(offset + touch.delta.y) -- 83
			end -- 83
		end, -- 78
		{dragDistance, offset, scrollActive, setOffset} -- 85
	) -- 85
	local beginDrag = useCallback( -- 86
		function(touch) -- 86
			local location = touchRootLocation(touch) -- 87
			dragging.current = true -- 88
			scrollActive.current = false -- 89
			dragDistance.current = 0 -- 90
			lastDragY.current = location.y -- 91
		end, -- 86
		{ -- 92
			dragDistance, -- 92
			dragging, -- 92
			lastDragY, -- 92
			scrollActive, -- 92
			touchRootLocation -- 92
		} -- 92
	) -- 92
	local endDrag = useCallback( -- 93
		function() -- 93
			dragging.current = false -- 94
			scrollActive.current = false -- 95
			dragDistance.current = 0 -- 96
		end, -- 93
		{dragDistance, dragging, scrollActive} -- 97
	) -- 97
	local syncClip = useCallback( -- 98
		function(node, clipWidth, clipHeight) -- 98
			if node ~= nil then -- 98
				node.size = Size(clipWidth, clipHeight) -- 100
				registerClip(node, clipWidth, clipHeight) -- 101
			end -- 101
		end, -- 98
		{} -- 103
	) -- 103
	local syncInputSize = useCallback( -- 104
		function(node, inputWidth, inputHeight) -- 104
			if node ~= nil then -- 104
				node.size = Size(inputWidth, inputHeight) -- 105
			end -- 105
		end, -- 104
		{} -- 106
	) -- 106
	local syncContentNode = useCallback( -- 107
		function(node) -- 107
			if node ~= nil then -- 107
				node.size = Size(width, props.contentHeight) -- 109
				node.y = contentYForOffset(offset) -- 110
			end -- 110
		end, -- 107
		{contentYForOffset, offset, props.contentHeight, width} -- 112
	) -- 112
	local onContentLayout = useCallback( -- 113
		function() return syncContentNode(contentRef.current) end, -- 113
		{syncContentNode} -- 113
	) -- 113
	local onRootLayout = useCallback( -- 114
		function(w, h) -- 114
			syncClip(rootRef.current, w, h) -- 115
			onContentLayout() -- 116
		end, -- 114
		{syncClip, onContentLayout} -- 117
	) -- 117
	local onRootMount = useCallback( -- 118
		function(node) -- 118
			syncClip(node, width, height) -- 119
		end, -- 118
		{height, syncClip, width} -- 120
	) -- 120
	local onRootUnmount = useCallback( -- 121
		function(node) -- 121
			unregisterClip(node) -- 122
		end, -- 121
		{} -- 123
	) -- 123
	local onInputLayout = useCallback( -- 124
		function(w, h) return syncInputSize(inputRef.current, w, h) end, -- 124
		{syncInputSize} -- 124
	) -- 124
	local onInputMount = useCallback( -- 125
		function(node) return syncInputSize(node, width, height) end, -- 125
		{height, syncInputSize, width} -- 125
	) -- 125
	local onWheel = useCallback( -- 126
		function(delta) return scrollByWheel(delta.y) end, -- 126
		{scrollByWheel} -- 126
	) -- 126
	local onDragLayout = useCallback( -- 127
		function(w, h) return syncInputSize(dragRef.current, w, h) end, -- 127
		{syncInputSize} -- 127
	) -- 127
	local onDragMount = useCallback( -- 128
		function(node) return syncInputSize(node, width, height) end, -- 128
		{height, syncInputSize, width} -- 128
	) -- 128
	local ____React_createElement_18 = React.createElement -- 128
	local ____temp_16 = { -- 128
		key = props.key, -- 128
		ref = rootRef, -- 128
		style = mergeStyle({position = "relative", width = width, height = height}, props.style), -- 128
		visible = props.visible, -- 128
		opacity = props.opacity, -- 128
		onMount = onRootMount, -- 128
		onLayout = onRootLayout, -- 128
		onUnmount = onRootUnmount -- 128
	} -- 128
	local ____React_createElement_result_17 = React.createElement( -- 128
		"menu", -- 128
		{anchorX = 0, anchorY = 0, width = width, height = height}, -- 128
		React.createElement("align-node", { -- 128
			key = "content", -- 128
			ref = contentRef, -- 128
			style = { -- 128
				width = width, -- 149
				height = props.contentHeight, -- 150
				flexDirection = "column", -- 151
				alignItems = "flex-start", -- 152
				justifyContent = "flex-start" -- 153
			}, -- 153
			anchorX = 0, -- 153
			onLayout = onContentLayout -- 153
		}, props.children) -- 153
	) -- 153
	local ____temp_10 -- 161
	if props.inputOverlay ~= false then -- 161
		____temp_10 = React.createElement("align-node", { -- 161
			key = "input-overlay", -- 161
			ref = inputRef, -- 161
			style = { -- 161
				position = "absolute", -- 166
				left = 0, -- 167
				top = 0, -- 168
				width = width, -- 169
				height = height -- 170
			}, -- 170
			touchEnabled = not props.disabled, -- 170
			swallowTouches = props.dragOverlay == true, -- 170
			swallowMouseWheel = true, -- 170
			onMount = onInputMount, -- 170
			onLayout = onInputLayout, -- 170
			onMouseWheel = onWheel -- 170
		}) -- 170
	else -- 170
		____temp_10 = nil -- 178
	end -- 178
	local ____temp_15 -- 180
	if props.inputOverlay ~= false then -- 180
		local ____React_createElement_14 = React.createElement -- 180
		local ____temp_12 = { -- 184
			position = "absolute", -- 185
			left = 0, -- 186
			top = 0, -- 187
			width = width, -- 188
			height = height -- 189
		} -- 189
		local ____temp_13 = not props.disabled -- 191
		local ____props_swallowDrag_11 = props.swallowDrag -- 192
		if ____props_swallowDrag_11 == nil then -- 192
			____props_swallowDrag_11 = false -- 192
		end -- 192
		____temp_15 = ____React_createElement_14("align-node", { -- 192
			key = "drag-capture", -- 192
			ref = dragRef, -- 192
			style = ____temp_12, -- 192
			touchEnabled = ____temp_13, -- 192
			swallowTouches = ____props_swallowDrag_11, -- 192
			onMount = onDragMount, -- 192
			onLayout = onDragLayout, -- 192
			onTapBegan = beginDrag, -- 192
			onTapMoved = moveDrag, -- 192
			onTapEnded = endDrag -- 192
		}) -- 192
	else -- 192
		____temp_15 = nil -- 198
	end -- 198
	return ____React_createElement_18( -- 129
		"align-node", -- 129
		____temp_16, -- 129
		____React_createElement_result_17, -- 129
		____temp_10, -- 129
		____temp_15 -- 129
	) -- 129
end -- 21
return ____exports -- 21