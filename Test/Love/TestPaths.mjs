import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

export const testRoot = path.dirname(fileURLToPath(import.meta.url));

function candidates() {
	return [
		process.env.DORA_SSR_ROOT,
		path.resolve(testRoot, "../../../Dora-SSR"),
		path.resolve(testRoot, "../../../../Dora-SSR"),
	].filter(Boolean);
}

export function resolveDoraSSRRoot() {
	for (const candidate of candidates()) {
		const root = path.resolve(candidate);
		if (fs.existsSync(path.join(root, "Source/Love/LoveRuntime.cpp"))) return root;
	}
	throw new Error("set DORA_SSR_ROOT to a Dora-SSR checkout");
}

export const doraSSRRoot = resolveDoraSSRRoot();
export const doraSourceRoot = path.join(doraSSRRoot, "Source");
