local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local json <const> = require("json")

local workflow = {}

local function clean(value)
	return tostring(value or ""):gsub("[\t\r\n]", " ")
end

function workflow.run(casesJson, statusFile, frameBudget)
	local cases = assert(json.decode(casesJson))
	local results = {}
	local index = 0
	local current
	local frames = 0
	local cooldown = 0
	frameBudget = frameBudget or 120

	Director.systemScheduler:schedule(function()
		if not current then
			if cooldown > 0 then
				cooldown = cooldown - 1
				return false
			end
			index = index + 1
			local case = cases[index]
			if not case then
				assert(Content:save(statusFile, table.concat(results, "\n")))
				package.loaded.host = nil
				print("HOST_LOVE_OPEN_SOURCE_CORPUS_PASS", #results)
				return true
			end
			local ok, node = pcall(LoveNode, case.path)
			if not ok or not node then
				table.insert(results, clean(case.name) .. "\tinit-failed\t"
					.. clean(ok and "LoveNode returned nil" or node))
				print("LOVE_CORPUS_RESULT", case.name, "init-failed")
				cooldown = 6
				return false
			end
			current = node
			frames = 0
			Director.entry:addChild(node)
			return false
		end

		frames = frames + 1
		if current.running and frames < frameBudget then
			return false
		end
		local error = current.lastError
		local status = error == "" and "pass" or "runtime-failed"
		table.insert(results, clean(cases[index].name) .. "\t" .. status .. "\t" .. clean(error))
		print("LOVE_CORPUS_RESULT", cases[index].name, status, frames, error)
		current:removeFromParent(true)
		current = nil
		cooldown = 6
		return false
	end)
end

return workflow
