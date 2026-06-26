// @preview-file on clear
import { Color, Director, Node as DNode, loop, sleep } from "Dora";
import { React, createRoot, signal } from "DoraX";
import { Button, CooldownButton, HealthBar, Panel, ResourceCounter, Row } from "UIX";

const host = DNode();
Director.ui.addChild(host);

const hp = signal(0.82);
const coins = signal(1280);
const fireCooldown = signal(0);
const iceCooldown = signal(30);
const settingsOpen = signal(false);
const clicks = signal(0);
const panelWide = signal(false);

const root = createRoot(host);

function App(this: void) {
	return (
		<align-node windowRoot style={{ padding: 18, flexDirection: "column" }}>
			<Row style={{ height: 52, width: "100%", alignItems: "center" }} gap={14}>
				<HealthBar value={hp.value} max={1} showValue style={{ width: 260, height: 22 }} />
				<ResourceCounter icon="coin" value={coins.value} variant="warm" />
			</Row>
			<Button
				variant="secondary"
				icon="gear"
				style={{ position: "absolute", left: 18, top: 84, width: 190 }}
				onClick={() => {
					settingsOpen.value = !settingsOpen.value;
					clicks.value += 1;
					panelWide.value = !panelWide.value;
				}}
			>
				Settings
			</Button>
			{settingsOpen.value ?
				<Panel
					key="settings-panel"
					title="Settings"
					variant="glass"
					style={{ position: "absolute", left: 18, top: 142, width: panelWide.value ? 360 : 240, height: 150 }}
				>
					<ResourceCounter icon="check" value={`Clicks ${clicks.value}`} variant="success" />
				</Panel> : undefined}
			<Panel
				key="skills-panel"
				title="Skills"
				variant="glass"
				padding={12}
				headerHeight={30}
				style={{ position: "absolute", right: 18, bottom: 18, width: 286, height: 128 }}
			>
				<Row gap={8} style={{ width: "100%", height: 56, alignItems: "center" }}>
					<CooldownButton icon="heart" hotkey="Q" cooldown={fireCooldown.value} maxCooldown={5} onCast={() => fireCooldown.value = 5} />
					<CooldownButton icon="mana" hotkey="W" cooldown={iceCooldown.value} maxCooldown={30} onCast={() => iceCooldown.value = 30} />
					<CooldownButton icon="warning" hotkey="E" cooldown={0} maxCooldown={8} count={3} />
				</Row>
			</Panel>
		</align-node>
	);
}

root.render(() => <App />);

host.schedule(loop(() => {
	sleep(0.25);
	hp.value = hp.value <= 0.18 ? 0.95 : hp.value - 0.03;
	coins.value += 3;
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25);
	iceCooldown.value = math.max(0, iceCooldown.value - 0.25);
	return false;
}));

host.onCleanup(() => {
	host.unschedule();
	root.unmount();
});

Director.clearColor = Color(0xff111827);
