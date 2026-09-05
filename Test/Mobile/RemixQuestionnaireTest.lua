-- [ts]: RemixQuestionnaireTest.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Path = ____Dora.Path -- 1
local sleep = ____Dora.sleep -- 1
local thread = ____Dora.thread -- 1
local ____Remix = require("Dev.Mobile.Remix") -- 2
local startMobileRemix = ____Remix.startMobileRemix -- 2
local ____RemixModel = require("Dev.Mobile.RemixModel") -- 3
local buildQuestionnaireAnswers = ____RemixModel.buildQuestionnaireAnswers -- 3
thread(function() -- 5
	local marker = Path(Content.appPath, "mobile-remix-questionnaire-test.result") -- 6
	local host -- 7
	Content:save(marker, "running") -- 8
	do -- 8
		local function ____catch(e) -- 8
			Content:save( -- 68
				marker, -- 68
				"failed: " .. tostring(e) -- 68
			) -- 68
		end -- 68
		local ____try, ____hasReturned = pcall(function() -- 68
			local session = {id = 1, status = "WAITING_USER", workMode = "plan"} -- 10
			local questions = {{ -- 11
				id = "layout", -- 12
				prompt = "First line of the question\nSecond line of the question\nThird line of the question", -- 13
				type = "single_choice", -- 14
				required = false, -- 15
				options = {{id = "first", label = "First option"}} -- 16
			}} -- 16
			local detail = { -- 18
				success = true, -- 19
				session = session, -- 20
				messages = {}, -- 21
				steps = {}, -- 22
				hasActivePlan = false, -- 23
				pendingQuestionnaire = {id = 1, schema = {title = "Layout test", questions = questions}} -- 24
			} -- 24
			local services = { -- 32
				createSession = function() return {success = true, session = session} end, -- 33
				getSession = function() return detail end, -- 34
				setWorkMode = function() return {success = true} end, -- 35
				sendPrompt = function() return {success = true} end, -- 36
				respondQuestionnaire = function() return {success = true} end, -- 37
				stopSessionTask = function() return nil end, -- 38
				getActiveLLMConfig = function() return {success = false, message = "not needed"} end, -- 39
				getLLMConfig = function() return {success = false, message = "not needed"} end, -- 40
				getLLMConfigSummaries = function() return {{id = 1, name = "Test"}} end -- 41
			} -- 41
			host = startMobileRemix({ -- 43
				entry = {id = "layout", title = "Layout test", workDir = Content.writablePath}, -- 44
				onBack = function() -- 45
				end, -- 45
				onPlay = function() -- 46
				end, -- 46
				services = services -- 47
			}) -- 47
			sleep() -- 49
			local prompt -- 50
			local option -- 51
			host:traverse(function(node) -- 52
				if node.tag == "remix-question-prompt" then -- 52
					prompt = node -- 53
				end -- 53
				if node.tag == "remix-question-layout-option-first" then -- 53
					option = node -- 54
				end -- 54
				return false -- 55
			end) -- 52
			assert(prompt and option, "questionnaire nodes were not rendered") -- 57
			local promptNode = prompt -- 58
			local optionNode = option -- 59
			local gap = promptNode.y - promptNode.height / 2 - (optionNode.y + optionNode.height) -- 60
			assert( -- 61
				gap >= 13.5, -- 61
				"multi-line prompt gap is too small: " .. tostring(gap) -- 61
			) -- 61
			local skip -- 62
			host:traverse(function(node) -- 63
				if node.tag == "remix-question-skip" then -- 63
					skip = node -- 63
				end -- 63
				return false -- 63
			end) -- 63
			assert(skip, "optional question did not render a skip action") -- 64
			local answers = buildQuestionnaireAnswers(questions, {}, {}) -- 65
			assert(answers[1].questionId == "layout" and answers[1].status == "skipped", "empty optional answer was not serialized as skipped") -- 66
			Content:save( -- 67
				marker, -- 67
				("passed: multi-line prompt gap " .. tostring(gap)) .. "; optional question skipped" -- 67
			) -- 67
		end) -- 67
		if not ____try then -- 67
			____catch(____hasReturned) -- 67
		end -- 67
		do -- 67
			if host ~= nil then -- 67
				host:removeFromParent(true) -- 69
			end -- 69
		end -- 69
	end -- 69
end) -- 5
return ____exports -- 5
