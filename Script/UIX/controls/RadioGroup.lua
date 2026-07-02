-- [tsx]: RadioGroup.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
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
local ____FocusRing = require("UIX.foundation.FocusRing") -- 7
local FocusRing = ____FocusRing.FocusRing -- 7
local ____Text = require("UIX.foundation.Text") -- 8
local Text = ____Text.Text -- 8
local ____Column = require("UIX.layout.Column") -- 9
local Column = ____Column.Column -- 9
local ____Row = require("UIX.layout.Row") -- 10
local Row = ____Row.Row -- 10
local ____helpers = require("UIX.layout.helpers") -- 11
local mergeStyle = ____helpers.mergeStyle -- 11
local ____PaintNode = require("UIX.paint.PaintNode") -- 12
local PaintNode = ____PaintNode.PaintNode -- 12
local ____color = require("UIX.paint.color") -- 13
local withAlpha = ____color.withAlpha -- 13
local ____Interaction = require("UIX.input.Interaction") -- 14
local useInteraction = ____Interaction.useInteraction -- 14
local function radioDotPainter(selected) -- 46
	return function(ctx) -- 47
		local theme = ctx.theme -- 48
		local state = ctx.state -- 49
		local disabled = state.disabled -- 50
		local size = math.min(ctx.width, ctx.height) -- 51
		local cx = ctx.width * 0.5 -- 52
		local cy = ctx.height * 0.5 -- 53
		local radius = size * 0.36 -- 54
		local stroke = selected and theme.colors.accent.primary or theme.colors.line.normal -- 55
		nvg.BeginPath() -- 57
		nvg.Circle(cx, cy, radius) -- 58
		nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, disabled and theme.painter.disabledAlpha or (selected and 0.22 * ctx.opacity or ctx.opacity)))) -- 59
		nvg.Fill() -- 60
		nvg.StrokeWidth(selected and 2 or theme.stroke.hairline) -- 61
		nvg.StrokeColor(Color(withAlpha(disabled and theme.colors.text.disabled or stroke, disabled and 0.38 or ctx.opacity))) -- 62
		nvg.Stroke() -- 63
		if selected then -- 63
			nvg.BeginPath() -- 66
			nvg.Circle(cx, cy, radius * 0.6) -- 67
			nvg.FillColor(Color(withAlpha(disabled and theme.colors.text.disabled or theme.colors.text.primary, ctx.opacity))) -- 68
			nvg.Fill() -- 69
		end -- 69
	end -- 47
end -- 46
local function radioItemSurfacePainter(selected) -- 74
	return function(ctx) -- 75
		local theme = ctx.theme -- 76
		local state = ctx.state -- 77
		local disabled = state.disabled -- 78
		local radius = theme.radius.sm -- 79
		local fill = disabled and theme.colors.surface.sunken or (selected and theme.colors.accent.primary or (state.pressed and theme.colors.surface.raised or theme.colors.surface.base)) -- 80
		local fillAlpha = disabled and theme.painter.disabledAlpha * ctx.opacity or (selected and (state.pressed and 0.3 or 0.18) * ctx.opacity or ctx.opacity) -- 83
		local stroke = selected and theme.colors.accent.primary or theme.colors.line.normal -- 86
		nvg.BeginPath() -- 88
		nvg.RoundedRect( -- 89
			0, -- 89
			0, -- 89
			ctx.width, -- 89
			ctx.height, -- 89
			radius -- 89
		) -- 89
		nvg.FillColor(Color(withAlpha(fill, fillAlpha))) -- 90
		nvg.Fill() -- 91
		nvg.StrokeWidth(selected and theme.stroke.normal or theme.stroke.hairline) -- 92
		nvg.StrokeColor(Color(withAlpha(stroke, disabled and 0.38 or ctx.opacity))) -- 93
		nvg.Stroke() -- 94
	end -- 75
