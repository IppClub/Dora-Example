// @preview-file on clear
import {
	AlignNode,
	App,
	Billboard,
	AudioSource,
	Body,
	BodyDef,
	BodyMoveType,
	Camera3D,
	ClipNode,
	Color,
	Color3,
	DirectionalLight3D,
	Director,
	DragonBone,
	DrawNode,
	EffekNode,
	Grid,
	Label,
	Line,
	Menu,
	Model,
	Model3D,
	Node,
	Particle,
	PhysicsWorld3D,
	PhysicsWorld,
	Playable,
	Size,
	Spine,
	Sprite,
	Surface3D,
	TIC80Node,
	TileNode,
	Vec2,
	Vec3,
	VGNode,
	VideoNode,
	View3D,
	threadLoop,
} from "Dora";
import {SetCond, WindowFlag} from "ImGui";
import * as ImGui from "ImGui";
import * as nvg from "nvg";

const logicalSize = Size(320, 200);
const view = Director.entry;
const camera = Camera3D();
camera.lookAt(Vec3(0, 2.7, 8.8), Vec3(0, 1.25, 0));
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
rearDuck.position = Vec3(0.55, 0, -0.9);
rearDuck.scale = Vec3(0.88, 0.88, 0.88);
rearDuck.getMaterial(0)!.baseColor = Color(0xff58d68d);
view.addChild(rearDuck);

const frontDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
frontDuck.position = Vec3(-0.55, 0, 1.0);
frontDuck.scale = Vec3(0.88, 0.88, 0.88);
frontDuck.getMaterial(0)!.baseColor = Color(0xffff7f50);
view.addChild(frontDuck);

function panel(color = Color(0xff246bfd)) {
	const node = DrawNode();
	node.drawPolygon([
		Vec2(0, 0),
		Vec2(logicalSize.width, 0),
		Vec2(logicalSize.width, logicalSize.height),
		Vec2(0, logicalSize.height),
	], color, 4, Color(0xffbde0fe));
	return node;
}

function dot(pos: Vec2.Type, radius: number, color: Color.Type) {
	const node = DrawNode();
	node.drawDot(pos, radius, color);
	return node;
}

function textLabel(text: string, size = 28) {
	const label = Label("sarasa-mono-sc-regular", size)!;
	label.text = text;
	label.color = Color(0xffffffff);
	return label;
}

function unavailable(name: string) {
	const root = Node();
	root.addChild(dot(Vec2(160, 100), 55, Color(0xff6c757d)));
	const label = textLabel(`${name}\nresource unavailable`, 20);
	label.position = Vec2(160, 100);
	root.addChild(label);
	return root;
}

function centered(node: Node.Type, position = Vec2(160, 100)) {
	node.position = position;
	return node;
}

interface Scenario {
	name: string;
	coverage: string;
	expectedTexture: boolean;
	manualCheck?: string;
	build: () => Node.Type | undefined;
}

