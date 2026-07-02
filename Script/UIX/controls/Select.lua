-- [tsx]: Select.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local useSignal = ____DoraX.useSignal -- 2
local ____Button = require("UIX.controls.Button") -- 3
local Button = ____Button.Button -- 3
local ____Icon = require("UIX.foundation.Icon") -- 4
local Icon = ____Icon.Icon -- 4
local ____Text = require("UIX.foundation.Text") -- 5
local Text = ____Text.Text -- 5
local ____Column = require("UIX.layout.Column") -- 6
local Column = ____Column.Column -- 6
local ____Row = require("UIX.layout.Row") -- 7
local Row = ____Row.Row -- 7
local ____helpers = require("UIX.layout.helpers") -- 8
local mergeStyle = ____helpers.mergeStyle -- 8
local ____context = require("UIX.context") -- 10
local getUiContext = ____context.getUiContext -- 10
local ____PaintNode = require("UIX.paint.PaintNode") -- 11
local PaintNode = ____PaintNode.PaintNode -- 11
local ____primitives = require("UIX.paint.primitives") -- 12
local roundedPanel = ____primitives.roundedPanel -- 12
local function findSelectedItem(items, value) -- 33
	for ____, item in ipairs(items) do -- 34
		if item.id == value then -- 34
			return item -- 35
		end -- 35
	end -- 35
	return nil -- 37
end -- 33
function ____exports.Select(props) -- 40
	local theme = getUiContext().theme -- 41
	local localOpen = useSignal(false) -- 42
	local ____props_open_0 = props.open -- 43
	if ____props_open_0 == nil then -- 43
		____props_open_0 = localOpen.value -- 43
	end -- 43
	local open = ____props_open_0 -- 43
	local selected = findSelectedItem(props.items, props.value) -- 44
	local size = props.size or "md" -- 45
	local controlHeight = theme.size.control[size] -- 46
	local itemHeight = theme.size.control.sm -- 47
	local menuHeight = math.min(props.dropdownMaxHeight or 168, #props.items * (itemHeight + theme.space.xs) + theme.space.xs) -- 48
	local function setOpen(value) -- 49
		if props.open == nil then -- 49
			localOpen.value = value -- 50
		end -- 50
		local ____opt_1 = props.onOpenChange -- 50
		if ____opt_1 ~= nil then -- 50
			____opt_1(value) -- 51
		end -- 51
	end -- 49
	local function selectItem(item) -- 53
		if item.disabled == true or props.disabled == true then -- 53
			return -- 54
		end -- 54
		local ____opt_3 = props.onValueChange -- 54
		if ____opt_3 ~= nil then -- 54
			____opt_3(item.id) -- 55
		end -- 55
		setOpen(false) -- 56
	end -- 53
	local ____React_createElement_18 = React.createElement -- 53
	local ____array_17 = __TS__SparseArrayNew( -- 53
		Column, -- 59
		{ -- 59
			key = props.key, -- 59
			ref = props.ref, -- 59
			gap = theme.space.xs, -- 59
			style = mergeStyle({position = "relative", width = 180}, props.style), -- 59
			visible = props.visible, -- 59
			opacity = props.opacity -- 59
		} -- 59
	) -- 59
	local ____React_createElement_15 = React.createElement -- 59
	local ____Button_13 = Button -- 70
	local ____temp_14 = { -- 70
		key = "select-trigger", -- 70
		size = size, -- 70
		variant = props.variant or "ghost", -- 70
		disabled = props.disabled, -- 70
		style = {width = "100%"}, -- 70
		onClick = function() return setOpen(not open) end -- 70
	} -- 70
	local ____React_createElement_12 = React.createElement -- 70
	local ____Row_10 = Row -- 78
	local ____temp_11 = {style = { -- 78
		width = "100%", -- 79
		height = "100%", -- 80
		padding = {0, theme.space.md}, -- 81
		alignItems = "center", -- 82
		justifyContent = "space-between", -- 83
		gap = theme.space.sm -- 84
	}} -- 84
	local ____temp_7 -- 86
	if (selected and selected.icon) ~= nil then -- 86
		____temp_7 = React.createElement(Icon, {icon = selected.icon, size = theme.size.icon[size], disabled = props.disabled}) -- 86
	else -- 86
		____temp_7 = nil -- 87
	end -- 87
	__TS__SparseArrayPush( -- 87
		____array_17, -- 87
		____React_createElement_15( -- 87
			____Button_13, -- 70
			____temp_14, -- 70
			____React_createElement_12( -- 70
				____Row_10, -- 78
				____temp_11, -- 78
				____temp_7, -- 78
				React.createElement(Text, { -- 78
					text = selected and selected.label or props.placeholder or "Select", -- 78
					fontSize = theme.font.size.md, -- 78
					color = props.disabled == true and theme.colors.text.disabled or theme.colors.text.primary, -- 78
					alignment = "Left", -- 78
					style = {flex = 1, height = controlHeight} -- 78
				}), -- 78
				React.createElement(Icon, {icon = open and "chevronUp" or "chevronDown", size = theme.size.icon.sm, disabled = props.disabled}) -- 78
			) -- 78
		) -- 78
	) -- 78
	local ____open_16 -- 98
	if open then -- 98
		____open_16 = React.createElement( -- 98
			Column, -- 99
			{key = "select-menu", gap = theme.space.xs, style = {position = "relative", width = "100%", height = menuHeight, padding = theme.space.xs}}, -- 99
			React.createElement( -- 99
				PaintNode, -- 109
				{ -- 109
					key = "select-menu-surface", -- 109
					painter = function(ctx) return roundedPanel(ctx, {x = 0, y = 0, width = ctx.width, height = ctx.height}, {variant = "solid", elevated = true}) end -- 109
				} -- 109
			), -- 109
			__TS__ArrayMap( -- 116
				props.items, -- 116
				function(____, item) return React.createElement( -- 116
					Button, -- 117
					{ -- 117
						key = "select-item-" .. item.id, -- 117
						size = "sm", -- 117
						variant = item.id == props.value and "primary" or "ghost", -- 117
						selected = item.id == props.value, -- 117
						disabled = props.disabled == true or item.disabled == true, -- 117
						icon = item.icon, -- 117
						style = {width = "100%", height = itemHeight}, -- 117
						onClick = function() return selectItem(item) end -- 117
					}, -- 117
					item.label -- 127
				) end -- 127
			) -- 127
		) -- 127
	else -- 127
		____open_16 = nil -- 130
	end -- 130
	__TS__SparseArrayPush(____array_17, ____open_16) -- 130
	return ____React_createElement_18(__TS__SparseArraySpread(____array_17)) -- 58
end -- 40
return ____exports -- 40