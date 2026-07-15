import {
	App,
	Body3D,
	BodyDef3D,
	Content,
	DirectionalLight3D,
	Director,
	FixtureDef3D,
	Model3D,
	Node3D,
	PhysicsWorld3D,
	Vec3,
	sleep,
	thread,
} from "Dora";

const resultPath = "/tmp/dora-3d-auto-managed-result.txt";
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`AUTO_MANAGED_3D_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
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

const view = Director.entry;
const scene = view.scene;

const automaticNode = Node3D();
automaticNode.tag = "automatic-node";

const explicitRoot = Node3D();
explicitRoot.tag = "explicit-root";
const explicitChild = Node3D();
explicitChild.tag = "explicit-child";
explicitRoot.addChild(explicitChild);

const automaticModel = Model3D("Test/Model3D/Assets/Model/Duck.glb");
automaticModel.tag = "automatic-model";

const automaticLight = DirectionalLight3D();
automaticLight.tag = "automatic-light";

const world = PhysicsWorld3D();
const bodyDef = BodyDef3D();
bodyDef.type = PhysicsWorld3D.Static;
bodyDef.attach(FixtureDef3D.box(Vec3(0.5, 0.5, 0.5)));
const automaticBody = Body3D(bodyDef, world, Vec3(0, -2, 0));
automaticBody.tag = "automatic-body";

const cleanedNode = Node3D();
cleanedNode.cleanup();

thread(() => {
	sleep();
	expect(scene.parent === undefined, "scene_root_was_auto_attached");
	expect(automaticNode.parent === scene, "node3d_not_auto_attached");
	expect(explicitRoot.parent === scene, "explicit_root_not_auto_attached");
	expect(explicitChild.parent === explicitRoot, "explicit_child_was_reparented");
	expect(automaticModel.parent === scene, "model3d_not_auto_attached");
	expect(automaticLight.parent === scene, "light3d_not_auto_attached");
	expect(automaticBody.parent === scene, "body3d_not_auto_attached");
	expect(cleanedNode.parent === undefined, "cleaned_node_was_auto_attached");

	emit("AUTO_MANAGED_3D_RESULT node=PASS explicit=PASS model=PASS light=PASS body=PASS cleanup=PASS");
	finish("PASS");
});