const scenarios: Scenario[] = [
	{
		name: "Single / DrawNode",
		coverage: "DrawNode shape renderer; direct backend",
		expectedTexture: false,
		build: () => dot(Vec2(160, 100), 64, Color(0xffffbe0b)),
	},
	{
		name: "Single / Sprite",
		coverage: "Sprite texture renderer; direct backend",
		expectedTexture: false,
		build: () => {
			const sprite = Sprite("Image/icon.png");
			if (!sprite) return undefined;
			sprite.position = Vec2(160, 100);
			sprite.scaleX = 0.65;
			sprite.scaleY = 0.65;
			return sprite;
		},
	},
	{
		name: "Single / Label",
		coverage: "Label glyph batching and font texture",
		expectedTexture: true,
		manualCheck: "The text must read LEFT to RIGHT without horizontal mirroring.",
		build: () => centered(textLabel("LEFT  Surface3D  RIGHT\nLabel", 24)),
	},
	{
		name: "Single / Line",
		coverage: "Line vertex renderer",
		expectedTexture: true,
		build: () => Line([
			Vec2(50, 35), Vec2(270, 35), Vec2(70, 165),
			Vec2(160, 55), Vec2(250, 165), Vec2(50, 35),
		], Color(0xffffbe0b)),
	},
	{
		name: "Single / Grid",
		coverage: "Grid textured mesh with deformed vertices",
		expectedTexture: true,
		build: () => {
			const grid = Grid("Image/icon.png", 4, 3);
			grid.position = Vec2(85, 25);
			grid.scaleX = 0.58;
			grid.scaleY = 0.58;
			const pos = grid.getPos(2, 1);
			grid.setPos(2, 1, pos.add(Vec2(24, 18)), 0.15);
			grid.setColor(2, 1, Color(0xffffbe0b));
			return grid;
		},
	},
	{
		name: "Single / ClipNode",
		coverage: "ClipNode stencil writes isolated in RenderTarget",
		expectedTexture: true,
		build: () => {
			const stencil = dot(Vec2(160, 100), 70, Color(0xffffffff));
			const clip = ClipNode(stencil);
			clip.addChild(panel(Color(0xffe63946)));
			return clip;
		},
	},
	{
		name: "Container / Node",
		coverage: "Generic Node container with transformed children",
		expectedTexture: true,
		build: () => {
			const root = Node();
			const child = dot(Vec2.zero, 44, Color(0xffa855f7));
			child.position = Vec2(160, 100);
			child.angle = 18;
			root.addChild(child);
			return root;
		},
	},
	{
		name: "Container / AlignNode",
		coverage: "AlignNode layout container and layout callback",
		expectedTexture: true,
		build: () => {
			const align = AlignNode(false);
			align.size = logicalSize;
			align.css("width: 320; height: 200; justify-content: center; align-items: center");
			const marker = dot(Vec2.zero, 48, Color(0xff22c55e));
			align.addChild(marker);
			return align;
		},
	},
	{
		name: "Container / Menu",
		coverage: "Menu interaction container inside a Surface3D subtree",
		expectedTexture: true,
		build: () => {
			const menu = Menu(320, 200);
			menu.position = Vec2(160, 100);
			menu.addChild(dot(Vec2.zero, 52, Color(0xfff97316)));
			return menu;
		},
	},
	{
		name: "Resource / Particle",
		coverage: "Particle renderer, scheduler and dynamic vertex count",
		expectedTexture: true,
		build: () => {
			const particle = Particle("Particle/fire.par");
			if (!particle) return undefined;
			particle.position = Vec2(160, 55);
			particle.start();
			return particle;
		},
	},
	{
		name: "Resource / Model",
		coverage: "Dora 2D Model playable and animation slots",
		expectedTexture: true,
		build: () => {
			const model = Model("Model/xiaoli.model");
			if (!model) return undefined;
			model.position = Vec2(160, 45);
			model.scaleX = 0.48;
			model.scaleY = 0.48;
			const animations = Model.getAnimations("Model/xiaoli.model");
			if (animations.length > 0) model.play(animations[0], true);
			return model;
		},
	},
	{
		name: "Resource / Playable",
		coverage: "Playable factory dispatch to Dora Model",
		expectedTexture: true,
		build: () => {
			const playable = Playable("model:Model/xiaoli.model");
			if (!playable) return undefined;
			playable.position = Vec2(160, 45);
			playable.scaleX = 0.48;
			playable.scaleY = 0.48;
			return playable;
		},
	},
	{
		name: "Resource / Spine",
		coverage: "Spine mesh animation",
		expectedTexture: true,
		build: () => {
			const spine = Spine("Spine/moling");
			if (!spine) return undefined;
			spine.position = Vec2(160, 20);
			spine.scaleX = 0.45;
			spine.scaleY = 0.45;
			const animations = Spine.getAnimations("Spine/moling");
			if (animations.length > 0) spine.play(animations[0], true);
			return spine;
		},
	},
	{
		name: "Resource / DragonBone",
		coverage: "DragonBone mesh animation",
		expectedTexture: true,
		build: () => {
			const bone = DragonBone("DragonBones/NewDragon");
			if (!bone) return undefined;
			bone.position = Vec2(160, 15);
			bone.scaleX = 0.32;
			bone.scaleY = 0.32;
			const animations = DragonBone.getAnimations("DragonBones/NewDragon");
			if (animations.length > 0) bone.play(animations[0], true);
			return bone;
		},
	},
	{
		name: "Resource / TileNode",
		coverage: "TMX TileNode renderer and multi-texture batching",
		expectedTexture: true,
		build: () => {
			const tile = TileNode("TMX/platform.tmx");
			if (!tile) return undefined;
			tile.position = Vec2(30, 15);
			tile.scaleX = 0.22;
			tile.scaleY = 0.22;
			return tile;
		},
	},
	{
		name: "Resource / EffekNode",
		coverage: "Effekseer standalone render pass",
		expectedTexture: true,
		manualCheck: "The lightning effect animates near the panel center; use Rebuild to replay it.",
		build: () => {
			const effect = EffekNode();
			effect.position = Vec2(160, 100);
			effect.scaleX = 10;
			effect.scaleY = 10;
			effect.play("Particle/effek/sword_lightning.efkefc");
			return effect;
		},
	},
	{
		name: "Resource / VGNode",
		coverage: "NanoVG framebuffer surface",
		expectedTexture: true,
		build: () => {
			const vg = VGNode(320, 200, 1);
			vg.render(() => {
				nvg.BeginPath();
				nvg.RoundedRect(35, 35, 250, 130, 24);
				nvg.FillColor(Color(0xff14b8a6));
				nvg.Fill();
				nvg.ClosePath();
			});
			return vg;
		},
	},
	{
		name: "Resource / VideoNode",
		coverage: "VideoNode dynamic Sprite texture (optional test asset)",
		expectedTexture: true,
		build: () => {
			const video = VideoNode("../random/test_640x360.h264", true);
			if (!video) return unavailable("VideoNode");
			video.position = Vec2(160, 100);
			video.scaleX = 0.5;
			video.scaleY = 0.5;
			return video;
		},
	},
	{
		name: "Resource / TIC80Node",
		coverage: "TIC80Node dynamic Sprite texture (optional test cart)",
		expectedTexture: true,
		build: () => {
			const tic = TIC80Node("../random/cart.tic");
			if (!tic) return unavailable("TIC80Node");
			tic.position = Vec2(160, 100);
			return tic;
		},
	},
	{
		name: "Lifecycle / AudioSource",
		coverage: "AudioSource node lifecycle plus visual sibling",
		expectedTexture: true,
		build: () => {
			const root = Node();
			const audio = AudioSource("Audio/di.wav", false);
			if (audio) root.addChild(audio);
			root.addChild(dot(Vec2(160, 100), 54, Color(0xff0ea5e9)));
			root.addChild(centered(textLabel("AudioSource", 22), Vec2(160, 100)));
			return root;
		},
	},
	{
		name: "Physics / World + Body",
		coverage: "PhysicsWorld, Body and debug renderer",
		expectedTexture: true,
		build: () => {
			const world = PhysicsWorld();
			world.showDebug = true;
			const def = BodyDef();
			def.type = BodyMoveType.Dynamic;
			def.attachDisk(42, 1, 0.4, 0.2);
			const body = Body(def, world, Vec2(160, 100));
			world.addChild(body);
			return world;
		},
	},
	{
		name: "Nested / View3D",
		coverage: "View3D nested inside the 2D subtree",
		expectedTexture: true,
		manualCheck: "Known failure under investigation: nested 3D content and blue panel should be visible",
		build: () => {
			const nested = View3D();
			nested.size = logicalSize;
			const duck = Model3D("Test/Model3D/Assets/Model/Duck.glb");
			duck.scale = Vec3(0.7, 0.7, 0.7);
			nested.addChild(duck);
			return nested;
		},
	},
	{
		name: "Lifecycle / PhysicsWorld3D",
		coverage: "PhysicsWorld3D 2D host-node lifecycle inside the subtree",
		expectedTexture: true,
		build: () => {
			const root = Node();
			const world = PhysicsWorld3D();
			world.gravity = Vec3(0, -9.81, 0);
			root.addChild(world);
			root.addChild(dot(Vec2(160, 100), 54, Color(0xff84cc16)));
			root.addChild(centered(textLabel("PhysicsWorld3D", 21), Vec2(160, 100)));
			return root;
		},
	},
	{
		name: "Tree / Direct siblings",
		coverage: "Sprite + multiple DrawNode siblings without generic containers",
		expectedTexture: false,
		build: () => {
			const sprite = Sprite("Image/icon.png");
			if (!sprite) return undefined;
			sprite.position = Vec2(160, 100);
			sprite.scaleX = 0.45;
			sprite.scaleY = 0.45;
			return sprite;
		},
	},
	{
		name: "Tree / Generic nested",
		coverage: "Three-level Node tree with transforms, order and opacity",
		expectedTexture: true,
		build: () => {
			const level1 = Node();
			level1.position = Vec2(160, 100);
			level1.angle = 12;
			const level2 = Node();
			level2.scaleX = 1.15;
			level2.scaleY = 0.85;
			const level3 = Node();
			level3.opacity = 0.82;
			level3.addChild(dot(Vec2(-42, 0), 38, Color(0xffffbe0b)));
			level3.addChild(dot(Vec2(42, 0), 38, Color(0xffa855f7)));
			level2.addChild(level3);
			level1.addChild(level2);
			return level1;
		},
	},
	{
		name: "Tree / Mixed renderers",
		coverage: "DrawNode + Sprite + Label + Line + ClipNode in one tree",
		expectedTexture: true,
		build: () => {
			const root = Node();
			root.addChild(dot(Vec2(65, 55), 34, Color(0xffffbe0b)));
			const sprite = Sprite("Image/icon.png");
			if (sprite) {
				sprite.position = Vec2(160, 100);
				sprite.scaleX = 0.32;
				sprite.scaleY = 0.32;
				root.addChild(sprite);
			}
			root.addChild(centered(textLabel("MIX", 28), Vec2(255, 145)));
			root.addChild(Line([Vec2(25, 175), Vec2(295, 175)], Color(0xffffffff)));
			const clip = ClipNode(dot(Vec2(255, 55), 32, Color(0xffffffff)));
			clip.addChild(dot(Vec2(255, 55), 55, Color(0xffef4444)));
			root.addChild(clip);
			return root;
		},
	},
	{
		name: "Tree / Grabber nested",
		coverage: "Generic tree owning its own Grabber render pass",
		expectedTexture: true,
		build: () => {
			const root = Node();
			root.size = logicalSize;
			root.addChild(dot(Vec2(120, 100), 58, Color(0xfff97316)));
			root.addChild(dot(Vec2(200, 100), 58, Color(0xff0ea5e9)));
			root.grab(true);
			return root;
		},
	},
	{
		name: "Tree / Dynamic churn",
		coverage: "Runtime-created and removed Node/ClipNode/Label/Sprite branches",
		expectedTexture: true,
		build: () => {
			const root = Node();
			let elapsed = 1;
			let generation = 0;
			root.schedule((deltaTime) => {
				elapsed += deltaTime;
				if (elapsed < 0.35) return false;
				elapsed = 0;
				generation++;
				root.removeAllChildren(true);
				for (let i = 0; i < 3 + generation % 4; i++) {
					const branch = Node();
					branch.position = Vec2(45 + i * 48, 100 + (i % 2) * 28);
					branch.addChild(dot(Vec2.zero, 22, Color(i % 2 === 0 ? 0xff22c55e : 0xffa855f7)));
					root.addChild(branch);
				}
				return false;
			});
			return root;
		},
	},
];

