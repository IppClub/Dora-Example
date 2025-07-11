// @preview-file on clear
import { React, toNode } from 'DoraX';
import { App, Vec2, threadLoop, Node } from 'Dora';
import { SetCond, WindowFlag } from 'ImGui';
import * as ImGui from 'ImGui';

let current: Node.Type | null = null;

function Test(name: string, jsx: React.Element) {
	return {name, test: () => {
		current = toNode(
			<node scaleX={50} scaleY={50} scaleZ={10}>
			{jsx}
			</node>);
	}};
}

const tests = [

	Test("Laser",
		<effek-node angleY={-90}>
			<effek file='Particle/effek/Laser01.efk' x={-200}/>
		</effek-node>
	),

	Test("Simple Model UV",
		<effek-node>
			<effek file='Particle/effek/Simple_Model_UV.efkefc'/>
		</effek-node>
	),

	Test("Sword Lightning",
		<effek-node>
			<effek file='Particle/effek/sword_lightning.efkefc'/>
		</effek-node>
	),
];

tests[0].test();

const testNames = tests.map(t => t.name);

let currentTest = 1;
const windowFlags = [
	WindowFlag.NoDecoration,
	WindowFlag.NoSavedSettings,
	WindowFlag.NoFocusOnAppearing,
	WindowFlag.NoNav,
	WindowFlag.NoMove
];
threadLoop(() => {
	const {width} = App.visualSize;
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), SetCond.Always, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(200, 0), SetCond.Always);
	ImGui.Begin("Effekseer", windowFlags, () => {
		ImGui.Text("Effekseer (TSX)");
		ImGui.Separator();
		let changed = false;
		[changed, currentTest] = ImGui.Combo("Test", currentTest, testNames);
		if (changed) {
			if (current) {
				current.removeFromParent();
			}
			tests[currentTest - 1].test();
		}
	});
	return false;
});
