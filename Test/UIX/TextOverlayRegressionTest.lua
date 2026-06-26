-- [tsx]: TextOverlayRegressionTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local Modal = ____UIX.Modal -- 4
local Tooltip = ____UIX.Tooltip -- 4
local resultFile = Path(Content.writablePath, "UIXTextOverlayRegressionTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXTextOverlayRegressionTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local modalHost = DNode() -- 20
Director.ui:addChild(modalHost, 10000) -- 21
local root = createRoot(host) -- 22
local modalRoot = createRoot(modalHost) -- 23
local tooltipRef = reference() -- 24
local modalRef = reference() -- 25
local open = signal(true) -- 26
local closed = signal(0) -- 27
root:render(function() return React.createElement( -- 29
	"align-node", -- 29
	{windowRoot = true, style = {padding = 8}}, -- 29
	React.createElement(Tooltip, { -- 29
		ref = tooltipRef, -- 29
		key = "wrap-tooltip", -- 29
		title = "UIX", -- 29
		text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", -- 29
		width = 220, -- 29
		style = {left = 18, bottom = 18} -- 29
	}) -- 29
) end) -- 29
modalRoot:render(function() return React.createElement( -- 42
	Modal, -- 43
	{ -- 43
		ref = modalRef, -- 43
		key = "overlay-modal", -- 43
		open = open.value, -- 43
		title = "Overlay", -- 43
		message = "Modal text and controls should render in the same nvg layer.", -- 43
		width = 300, -- 43
		height = 196, -- 43
		onClose = function() -- 43
			closed.value = closed.value + 1 -- 52
			open.value = false -- 53
		end -- 51
	} -- 51
) end) -- 51
Director.systemScheduler:schedule(once(function() -- 58
	expect(tooltipRef.current ~= nil, "tooltip did not mount") -- 59
	expect(tooltipRef.current.width == 220, "tooltip width changed unexpectedly") -- 60
	expect(tooltipRef.current.height >= 88, "tooltip height is too small for wrapped text") -- 61
	expect(modalRef.current ~= nil, "modal did not mount") -- 62
	expect(modalRef.current.width > 0 and modalRef.current.height > 0, "modal root did not receive visual size") -- 63
	modalRef.current:emit("Tapped") -- 64
	expect(closed.value == 1, "modal backdrop tap did not close") -- 65
	Director.systemScheduler:schedule(once(function() -- 66
		expect(open.value == false, "modal signal did not close") -- 67
		Content:save(resultFile, "passed") -- 68
		Log("Info", "[UIXTextOverlayRegressionTest] passed") -- 69
		host:removeFromParent(true) -- 70
		root:unmount() -- 71
		modalRoot:unmount() -- 72
		modalHost:removeFromParent(true) -- 73
	end)) -- 66
end)) -- 58
return ____exports -- 58