import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference } from "DoraX";
import { Badge, Row } from "UIX";

const resultFile = Path(Content.writablePath, "UIXBadgeDisplayTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXBadgeDisplayTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const readyRef = reference<Dora.AlignNode.Type>();
const rareRef = reference<Dora.AlignNode.Type>();
const manaRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Row gap={6}>
			<Badge ref={readyRef} tone="success" icon="check">Ready</Badge>
			<Badge ref={rareRef} tone="warm" dot>Rare</Badge>
			<Badge ref={manaRef} tone="mana" outline text="Mana" />
		</Row>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(readyRef.current !== undefined, "ready badge ref missing");
	expect(rareRef.current !== undefined, "rare badge ref missing");
	expect(manaRef.current !== undefined, "mana badge ref missing");
	expect(readyRef.current!.width > 0, "ready badge width missing");
	expect(rareRef.current!.height > 0, "rare badge height missing");
	Content.save(resultFile, "passed");
	Log("Info", "[UIXBadgeDisplayTest] passed");
	host.removeFromParent(true);
	root.unmount();
}));
