import { Content, Director, Log, Node as DNode, Path, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Panel } from "UIX";

const resultFile = Path(Content.writablePath, "UIXConditionalPanelKeyTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXConditionalPanelKeyTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const settingsOpen = signal(true);
const settingsRef = reference<Dora.AlignNode.Type>();
const skillsRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		{settingsOpen.value ?
			<Panel
				key="settings-panel"
				ref={settingsRef}
				title="Settings"
				style={{ position: "absolute", left: 18, top: 142, width: 360, height: 150 }}
			/> : undefined}
		<Panel
			key="skills-panel"
			ref={skillsRef}
			title="Skills"
			style={{ position: "absolute", right: 18, bottom: 18, width: 286, height: 128 }}
		/>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(settingsRef.current !== undefined, "settings panel was not mounted");
	expect(skillsRef.current !== undefined, "skills panel was not mounted");
	const firstSkills = skillsRef.current!;
	settingsOpen.value = false;
	Director.systemScheduler.schedule(once(() => {
		expect(skillsRef.current === firstSkills, "keyed skills panel should be preserved after removing previous conditional sibling");
		expect(settingsRef.current === undefined, "settings panel ref should be cleared after unmount");
		Content.save(resultFile, "passed");
		Log("Info", "[UIXConditionalPanelKeyTest] passed");
		host.removeFromParent(true);
		root.unmount();
	}));
}));