const content = Node();
content.size = logicalSize;
const surface = Surface3D(content, Size(4.8, 3.0), Size(640, 400))!;
if (!surface) error("Surface3D creation failed");
surface.position = Vec3(0, 1.35, 0);
view.addChild(surface);

let currentScenario = 1;
let currentNode: Node.Type | undefined;
let currentAvailable = true;
let rebuildCount = 0;
let autoAdvance = false;
let autoElapsed = 0;
let billboard = 1;

function applyScenario(index: number) {
	if (currentNode) {
		content.removeChild(currentNode, true);
		currentNode = undefined;
	}
	content.removeAllChildren(true);
	content.addChild(panel());
	currentScenario = index;
	const scenario = scenarios[currentScenario - 1];
	currentNode = scenario.build();
	currentAvailable = currentNode !== undefined;
	if (currentNode) content.addChild(currentNode);
	rebuildCount++;
	print(`SURFACE_MATRIX scenario=${scenario.name} rebuild=${rebuildCount}`);
}

function setBillboard(next: number) {
	billboard = next;
	surface.billboard = next === 2 ? Billboard.Screen : next === 3 ? Billboard.YAxis : Billboard.None;
}

applyScenario(currentScenario);
print(`SURFACE_3D_NODE_MATRIX_READY count=${scenarios.length}`);

