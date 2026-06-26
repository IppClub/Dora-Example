-- [tsx]: OverlayComponentsTest.tsx
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
local ToastStack = ____UIX.ToastStack -- 4
local Tooltip = ____UIX.Tooltip -- 4
local resultFile = Path(Content.writablePath, "UIXOverlayComponentsTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXOverlayComponentsTest] " .. message) -- 11
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
local modalOpen = signal(true) -- 24
local closeCount = signal(0) -- 25
local modalRef = reference() -- 26
local toastRef = reference() -- 27
local tooltipRef = reference() -- 28
root:render(function() return React.createElement( -- 30
	"align-node", -- 30
	{windowRoot = true, style = {padding = 8}}, -- 30
	React.createElement(Tooltip, {ref = tooltipRef, title = "Skill", text = "Deals damage and starts cooldown.", style = {left = 16, top = 16}}), -- 30
	React.createElement(ToastStack, {ref = toastRef, items = {{id = "a", title = "Loot", message = "Coins +75"}, {id = "b", message = "Shield ready"}}, style = {right = 16, top = 16}}) -- 30
) end) -- 30
modalRoot:render(function() return React.createElement( -- 49
	Modal, -- 50
	{ -- 50
		ref = modalRef, -- 50
		open = modalOpen.value, -- 50
		title = "Confirm", -- 50
		message = "Close this modal?", -- 50
		onClose = function() -- 50
			closeCount.value = closeCount.value + 1 -- 56
			modalOpen.value = false -- 57
		end -- 55
	} -- 55
) end) -- 55
Director.systemScheduler:schedule(once(function() -- 62
	expect(tooltipRef.current ~= nil, "tooltip did not mount") -- 63
	expect(toastRef.current ~= nil, "toast stack did not mount") -- 64
	expect(toastRef.current.children ~= nil and toastRef.current.children.count == 2, "toast stack did not render two items") -- 65
	expect(modalRef.current ~= nil, "modal did not mount") -- 66
	modalRef.current:emit("Tapped") -- 67
	expect(closeCount.value == 1, "modal backdrop did not invoke onClose") -- 68
	Director.systemScheduler:schedule(once(function() -- 69
		expect(modalOpen.value == false, "modal open signal did not update") -- 70
		Content:save(resultFile, "passed") -- 71
		Log("Info", "[UIXOverlayComponentsTest] passed") -- 72
		host:removeFromParent(true) -- 73
		root:unmount() -- 74
		modalRoot:unmount() -- 75
		modalHost:removeFromParent(true) -- 76
	end)) -- 69
end)) -- 62
return ____exports -- 62