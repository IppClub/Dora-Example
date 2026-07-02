-- [tsx]: TextInput.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 1
local Color = ____Dora.Color -- 1
local Keyboard = ____Dora.Keyboard -- 1
local Rect = ____Dora.Rect -- 1
local Vec2 = ____Dora.Vec2 -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local useCallback = ____DoraX.useCallback -- 3
local useRef = ____DoraX.useRef -- 3
local useSignal = ____DoraX.useSignal -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____Icon = require("UIX.foundation.Icon") -- 6
local Icon = ____Icon.Icon -- 6
local ____PaintNode = require("UIX.paint.PaintNode") -- 7
local PaintNode = ____PaintNode.PaintNode -- 7
local ____color = require("UIX.paint.color") -- 8
local withAlpha = ____color.withAlpha -- 8
local ____helpers = require("UIX.layout.helpers") -- 9
local mergeStyle = ____helpers.mergeStyle -- 9
local fontIds = {} -- 29
local function getFontId(fontName) -- 31
	local fontId = fontIds[fontName] -- 32
	if fontId == nil or fontId == 0 then -- 32
		fontId = nvg.CreateFont(fontName) -- 34
		fontIds[fontName] = fontId -- 35
	end -- 35
	return fontId -- 37
end -- 31
local function utf8Len(text) -- 40
	local len = utf8.len(text) -- 41
	return len or #text -- 42
end -- 40
local function utf8Head(text, count) -- 45
	if count <= 0 then -- 45
		return "" -- 46
	end -- 46
	local nextPos = utf8.offset(text, count + 1) -- 47
	return nextPos == nil and text or string.sub(text, 1, nextPos - 1) -- 48
end -- 45
local function utf8DropTail(text, count) -- 51
	return utf8Head( -- 52
		text, -- 52
		math.max( -- 52
			0, -- 52
			utf8Len(text) - count -- 52
		) -- 52
	) -- 52
end -- 51
local function limitText(text, maxLength) -- 55
	if maxLength == nil or maxLength <= 0 then -- 55
		return text -- 56
	end -- 56
	return utf8Head(text, maxLength) -- 57
end -- 55
local function measureTextWidth(fontName, fontSize, text) -- 60
	nvg.FontFaceId(getFontId(fontName)) -- 61
	nvg.FontSize(fontSize) -- 62
	local bounds = Rect(0, 0, 0, 0) -- 63
	return nvg.TextBounds(0, 0, text, bounds) -- 64
end -- 60
local function displayBase(text, editing) -- 67
	local editingLen = utf8Len(editing) -- 68
	return editingLen > 0 and utf8DropTail(text, editingLen) or text -- 69
