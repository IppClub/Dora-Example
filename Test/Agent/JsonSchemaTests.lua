-- [ts]: JsonSchemaTests.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local json = ____Dora.json -- 2
local ____JsonSchema = require("Agent.JsonSchema") -- 3
local compileJsonSchema = ____JsonSchema.compileJsonSchema -- 3
local validateJsonSchema = ____JsonSchema.validateJsonSchema -- 3
local validateJsonValue = ____JsonSchema.validateJsonValue -- 3
function ____exports.runJsonSchemaTests() -- 12
	local passed = 0 -- 13
	local total = 0 -- 14
	local failures = {} -- 15
	local function check(condition, name) -- 17
		total = total + 1 -- 18
		if condition then -- 18
			passed = passed + 1 -- 20
		else -- 20
			failures[#failures + 1] = name -- 22
		end -- 22
	end -- 17
	local toolSchema = {type = "object", properties = { -- 26
		name = {type = "string", minLength = 2, maxLength = 8}, -- 29
		count = {type = "integer", minimum = 1, maximum = 5}, -- 30
		tags = {type = "array", items = {type = "string"}, minItems = 1, maxItems = 3}, -- 31
		mode = {enum = {"code", "plan"}}, -- 32
		meta = {type = "object", properties = {enabled = {type = "boolean"}}, required = {"enabled"}, additionalProperties = false} -- 33
	}, required = {"name", "count", "tags", "mode"}, additionalProperties = false} -- 33
	check( -- 44
		validateJsonSchema(toolSchema).valid, -- 44
		"accept supported schema" -- 44
	) -- 44
	check( -- 45
		not validateJsonSchema({type = "object", ["$ref"] = "#/$defs/value"}).valid, -- 45
		"reject unsupported $ref" -- 45
	) -- 45
	check( -- 46
		not validateJsonSchema({type = "wat"}).valid, -- 46
		"reject unsupported type" -- 46
	) -- 46
	check( -- 47
		not validateJsonSchema({required = {"a", "a"}}).valid, -- 47
		"reject duplicate required name" -- 47
	) -- 47
	check( -- 48
		not validateJsonSchema({minItems = 2, maxItems = 1}).valid, -- 48
		"reject inverted item range" -- 48
	) -- 48
	check( -- 49
		not validateJsonSchema({enum = {1, 1}}).valid, -- 49
		"reject duplicate enum value" -- 49
	) -- 49
	check( -- 50
		validateJsonSchema({ -- 50
			["$schema"] = "agent-json-schema-subset", -- 50
			title = "T", -- 50
			description = "D", -- 50
			default = {}, -- 50
			examples = {1} -- 50
		}).valid, -- 50
		"accept supported annotations" -- 50
	) -- 50
	local compiled = compileJsonSchema(toolSchema) -- 52
	check(compiled.success, "compile supported schema") -- 53
	if compiled.success then -- 53
		check( -- 55
			compiled.validator:validate({name = "alpha", count = 2, tags = {"a"}, mode = "code"}).valid, -- 55
			"accept valid nested object" -- 55
		) -- 55
		local missing = compiled.validator:validate({name = "alpha", count = 2, tags = {"a"}}) -- 56
		local ____check_3 = check -- 57
		local ____temp_2 = not missing.valid -- 57
		if ____temp_2 then -- 57
			local ____opt_0 = missing.errors[1] -- 57
			____temp_2 = (____opt_0 and ____opt_0.keyword) == "required" -- 57
		end -- 57
		____check_3(____temp_2, "reject missing required property") -- 57
		local extra = compiled.validator:validate({ -- 58
			name = "alpha", -- 58
			count = 2, -- 58
			tags = {"a"}, -- 58
			mode = "code", -- 58
			extra = true -- 58
		}) -- 58
		local ____check_7 = check -- 59
		local ____temp_6 = not extra.valid -- 59
		if ____temp_6 then -- 59
			local ____opt_4 = extra.errors[1] -- 59
			____temp_6 = (____opt_4 and ____opt_4.instancePath) == "/extra" -- 59
		end -- 59
		____check_7(____temp_6, "reject additional property with path") -- 59
		local nested = compiled.validator:validate({ -- 60
			name = "alpha", -- 60
			count = 2, -- 60
			tags = {"a"}, -- 60
			mode = "code", -- 60
			meta = {enabled = "yes"} -- 60
		}) -- 60
		local ____check_11 = check -- 61
		local ____temp_10 = not nested.valid -- 61
		if ____temp_10 then -- 61
			local ____opt_8 = nested.errors[1] -- 61
			____temp_10 = (____opt_8 and ____opt_8.instancePath) == "/meta/enabled" -- 61
		end -- 61
		____check_11(____temp_10, "report nested instance path") -- 61
		check( -- 62
			not compiled.validator:validate({name = "alpha", count = 2.5, tags = {"a"}, mode = "code"}).valid, -- 62
			"reject fractional integer" -- 62
		) -- 62
		check( -- 63
			not compiled.validator:validate({name = "alpha", count = 2, tags = {}, mode = "code"}).valid, -- 63
			"enforce minItems" -- 63
		) -- 63
	end -- 63
	check( -- 66
		validateJsonValue({type = {"string", "null"}}, json.null).valid, -- 66
		"accept Dora JSON null" -- 66
	) -- 66
	check( -- 67
		validateJsonValue({type = {"string", "null"}}, "ok").valid, -- 67
		"accept type union" -- 67
	) -- 67
	check( -- 68
		not validateJsonValue({type = {"string", "null"}}, false).valid, -- 68
		"reject value outside type union" -- 68
	) -- 68
	check( -- 69
		validateJsonValue({type = "string", minLength = 2, maxLength = 2}, "你好").valid, -- 69
		"count UTF-8 characters" -- 69
	) -- 69
	check( -- 70
		validateJsonValue({minimum = 1, maximum = 2}, 1).valid, -- 70
		"accept inclusive numeric boundary" -- 70
	) -- 70
	check( -- 71
		not validateJsonValue({exclusiveMinimum = 1}, 1).valid, -- 71
		"reject exclusive numeric boundary" -- 71
	) -- 71
	check( -- 72
		not validateJsonValue({type = "number"}, math.huge).valid, -- 72
		"reject non-finite number" -- 72
	) -- 72
	check( -- 74
		validateJsonValue({const = {a = {1, "x"}}}, {a = {1, "x"}}).valid, -- 74
		"deep compare const" -- 74
	) -- 74
	check( -- 75
		validateJsonValue({enum = {{a = 1}, {a = 2}}}, {a = 2}).valid, -- 75
		"deep compare enum" -- 75
	) -- 75
	check( -- 76
		validateJsonValue({anyOf = {{type = "string"}, {type = "number"}}}, 3).valid, -- 76
		"accept anyOf branch" -- 76
	) -- 76
	check( -- 77
		not validateJsonValue({anyOf = {{type = "string"}, {type = "number"}}}, true).valid, -- 77
		"reject all anyOf branches" -- 77
	) -- 77
	check( -- 78
		validateJsonValue({oneOf = {{type = "integer"}, {type = "string"}}}, 3).valid, -- 78
		"accept exactly one oneOf branch" -- 78
	) -- 78
	check( -- 79
		not validateJsonValue({oneOf = {{type = "number"}, {type = "integer"}}}, 3).valid, -- 79
		"reject multiple oneOf branches" -- 79
	) -- 79
	check( -- 80
		validateJsonValue({["not"] = {type = "string"}}, 3).valid, -- 80
		"accept value rejected by not branch" -- 80
	) -- 80
	check( -- 81
		not validateJsonValue({["not"] = {type = "string"}}, "x").valid, -- 81
		"reject value accepted by not branch" -- 81
	) -- 81
	check( -- 82
		validateJsonValue({allOf = {{minimum = 1}, {maximum = 3}}}, 2).valid, -- 82
		"accept allOf constraints" -- 82
	) -- 82
	check( -- 83
		not validateJsonValue({allOf = {{minimum = 1}, {maximum = 3}}}, 4).valid, -- 83
		"reject failed allOf constraint" -- 83
	) -- 83
	local escaped = validateJsonValue({type = "object", properties = {["a/b"] = {type = "number"}}}, {["a/b"] = "x"}) -- 85
	local ____check_15 = check -- 89
	local ____temp_14 = not escaped.valid -- 89
	if ____temp_14 then -- 89
		local ____opt_12 = escaped.errors[1] -- 89
		____temp_14 = (____opt_12 and ____opt_12.instancePath) == "/a~1b" -- 89
	end -- 89
	____check_15(____temp_14, "escape JSON pointer path") -- 89
	local sparse = {1, 2} -- 91
	sparse[1] = nil -- 92
	check( -- 93
		not validateJsonValue({type = "array"}, sparse).valid, -- 93
		"reject sparse or undefined array item" -- 93
	) -- 93
	local cyclic = {} -- 95
	cyclic.self = cyclic -- 96
	check( -- 97
		not validateJsonValue(true, cyclic).valid, -- 97
		"reject cyclic instance" -- 97
	) -- 97
	local cyclicSchema = {type = "object"} -- 98
	cyclicSchema["not"] = cyclicSchema -- 99
	check( -- 100
		not validateJsonSchema(cyclicSchema).valid, -- 100
		"reject cyclic schema" -- 100
	) -- 100
	local bounded = validateJsonValue({type = "object", additionalProperties = false}, {a = 1, b = 2, c = 3}, {maxErrors = 2}) -- 102
	check(not bounded.valid and #bounded.errors == 2 and bounded.truncated, "bound validation errors") -- 106
	local deepSchema = {type = "string"} -- 108
	do -- 108
		local i = 0 -- 109
		while i < 8 do -- 109
			deepSchema = {["not"] = deepSchema} -- 109
			i = i + 1 -- 109
		end -- 109
	end -- 109
	check( -- 110
		not validateJsonSchema(deepSchema, {maxDepth = 4}).valid, -- 110
		"bound schema recursion depth" -- 110
	) -- 110
	check( -- 111
		validateJsonValue(true, {value = 1}).valid, -- 111
		"accept true schema" -- 111
	) -- 111
	check( -- 112
		not validateJsonValue(false, {value = 1}).valid, -- 112
		"reject false schema" -- 112
	) -- 112
	return {success = #failures == 0, passed = passed, total = total, failures = failures} -- 114
end -- 12
return ____exports -- 12