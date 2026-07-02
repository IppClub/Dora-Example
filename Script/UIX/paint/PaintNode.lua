-- [tsx]: PaintNode.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 1
local Node = ____Dora.Node -- 1
local Size = ____Dora.Size -- 1
local Vec2 = ____Dora.Vec2 -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local useCallback = ____DoraX.useCallback -- 3
local useRef = ____DoraX.useRef -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____clip = require("UIX.paint.clip") -- 6
local applyAncestorClips = ____clip.applyAncestorClips -- 6
local ____types = require("UIX.types") -- 7
local mergeInteractionState = ____types.mergeInteractionState -- 7
function ____exports.PaintNode(props) -- 34
	local holder = useRef() -- 35
	holder.current = props -- 36
	local onCreate = useCallback( -- 37
		function() -- 37
			local node = Node() -- 38
			node.anchor = Vec2(0, 0) -- 39
			node:onRender(function() -- 40
				local latest = holder.current -- 41
				local ui = getUiContext() -- 42
				local parent = node.parent -- 43
				local width = latest.width or parent and parent.width or node.width -- 44
				local height = latest.height or parent and parent.height or node.height -- 45
				node.size = Size(width, height) -- 46
				nvg.Save() -- 47
				nvg.ApplyTransform(node) -- 48
				applyAncestorClips(node) -- 49
				latest.painter({ -- 50
					width = width, -- 51
					height = height, -- 52
					theme = ui.theme, -- 53
					pixelRatio = ui.scale, -- 54
					opacity = node.opacity, -- 55
					state = mergeInteractionState(latest.state), -- 56
					time = App.elapsedTime, -- 57
					data = latest.data, -- 58
					node = node -- 59
				}) -- 59
				nvg.Restore() -- 61
				return false -- 62
			end) -- 40
			local ____opt_4 = holder.current.onMountNode -- 40
			if ____opt_4 ~= nil then -- 40
				____opt_4(node) -- 64
			end -- 64
			return node -- 65
		end, -- 37
		{holder} -- 66
	) -- 66
	return React.createElement( -- 67
		"custom-node", -- 67
		{ -- 67
			ref = props.ref, -- 67
			key = props.key, -- 67
			order = props.order, -- 67
			renderOrder = props.renderOrder, -- 67
			visible = props.visible, -- 67
			opacity = props.opacity, -- 67
			onCreate = onCreate, -- 67
			onUnmount = function(____self) -- 67
				local clearRender = ____self.clearRender -- 77
				if type(clearRender) == "function" then -- 77
					clearRender(____self) -- 79
				end -- 79
			end -- 76
		}, -- 76
		props.children -- 83
	) -- 83
end -- 34
return ____exports -- 34