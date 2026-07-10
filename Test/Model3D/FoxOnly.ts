// @preview-file on clear
import { App, Camera3D, Director, Model3D, Vec2, Vec3, threadLoop } from "Dora";
import { SetCond, WindowFlag } from "ImGui";
import * as ImGui from "ImGui";

const camera = Camera3D();
camera.lookAt(Vec3(0, 0.75, 3.2), Vec3(0, 0.45, 0));
Director.pushCamera(camera);

const view = Director.entry;

view.setEnvironmentMap("Test/Model3D/Assets/Env/studio.png");
view.setEnvironmentIntensity(1.0, 1.8, 1.2);

const fox = Model3D("Test/Model3D/Assets/Model/Fox.glb");
view.addChild(fox);
fox.scaleX = 0.015;
fox.scaleY = 0.015;
fox.scaleZ = 0.015;
fox.speed = 1.0;
fox.play("Run", true);

let elapsed = 0;
let speed = 1.0;

threadLoop(() => {
	elapsed += App.deltaTime;
	fox.angleY = elapsed * 22.5;

	const {width} = App.visualSize;
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), SetCond.FirstUseEver, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(280, 0), SetCond.FirstUseEver);
	ImGui.SetNextWindowBgAlpha(0.42);
	ImGui.Begin("Fox Normal", [WindowFlag.NoSavedSettings, WindowFlag.NoFocusOnAppearing], () => {
		ImGui.Text("Fox Animation");
		ImGui.Text("Env: Studio");
		ImGui.Text(`Playing: ${fox.playing ? "true" : "false"}`);
		ImGui.Text(`Paused: ${fox.paused ? "true" : "false"}`);
		ImGui.Text(`Time: ${fox.elapsed.toFixed(2)} / ${fox.duration.toFixed(2)}`);
		let changed = false;
		ImGui.PushItemWidth(-80, () => {
			[changed, speed] = ImGui.DragFloat("Speed", speed, 0.05, 0, 3, "%.2f");
		});
		if (changed) {
			fox.speed = speed;
		}
		if (ImGui.Button(fox.paused ? "Resume" : "Pause", Vec2(90, 28))) {
			if (fox.paused) {
				fox.resume();
			} else {
				fox.pause();
			}
		}
		ImGui.SameLine();
		if (ImGui.Button("Stop", Vec2(80, 28))) {
			fox.stop();
		}
		ImGui.SameLine();
		if (ImGui.Button("Play", Vec2(80, 28))) {
			fox.play("Run", true);
		}
	});

	return false;
});
