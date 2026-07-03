-- [tsx]: Text.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__StringSplit = ____lualib.__TS__StringSplit -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Color = ____Dora.Color -- 1
local Rect = ____Dora.Rect -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local nvg = require("nvg") -- 4
local ____context = require("UIX.context") -- 5
local getUiContext = ____context.getUiContext -- 5
local ____PaintNode = require("UIX.paint.PaintNode") -- 6
local PaintNode = ____PaintNode.PaintNode -- 6
local ____helpers = require("UIX.layout.helpers") -- 8
local mergeStyle = ____helpers.mergeStyle -- 8
local textFromChildren = ____helpers.textFromChildren -- 8
local fontIds = {} -- 24
local wrapCharWidthRatio = 0.58 -- 25
local function getFontId(fontName) -- 27
	local fontId = fontIds[fontName] -- 28
	if fontId == nil or fontId == 0 then -- 28
		fontId = nvg.CreateFont(fontName) -- 30
		fontIds[fontName] = fontId -- 31
	end -- 31
	return fontId -- 33
end -- 27
local function toNvgAlign(alignment) -- 36
	if alignment == "Left" then -- 36
		return "Left" -- 37
	end -- 37
	if alignment == "Right" then -- 37
		return "Right" -- 38
	end -- 38
	return "Center" -- 39
end -- 36
local function splitTextLines(text) -- 42
	local lines = __TS__StringSplit(text, "\n") -- 43
	return #lines > 0 and lines or ({""}) -- 44
