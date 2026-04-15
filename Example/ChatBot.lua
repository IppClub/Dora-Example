-- [ts]: ChatBot.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__Promise = ____lualib.__TS__Promise -- 1
local __TS__New = ____lualib.__TS__New -- 1
local __TS__Class = ____lualib.__TS__Class -- 1
local __TS__ClassExtends = ____lualib.__TS__ClassExtends -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local __TS__AsyncAwaiter = ____lualib.__TS__AsyncAwaiter -- 1
local __TS__Await = ____lualib.__TS__Await -- 1
local __TS__ArrayIsArray = ____lualib.__TS__ArrayIsArray -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local HttpClient = ____Dora.HttpClient -- 2
local json = ____Dora.json -- 2
local thread = ____Dora.thread -- 2
local Buffer = ____Dora.Buffer -- 2
local Vec2 = ____Dora.Vec2 -- 2
local DNode = ____Dora.Node -- 2
local Log = ____Dora.Log -- 2
local DB = ____Dora.DB -- 2
local Path = ____Dora.Path -- 2
local Content = ____Dora.Content -- 2
local Director = ____Dora.Director -- 2
local App = ____Dora.App -- 2
local ImGui = require("ImGui") -- 3
local ____flow = require("Agent.flow") -- 5
local Node = ____flow.Node -- 5
local Flow = ____flow.Flow -- 5
local Config = require("Config") -- 6
if not DB:existDB("llm") then -- 6
	local dbPath = Path(Content.writablePath, "llm.db") -- 15
	DB:exec(("ATTACH DATABASE '" .. dbPath) .. "' AS llm") -- 16
	Director.entry:slot( -- 17
		"Cleanup", -- 17
		function() return DB:exec("DETACH DATABASE llm") end -- 17
	) -- 17
end -- 17
local config = Config( -- 20
	"llm", -- 20
	"url", -- 20
	"model", -- 20
	"apiKey", -- 20
	"output" -- 20
) -- 20
config:load() -- 21
local url = Buffer(512) -- 23
if type(config.url) == "string" then -- 23
	url.text = config.url -- 25
else -- 25
	config.url = "https://api.deepseek.com/chat/completions" -- 27
	url.text = "https://api.deepseek.com/chat/completions" -- 27
end -- 27
local apiKey = Buffer(256) -- 29
if type(config.apiKey) == "string" then -- 29
	apiKey.text = config.apiKey -- 31
end -- 31
local model = Buffer(128) -- 33
if type(config.model) == "string" then -- 33
	model.text = config.model -- 35
else -- 35
	config.model = "deepseek-chat" -- 37
	model.text = "deepseek-chat" -- 37
end -- 37
local function callLLM(messages, url, apiKey, model, receiver) -- 45
	local data = {model = model, messages = messages, stream = true} -- 46
	return __TS__New( -- 51
		__TS__Promise, -- 51
		function(____, resolve, reject) -- 51
			thread(function() -- 52
				local jsonStr = json.encode(data) -- 53
				if jsonStr then -- 53
					local res = HttpClient:postAsync( -- 55
						url, -- 55
						{"Authorization: Bearer " .. apiKey}, -- 55
						jsonStr, -- 57
						10, -- 57
						receiver -- 57
					) -- 57
					if res then -- 57
						resolve(nil, res) -- 59
					else -- 59
						reject(nil, "failed to get http response") -- 61
					end -- 61
				end -- 61
			end) -- 52
		end -- 51
	) -- 51
end -- 45
local endPost = false -- 68
local root = DNode() -- 70
root:onCleanup(function() -- 71
	endPost = true -- 72
end) -- 71
local llmWorking = false -- 79
local ChatNode = __TS__Class() -- 81
ChatNode.name = "ChatNode" -- 81
__TS__ClassExtends(ChatNode, Node) -- 81
function ChatNode.prototype.prep(self, shared) -- 82
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 82
		return ____awaiter_resolve( -- 82
			nil, -- 82
			__TS__New( -- 83
				__TS__Promise, -- 83
				function(____, resolve) -- 83
					root:slot( -- 84
						"Input", -- 84
						function(message) -- 84
							local ____shared_messages_0 = shared.messages -- 84
							____shared_messages_0[#____shared_messages_0 + 1] = {role = "user", content = message} -- 85
							resolve( -- 86
								nil, -- 86
								__TS__ArraySlice(shared.messages, -10) -- 86
							) -- 86
						end -- 84
					) -- 84
				end -- 83
			) -- 83
		) -- 83
	end) -- 83
