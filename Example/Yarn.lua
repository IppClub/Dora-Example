-- [yue]: Example/Yarn.yue
local _ENV = Dora(Dora.ImGui) -- 2
local YarnRunner = require("YarnRunner") -- 3
local LineRect = require("UI.View.Shape.LineRect") -- 4
local CircleButton = require("UI.Control.Basic.CircleButton") -- 5
local ScrollArea = require("UI.Control.Basic.ScrollArea") -- 6
local App <const> = App -- 7
local math <const> = math -- 7
local AlignNode <const> = AlignNode -- 7
local View <const> = View -- 7
local Vec2 <const> = Vec2 -- 7
local Size <const> = Size -- 7
local Label <const> = Label -- 7
local Menu <const> = Menu -- 7
local setmetatable <const> = setmetatable -- 7
local table <const> = table -- 7
local tostring <const> = tostring -- 7
local select <const> = select -- 7
local coroutine <const> = coroutine -- 7
local Path <const> = Path -- 7
local type <const> = type -- 7
local ipairs <const> = ipairs -- 7
local thread <const> = thread -- 7
local Content <const> = Content -- 7
local threadLoop <const> = threadLoop -- 7
local SetNextWindowPos <const> = SetNextWindowPos -- 7
local SetNextWindowSize <const> = SetNextWindowSize -- 7
local Begin <const> = Begin -- 7
local Text <const> = Text -- 7
local Separator <const> = Separator -- 7
local Combo <const> = Combo -- 7
local xpcall <const> = xpcall -- 7
local debug <const> = debug -- 7
local pairs <const> = pairs -- 7
local fontScale = App.devicePixelRatio -- 9
local fontSize = math.floor(20 * fontScale) -- 10
local texts = { } -- 12
local root, label, scroll, control, menu -- 14
do -- 16
	root = AlignNode(true) -- 16
	local viewWidth, viewHeight -- 17
	do -- 17
		local _obj_0 = View.size -- 17
		viewWidth, viewHeight = _obj_0.width, _obj_0.height -- 17
	end -- 17
	root:css("flex-direction: column-reverse") -- 18
	local width <const>, height <const> = viewWidth - 100, viewHeight - 10 -- 19
	root:addChild((function() -- 20
		scroll = ScrollArea({ -- 21
			width = width, -- 21
			height = height, -- 22
			paddingX = 0, -- 23
			paddingY = 50, -- 24
			viewWidth = height, -- 25
			viewHeight = height -- 26
		}) -- 20
		root:onAlignLayout(function(w, h) -- 28
			scroll.position = Vec2(w / 2, h / 2) -- 29
			w = w - 100 -- 30
			h = h - 10 -- 31
			scroll.view.children.first.textWidth = (w - fontSize) * fontScale -- 32
			scroll:adjustSizeWithAlign("Auto", 10, Size(w, h)) -- 33
			do -- 34
				local _obj_0 = scroll.area:getChildByTag("border") -- 34
				if _obj_0 ~= nil then -- 34
					_obj_0:removeFromParent() -- 34
				end -- 34
			end -- 34
			local border = LineRect({ -- 35
				x = 1, -- 35
				y = 1, -- 35
				width = w - 2, -- 35
				height = h - 2, -- 35
				color = 0xffffffff -- 35
			}) -- 35
			return scroll.area:addChild(border, 0, "border") -- 36
		end) -- 28
		scroll.view:addChild((function() -- 37
			label = Label("sarasa-mono-sc-regular", fontSize) -- 37
			do -- 38
				local _tmp_0 = 1 / fontScale -- 38
				label.scaleX = _tmp_0 -- 38
				label.scaleY = _tmp_0 -- 38
			end -- 38
			label.alignment = "Left" -- 39
			label.textWidth = (width - fontSize) * fontScale -- 40
			label.text = "" -- 41
			return label -- 37
		end)()) -- 37
		return scroll -- 20
	end)()) -- 20
	root:addChild((function() -- 42
		control = AlignNode() -- 42
		control:css("height: 140; margin-bottom: 40") -- 43
		menu = Menu() -- 44
		control:addChild(menu) -- 45
		control:onAlignLayout(function(w, h) -- 46
			menu.position = Vec2(w / 2, h / 2) -- 47
		end) -- 46
		return control -- 42
	end)()) -- 42
end -- 16
local _anon_func_0 = function(...) -- 50
	local _accum_0 = { } -- 50
	local _len_0 = 1 -- 50
	for i = 1, select('#', ...) do -- 50
		_accum_0[_len_0] = tostring(select(i, ...)) -- 50
		_len_0 = _len_0 + 1 -- 50
	end -- 50
	return _accum_0 -- 50
