-- Interactive native picker regression. Run this file and select a ZIP beside
-- a Markdown file: ZIP must be enabled, Markdown disabled. Cancel must return "".
local D = require("Dora")
D.App:openFileDialog(false, function(path)
	local result = path == "" and "cancelled" or (D.Path:getExt(path):lower() == "zip" and "passed: " .. path or "failed: non-ZIP selected: " .. path)
	D.Content:save("/tmp/dora-package-picker.result", result)
end, "zip")
