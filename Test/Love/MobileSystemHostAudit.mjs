import fs from "node:fs";
import path from "node:path";
import {doraSSRRoot} from "./TestPaths.mjs";

function requireText(relativePath, needles) {
	const filename = path.join(doraSSRRoot, relativePath);
	const content = fs.readFileSync(filename, "utf8");
	for (const needle of needles) {
		if (!content.includes(needle)) {
			throw new Error(`${relativePath} is missing mobile system host contract: ${needle}`);
		}
	}
}

requireText("Source/Basic/Application.h", [
	"void vibrate(double seconds);",
	"bool hasBackgroundMusic() const;",
]);
requireText("Source/Basic/Application.cpp", [
	"SDL_AndroidGetActivity()",
	'GetMethodID(clazz, "vibrate", "(D)V")',
	'GetMethodID(clazz, "hasBackgroundMusic", "()Z")',
]);
requireText("Source/Basic/Application.mm", [
	"AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)",
	"secondaryAudioShouldBeSilencedHint",
]);
requireText("Source/Love/LoveNode.cpp", [
	"SharedApplication.vibrate(seconds);",
	"return SharedApplication.hasBackgroundMusic();",
]);
requireText("Projects/Android/Dora/app/src/main/AndroidManifest.xml", [
	'android.permission.VIBRATE',
]);
requireText("Projects/Android/Dora/app/src/main/java/org/ippclub/dorassr/MainActivity.java", [
	"public void vibrate(double seconds)",
	"VibrationEffect.createOneShot",
	"vibrator.cancel();",
	"public boolean hasBackgroundMusic()",
	"audioManager.isMusicActive()",
]);
requireText("Projects/Android/Dora/app/src/main/java/org/libsdl/app/SDLActivity.java", [
	"commitTextFromKeyEvent",
	"mGenerateScancodes = false",
	"codePoint < 128 && mGenerateScancodes",
]);
requireText("Source/Input/Keyboard.cpp", [
	"SDL_HINT_ENABLE_SCREEN_KEYBOARD",
	"bool oldDown = _newCodeStates[key]",
	"bool oldDown = _newKeyStates[key]",
]);

console.log("LOVE_MOBILE_SYSTEM_HOST_AUDIT_PASS ios=AudioToolbox+AVAudioSession android=Vibrator+AudioManager+IME");
