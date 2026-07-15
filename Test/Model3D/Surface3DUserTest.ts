// @preview-file on clear
import {
	App,
	Billboard,
	Camera3D,
	ClipNode,
	Color,
	Color3,
	DirectionalLight3D,
	Director,
	DrawNode,
	Model3D,
	Node,
	Size,
	Surface3D,
	Vec2,
	Vec3,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";

const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(0, 2.5, 7.5), Vec3(0, 1.1, 0));
Director.pushCamera(camera);
view.setEnvironmentMap("");
view.setEnvironmentIntensity(0.22, 0.05, 1);

const light = DirectionalLight3D();
light.color = Color3(0xfff2dc);
light.intensity = 4;
light.angleX = -38;
light.angleY = 30;
view.addChild(light);

const ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf");
ground.position = Vec3(0, -0.72, 0);
view.addChild(ground);

const rearDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
rearDuck.position = Vec3(0.45, 0, -0.8);
rearDuck.scale = Vec3(0.9, 0.9, 0.9);
rearDuck.angleY = -25;
rearDuck.getMaterial(0)!.baseColor = Color(0xff58d68d);
view.addChild(rearDuck);

const frontDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
frontDuck.position = Vec3(-0.35, 0, 1.0);
frontDuck.scale = Vec3(0.9, 0.9, 0.9);
frontDuck.angleY = 25;
frontDuck.getMaterial(0)!.baseColor = Color(0xffff7f50);
view.addChild(frontDuck);

function makePanel() {
	const panel = DrawNode();
	panel.drawPolygon([
		Vec2(0, 0),
		Vec2(128, 0),
		Vec2(128, 88),
		Vec2(0, 88),
	], Color(0xff246bfd), 3, Color(0xffbde0fe));
	panel.drawDot(Vec2(25, 44), 15, Color(0xffff7f50));
	panel.drawDot(Vec2(64, 44), 15, Color(0xffffbe0b));
	panel.drawDot(Vec2(103, 44), 15, Color(0xff58d68d));
	return panel;
}

const content = Node();
content.size = Size(128, 88);
content.addChild(makePanel());

const surface = Surface3D(content, Size(3.2, 2.2), Size(256, 176))!;
if (!surface) error("Surface3D creation failed");
surface.position = Vec3(0, 1.15, 0);
view.addChild(surface);

const modes = ["Direct DrawNode", "Dynamic ClipNode", "Generic Node fallback", "Grabber fallback"];
const billboards = ["None", "Screen", "Y axis"];
let mode = 1;
let billboard = 1;
let activeNode: Node.Type | undefined;
let targetMode = "direct";

function clearMode() {
	content.grab(false);
	if (activeNode) {
		content.removeChild(activeNode, true);
		activeNode = undefined;
	}
}

function setMode(next: number) {
	clearMode();
	mode = next;
	if (mode === 2) {
		const stencil = DrawNode();
		stencil.drawDot(Vec2(64, 44), 34, Color(0xffffffff));
		const clip = ClipNode(stencil);
		const fill = DrawNode();
		fill.drawPolygon([
			Vec2(12, 6),
			Vec2(116, 6),
			Vec2(116, 82),
			Vec2(12, 82),
		], Color(0xddee4b2b));
		clip.addChild(fill);
		content.addChild(clip);
		activeNode = clip;
		targetMode = "texture (ClipNode depth/stencil isolation)";
	} else if (mode === 3) {
		const group = Node();
		const mark = DrawNode();
		mark.drawDot(Vec2(64, 44), 27, Color(0xddff2da8));
		group.addChild(mark);
		content.addChild(group);
		activeNode = group;
		targetMode = "texture (conservative generic-node fallback)";
	} else if (mode === 4) {
		content.grab(true);
		targetMode = "texture (grabber owns a render pass)";
	} else {
		targetMode = "direct (depth-preserving Surface3D view)";
	}
}

function setBillboard(next: number) {
	billboard = next;
	surface.billboard = next === 2 ? Billboard.Screen : next === 3 ? Billboard.YAxis : Billboard.None;
}

setMode(mode);
print("SURFACE_3D_USER_TEST_READY");
threadLoop(() => {
	frontDuck.angleY += App.deltaTime * 25;
	rearDuck.angleY -= App.deltaTime * 18;

	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(390, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.88);
	ImGui.Begin("Surface3D User Test", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text("The orange duck is in front of the 2D surface.");
		ImGui.Text("The green duck is behind it.");
		ImGui.Text("Their overlap verifies shared 3D depth.");
		ImGui.Separator();

		let changed = false;
		[changed, mode] = ImGui.Combo("2D subtree", mode, modes);
		if (changed) setMode(mode);
		[changed, billboard] = ImGui.Combo("Billboard", billboard, billboards);
		if (changed) setBillboard(billboard);

		if (ImGui.Button("Rotate -30 deg", Vec2(175, 30))) surface.angleY -= 30;
		ImGui.SameLine();
		if (ImGui.Button("Rotate +30 deg", Vec2(175, 30))) surface.angleY += 30;
		if (ImGui.Button("Reset", Vec2(-1, 30))) {
			surface.angleY = 0;
			setBillboard(1);
			setMode(1);
		}

		ImGui.Separator();
		ImGui.Text(`Expected: ${targetMode}`);
		ImGui.Text(`Actual backend: ${surface.usingTexture ? "texture" : "direct"}`);
		ImGui.Text(`Surface yaw: ${surface.angleY.toFixed(0)} deg`);
		ImGui.Text(`Draw calls: ${view.stats.drawCalls}`);
		const backendMatches = surface.usingTexture === (mode !== 1);
		ImGui.Text(`Backend selection: ${backendMatches ? "PASS" : "UPDATING"}`);
	});
	return false;
});
