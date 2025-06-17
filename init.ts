// @preview-file on clear
import { WindowFlag, SetCond } from "ImGui";
import * as ImGui from "ImGui";
import { App, Vec2, threadLoop } from "Dora";

const windowFlags = [
	WindowFlag.NoDecoration,
	WindowFlag.AlwaysAutoResize,
	WindowFlag.NoSavedSettings,
	WindowFlag.NoFocusOnAppearing,
	WindowFlag.NoNav,
	WindowFlag.NoMove
];
threadLoop(() => {
	const size = App.visualSize;
	ImGui.SetNextWindowBgAlpha(0.35);
	ImGui.SetNextWindowPos(Vec2(size.width - 10, 10), SetCond.Always, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(240, 0), SetCond.FirstUseEver);
	let stop = false;
	ImGui.Begin("Examples", windowFlags, () => {
		ImGui.Text("Dora Example");
		ImGui.Separator();
		ImGui.TextWrapped("Showcases code snippet-based demonstrations of features in the Dora SSR game engine. See more in the example tab.");
		if (ImGui.Button("Try Snake")) {
			require("Example/Snake");
			stop = true;
		}
	});
	return stop;
});
