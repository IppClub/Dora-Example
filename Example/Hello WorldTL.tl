-- @preview-file on clear
local threadLoop <const> = require("threadLoop")
local Node <const> = require("Node")
local sleep <const> = require("sleep")

local node = Node()
node:onEnter(function()
	print("on enter event")
end)
node:onExit(function()
	print("on exit event")
end)
node:onCleanup(function()
	print("on node destoyed event")
end)
node:once(function()
	for i = 5, 1, -1 do
		print(i)
		sleep(1)
	end
	print("Hello World!")
end)

-- example codes ends here, some test ui below --

local ImGui = require("ImGui")
local Vec2 = require("Vec2")
local App = require("App")

local windowFlags = {
	"NoDecoration",
	"AlwaysAutoResize",
	"NoSavedSettings",
	"NoFocusOnAppearing",
	"NoNav",
	"NoMove"
}
threadLoop(function(): boolean
	local size = App.visualSize
	ImGui.SetNextWindowBgAlpha(0.35)
	ImGui.SetNextWindowPos(Vec2(size.width - 10, 10), "Always", Vec2(1, 0))
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver")
	ImGui.Begin("Hello World", windowFlags, function()
		ImGui.Text("Hello World (Teal)")
		ImGui.Separator()
		ImGui.TextWrapped("Basic Dora schedule and signal function usage. Written in Teal. View outputs in log window!")
	end)
end)