end -- 82
function ChatNode.prototype.exec(self, messages) -- 90
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 90
		return ____awaiter_resolve( -- 90
			nil, -- 90
			__TS__New( -- 91
				__TS__Promise, -- 91
				function(____, resolve, reject) -- 91
					return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 91
						local str = "" -- 92
						root:emit("Output", "LLM: ") -- 93
						llmWorking = true -- 94
						local ____try = __TS__AsyncAwaiter(function() -- 94
							__TS__Await(callLLM( -- 96
								messages, -- 96
								url.text, -- 96
								apiKey.text, -- 96
								model.text, -- 96
								function(data) -- 96
									if endPost then -- 96
										return true -- 98
									end -- 98
									local done = string.match(data, "data:%s*(%b[])") -- 100
									if done == "[DONE]" then -- 100
										resolve(nil, str) -- 102
										return false -- 103
									end -- 103
									for item in string.gmatch(data, "data:%s*(%b{})") do -- 105
										local res = json.decode(item) -- 106
										if res and not __TS__ArrayIsArray(res) then -- 106
											str = str .. res.choices[1].delta.content -- 108
										end -- 108
									end -- 108
									root:emit("Update", "LLM: " .. str) -- 111
									return false -- 112
								end -- 96
							)) -- 96
							llmWorking = false -- 114
						end) -- 114
						__TS__Await(____try.catch( -- 95
							____try, -- 95
							function(____, e) -- 95
								llmWorking = false -- 116
								reject(nil, e) -- 117
							end -- 117
						)) -- 117
					end) -- 117
				end -- 91
			) -- 91
		) -- 91
	end) -- 91
end -- 90
function ChatNode.prototype.post(self, shared, _prepRes, execRes) -- 121
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 121
		if execRes ~= "" then -- 121
			local ____shared_messages_1 = shared.messages -- 121
			____shared_messages_1[#____shared_messages_1 + 1] = {role = "system", content = execRes} -- 123
		end -- 123
		return ____awaiter_resolve(nil, nil) -- 123
	end) -- 123
end -- 121
local chatNode = __TS__New(ChatNode, 2, 1) -- 129
chatNode:next(chatNode) -- 130
local flow = __TS__New(Flow, chatNode) -- 132
local runFlow -- 133
runFlow = function() -- 133
	return __TS__AsyncAwaiter(function(____awaiter_resolve) -- 133
		local chatInfo = {messages = {}} -- 134
		local ____try = __TS__AsyncAwaiter(function() -- 134
			__TS__Await(flow:run(chatInfo)) -- 138
		end) -- 138
		__TS__Await(____try.catch( -- 137
			____try, -- 137
			function(____, err) -- 137
				Log("Error", err) -- 140
				runFlow() -- 141
			end -- 141
		)) -- 141
	end) -- 141
end -- 133
runFlow() -- 144
local logs = {} -- 146
local inputBuffer = Buffer(500) -- 147
local function ChatButton() -- 149
	ImGui.PushItemWidth( -- 150
		-50, -- 150
		function() -- 150
			if ImGui.InputText("Chat", inputBuffer, {"EnterReturnsTrue"}) then -- 150
				local command = inputBuffer.text -- 152
				if command ~= "" then -- 152
					logs[#logs + 1] = "User: " .. command -- 154
					root:emit("Input", command) -- 155
				end -- 155
				inputBuffer.text = "" -- 157
			end -- 157
		end -- 150
	) -- 150
end -- 149
local inputFlags = {"Password"} -- 162
local windowsFlags = { -- 163
	"NoMove", -- 164
	"NoCollapse", -- 165
	"NoResize", -- 166
	"NoDecoration", -- 167
	"NoNav", -- 168
	"NoSavedSettings", -- 169
	"NoBringToFrontOnFocus", -- 170
	"NoFocusOnAppearing" -- 171
} -- 171
root:loop(function() -- 173
	local ____App_visualSize_2 = App.visualSize -- 174
	local width = ____App_visualSize_2.width -- 174
	local height = ____App_visualSize_2.height -- 174
	ImGui.SetNextWindowPos(Vec2.zero, "Always", Vec2.zero) -- 175
	ImGui.SetNextWindowSize( -- 176
		Vec2(width, height - 40), -- 176
		"Always" -- 176
	) -- 176
	ImGui.Begin( -- 177
		"LLM Chat", -- 177
		windowsFlags, -- 177
		function() -- 177
			ImGui.Text("ChatBot") -- 178
			ImGui.SameLine() -- 179
			ImGui.Dummy(Vec2(width - 200, 0)) -- 180
			ImGui.SameLine() -- 181
			if ImGui.CollapsingHeader("Config") then -- 181
				if ImGui.InputText("URL", url) then -- 181
					config.url = url.text -- 184
				end -- 184
				if ImGui.InputText("API Key", apiKey, inputFlags) then -- 184
					config.apiKey = apiKey.text -- 187
				end -- 187
				if ImGui.InputText("Model", model) then -- 187
					config.model = model.text -- 190
				end -- 190
			end -- 190
			ImGui.Separator() -- 193
			ImGui.BeginChild( -- 194
				"LogArea", -- 194
				Vec2(0, -40), -- 194
				function() -- 194
					for ____, log in ipairs(logs) do -- 195
						ImGui.TextWrapped(log) -- 196
					end -- 196
					if ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then -- 196
						ImGui.SetScrollHereY(1) -- 199
					end -- 199
				end -- 194
			) -- 194
			if llmWorking then -- 194
				ImGui.BeginDisabled(function() -- 203
					ChatButton() -- 204
				end) -- 203
			else -- 203
				ChatButton() -- 207
			end -- 207
		end -- 177
	) -- 177
	return false -- 210
end) -- 173
root:slot( -- 213
	"Output", -- 213
	function(message) -- 213
		logs[#logs + 1] = message -- 214
	end -- 213
) -- 213
root:slot( -- 217
	"Update", -- 217
	function(message) -- 217
		logs[#logs] = message -- 218
	end -- 217
) -- 217
return ____exports -- 217