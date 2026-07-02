-- [tsx]: Stepper.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____Button = require("UIX.controls.Button") -- 6
local Button = ____Button.Button -- 6
local ____Icon = require("UIX.foundation.Icon") -- 7
local Icon = ____Icon.Icon -- 7
local ____Text = require("UIX.foundation.Text") -- 8
local Text = ____Text.Text -- 8
local ____Row = require("UIX.layout.Row") -- 9
local Row = ____Row.Row -- 9
local ____helpers = require("UIX.layout.helpers") -- 10
local mergeStyle = ____helpers.mergeStyle -- 10
local ____PaintNode = require("UIX.paint.PaintNode") -- 11
local PaintNode = ____PaintNode.PaintNode -- 11
local ____color = require("UIX.paint.color") -- 12
local withAlpha = ____color.withAlpha -- 12
local ____types = require("UIX.types") -- 13
local clamp = ____types.clamp -- 13
local function normalizeValue(value, min, max, step) -- 30
	local snapped = step > 0 and min + math.floor((value - min) / step + 0.5) * step or value -- 31
	return clamp(snapped, min, max) -- 32
end -- 30
local function stepperValueSurface() -- 35
	return function(ctx) -- 36
		local theme = ctx.theme -- 37
		nvg.BeginPath() -- 38
		nvg.RoundedRect( -- 39
			0, -- 39
			0, -- 39
			ctx.width, -- 39
			ctx.height, -- 39
			theme.radius.sm -- 39
		) -- 39
		nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, ctx.state.disabled and theme.painter.disabledAlpha or ctx.opacity))) -- 40
		nvg.Fill() -- 41
		nvg.StrokeWidth(theme.stroke.hairline) -- 42
		nvg.StrokeColor(Color(withAlpha(theme.colors.line.subtle, ctx.state.disabled and 0.38 or ctx.opacity))) -- 43
		nvg.Stroke() -- 44
	end -- 36
end -- 35
function ____exports.Stepper(props) -- 48
	local theme = getUiContext().theme -- 49
	local min = props.min or 0 -- 50
	local max = props.max or 999 -- 51
	local step = props.step or 1 -- 52
	local disabled = props.disabled == true -- 53
	local value = normalizeValue(props.value, min, max, step) -- 54
	local canDecrease = not disabled and value > min -- 55
	local canIncrease = not disabled and value < max -- 56
	local ____opt_0 = props.formatValue -- 56
	local display = ____opt_0 and ____opt_0(value) or tostring(value) -- 57
	local valueWidth = props.valueWidth or 76 -- 58
	local height = theme.size.control.md -- 59
	local function emit(next) -- 60
		if disabled then -- 60
			return -- 61
		end -- 61
		local normalized = normalizeValue(next, min, max, step) -- 62
		if normalized ~= value then -- 62
			local ____opt_2 = props.onValueChange -- 62
			if ____opt_2 ~= nil then -- 62
				____opt_2(normalized) -- 63
			end -- 63
		end -- 63
	end -- 60
	local textColor = disabled and theme.colors.text.disabled or theme.colors.text.primary -- 65
	local ____React_createElement_12 = React.createElement -- 65
	local ____array_11 = __TS__SparseArrayNew( -- 65
		Row, -- 67
		{ -- 67
			key = props.key, -- 67
			ref = props.ref, -- 67
			style = mergeStyle({height = height, alignItems = "center", gap = 6}, props.style), -- 67
			visible = props.visible, -- 67
			opacity = props.opacity -- 67
		}, -- 67
		React.createElement( -- 67
			Button, -- 78
			{ -- 78
				key = "stepper-dec", -- 78
				ref = props.decreaseRef, -- 78
				variant = "ghost", -- 78
				icon = "minus", -- 78
				disabled = not canDecrease, -- 78
				style = {width = height, height = height}, -- 78
				onClick = function() return emit(value - step) end -- 78
			} -- 78
		) -- 78
	) -- 78
	local ____React_createElement_10 = React.createElement -- 78
	local ____temp_8 = {key = "stepper-value", style = {position = "relative", width = valueWidth, height = height}} -- 78
	local ____React_createElement_result_9 = React.createElement( -- 78
		PaintNode, -- 95
		{ -- 95
			key = "stepper-value-bg", -- 95
			state = {disabled = disabled}, -- 95
			painter = stepperValueSurface() -- 95
		} -- 95
	) -- 95
	local ____React_createElement_7 = React.createElement -- 95
	local ____array_6 = __TS__SparseArrayNew(Row, {key = "stepper-value-content", style = { -- 95
		width = "100%", -- 99
		height = "100%", -- 100
		padding = {0, theme.space.sm}, -- 101
		alignItems = "center", -- 102
		justifyContent = "center", -- 103
		gap = theme.space.xs -- 104
	}}) -- 104
	local ____temp_4 -- 107
	if props.prefixIcon ~= nil then -- 107
		____temp_4 = React.createElement(Icon, { -- 107
			key = "stepper-prefix", -- 107
			icon = props.prefixIcon, -- 107
			size = theme.size.icon.sm, -- 107
			color = textColor, -- 107
			disabled = disabled -- 107
		}) -- 107
	else -- 107
		____temp_4 = nil -- 108
	end -- 108
	__TS__SparseArrayPush( -- 108
		____array_6, -- 108
		____temp_4, -- 108
		React.createElement(Text, {key = "stepper-text", text = display, fontSize = theme.font.size.md, color = textColor}) -- 108
	) -- 108
	local ____temp_5 -- 110
	if props.suffixLabel ~= nil then -- 110
		____temp_5 = React.createElement(Text, {key = "stepper-suffix", text = props.suffixLabel, fontSize = theme.font.size.xs, color = disabled and theme.colors.text.disabled or theme.colors.text.secondary}) -- 110
	else -- 110
		____temp_5 = nil -- 111
	end -- 111
	__TS__SparseArrayPush(____array_6, ____temp_5) -- 111
	__TS__SparseArrayPush( -- 111
		____array_11, -- 111
		____React_createElement_10( -- 111
			"align-node", -- 111
			____temp_8, -- 111
			____React_createElement_result_9, -- 111
			____React_createElement_7(__TS__SparseArraySpread(____array_6)) -- 111
		), -- 111
		React.createElement( -- 111
			Button, -- 114
			{ -- 114
				key = "stepper-inc", -- 114
				ref = props.increaseRef, -- 114
				variant = "secondary", -- 114
				icon = "plus", -- 114
				disabled = not canIncrease, -- 114
				style = {width = height, height = height}, -- 114
				onClick = function() return emit(value + step) end -- 114
			} -- 114
		) -- 114
	) -- 114
	return ____React_createElement_12(__TS__SparseArraySpread(____array_11)) -- 66
end -- 48
return ____exports -- 48