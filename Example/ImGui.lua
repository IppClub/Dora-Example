-- [yue]: Example/ImGui.yue
local _ENV = Dora -- 2
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
return threadLoop(ImGui.ShowDemoWindow) -- 5