end -- 42
local function longestLineLength(text) -- 47
	local length = 0 -- 48
	for ____, line in ipairs(splitTextLines(text)) do -- 49
		length = math.max(length, #line) -- 50
	end -- 50
	return length -- 52
end -- 47
local function splitLongWord(word, maxChars, out) -- 55
	local index = 0 -- 56
	while index < #word do -- 56
		out[#out + 1] = __TS__StringSubstring(word, index, index + maxChars) -- 58
		index = index + maxChars -- 59
	end -- 59
end -- 55
function ____exports.wrapTextLines(text, maxWidth, fontSize) -- 63
	local charWidth = math.max(1, fontSize * wrapCharWidthRatio) -- 64
	local maxChars = math.max( -- 65
		1, -- 65
		math.floor(maxWidth / charWidth) -- 65
	) -- 65
	local lines = {} -- 66
	for ____, paragraph in ipairs(__TS__StringSplit(text, "\n")) do -- 67
		local line = "" -- 68
		for ____, word in ipairs(__TS__StringSplit(paragraph, " ")) do -- 69
			do -- 69
				if word == "" then -- 69
					goto __continue15 -- 70
				end -- 70
				if #word > maxChars then -- 70
					if line ~= "" then -- 70
						lines[#lines + 1] = line -- 73
						line = "" -- 74
					end -- 74
					splitLongWord(word, maxChars, lines) -- 76
					goto __continue15 -- 77
				end -- 77
				local next = line == "" and word or (line .. " ") .. word -- 79
				if #next > maxChars then -- 79
					if line ~= "" then -- 79
						lines[#lines + 1] = line -- 81
					end -- 81
					line = word -- 82
				else -- 82
					line = next -- 84
				end -- 84
			end -- 84
			::__continue15:: -- 84
		end -- 84
		lines[#lines + 1] = line -- 87
	end -- 87
	return #lines > 0 and lines or ({""}) -- 89
end -- 63
local function measureTextWidth(text) -- 92
	local bounds = Rect(0, 0, 0, 0) -- 93
	return nvg.TextBounds(0, 0, text, bounds) -- 94
end -- 92
local function splitLongWordMeasured(word, maxWidth, out) -- 97
	local chunk = "" -- 98
	for i = 1, #word do -- 98
		local next = chunk .. __TS__StringSubstring(word, i - 1, i) -- 100
		if chunk ~= "" and measureTextWidth(next) > maxWidth then -- 100
			out[#out + 1] = chunk -- 102
			chunk = __TS__StringSubstring(word, i - 1, i) -- 103
		else -- 103
			chunk = next -- 105
		end -- 105
	end -- 105
	if chunk ~= "" then -- 105
		out[#out + 1] = chunk -- 108
	end -- 108
end -- 97
local function wrapTextLinesMeasured(text, maxWidth) -- 111
	local lines = {} -- 112
	for ____, paragraph in ipairs(__TS__StringSplit(text, "\n")) do -- 113
		local line = "" -- 114
		for ____, word in ipairs(__TS__StringSplit(paragraph, " ")) do -- 115
			do -- 115
				if word == "" then -- 115
					goto __continue32 -- 116
				end -- 116
				if measureTextWidth(word) > maxWidth then -- 116
					if line ~= "" then -- 116
						lines[#lines + 1] = line -- 119
						line = "" -- 120
					end -- 120
					splitLongWordMeasured(word, maxWidth, lines) -- 122
					goto __continue32 -- 123
				end -- 123
				local next = line == "" and word or (line .. " ") .. word -- 125
				if line ~= "" and measureTextWidth(next) > maxWidth then -- 125
					lines[#lines + 1] = line -- 127
					line = word -- 128
				else -- 128
					line = next -- 130
				end -- 130
			end -- 130
			::__continue32:: -- 130
		end -- 130
		lines[#lines + 1] = line -- 133
	end -- 133
	return #lines > 0 and lines or ({""}) -- 135
end -- 111
local function textLinesMeasured(text, wrap, maxWidth) -- 138
	return wrap and wrapTextLinesMeasured(text, maxWidth) or splitTextLines(text) -- 139
end -- 138
local function firstLineY(height, blockHeight, lineHeight, verticalAlign) -- 142
	if verticalAlign == "top" then -- 142
		return lineHeight * 0.5 -- 143
	end -- 143
	if verticalAlign == "bottom" then -- 143
		return height - blockHeight + lineHeight * 0.5 -- 144
	end -- 144
	return (height - blockHeight) * 0.5 + lineHeight * 0.5 -- 145
end -- 142
function ____exports.Text(props) -- 148
	local theme = getUiContext().theme -- 149
	local value = textFromChildren( -- 150
		props.children, -- 150
		props.text ~= nil and tostring(props.text) or "" -- 150
	) -- 150
	local fontSize = props.fontSize or theme.font.size.md -- 151
	local fontName = props.fontName or theme.font.name -- 152
	local hAlign = toNvgAlign(props.alignment) -- 153
	local lineHeight = props.lineHeight or fontSize * 1.25 -- 154
	local explicitLineCount = #splitTextLines(value) -- 155
	local estimatedWidth = math.max( -- 156
		fontSize, -- 156
		longestLineLength(value) * fontSize * 0.62 + 4 -- 156
	) -- 156
	local estimatedHeight = math.max(fontSize, lineHeight * explicitLineCount) -- 157
	return React.createElement( -- 158
		"align-node", -- 158
		{ -- 158
			key = props.key, -- 158
			ref = props.ref, -- 158
			order = props.order, -- 158
			renderOrder = props.renderOrder, -- 158
			style = mergeStyle({width = estimatedWidth, height = estimatedHeight, alignItems = "center", justifyContent = "center"}, props.style), -- 158
			visible = props.visible, -- 158
			opacity = props.opacity -- 158
		}, -- 158
		React.createElement( -- 158
			PaintNode, -- 173
			{ -- 173
				key = "text-paint", -- 173
				painter = function(ctx) -- 173
					local x = hAlign == "Left" and 0 or (hAlign == "Right" and ctx.width or ctx.width * 0.5) -- 176
					nvg.FontFaceId(getFontId(fontName)) -- 177
					nvg.FontSize(fontSize) -- 178
					nvg.TextAlign(hAlign, "Middle") -- 179
					nvg.FillColor(Color(props.color or ctx.theme.colors.text.primary)) -- 180
					local lines = textLinesMeasured(value, props.wrap == true, ctx.width) -- 181
					local blockHeight = lineHeight * #lines -- 182
					local y0 = firstLineY(ctx.height, blockHeight, lineHeight, props.verticalAlign) -- 183
					nvg.Save() -- 184
					nvg.Scale(1, -1) -- 185
					for i = 1, #lines do -- 185
						local y = y0 + (#lines - i) * lineHeight -- 187
						nvg.Text(x, -y, lines[i]) -- 188
					end -- 188
					nvg.Restore() -- 190
				end -- 175
			} -- 175
		) -- 175
	) -- 175
end -- 148
return ____exports -- 148