threadLoop(() => {
	frontDuck.angleY += App.deltaTime * 25;
	rearDuck.angleY -= App.deltaTime * 18;
	if (autoAdvance) {
		autoElapsed += App.deltaTime;
		if (autoElapsed >= 2.5) {
			autoElapsed = 0;
			applyScenario(currentScenario % scenarios.length + 1);
		}
	}

	const scenario = scenarios[currentScenario - 1];
	ImGui.SetNextWindowPos(Vec2(12, 12), SetCond.Always);
	ImGui.SetNextWindowSize(Vec2(490, 0), SetCond.Always);
	ImGui.SetNextWindowBgAlpha(0.9);
	ImGui.Begin("Surface3D 2D Node Matrix", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text(`Coverage: ${scenarios.length} scenarios`);
		ImGui.TextWrapped(scenario.coverage);
		ImGui.Separator();

		let changed = false;
		[changed, currentScenario] = ImGui.Combo("2D node / tree", currentScenario, scenarios.map(item => item.name));
		if (changed) applyScenario(currentScenario);

		if (ImGui.Button("Previous", Vec2(145, 30))) {
			applyScenario((currentScenario + scenarios.length - 2) % scenarios.length + 1);
		}
		ImGui.SameLine();
		if (ImGui.Button("Rebuild", Vec2(145, 30))) applyScenario(currentScenario);
		ImGui.SameLine();
		if (ImGui.Button("Next", Vec2(145, 30))) applyScenario(currentScenario % scenarios.length + 1);

		[changed, autoAdvance] = ImGui.Checkbox("Auto advance every 2.5s", autoAdvance);
		if (changed) autoElapsed = 0;
		[changed, billboard] = ImGui.Combo("Billboard", billboard, ["None", "Screen", "Y axis"]);
		if (changed) setBillboard(billboard);

		if (ImGui.Button("Rotate -30 deg", Vec2(215, 30))) surface.angleY -= 30;
		ImGui.SameLine();
		if (ImGui.Button("Rotate +30 deg", Vec2(215, 30))) surface.angleY += 30;

		ImGui.Separator();
		const actualTexture = surface.usingTexture;
		const backendMatches = actualTexture === scenario.expectedTexture;
		ImGui.Text(`Expected backend: ${scenario.expectedTexture ? "texture" : "direct"}`);
		ImGui.Text(`Actual backend: ${actualTexture ? "texture" : "direct"}`);
		ImGui.Text(`Resource/build: ${currentAvailable ? "READY" : "UNAVAILABLE"}`);
		ImGui.Text(`Backend selection: ${backendMatches ? "PASS" : "UPDATING"}`);
		ImGui.TextWrapped(`Manual check: ${scenario.manualCheck ?? "node content remains visible inside the blue panel"}`);
		ImGui.Text(`Rebuilds: ${rebuildCount}  Draw calls: ${view.stats.drawCalls}`);
	});
	return false;
});
