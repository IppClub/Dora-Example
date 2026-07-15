import {App, Content, Director, Node, sleep, thread} from "Dora";

const resultPath = "/tmp/dora-2d-auto-managed-result.txt";
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`AUTO_MANAGED_2D_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
	Content.save(resultPath, `${results.join("\n")}\n`);
	App.devMode = false;
	App.shutdown();
}

function expect(condition: boolean, reason: string) {
	if (!condition) {
		finish("FAIL", reason);
		error(reason);
	}
}

Content.remove(resultPath);

const automaticNode = Node();
automaticNode.tag = "automatic-2d-node";

const explicitRoot = Node();
explicitRoot.tag = "explicit-2d-root";
const explicitChild = Node();
explicitChild.tag = "explicit-2d-child";
explicitRoot.addChild(explicitChild);

const cleanedNode = Node();
cleanedNode.cleanup();

thread(() => {
	sleep();
	expect(automaticNode.parent === Director.entry, "node_not_auto_attached");
	expect(explicitRoot.parent === Director.entry, "explicit_root_not_auto_attached");
	expect(explicitChild.parent === explicitRoot, "explicit_child_was_reparented");
	expect(cleanedNode.parent === undefined, "cleaned_node_was_auto_attached");

	emit("AUTO_MANAGED_2D_RESULT node=PASS explicit=PASS cleanup=PASS");
	finish("PASS");
});