end -- 50
local commands = setmetatable({ }, { -- 49
	__index = function(_self, name) -- 49
		return function(...) -- 49
			local msg = "[command]: " .. name .. " " .. table.concat(_anon_func_0(...), ", ") -- 50
			return coroutine.yield("Command", msg) -- 51
		end -- 49
	end -- 49
}) -- 49
local testFiles = { -- 53
	Path("Example", "tutorial.yarn") -- 53
} -- 53
local files = { -- 54
	"Test/tutorial.yarn" -- 54
} -- 54
local runner = YarnRunner(testFiles[1], "Start", { }, commands, true) -- 56
local advance -- 58
local setButtons -- 60
setButtons = function(options) -- 60
	menu:removeAllChildren() -- 61
	local buttons -- 62
	if options ~= nil then -- 62
		buttons = options -- 62
	else -- 62
		buttons = 1 -- 62
	end -- 62
	menu.size = Size(80 * buttons, 80) -- 64
	for i = 1, buttons do -- 65
		menu:addChild((function() -- 66
			local _with_0 = CircleButton({ -- 67
				text = options and tostring(i) or "Next", -- 67
				radius = 30, -- 68
				fontSize = 20 -- 69
			}) -- 66
			_with_0:onTapped(function() -- 71
				if options then -- 72
					return advance(i) -- 73
				else -- 75
					return advance() -- 75
				end -- 72
			end) -- 71
			return _with_0 -- 66
		end)()) -- 66
	end -- 65
	menu:alignItems() -- 76
	return menu -- 63
end -- 60
advance = function(option) -- 78
	local action, result = runner:advance(option) -- 79
	if "Text" == action then -- 80
		local charName = "" -- 81
		if result.marks then -- 82
			local _list_0 = result.marks -- 83
			for _index_0 = 1, #_list_0 do -- 83
				local mark = _list_0[_index_0] -- 83
				local _type_0 = type(mark) -- 84
				local _tab_0 = "table" == _type_0 or "userdata" == _type_0 -- 84
				if _tab_0 then -- 84
					local attr = mark.name -- 84
					local name -- 84
					do -- 84
						local _obj_0 = mark.attrs -- 84
						local _type_1 = type(_obj_0) -- 84
						if "table" == _type_1 or "userdata" == _type_1 then -- 84
							name = _obj_0.name -- 84
						end -- 84
					end -- 84
					if attr ~= nil and name ~= nil then -- 84
						if attr == "Character" then -- 85
							charName = tostring(name) .. ": " -- 85
						end -- 85
					end -- 84
				end -- 84
			end -- 83
		end -- 82
		texts[#texts + 1] = charName .. result.text -- 86
		if result.optionsFollowed then -- 87
			advance() -- 88
		else -- 90
			setButtons() -- 90
		end -- 87
	elseif "Option" == action then -- 91
		for i, op in ipairs(result) do -- 92
			texts[#texts + 1] = "[" .. tostring(i) .. "]: " .. tostring(op.text) -- 93
		end -- 92
		setButtons(#result) -- 94
	elseif "Command" == action then -- 95
		texts[#texts + 1] = result -- 96
		setButtons() -- 97
	else -- 99
		menu:removeAllChildren() -- 99
		texts[#texts + 1] = result -- 100
	end -- 80
	label.text = table.concat(texts, "\n") -- 101
	scroll:adjustSizeWithAlign("Auto", 10) -- 102
	return thread(function() -- 103
		return scroll:scrollToPosY(label.y - label.height / 2) -- 103
	end) -- 103
end -- 78
advance() -- 105
local _list_0 = Content:getAllFiles(Content.writablePath) -- 107
for _index_0 = 1, #_list_0 do -- 107
	local file = _list_0[_index_0] -- 107
	if "yarn" ~= Path:getExt(file) then -- 108
		goto _continue_0 -- 108
	end -- 108
	testFiles[#testFiles + 1] = Path(Content.writablePath, file) -- 109
	files[#files + 1] = Path:getFilename(file) -- 110
	::_continue_0:: -- 108
end -- 107
local currentFile = 1 -- 112
local windowFlags = { -- 114
	"NoDecoration", -- 114
	"NoSavedSettings", -- 114
	"NoFocusOnAppearing", -- 114
	"NoNav", -- 114
	"NoMove" -- 114
} -- 114
return threadLoop(function() -- 121
	local width -- 122
	width = App.visualSize.width -- 122
	SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 123
	SetNextWindowSize(Vec2(200, 0), "Always") -- 124
	return Begin("Yarn Test", windowFlags, function() -- 125
		Text("Yarn Tester (Yuescript)") -- 126
		Separator() -- 127
		local changed -- 128
		changed, currentFile = Combo("File", currentFile, files) -- 128
		if changed then -- 129
			xpcall(function() -- 130
				runner = YarnRunner(testFiles[currentFile], "Start", { }, commands, true) -- 131
				texts = { } -- 132
				return advance() -- 133
			end, function(err) -- 133
				local msg = debug.traceback(err) -- 135
				label.text = "failed to load file " .. tostring(testFiles[currentFile]) .. "\n" .. tostring(msg) -- 136
				return scroll:adjustSizeWithAlign("Auto", 10) -- 137
			end) -- 130
		end -- 129
		Text("Variables") -- 138
		Separator() -- 139
		for k, v in pairs(runner.state) do -- 140
			Text(tostring(k) .. ": " .. tostring(v)) -- 141
		end -- 140
	end) -- 125
end) -- 121