end -- 74
local function RadioOption(props) -- 98
	local theme = getUiContext().theme -- 99
	local disabled = props.item.disabled == true -- 100
	local interaction = useInteraction({disabled = disabled, selected = props.selected}) -- 101
	if props.focused and not interaction.state.focused then -- 101
		interaction.setFocused(true) -- 106
	end -- 106
	local textColor = disabled and theme.colors.text.disabled or (props.selected and theme.colors.text.primary or theme.colors.text.secondary) -- 108
	local ____React_createElement_7 = React.createElement -- 108
	local ____temp_5 = { -- 108
		key = props.item.id, -- 108
		ref = props.item.ref, -- 108
		style = {position = "relative", width = props.width, height = props.height, minWidth = props.height}, -- 108
		touchEnabled = not disabled, -- 108
		swallowTouches = true, -- 108
		onTapBegan = function() return interaction.setPressed(true) end, -- 108
		onTapEnded = function() return interaction.setPressed(false) end, -- 108
		onTapped = function() -- 108
			if not disabled and not props.selected then -- 108
				local ____opt_0 = props.onSelect -- 108
				if ____opt_0 ~= nil then -- 108
					____opt_0(props.item.id) -- 124
				end -- 124
			end -- 124
		end, -- 123
		onUnmount = function() return interaction.reset() end -- 123
	} -- 123
	local ____React_createElement_result_6 = React.createElement( -- 123
		PaintNode, -- 128
		{ -- 128
			key = "radio-item-surface", -- 128
			state = interaction.state, -- 128
			painter = radioItemSurfacePainter(props.selected) -- 128
		} -- 128
	) -- 128
	local ____React_createElement_4 = React.createElement -- 128
	local ____array_3 = __TS__SparseArrayNew( -- 128
		Row, -- 129
		{key = "radio-item-content", style = { -- 129
			width = "100%", -- 132
			height = "100%", -- 133
			padding = {0, theme.space.sm}, -- 134
			alignItems = "center", -- 135
			justifyContent = "flex-start", -- 136
			gap = theme.space.xs -- 137
		}}, -- 137
		React.createElement( -- 137
			"align-node", -- 137
			{key = "radio-dot", style = {width = 20, height = 20}}, -- 137
			React.createElement( -- 137
				PaintNode, -- 141
				{ -- 141
					key = "radio-dot-paint", -- 141
					state = interaction.state, -- 141
					painter = radioDotPainter(props.selected) -- 141
				} -- 141
			) -- 141
		) -- 141
	) -- 141
	local ____temp_2 -- 143
	if props.item.icon ~= nil then -- 143
		____temp_2 = React.createElement(Icon, { -- 143
			key = "radio-icon", -- 143
			icon = props.item.icon, -- 143
			size = theme.size.icon.sm, -- 143
			color = textColor, -- 143
			disabled = disabled -- 143
		}) -- 143
	else -- 143
		____temp_2 = nil -- 144
	end -- 144
	__TS__SparseArrayPush( -- 144
		____array_3, -- 144
		____temp_2, -- 144
		React.createElement(Text, {key = "radio-label", text = props.item.label, fontSize = theme.font.size.sm, color = textColor}) -- 144
	) -- 144
	return ____React_createElement_7( -- 109
		"align-node", -- 109
		____temp_5, -- 109
		____React_createElement_result_6, -- 109
		____React_createElement_4(__TS__SparseArraySpread(____array_3)), -- 109
		React.createElement(FocusRing, {key = "radio-focus-ring", active = interaction.state.focused, disabled = disabled}) -- 109
	) -- 109
end -- 98
function ____exports.RadioGroup(props) -- 152
	local theme = getUiContext().theme -- 153
	local direction = props.direction or "column" -- 154
	local height = props.itemHeight or theme.size.control.md -- 155
	local gap = props.gap or theme.space.sm -- 156
	local items = __TS__ArrayMap( -- 157
		props.items, -- 157
		function(____, item) return React.createElement(RadioOption, { -- 157
			key = item.id, -- 157
			item = item, -- 157
			selected = item.id == props.value, -- 157
			focused = item.id == props.focusedId, -- 157
			width = props.itemWidth, -- 157
			height = height, -- 157
			onSelect = props.onValueChange -- 157
		}) end -- 157
	) -- 157
	local ____mergeStyle_14 = mergeStyle -- 168
	local ____gap_12 = gap -- 169
	local ____opt_8 = props.style -- 169
	local ____temp_13 = ____opt_8 and ____opt_8.width -- 170
	local ____opt_10 = props.style -- 170
	local commonStyle = ____mergeStyle_14({gap = ____gap_12, width = ____temp_13, height = ____opt_10 and ____opt_10.height}, props.style) -- 168
	local ____temp_15 -- 173
	if direction == "row" then -- 173
		____temp_15 = React.createElement(Row, {key = props.key, style = commonStyle, visible = props.visible, opacity = props.opacity}, items) -- 173
	else -- 173
		____temp_15 = React.createElement(Column, {key = props.key, style = commonStyle, visible = props.visible, opacity = props.opacity}, items) -- 177
	end -- 177
	return ____temp_15 -- 173
end -- 152
return ____exports -- 152