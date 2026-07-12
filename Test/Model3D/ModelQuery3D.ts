// @preview-file on clear
import {
	App,
	Camera3D,
	Color3,
	Content,
	DirectionalLight3D,
	Director,
	Model3D,
	Node3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(3.5, 2.5, 7), Vec3(0, 1.2, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0.2, 0, 1);
view.showAABB = true;

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 4;
light.angleX = -35;
light.angleY = 25;
view.addChild(light);

const fox = Model3D("Test/Model3D/Assets/Model/Fox.glb");
fox.scale = Vec3(0.02, 0.02, 0.02);
view.addChild(fox);

const animationNames: string[] = [];
for (let i = 0; i < fox.animationCount; i += 1) {
	animationNames.push(fox.getAnimationName(i));
}

const attachment = Node3D();
const nodeName = "b_Head_05";
const hasHead = fox.hasNode(nodeName);
const attached = fox.attachToNode(nodeName, attachment);
const attachmentStart = attachment.convertToWorldSpace(Vec3(0, 0, 0));

const localMin = fox.getLocalBoundsMin();
const localMax = fox.getLocalBoundsMax();
const worldMin = fox.getWorldBoundsMin();
const worldMax = fox.getWorldBoundsMax();
const boundsValid = localMax.x > localMin.x
	&& localMax.y > localMin.y
	&& localMax.z > localMin.z
	&& worldMax.x > worldMin.x
	&& worldMax.y > worldMin.y
	&& worldMax.z > worldMin.z;

fox.play("Run", true);

let elapsed = 0;
let status = "Pending";
let attachmentDelta = 0;
let verified = false;
threadLoop(() => {
	elapsed += App.deltaTime;
	if (!verified && elapsed >= 2) {
		verified = true;
		const current = attachment.convertToWorldSpace(Vec3(0, 0, 0));
		const dx = current.x - attachmentStart.x;
		const dy = current.y - attachmentStart.y;
		const dz = current.z - attachmentStart.z;
		attachmentDelta = Math.sqrt(dx * dx + dy * dy + dz * dz);
		const passed = animationNames.length === 3
			&& animationNames.indexOf("Run") >= 0
			&& hasHead
			&& attached
			&& boundsValid
			&& attachmentDelta > 0.001;
		status = passed ? "PASS" : "FAIL";
		const screenshot = App.saveScreenshot("/tmp/dora-3d-model-query/model-query-runtime");
		const summary = `MODEL_QUERY_SUMMARY status=${status} animations=${animationNames.join(",")} hasHead=${hasHead} attached=${attached} bounds=${boundsValid} attachmentDelta=${attachmentDelta.toFixed(4)} localMin=${localMin.x.toFixed(2)},${localMin.y.toFixed(2)},${localMin.z.toFixed(2)} localMax=${localMax.x.toFixed(2)},${localMax.y.toFixed(2)},${localMax.z.toFixed(2)} screenshot=${screenshot}`;
		Content.save("/tmp/dora-3d-model-query/summary.txt", summary);
		print(summary);
	}

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(440, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.8);
	ImGui.Begin("Model3D Query", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Animations (${animationNames.length}): ${animationNames.join(", ")}`);
		ImGui.Text(`Node ${nodeName}: ${hasHead ? "Found" : "Missing"}`);
		ImGui.Text(`Attachment: ${attached ? "Attached" : "Failed"}`);
		ImGui.Text(`Attachment delta: ${attachmentDelta.toFixed(4)}`);
		ImGui.Text(`Local bounds valid: ${boundsValid ? "true" : "false"}`);
		ImGui.Text(`Verification: ${status}`);
	});
	return false;
});
