-- [tsx]: Tooltip.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Size = ____Dora.Size -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local useRef = ____DoraX.useRef -- 2
local ____context = require("UIX.context") -- 3
local getUiContext = ____context.getUiContext -- 3
local ____Text = require("UIX.foundation.Text") -- 4
local Text = ____Text.Text -- 4
local wrapTextLines = ____Text.wrapTextLines -- 4
local ____Column = require("UIX.layout.Column") -- 5
local Column = ____Column.Column -- 5
local ____PaintNode = require("UIX.paint.PaintNode") -- 6
local PaintNode = ____PaintNode.PaintNode -- 6
local ____primitives = require("UIX.paint.primitives") -- 7
local roundedPanel = ____primitives.roundedPanel -- 7
local ____helpers = require("UIX.layout.helpers") -- 8
local mergeStyle = ____helpers.mergeStyle -- 8
function ____exports.Tooltip(props) -- 17
	local theme = getUiContext().theme -- 18
	local localRef = useRef() -- 19
	local rootRef = props.ref or localRef -- 20
	local width = props.width or 220 -- 21
	local hasTitle = props.title ~= nil and props.title ~= "" -- 22
	local textFontSize = theme.font.size.sm -- 23
	local textLineHeight = textFontSize * 1.25 -- 24
	local textWidth = width - theme.space.md * 2 -- 25
	local textLines = props.text ~= nil and wrapTextLines(props.text, textWidth, textFontSize) or ({}) -- 26
	local textHeight = props.text ~= nil and math.max(textLineHeight, #textLines * textLineHeight) or 0 -- 27
	local tooltipHeight = (hasTitle and 30 or 0) + textHeight + theme.space.md * 2 -- 28
	local function syncSize(node) -- 29
		if node ~= nil then -- 29
			node.size = Size(width, tooltipHeight) -- 30
		end -- 30
	end -- 29
	local ____React_createElement_7 = React.createElement -- 29
	local ____temp_5 = { -- 29
		key = props.key, -- 29
		ref = rootRef, -- 29
		style = mergeStyle({ -- 29
			position = "absolute", -- 37
			width = width, -- 38
			height = tooltipHeight, -- 39
			padding = theme.space.md, -- 40
			gap = theme.space.xs -- 41
		}, props.style), -- 41
		visible = props.visible, -- 41
		opacity = props.opacity, -- 41
		touchEnabled = false, -- 41
		onMount = function() return syncSize(rootRef.current) end, -- 41
		onLayout = function() return syncSize(rootRef.current) end -- 41
	} -- 41
	local ____React_createElement_result_6 = React.createElement( -- 41
		PaintNode, -- 49
		{painter = function(ctx) return roundedPanel(ctx, {x = 0, y = 0, width = ctx.width, height = ctx.height}, {variant = "solid", radius = theme.radius.sm}) end} -- 49
	) -- 49
	local ____React_createElement_4 = React.createElement -- 49
	local ____Column_2 = Column -- 53
	local ____temp_3 = {style = {width = "100%", height = "100%", gap = theme.space.xs}} -- 53
	local ____hasTitle_0 -- 54
	if hasTitle then -- 54
		____hasTitle_0 = React.createElement(Text, {text = props.title, fontSize = theme.font.size.md, color = theme.colors.text.primary, style = {width = "100%", height = 26}}) -- 54
	else -- 54
		____hasTitle_0 = nil -- 55
	end -- 55
	local ____temp_1 -- 56
	if props.text ~= nil then -- 56
		____temp_1 = React.createElement( -- 56
			Text, -- 57
			{ -- 57
				text = props.text, -- 57
				fontSize = textFontSize, -- 57
				lineHeight = textLineHeight, -- 57
				wrap = true, -- 57
				alignment = "Left", -- 57
				color = theme.colors.text.secondary, -- 57
				style = { -- 57
					width = "100%", -- 64
					height = math.max(textLineHeight, textHeight) -- 64
				} -- 64
			} -- 64
		) -- 64
	else -- 64
		____temp_1 = nil -- 65
	end -- 65
	return ____React_createElement_7( -- 32
		"align-node", -- 32
		____temp_5, -- 32
		____React_createElement_result_6, -- 32
		____React_createElement_4( -- 32
			____Column_2, -- 53
			____temp_3, -- 53
			____hasTitle_0, -- 53
			____temp_1, -- 53
			props.children -- 66
		) -- 66
	) -- 66
end -- 17
return ____exports -- 17