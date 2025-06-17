-- [yue]: Example/Yarn.yue
local App = Dora.App -- 1
local math = _G.math -- 1
local AlignNode = Dora.AlignNode -- 1
local View = Dora.View -- 1
local Vec2 = Dora.Vec2 -- 1
local Size = Dora.Size -- 1
local Label = Dora.Label -- 1
local Menu = Dora.Menu -- 1
local setmetatable = _G.setmetatable -- 1
local table = _G.table -- 1
local select = _G.select -- 1
local tostring = _G.tostring -- 1
local coroutine = _G.coroutine -- 1
local Path = Dora.Path -- 1
local type = _G.type -- 1
local ipairs = _G.ipairs -- 1
local thread = Dora.thread -- 1
local Content = Dora.Content -- 1
local threadLoop = Dora.threadLoop -- 1
local _module_0 = Dora.ImGui -- 1
local SetNextWindowPos = _module_0.SetNextWindowPos -- 1
local SetNextWindowSize = _module_0.SetNextWindowSize -- 1
local Begin = _module_0.Begin -- 1
local Text = _module_0.Text -- 1
local Separator = _module_0.Separator -- 1
local Combo = _module_0.Combo -- 1
local xpcall = _G.xpcall -- 1
local debug = _G.debug -- 1
local pairs = _G.pairs -- 1
local YarnRunner = require("YarnRunner") -- 3
local LineRect = require("UI.View.Shape.LineRect") -- 4
local CircleButton = require("UI.Control.Basic.CircleButton") -- 5
local ScrollArea = require("UI.Control.Basic.ScrollArea") -- 6
local fontScale = App.devicePixelRatio -- 8
local fontSize = math.floor(20 * fontScale) -- 9
local texts = { } -- 11
local root, label, scroll, control, menu -- 13
do -- 15
	root = AlignNode(true) -- 15
	local viewWidth, viewHeight -- 16
	do -- 16
		local _obj_0 = View.size -- 16
		viewWidth, viewHeight = _obj_0.width, _obj_0.height -- 16
	end -- 16
	root:css("flex-direction: column-reverse") -- 17
	local width <const>, height <const> = viewWidth - 100, viewHeight - 10 -- 18
	root:addChild((function() -- 19
		scroll = ScrollArea({ -- 20
			width = width, -- 20
			height = height, -- 21
			paddingX = 0, -- 22
			paddingY = 50, -- 23
			viewWidth = height, -- 24
			viewHeight = height -- 25
		}) -- 19
		root:onAlignLayout(function(w, h) -- 27
			scroll.position = Vec2(w / 2, h / 2) -- 28
			w = w - 100 -- 29
			h = h - 10 -- 30
			scroll.view.children.first.textWidth = (w - fontSize) * fontScale -- 31
			scroll:adjustSizeWithAlign("Auto", 10, Size(w, h)) -- 32
			do -- 33
				local _obj_0 = scroll.area:getChildByTag("border") -- 33
				if _obj_0 ~= nil then -- 33
					_obj_0:removeFromParent() -- 33
				end -- 33
			end -- 33
			local border = LineRect({ -- 34
				x = 1, -- 34
				y = 1, -- 34
				width = w - 2, -- 34
				height = h - 2, -- 34
				color = 0xffffffff -- 34
			}) -- 34
			return scroll.area:addChild(border, 0, "border") -- 35
		end) -- 27
		scroll.view:addChild((function() -- 36
			label = Label("sarasa-mono-sc-regular", fontSize) -- 36
			do -- 37
				local _tmp_0 = 1 / fontScale -- 37
				label.scaleX = _tmp_0 -- 37
				label.scaleY = _tmp_0 -- 37
			end -- 37
			label.alignment = "Left" -- 38
			label.textWidth = (width - fontSize) * fontScale -- 39
			label.text = "" -- 40
			return label -- 36
		end)()) -- 36
		return scroll -- 19
	end)()) -- 19
	root:addChild((function() -- 41
		control = AlignNode() -- 41
		control:css("height: 140; margin-bottom: 40") -- 42
		menu = Menu() -- 43
		control:addChild(menu) -- 44
		control:onAlignLayout(function(w, h) -- 45
			menu.position = Vec2(w / 2, h / 2) -- 46
		end) -- 45
		return control -- 41
	end)()) -- 41
end -- 15
local _anon_func_0 = function(select, tostring, ...) -- 49
	local _accum_0 = { } -- 49
	local _len_0 = 1 -- 49
	for i = 1, select('#', ...) do -- 49
		_accum_0[_len_0] = tostring(select(i, ...)) -- 49
		_len_0 = _len_0 + 1 -- 49
	end -- 49
	return _accum_0 -- 49
