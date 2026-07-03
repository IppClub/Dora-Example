import { Content, Director, Log, Node as DNode, Path, TextAlign, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference } from "DoraX";
import { Column, Text } from "UIX";

const resultFile = Path(Content.writablePath, "UIXTextMultilineTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXTextMultilineTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const plainRef = reference<Dora.AlignNode.Type>();
const wrapRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Column style={{ width: 260, gap: 8 }}>
			<Text
				ref={plainRef}
				key="plain-newline"
				text={"First line\nSecond line"}
				alignment={TextAlign.Left}
				verticalAlign="top"
			/>
			<Text
				ref={wrapRef}
				key="wrap-newline"
				text={"Alpha beta gamma\nDelta epsilon zeta"}
				alignment={TextAlign.Left}
				wrap
				style={{ width: 120 }}
			/>
		</Column>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(plainRef.current !== undefined, "plain multiline text did not mount");
	expect(wrapRef.current !== undefined, "wrapped multiline text did not mount");
	expect(plainRef.current!.height >= 40, `plain multiline height is too small: ${plainRef.current!.height}`);
	expect(wrapRef.current!.height >= 40, `wrapped multiline height is too small: ${wrapRef.current!.height}`);
	Content.save(resultFile, "passed");
	Log("Info", "[UIXTextMultilineTest] passed");
	host.removeFromParent(true);
	root.unmount();
}));
