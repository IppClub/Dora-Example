-- [tsx]: Spacer.tsx
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 1
local React = ____DoraX.React -- 1
function ____exports.Spacer(props) -- 9
	local flex = props.flex or (props.width == nil and props.height == nil and 1 or 0) -- 10
	return React.createElement("align-node", {style = {flex = flex, width = props.width, height = props.height}}) -- 11
end -- 9
return ____exports -- 9