end -- 49
local commands = setmetatable({ }, { -- 48
	__index = function(_self, name) -- 48
		return function(...) -- 48
			local msg = "[command]: " .. name .. " " .. table.concat(_anon_func_0(select, tostring, ...), ", ") -- 49
			return coroutine.yield("Command", msg) -- 50
		end -- 50
	end -- 48
}) -- 48
local testFiles = { -- 52
	Path("Example", "tutorial.yarn") -- 52
} -- 52
local files = { -- 53
	"Test/tutorial.yarn" -- 53
} -- 53
local runner = YarnRunner(testFiles[1], "Start", { }, commands, true) -- 55
local advance -- 57
local setButtons -- 59
setButtons = function(options) -- 59
	menu:removeAllChildren() -- 60
	local buttons -- 61
	if options ~= nil then -- 61
		buttons = options -- 61
	else -- 61
		buttons = 1 -- 61
	end -- 61
	menu.size = Size(80 * buttons, 80) -- 63
	for i = 1, buttons do -- 64
		menu:addChild((function() -- 65
			local _with_0 = CircleButton({ -- 66
				text = options and tostring(i) or "Next", -- 66
				radius = 30, -- 67
				fontSize = 20 -- 68
			}) -- 65
			_with_0:onTapped(function() -- 70
				if options then -- 71
					return advance(i) -- 72
				else -- 74
					return advance() -- 74
				end -- 71
			end) -- 70
			return _with_0 -- 65
		end)()) -- 65
	end -- 74
	menu:alignItems() -- 75
	return menu -- 62
end -- 59
advance = function(option) -- 77
	local action, result = runner:advance(option) -- 78
	if "Text" == action then -- 79
		local charName = "" -- 80
		if result.marks then -- 81
			local _list_0 = result.marks -- 82
			for _index_0 = 1, #_list_0 do -- 82
				local mark = _list_0[_index_0] -- 82
				local _type_0 = type(mark) -- 83
				local _tab_0 = "table" == _type_0 or "userdata" == _type_0 -- 83
				if _tab_0 then -- 83
					local attr = mark.name -- 83
					local name -- 83
					do -- 83
						local _obj_0 = mark.attrs -- 83
						local _type_1 = type(_obj_0) -- 83
						if "table" == _type_1 or "userdata" == _type_1 then -- 83
							name = _obj_0.name -- 83
						end -- 84
					end -- 84
					if attr ~= nil and name ~= nil then -- 83
						if attr == "Character" then -- 84
							charName = tostring(name) .. ": " -- 84
						end -- 84
					end -- 83
				end -- 84
			end -- 84
		end -- 81
		texts[#texts + 1] = charName .. result.text -- 85
		if result.optionsFollowed then -- 86
			advance() -- 87
		else -- 89
			setButtons() -- 89
		end -- 86
	elseif "Option" == action then -- 90
		for i, op in ipairs(result) do -- 91
			texts[#texts + 1] = "[" .. tostring(i) .. "]: " .. tostring(op.text) -- 92
		end -- 92
		setButtons(#result) -- 93
	elseif "Command" == action then -- 94
		texts[#texts + 1] = result -- 95
		setButtons() -- 96
	else -- 98
		menu:removeAllChildren() -- 98
		texts[#texts + 1] = result -- 99
	end -- 99
	label.text = table.concat(texts, "\n") -- 100
	scroll:adjustSizeWithAlign("Auto", 10) -- 101
	return thread(function() -- 102
		return scroll:scrollToPosY(label.y - label.height / 2) -- 102
	end) -- 102
end -- 77
advance() -- 104
local _list_0 = Content:getAllFiles(Content.writablePath) -- 106
for _index_0 = 1, #_list_0 do -- 106
	local file = _list_0[_index_0] -- 106
	if "yarn" ~= Path:getExt(file) then -- 107
		goto _continue_0 -- 107
	end -- 107
	testFiles[#testFiles + 1] = Path(Content.writablePath, file) -- 108
	files[#files + 1] = Path:getFilename(file) -- 109
	::_continue_0:: -- 107
end -- 109
local currentFile = 1 -- 111
local windowFlags = { -- 113
	"NoDecoration", -- 113
	"NoSavedSettings", -- 113
	"NoFocusOnAppearing", -- 113
	"NoNav", -- 113
	"NoMove" -- 113
} -- 113
return threadLoop(function() -- 120
	local width -- 121
	width = App.visualSize.width -- 121
	SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 122
	SetNextWindowSize(Vec2(200, 0), "Always") -- 123
	return Begin("Yarn Test", windowFlags, function() -- 124
		Text("Yarn Tester (Yuescript)") -- 125
		Separator() -- 126
		local changed -- 127
		changed, currentFile = Combo("File", currentFile, files) -- 127
		if changed then -- 128
			xpcall(function() -- 129
				runner = YarnRunner(testFiles[currentFile], "Start", { }, commands, true) -- 130
				texts = { } -- 131
				return advance() -- 132
			end, function(err) -- 136
				local msg = debug.traceback(err) -- 134
				label.text = "failed to load file " .. tostring(testFiles[currentFile]) .. "\n" .. tostring(msg) -- 135
				return scroll:adjustSizeWithAlign("Auto", 10) -- 136
			end) -- 136
		end -- 128
		Text("Variables") -- 137
		Separator() -- 138
		for k, v in pairs(runner.state) do -- 139
			Text(tostring(k) .. ": " .. tostring(v)) -- 140
		end -- 140
	end) -- 140
end) -- 140