end -- 67
function ____exports.TextInput(props) -- 72
	local ui = getUiContext() -- 73
	local theme = ui.theme -- 74
	local size = props.size or "md" -- 75
	local height = theme.size.control[size] -- 76
	local fontName = props.fontName or theme.font.name -- 77
	local fontSize = props.fontSize or theme.font.size.md -- 78
	local iconSize = theme.size.icon[size] -- 79
	local disabled = props.disabled == true -- 80
	local localValue = useSignal(props.defaultValue or "") -- 81
	local focused = useSignal(props.focused == true) -- 82
	local editing = useRef("") -- 83
	local editingBase = useRef(nil) -- 84
	local valueRef = useRef("") -- 85
	local rootRef = props.ref or useRef() -- 86
	local ____opt_0 = props.style -- 86
	local styleWidth = ____opt_0 and ____opt_0.width -- 87
	local ____opt_2 = props.style -- 87
	local width = (____opt_2 and ____opt_2.width) == nil and 220 or styleWidth -- 88
	local textValue = props.value or localValue.value -- 89
	valueRef.current = textValue -- 90
	local setFocused = useCallback( -- 92
		function(next) -- 92
			if disabled then -- 92
				return -- 93
			end -- 93
			if focused.value ~= next then -- 93
				focused.value = next -- 95
				local ____opt_4 = props.onFocusChange -- 95
				if ____opt_4 ~= nil then -- 95
					____opt_4(next) -- 96
				end -- 96
			end -- 96
		end, -- 92
		{disabled, focused.value, props.onFocusChange} -- 98
	) -- 98
	local updateIMEPos = useCallback( -- 100
		function() -- 100
			local node = rootRef.current -- 101
			if node == nil then -- 101
				return -- 102
			end -- 102
			local leftInset = theme.space.md + (props.prefixIcon ~= nil and iconSize + theme.space.sm or 0) -- 103
			local rightInset = theme.space.md + (props.suffixIcon ~= nil and iconSize + theme.space.sm or 0) -- 104
			local textWidth = math.max(1, node.width - leftInset - rightInset) -- 105
			local text = valueRef.current or "" -- 106
			local contentWidth = measureTextWidth(fontName, fontSize, text) -- 107
			local offsetX = math.max(contentWidth + 4 - textWidth, 0) -- 108
			local cursorX = leftInset + math.max(0, contentWidth - offsetX) -- 109
			node:convertToWindowSpace( -- 110
				Vec2(cursorX, height * 0.5), -- 110
				function(pos) -- 110
					Keyboard:updateIMEPosHint(pos) -- 111
				end -- 110
			) -- 110
		end, -- 100
		{ -- 113
			fontName, -- 113
			fontSize, -- 113
			height, -- 113
			iconSize, -- 113
			props.prefixIcon, -- 113
			props.suffixIcon, -- 113
			theme.space.md, -- 113
			theme.space.sm -- 113
		} -- 113
	) -- 113
	local emitValue = useCallback( -- 115
		function(nextValue) -- 115
			local next = limitText(nextValue, props.maxLength) -- 116
			if props.value == nil then -- 116
				localValue.value = next -- 117
			end -- 117
			valueRef.current = next -- 118
			local ____opt_6 = props.onValueChange -- 118
			if ____opt_6 ~= nil then -- 118
				____opt_6(next) -- 119
			end -- 119
			updateIMEPos() -- 120
		end, -- 115
		{ -- 121
			localValue.value, -- 121
			props.maxLength, -- 121
			props.onValueChange, -- 121
			props.value, -- 121
			updateIMEPos, -- 121
			valueRef -- 121
		} -- 121
	) -- 121
	local attachInput = useCallback( -- 123
		function() -- 123
			local node = rootRef.current -- 124
			if node == nil or disabled then -- 124
				return -- 125
			end -- 125
			updateIMEPos() -- 126
			node:detachIME() -- 127
			node:attachIME() -- 128
			updateIMEPos() -- 129
		end, -- 123
		{disabled, updateIMEPos} -- 130
	) -- 130
	local onAttachIME = useCallback( -- 132
		function() -- 132
			local node = rootRef.current -- 133
			if node ~= nil then -- 133
				node.keyboardEnabled = true -- 134
			end -- 134
			editing.current = "" -- 135
			editingBase.current = nil -- 136
			setFocused(true) -- 137
		end, -- 132
		{editing, editingBase, setFocused} -- 138
	) -- 138
	local onDetachIME = useCallback( -- 140
		function() -- 140
			local node = rootRef.current -- 141
			if node ~= nil then -- 141
				node.keyboardEnabled = false -- 142
			end -- 142
			editing.current = "" -- 143
			editingBase.current = nil -- 144
			setFocused(false) -- 145
		end, -- 140
		{editing, editingBase, setFocused} -- 146
	) -- 146
	local onTextInput = useCallback( -- 148
		function(text) -- 148
			if disabled then -- 148
				return -- 149
			end -- 149
			local base = editingBase.current or displayBase(valueRef.current or "", editing.current or "") -- 150
			editing.current = "" -- 151
			editingBase.current = nil -- 152
			emitValue(base .. text) -- 153
		end, -- 148
		{disabled, editing, editingBase, emitValue} -- 154
	) -- 154
	local onTextEditing = useCallback( -- 156
		function(text) -- 156
			if disabled then -- 156
				return -- 157
			end -- 157
			local base = editingBase.current or displayBase(valueRef.current or "", editing.current or "") -- 158
			if text == "" then -- 158
				editing.current = "" -- 160
				editingBase.current = nil -- 161
				if props.value == nil then -- 161
					localValue.value = base -- 162
				end -- 162
				valueRef.current = base -- 163
				local ____opt_8 = props.onValueChange -- 163
				if ____opt_8 ~= nil then -- 163
					____opt_8(base) -- 164
				end -- 164
				updateIMEPos() -- 165
				return -- 166
			end -- 166
			editingBase.current = base -- 168
			local next = limitText(base .. text, props.maxLength) -- 169
			editing.current = text -- 170
			if props.value == nil then -- 170
				localValue.value = next -- 171
			end -- 171
			valueRef.current = next -- 172
			local ____opt_10 = props.onValueChange -- 172
			if ____opt_10 ~= nil then -- 172
				____opt_10(next) -- 173
			end -- 173
			updateIMEPos() -- 174
		end, -- 156
		{ -- 175
			disabled, -- 175
			editing, -- 175
			editingBase, -- 175
			localValue.value, -- 175
			props.maxLength, -- 175
			props.onValueChange, -- 175
			props.value, -- 175
			updateIMEPos, -- 175
			valueRef -- 175
		} -- 175
	) -- 175
	local onKeyPressed = useCallback( -- 177
		function(key) -- 177
			if disabled then -- 177
				return -- 178
			end -- 178
			if App.platform == "Android" and utf8Len(editing.current or "") == 1 then -- 178
				if key == "BackSpace" then -- 178
					editing.current = "" -- 181
					editingBase.current = nil -- 182
				end -- 182
			elseif (editing.current or "") ~= "" then -- 182
				return -- 185
			end -- 185
			if key == "BackSpace" then -- 185
				editingBase.current = nil -- 188
				local next = utf8DropTail(valueRef.current or "", 1) -- 189
				emitValue(next) -- 190
			elseif key == "Return" then -- 190
				editingBase.current = nil -- 192
				local ____opt_12 = rootRef.current -- 192
				if ____opt_12 ~= nil then -- 192
					____opt_12:detachIME() -- 193
				end -- 193
				local ____opt_14 = props.onSubmit -- 193
				if ____opt_14 ~= nil then -- 193
					____opt_14(valueRef.current or "") -- 194
				end -- 194
			elseif key == "Escape" then -- 194
				editingBase.current = nil -- 196
				local ____opt_16 = rootRef.current -- 196
				if ____opt_16 ~= nil then -- 196
					____opt_16:detachIME() -- 197
				end -- 197
			end -- 197
		end, -- 177
		{ -- 199
			disabled, -- 199
			editing, -- 199
			editingBase, -- 199
			emitValue, -- 199
			props.onSubmit -- 199
		} -- 199
	) -- 199
	local state = {disabled = disabled, focused = false} -- 201
	local textColor = disabled and theme.colors.text.disabled or theme.colors.text.primary -- 202
	local placeholderColor = theme.colors.text.secondary -- 203
	local iconColor = disabled and theme.colors.text.disabled or (focused.value and theme.colors.accent.primary or theme.colors.text.secondary) -- 204
	local prefixOffset = props.prefixIcon ~= nil and iconSize + theme.space.sm or 0 -- 205
	local suffixOffset = props.suffixIcon ~= nil and iconSize + theme.space.sm or 0 -- 206
	local leftInset = theme.space.md + prefixOffset -- 207
	local rightInset = theme.space.md + suffixOffset -- 208
	local controlWidth = width or 220 -- 209
	local textAreaWidth = math.max(1, controlWidth - leftInset - rightInset) -- 210
	local hasText = textValue ~= "" -- 211
	local contentWidth = measureTextWidth(fontName, fontSize, textValue) -- 212
	local offsetX = hasText and focused.value and math.max(contentWidth + 4 - textAreaWidth, 0) or 0 -- 213
	local cursorLeft = leftInset + math.max(0, hasText and contentWidth - offsetX or 0) + 2 -- 214
	local cursorTop = height * 0.24 -- 215
	local cursorHeight = height * 0.52 -- 216
	local ____React_createElement_23 = React.createElement -- 216
	local ____temp_21 = { -- 216
		key = props.key, -- 216
		ref = rootRef, -- 216
		style = mergeStyle({position = "relative", width = width or 220, height = height, minWidth = 96}, props.style), -- 216
		visible = props.visible, -- 216
		opacity = props.opacity, -- 216
		touchEnabled = not disabled, -- 216
		swallowTouches = true, -- 216
		onTapped = attachInput, -- 216
		onAttachIME = onAttachIME, -- 216
		onDetachIME = onDetachIME, -- 216
		onTextInput = onTextInput, -- 216
		onTextEditing = onTextEditing, -- 216
		onKeyPressed = onKeyPressed -- 216
	} -- 216
	local ____React_createElement_result_22 = React.createElement( -- 216
		PaintNode, -- 238
		{ -- 238
			key = "text-input-paint", -- 238
			state = state, -- 238
			painter = function(ctx) -- 238
				local textAreaWidth = math.max(1, ctx.width - leftInset - rightInset) -- 242
				local displayText = valueRef.current or "" -- 243
				local hasText = displayText ~= "" -- 244
				local paintText = hasText and displayText or (props.placeholder or "") -- 245
				local contentWidth = measureTextWidth(fontName, fontSize, displayText) -- 246
				local paintWidth = hasText and contentWidth or measureTextWidth(fontName, fontSize, paintText) -- 247
				local radius = theme.radius.md -- 248
				local active = focused.value and not disabled -- 249
				local offsetX = hasText and active and math.max(contentWidth + 4 - textAreaWidth, 0) or 0 -- 250
				local fillAlpha = disabled and theme.painter.disabledAlpha or 0.72 -- 251
				nvg.BeginPath() -- 252
				nvg.RoundedRect( -- 253
					1, -- 253
					2, -- 253
					ctx.width - 2, -- 253
					ctx.height - 3, -- 253
					radius -- 253
				) -- 253
				nvg.FillColor(Color(withAlpha(4278190080, 0.18 * ctx.opacity))) -- 254
				nvg.Fill() -- 255
				nvg.BeginPath() -- 256
				nvg.RoundedRect( -- 257
					0, -- 257
					0, -- 257
					ctx.width, -- 257
					ctx.height, -- 257
					radius -- 257
				) -- 257
				nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, fillAlpha * ctx.opacity))) -- 258
				nvg.Fill() -- 259
				nvg.BeginPath() -- 260
				nvg.RoundedRect( -- 261
					2, -- 261
					2, -- 261
					ctx.width - 4, -- 261
					ctx.height - 4, -- 261
					math.max(1, radius - 2) -- 261
				) -- 261
				nvg.FillColor(Color(withAlpha(theme.colors.surface.raised, (active and 0.2 or 0.1) * ctx.opacity))) -- 262
				nvg.Fill() -- 263
				if active then -- 263
					nvg.BeginPath() -- 265
					nvg.RoundedRect( -- 266
						3, -- 266
						3, -- 266
						ctx.width - 6, -- 266
						ctx.height - 6, -- 266
						math.max(1, radius - 3) -- 266
					) -- 266
					nvg.FillColor(Color(withAlpha(theme.colors.accent.primary, 0.055 * ctx.opacity))) -- 267
					nvg.Fill() -- 268
				end -- 268
				nvg.BeginPath() -- 270
				nvg.RoundedRect( -- 271
					0.5, -- 271
					0.5, -- 271
					ctx.width - 1, -- 271
					ctx.height - 1, -- 271
					radius -- 271
				) -- 271
				nvg.StrokeWidth(active and 1.5 or theme.stroke.hairline) -- 272
				nvg.StrokeColor(Color(withAlpha(active and theme.colors.accent.primary or theme.colors.line.normal, (disabled and 0.4 or (active and 0.82 or 0.72)) * ctx.opacity))) -- 273
				nvg.Stroke() -- 274
				if active then -- 274
					nvg.BeginPath() -- 276
					nvg.RoundedRect( -- 277
						2.5, -- 277
						2.5, -- 277
						ctx.width - 5, -- 277
						ctx.height - 5, -- 277
						math.max(1, radius - 2) -- 277
					) -- 277
					nvg.StrokeWidth(1) -- 278
					nvg.StrokeColor(Color(withAlpha(theme.colors.focus.glow, 0.65 * ctx.opacity))) -- 279
					nvg.Stroke() -- 280
				end -- 280
				nvg.Save() -- 282
				nvg.IntersectScissor(leftInset, 0, textAreaWidth, ctx.height) -- 283
				nvg.FontFaceId(getFontId(fontName)) -- 284
				nvg.FontSize(fontSize) -- 285
				nvg.TextAlign("Left", "Middle") -- 286
				nvg.FillColor(Color(withAlpha(hasText and textColor or placeholderColor, hasText and ctx.opacity or 0.72 * ctx.opacity))) -- 287
				nvg.Scale(1, -1) -- 288
				nvg.Text(leftInset - offsetX + (hasText and 0 or theme.space.sm), -ctx.height * 0.5, paintText) -- 289
				nvg.Restore() -- 290
			end -- 241
		} -- 241
	) -- 241
	local ____temp_18 -- 293
	if focused.value and not disabled then -- 293
		____temp_18 = React.createElement( -- 293
			"align-node", -- 293
			{key = "text-input-cursor", style = { -- 293
				position = "absolute", -- 297
				left = cursorLeft, -- 298
				top = cursorTop, -- 299
				width = 2, -- 300
				height = cursorHeight -- 301
			}}, -- 301
			React.createElement( -- 301
				PaintNode, -- 304
				{ -- 304
					key = "text-input-cursor-paint", -- 304
					painter = function(ctx) -- 304
						nvg.BeginPath() -- 307
						nvg.RoundedRect( -- 308
							0, -- 308
							0, -- 308
							ctx.width, -- 308
							ctx.height, -- 308
							1 -- 308
						) -- 308
						nvg.FillColor(Color(withAlpha(theme.colors.accent.primary, ctx.node.opacity))) -- 309
						nvg.Fill() -- 310
					end -- 306
				}, -- 306
				React.createElement( -- 306
					"loop", -- 306
					nil, -- 306
					React.createElement("opacity", {time = 0.08, start = 1, stop = 1}), -- 306
					React.createElement("delay", {time = 0.36}), -- 306
					React.createElement("opacity", {time = 0.12, start = 1, stop = 0}), -- 306
					React.createElement("delay", {time = 0.24}), -- 306
					React.createElement("opacity", {time = 0.12, start = 0, stop = 1}) -- 306
				) -- 306
			) -- 306
		) -- 306
	else -- 306
		____temp_18 = nil -- 321
	end -- 321
	local ____temp_19 -- 322
	if props.prefixIcon ~= nil then -- 322
		____temp_19 = React.createElement( -- 322
			"align-node", -- 322
			{key = "text-input-prefix", style = { -- 322
				position = "absolute", -- 326
				left = theme.space.md, -- 327
				top = (height - iconSize) * 0.5, -- 328
				width = iconSize, -- 329
				height = iconSize -- 330
			}}, -- 330
			React.createElement(Icon, {icon = props.prefixIcon, size = iconSize, disabled = disabled, color = iconColor}) -- 330
		) -- 330
	else -- 330
		____temp_19 = nil -- 334
	end -- 334
	local ____temp_20 -- 335
	if props.suffixIcon ~= nil then -- 335
		____temp_20 = React.createElement( -- 335
			"align-node", -- 335
			{key = "text-input-suffix", style = { -- 335
				position = "absolute", -- 339
				right = theme.space.md, -- 340
				top = (height - iconSize) * 0.5, -- 341
				width = iconSize, -- 342
				height = iconSize -- 343
			}}, -- 343
			React.createElement(Icon, {icon = props.suffixIcon, size = iconSize, disabled = disabled, color = iconColor}) -- 343
		) -- 343
	else -- 343
		____temp_20 = nil -- 347
	end -- 347
	return ____React_createElement_23( -- 217
		"align-node", -- 217
		____temp_21, -- 217
		____React_createElement_result_22, -- 217
		____temp_18, -- 217
		____temp_19, -- 217
		____temp_20 -- 217
	) -- 217
end -- 72
return ____exports -- 72