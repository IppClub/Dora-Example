-- [tsx]: Badge.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Color = ____Dora.Color -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____Icon = require("UIX.foundation.Icon") -- 6
local Icon = ____Icon.Icon -- 6
local ____Text = require("UIX.foundation.Text") -- 7
local Text = ____Text.Text -- 7
local ____Row = require("UIX.layout.Row") -- 8
local Row = ____Row.Row -- 8
local ____helpers = require("UIX.layout.helpers") -- 9
local mergeStyle = ____helpers.mergeStyle -- 9
local textFromChildren = ____helpers.textFromChildren -- 9
local ____PaintNode = require("UIX.paint.PaintNode") -- 10
local PaintNode = ____PaintNode.PaintNode -- 10
local ____color = require("UIX.paint.color") -- 11
local withAlpha = ____color.withAlpha -- 11
local function toneColor(ctx, tone) -- 25
	local theme = ctx.theme -- 26
	if tone == "primary" then -- 26
		return theme.colors.accent.primary -- 27
	end -- 27
	if tone == "secondary" then -- 27
		return theme.colors.accent.secondary -- 28
	end -- 28
	if tone == "success" then -- 28
		return theme.colors.state.success -- 29
	end -- 29
	if tone == "warning" then -- 29
		return theme.colors.state.warning -- 30
	end -- 30
	if tone == "danger" then -- 30
		return theme.colors.state.danger -- 31
	end -- 31
	if tone == "mana" then -- 31
		return theme.colors.state.mana -- 32
	end -- 32
	if tone == "warm" then -- 32
		return theme.colors.accent.warm -- 33
	end -- 33
	return theme.colors.line.normal -- 34
end -- 25
local function badgePainter(tone, outline) -- 37
	return function(ctx) -- 38
		local theme = ctx.theme -- 39
		local color = toneColor(ctx, tone) -- 40
		local radius = ctx.height * 0.5 -- 41
		local fill = outline and theme.colors.surface.base or color -- 42
		local fillAlpha = outline and 0.42 * ctx.opacity or (tone == "default" and 0.32 * ctx.opacity or 0.2 * ctx.opacity) -- 43
		nvg.BeginPath() -- 44
		nvg.RoundedRect( -- 45
			0, -- 45
			0, -- 45
			ctx.width, -- 45
			ctx.height, -- 45
			radius -- 45
		) -- 45
		nvg.FillColor(Color(withAlpha(fill, fillAlpha))) -- 46
		nvg.Fill() -- 47
		nvg.StrokeWidth(theme.stroke.hairline) -- 48
		nvg.StrokeColor(Color(withAlpha(color, tone == "default" and 0.72 * ctx.opacity or ctx.opacity))) -- 49
		nvg.Stroke() -- 50
	end -- 38
end -- 37
function ____exports.Badge(props) -- 54
	local theme = getUiContext().theme -- 55
	local size = props.size or "sm" -- 56
	local height = size == "lg" and 34 or (size == "md" and 28 or 22) -- 57
	local fontSize = size == "lg" and theme.font.size.md or (size == "md" and theme.font.size.sm or theme.font.size.xs) -- 58
	local iconSize = size == "lg" and theme.size.icon.md or theme.size.icon.sm -- 59
	local text = textFromChildren( -- 60
		props.children, -- 60
		props.text ~= nil and tostring(props.text) or "" -- 60
	) -- 60
	local hasIcon = props.icon ~= nil -- 61
	local hasDot = props.dot == true -- 62
	local paddingX = size == "lg" and theme.space.md or theme.space.sm -- 63
	local dotSize = 8 -- 64
	local contentWidth = math.max(0, #text * fontSize * 0.62) + (hasIcon and iconSize + theme.space.xs or 0) + (hasDot and dotSize + theme.space.xs or 0) -- 65
	local width = math.max(height, contentWidth + paddingX * 2) -- 66
	local tone = props.tone or "default" -- 67
	local color = (tone == "warm" or tone == "warning") and theme.colors.accent.warm or (tone == "default" and theme.colors.text.secondary or theme.colors.text.primary) -- 68
	local accent = tone == "primary" and theme.colors.accent.primary or (tone == "secondary" and theme.colors.accent.secondary or (tone == "success" and theme.colors.state.success or (tone == "warning" and theme.colors.state.warning or (tone == "danger" and theme.colors.state.danger or (tone == "mana" and theme.colors.state.mana or (tone == "warm" and theme.colors.accent.warm or theme.colors.line.normal)))))) -- 70
	local ____React_createElement_8 = React.createElement -- 70
	local ____temp_6 = { -- 70
		key = props.key, -- 70
		ref = props.ref, -- 70
		style = mergeStyle({position = "relative", width = width, height = height}, props.style), -- 70
		visible = props.visible, -- 70
		opacity = props.opacity -- 70
	} -- 70
	local ____React_createElement_result_7 = React.createElement( -- 70
		PaintNode, -- 90
		{ -- 90
			key = "badge-bg", -- 90
			painter = badgePainter(tone, props.outline == true) -- 90
		} -- 90
	) -- 90
	local ____React_createElement_5 = React.createElement -- 90
	local ____Row_3 = Row -- 91
	local ____temp_4 = {key = "badge-content", style = { -- 91
		width = "100%", -- 94
		height = "100%", -- 95
		padding = {0, paddingX}, -- 96
		alignItems = "center", -- 97
		justifyContent = "center", -- 98
		gap = theme.space.xs -- 99
	}} -- 99
	local ____hasDot_0 -- 102
	if hasDot then -- 102
		____hasDot_0 = React.createElement( -- 102
			"align-node", -- 102
			{key = "badge-dot", style = {width = dotSize, height = dotSize}}, -- 102
			React.createElement( -- 102
				PaintNode, -- 104
				{ -- 104
					key = "badge-dot-paint", -- 104
					painter = function(ctx) -- 104
						nvg.BeginPath() -- 107
						nvg.Circle( -- 108
							ctx.width * 0.5, -- 108
							ctx.height * 0.5, -- 108
							math.min(ctx.width, ctx.height) * 0.42 -- 108
						) -- 108
						nvg.FillColor(Color(withAlpha(accent, ctx.opacity))) -- 109
						nvg.Fill() -- 110
					end -- 106
				} -- 106
			) -- 106
		) -- 106
	else -- 106
		____hasDot_0 = nil -- 113
	end -- 113
	local ____hasIcon_1 -- 114
	if hasIcon then -- 114
		____hasIcon_1 = React.createElement(Icon, {key = "badge-icon", icon = props.icon, size = iconSize, color = accent}) -- 114
	else -- 114
		____hasIcon_1 = nil -- 115
	end -- 115
	local ____temp_2 -- 116
	if text ~= "" then -- 116
		____temp_2 = React.createElement(Text, {key = "badge-text", text = text, fontSize = fontSize, color = color}) -- 116
	else -- 116
		____temp_2 = nil -- 117
	end -- 117
	return ____React_createElement_8( -- 78
		"align-node", -- 78
		____temp_6, -- 78
		____React_createElement_result_7, -- 78
		____React_createElement_5( -- 78
			____Row_3, -- 91
			____temp_4, -- 91
			____hasDot_0, -- 91
			____hasIcon_1, -- 91
			____temp_2 -- 91
		) -- 91
	) -- 91
end -- 54
return ____exports -- 54