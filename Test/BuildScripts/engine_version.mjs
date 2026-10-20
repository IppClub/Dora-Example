import fs from "node:fs";
import path from "node:path";

const source = fs.readFileSync(path.resolve(process.env.DORA_ENGINE_ROOT || ".", "Source/Basic/Application.cpp"), "utf8");
const match = source.match(/^#define DORA_VERSION "([^"\n]+)"_slice$/m);
if (!match) throw new Error("Cannot read DORA_VERSION from engine source");
export const engineVersion = match[1];
