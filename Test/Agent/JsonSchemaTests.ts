// @preview-file off clear
import { json } from 'Dora';
import { compileJsonSchema, JsonSchema, validateJsonSchema, validateJsonValue } from 'Agent/JsonSchema';

export interface JsonSchemaTestResult {
	success: boolean;
	passed: number;
	total: number;
	failures: string[];
}

export function runJsonSchemaTests(): JsonSchemaTestResult {
	let passed = 0;
	let total = 0;
	const failures: string[] = [];

	function check(condition: boolean, name: string): void {
		total++;
		if (condition) {
			passed++;
		} else {
			failures.push(name);
		}
	}

	const toolSchema: JsonSchema = {
		type: "object",
		properties: {
			name: { type: "string", minLength: 2, maxLength: 8 },
			count: { type: "integer", minimum: 1, maximum: 5 },
			tags: { type: "array", items: { type: "string" }, minItems: 1, maxItems: 3 },
			mode: { enum: ["code", "plan"] },
			meta: {
				type: "object",
				properties: { enabled: { type: "boolean" } },
				required: ["enabled"],
				additionalProperties: false,
			},
		},
		required: ["name", "count", "tags", "mode"],
		additionalProperties: false,
	};

	check(validateJsonSchema(toolSchema).valid, "accept supported schema");
	check(!validateJsonSchema({ type: "object", $ref: "#/$defs/value" }).valid, "reject unsupported $ref");
	check(!validateJsonSchema({ type: "wat" }).valid, "reject unsupported type");
	check(!validateJsonSchema({ required: ["a", "a"] }).valid, "reject duplicate required name");
	check(!validateJsonSchema({ minItems: 2, maxItems: 1 }).valid, "reject inverted item range");
	check(!validateJsonSchema({ enum: [1, 1] }).valid, "reject duplicate enum value");
	check(validateJsonSchema({ $schema: "agent-json-schema-subset", title: "T", description: "D", default: {}, examples: [1] }).valid, "accept supported annotations");

	const compiled = compileJsonSchema(toolSchema);
	check(compiled.success, "compile supported schema");
	if (compiled.success) {
		check(compiled.validator.validate({ name: "alpha", count: 2, tags: ["a"], mode: "code" }).valid, "accept valid nested object");
		const missing = compiled.validator.validate({ name: "alpha", count: 2, tags: ["a"] });
		check(!missing.valid && missing.errors[0]?.keyword === "required", "reject missing required property");
		const extra = compiled.validator.validate({ name: "alpha", count: 2, tags: ["a"], mode: "code", extra: true });
		check(!extra.valid && extra.errors[0]?.instancePath === "/extra", "reject additional property with path");
		const nested = compiled.validator.validate({ name: "alpha", count: 2, tags: ["a"], mode: "code", meta: { enabled: "yes" } });
		check(!nested.valid && nested.errors[0]?.instancePath === "/meta/enabled", "report nested instance path");
		check(!compiled.validator.validate({ name: "alpha", count: 2.5, tags: ["a"], mode: "code" }).valid, "reject fractional integer");
		check(!compiled.validator.validate({ name: "alpha", count: 2, tags: [], mode: "code" }).valid, "enforce minItems");
	}

	check(validateJsonValue({ type: ["string", "null"] }, json.null).valid, "accept Dora JSON null");
	check(validateJsonValue({ type: ["string", "null"] }, "ok").valid, "accept type union");
	check(!validateJsonValue({ type: ["string", "null"] }, false).valid, "reject value outside type union");
	check(validateJsonValue({ type: "string", minLength: 2, maxLength: 2 }, "你好").valid, "count UTF-8 characters");
	check(validateJsonValue({ minimum: 1, maximum: 2 }, 1).valid, "accept inclusive numeric boundary");
	check(!validateJsonValue({ exclusiveMinimum: 1 }, 1).valid, "reject exclusive numeric boundary");
	check(!validateJsonValue({ type: "number" }, math.huge).valid, "reject non-finite number");

	check(validateJsonValue({ const: { a: [1, "x"] } }, { a: [1, "x"] }).valid, "deep compare const");
	check(validateJsonValue({ enum: [{ a: 1 }, { a: 2 }] }, { a: 2 }).valid, "deep compare enum");
	check(validateJsonValue({ anyOf: [{ type: "string" }, { type: "number" }] }, 3).valid, "accept anyOf branch");
	check(!validateJsonValue({ anyOf: [{ type: "string" }, { type: "number" }] }, true).valid, "reject all anyOf branches");
	check(validateJsonValue({ oneOf: [{ type: "integer" }, { type: "string" }] }, 3).valid, "accept exactly one oneOf branch");
	check(!validateJsonValue({ oneOf: [{ type: "number" }, { type: "integer" }] }, 3).valid, "reject multiple oneOf branches");
	check(validateJsonValue({ not: { type: "string" } }, 3).valid, "accept value rejected by not branch");
	check(!validateJsonValue({ not: { type: "string" } }, "x").valid, "reject value accepted by not branch");
	check(validateJsonValue({ allOf: [{ minimum: 1 }, { maximum: 3 }] }, 2).valid, "accept allOf constraints");
	check(!validateJsonValue({ allOf: [{ minimum: 1 }, { maximum: 3 }] }, 4).valid, "reject failed allOf constraint");

	const escaped = validateJsonValue({
		type: "object",
		properties: { "a/b": { type: "number" } },
	}, { "a/b": "x" });
	check(!escaped.valid && escaped.errors[0]?.instancePath === "/a~1b", "escape JSON pointer path");

	const sparse: unknown[] = [1, 2];
	sparse[0] = undefined;
	check(!validateJsonValue({ type: "array" }, sparse).valid, "reject sparse or undefined array item");

	const cyclic: Record<string, unknown> = {};
	cyclic.self = cyclic;
	check(!validateJsonValue(true, cyclic).valid, "reject cyclic instance");
	const cyclicSchema: Record<string, unknown> = { type: "object" };
	cyclicSchema.not = cyclicSchema;
	check(!validateJsonSchema(cyclicSchema).valid, "reject cyclic schema");

	const bounded = validateJsonValue({
		type: "object",
		additionalProperties: false,
	}, { a: 1, b: 2, c: 3 }, { maxErrors: 2 });
	check(!bounded.valid && bounded.errors.length === 2 && bounded.truncated, "bound validation errors");

	let deepSchema: JsonSchema = { type: "string" };
	for (let i = 0; i < 8; i++) deepSchema = { not: deepSchema };
	check(!validateJsonSchema(deepSchema, { maxDepth: 4 }).valid, "bound schema recursion depth");
	check(validateJsonValue(true, { value: 1 }).valid, "accept true schema");
	check(!validateJsonValue(false, { value: 1 }).valid, "reject false schema");

	return {
		success: failures.length === 0,
		passed,
		total,
		failures,
	};
}
