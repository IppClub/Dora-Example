import {
	App,
	Billboard,
	ClipNode,
	Color,
	Content,
	Director,
	DrawNode,
	Node,
	Size,
	Surface3D,
	Vec2,
	sleep,
	thread,
} from "Dora";

const resultPath = "/tmp/dora-3d-surface-result.txt";
const results: string[] = [];

function emit(message: string) {
	print(message);
	results.push(message);
}

function finish(status: "PASS" | "FAIL", reason = "") {
	emit(`SURFACE_3D_SUMMARY status=${status}${reason === "" ? "" : ` reason=${reason}`}`);
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

function makeDot(radius: number, color: number) {
	const draw = DrawNode();
	draw.drawDot(Vec2(32, 32), radius, Color(color));
	return draw;
}

Content.remove(resultPath);

const content = Node();
content.size = Size(64, 64);
content.addChild(makeDot(24, 0xff4cc9f0));

const surface = Surface3D(content, Size(2, 2), Size(64, 64));
if (surface === undefined) {
	finish("FAIL", "surface_create_failed");
	error("surface_create_failed");
}

Director.entry.addChild(surface);

thread(() => {
	// The initial DrawNode-only subtree can safely share View3D's bgfx view.
	sleep();
	expect(!surface.usingTexture, "simple_subtree_did_not_use_direct_mode");

	// ClipNode owns depth/stencil state, so adding it at runtime must isolate
	// the complete 2D subtree in a render target on the following frame.
	const stencil = makeDot(20, 0xffffffff);
	const clip = ClipNode(stencil);
	clip.addChild(makeDot(28, 0xffffbe0b));
	content.addChild(clip);
	sleep();
	expect(surface.usingTexture, "dynamic_clipnode_did_not_use_texture");

	// The decision is adaptive rather than a sticky/manual render mode.
	content.removeChild(clip, true);
	sleep();
	expect(!surface.usingTexture, "removed_clipnode_did_not_restore_direct_mode");

	// A generic nested Node is conservatively treated as incompatible with
	// the shared view even when its current child happens to be a DrawNode.
	const isolatedSubtree = Node();
	isolatedSubtree.addChild(makeDot(12, 0xfff72585));
	content.addChild(isolatedSubtree);
	sleep();
	expect(surface.usingTexture, "generic_2d_subtree_did_not_use_texture");

	content.removeChild(isolatedSubtree, true);
	sleep();
	expect(!surface.usingTexture, "removed_generic_subtree_did_not_restore_direct_mode");

	// Grabber-backed effects allocate their own pass and must also be isolated.
	content.grab(true);
	sleep();
	expect(surface.usingTexture, "grabber_did_not_use_texture");

	surface.billboard = Billboard.Screen;
	expect(surface.billboard === Billboard.Screen, "screen_billboard_roundtrip_failed");
	surface.billboard = Billboard.YAxis;
	expect(surface.billboard === Billboard.YAxis, "y_axis_billboard_roundtrip_failed");
	surface.billboard = Billboard.None;
	expect(surface.billboard === Billboard.None, "billboard_disable_roundtrip_failed");

	emit("SURFACE_3D_RESULT direct=PASS clip=PASS dynamic=PASS fallback=PASS grabber=PASS billboard=PASS");
	finish("PASS");
});
