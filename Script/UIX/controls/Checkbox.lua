-- [tsx]: Checkbox.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Color = ____Dora.Color -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____FocusRing = require("UIX.foundation.FocusRing") -- 6
local FocusRing = ____FocusRing.FocusRing -- 6
local ____Text = require("UIX.foundation.Text") -- 7
local Text = ____Text.Text -- 7
local ____Row = require("UIX.layout.Row") -- 8
local Row = ____Row.Row -- 8
local ____helpers = require("UIX.layout.helpers") -- 9
local mergeStyle = ____helpers.mergeStyle -- 9
local ____PaintNode = require("UIX.paint.PaintNode") -- 10
local PaintNode = ____PaintNode.PaintNode -- 10
local ____color = require("UIX.paint.color") -- 11
local withAlpha = ____color.withAlpha -- 11
local ____Interaction = require("UIX.input.Interaction") -- 12
local useInteraction = ____Interaction.useInteraction -- 12
local function checkboxPainter(checked, indeterminate) -- 23
	return function(ctx) -- 24
		local theme = ctx.theme -- 25
		local state = ctx.state -- 26
		local size = math.min(ctx.width, ctx.height) -- 27
		local x = (ctx.width - size) * 0.5 -- 28
		local y = (ctx.height - size) * 0.5 -- 29
		local radius = math.max(3, size * 0.18) -- 30
		local active = checked or indeterminate -- 31
		local disabled = state.disabled -- 32
		local fill = disabled and withAlpha(theme.colors.surface.sunken, theme.painter.disabledAlpha) or (active and withAlpha(theme.colors.accent.primary, state.pressed and 0.72 or 0.58) or theme.colors.surface.sunken) -- 33
		local stroke = active and theme.colors.accent.primary or theme.colors.line.normal -- 36
		nvg.BeginPath() -- 38
		nvg.RoundedRect( -- 39
			x, -- 39
			y, -- 39
			size, -- 39
			size, -- 39
			radius -- 39
		) -- 39
		nvg.FillColor(Color(withAlpha(fill, ctx.opacity))) -- 40
		nvg.Fill() -- 41
		nvg.StrokeWidth(active and theme.stroke.normal or theme.stroke.hairline) -- 42
		nvg.StrokeColor(Color(withAlpha(stroke, disabled and 0.38 or ctx.opacity))) -- 43
		nvg.Stroke() -- 44
		if indeterminate then -- 44
			nvg.BeginPath() -- 47
			nvg.MoveTo(x + size * 0.28, y + size * 0.5) -- 48
			nvg.LineTo(x + size * 0.72, y + size * 0.5) -- 49
			nvg.StrokeWidth(3) -- 50
			nvg.StrokeColor(Color(withAlpha(disabled and theme.colors.text.disabled or theme.colors.text.primary, ctx.opacity))) -- 51
			nvg.Stroke() -- 52
		elseif checked then -- 52
			nvg.BeginPath() -- 54
			nvg.MoveTo(x + size * 0.24, y + size * 0.48) -- 55
			nvg.LineTo(x + size * 0.43, y + size * 0.3) -- 56
			nvg.LineTo(x + size * 0.78, y + size * 0.7) -- 57
			nvg.StrokeWidth(3) -- 58
			nvg.StrokeColor(Color(withAlpha(disabled and theme.colors.text.disabled or theme.colors.text.primary, ctx.opacity))) -- 59
			nvg.Stroke() -- 60
		end -- 60
	end -- 24
end -- 23
function ____exports.Checkbox(props) -- 65
	local theme = getUiContext().theme -- 66
	local disabled = props.disabled == true -- 67
	local interaction = useInteraction({disabled = disabled, selected = props.checked or props.indeterminate == true}) -- 68
	if props.focused == true and not interaction.state.focused then -- 68
		interaction.setFocused(true) -- 73
	end -- 73
	local boxSize = 28 -- 75
	local control = React.createElement( -- 76
		"align-node", -- 76
		{ -- 76
			ref = props.ref, -- 76
			style = {position = "relative", width = boxSize, height = boxSize}, -- 76
			touchEnabled = not disabled, -- 76
			swallowTouches = true, -- 76
			onTapBegan = function() return interaction.setPressed(true) end, -- 76
			onTapEnded = function() return interaction.setPressed(false) end, -- 76
			onTapped = function() -- 76
				if not disabled then -- 76
					local ____opt_0 = props.onChange -- 76
					if ____opt_0 ~= nil then -- 76
						____opt_0(not props.checked) -- 85
					end -- 85
				end -- 85
			end, -- 84
			onUnmount = function() return interaction.reset() end -- 84
		}, -- 84
		React.createElement( -- 84
			PaintNode, -- 89
			{ -- 89
				key = "checkbox-surface", -- 89
				state = interaction.state, -- 89
				painter = checkboxPainter(props.checked, props.indeterminate == true) -- 89
			} -- 89
		), -- 89
		React.createElement(FocusRing, {key = "checkbox-focus-ring", active = interaction.state.focused, disabled = disabled}) -- 89
	) -- 89
	local ____React_createElement_5 = React.createElement -- 89
	local ____Row_3 = Row -- 98
	local ____temp_4 = { -- 98
		key = props.key, -- 98
		style = mergeStyle({height = theme.size.control.sm, alignItems = "center", gap = theme.space.sm}, props.style), -- 98
		visible = props.visible, -- 98
		opacity = props.opacity -- 98
	} -- 98
	local ____temp_2 -- 105
	if props.label ~= nil then -- 105
		____temp_2 = React.createElement(Text, {text = props.label, fontSize = theme.font.size.sm, color = disabled and theme.colors.text.disabled or theme.colors.text.primary}) -- 105
	else -- 105
		____temp_2 = nil -- 106
	end -- 106
	return ____React_createElement_5(____Row_3, ____temp_4, control, ____temp_2) -- 97
end -- 65
return ____exports -- 65