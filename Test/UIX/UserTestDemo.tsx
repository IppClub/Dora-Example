// @preview-file on clear
import { Color, Director, Node as DNode, loop, sleep } from "Dora";
import { React, createRoot, signal } from "DoraX";
import { Button } from "UIX/controls/Button";
import { Column } from "UIX/layout/Column";
import { CooldownButton } from "UIX/game/CooldownButton";
import { HealthBar } from "UIX/game/HealthBar";
import { InventoryGrid } from "UIX/game/InventoryGrid";
import { Panel } from "UIX/layout/Panel";
import { ProgressBar } from "UIX/controls/ProgressBar";
import { ResourceCounter } from "UIX/game/ResourceCounter";
import { Row } from "UIX/layout/Row";
import { ScrollView } from "UIX/layout/ScrollView";
import { Slider } from "UIX/controls/Slider";
import { Tabs } from "UIX/controls/Tabs";
import { Text } from "UIX/foundation/Text";
import { Modal } from "UIX/overlay/Modal";
import { ToastStack } from "UIX/overlay/ToastStack";
import { Tooltip } from "UIX/overlay/Tooltip";
import { Toggle } from "UIX/controls/Toggle";

const host = DNode();
Director.ui.addChild(host);
const modalHost = DNode();
Director.ui.addChild(modalHost, 10000);
Director.clearColor = Color(0xff0e1726);

const hp = signal(0.74);
const mana = signal(0.52);
const gold = signal(1460);
const gems = signal(18);
const autoRegen = signal(true);
const compact = signal(false);
const difficulty = signal(0.45);
const activeTab = signal("combat");
const selectedItem = signal("potion");
const logText = signal("Ready");
const clicks = signal(0);
const modalOpen = signal(false);
const tooltipVisible = signal(true);
const fireCooldown = signal(0);
const shieldCooldown = signal(0);
const blinkCooldown = signal(0);
const settingsOpen = signal(true);

function pushLog(this: void, text: string) {
	clicks.value += 1;
	logText.value = `${text} #${clicks.value}`;
}

function castFire(this: void) {
	fireCooldown.value = 5;
	mana.value = math.max(0, mana.value - 0.14);
	pushLog("Fire");
}

function castShield(this: void) {
	shieldCooldown.value = 8;
	hp.value = math.min(1, hp.value + 0.12);
	pushLog("Shield");
}

function castBlink(this: void) {
	blinkCooldown.value = 3;
	gems.value = math.max(0, gems.value - 1);
	pushLog("Blink");
}

function CombatPage(this: void) {
	return (
		<Column key="combat-page" style={{ gap: 10, width: "100%" }}>
			<Row gap={10} style={{ height: 72, alignItems: "center" }}>
				<CooldownButton icon="warning" cooldown={fireCooldown.value} maxCooldown={5} onCast={castFire} />
				<CooldownButton icon="heart" cooldown={shieldCooldown.value} maxCooldown={8} onCast={castShield} />
				<CooldownButton icon="mana" cooldown={blinkCooldown.value} maxCooldown={3} disabled={gems.value <= 0} onCast={castBlink} />
			</Row>
			<Row gap={10} style={{ height: 42 }}>
				<Button variant="danger" icon="warning" style={{ width: 110 }} onClick={() => {
					hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12);
					pushLog("Damage");
				}}>
					Damage
				</Button>
				<Button variant="secondary" icon="heart" style={{ width: 96 }} onClick={() => {
					hp.value = math.min(1, hp.value + 0.18);
					pushLog("Heal");
				}}>
					Heal
				</Button>
			</Row>
		</Column>
	);
}

function InventoryPage(this: void) {
	const items = [
		{ id: "potion", icon: "heart", quality: "common" as const, count: 3 },
		{ id: "crystal", icon: "mana", quality: "rare" as const, count: gems.value },
		{ id: "bomb", icon: "warning", quality: "epic" as const, count: 2 },
		{ id: "coin", icon: "coin", quality: "legendary" as const, count: math.floor(gold.value / 100) },
		{ id: "lock", icon: "lock", quality: "common" as const, disabled: true },
		{ id: "shield", icon: "check", quality: "rare" as const, count: 1 },
		{ id: "blink", icon: "mana", quality: "epic" as const, count: gems.value },
		{ id: "kit", icon: "heart", quality: "common" as const, count: 5 },
		{ id: "map", icon: "gear", quality: "legendary" as const, count: 1 },
		{ id: "rune", icon: "warning", quality: "rare" as const, count: 4 },
		{ id: "empty", icon: "close", quality: "common" as const, disabled: true },
	];
	return (
		<Column key="inventory-page" style={{ gap: 10, width: "100%", height: 264 }}>
			<InventoryGrid
				key="bag-grid"
				items={items}
				columns={4}
				rows={3}
				slotSize={48}
				gap={8}
				selectedId={selectedItem.value}
				slotSwallowTouches={false}
					onSelect={(id: string) => {
					selectedItem.value = id;
					pushLog(`Item ${id}`);
				}}
			/>
			<Row key="bag-resources" gap={12} style={{ height: 42, alignItems: "center" }}>
				<ResourceCounter icon="coin" value={gold.value} variant="warm" />
				<ResourceCounter icon="mana" value={gems.value} variant="default" />
			</Row>
			<Row key="bag-actions" gap={10} style={{ height: 42 }}>
				<Button variant="secondary" icon="coin" swallowTouches={false} style={{ width: 120 }} onClick={() => {
					gold.value += 75;
					pushLog("Loot");
				}}>
					Loot
				</Button>
				<Button variant="ghost" icon="check" disabled={gold.value < 200} swallowTouches={false} style={{ width: 120 }} onClick={() => {
					gold.value -= 200;
					gems.value += 1;
					pushLog("Trade");
				}}>
					Trade
				</Button>
			</Row>
		</Column>
	);
}

function SettingsPage(this: void) {
	return (
		<Column key="settings-page" style={{ gap: 12, width: "100%" }}>
			<Toggle checked={autoRegen.value} label="Auto Regen" onChange={(value) => {
				autoRegen.value = value;
				pushLog(value ? "Regen On" : "Regen Off");
			}} />
			<Toggle checked={compact.value} label="Compact HUD" onChange={(value) => {
				compact.value = value;
				pushLog(value ? "Compact" : "Expanded");
			}} />
			<Slider value={difficulty.value} min={0} max={1} step={0.05} showValue onValueChange={(value) => {
				difficulty.value = value;
				pushLog("Difficulty");
			}} />
		</Column>
	);
}

function ActivePage(this: void) {
	switch (activeTab.value) {
		case "inventory": return <InventoryPage />;
		case "settings": return <SettingsPage />;
		default: return <CombatPage />;
	}
}

function App(this: void) {
	const panelWidth = compact.value ? 316 : 420;
	const pageScrollHeight = 156;
	const inventoryContentHeight = 284;
	return (
		<align-node windowRoot style={{ padding: 18, flexDirection: "column" }}>
			<Row key="top-hud" gap={14} style={{ width: "100%", height: 58, alignItems: "center" }}>
				<Column style={{ width: compact.value ? 220 : 320, gap: 7 }}>
					<HealthBar value={hp.value} max={1} showValue style={{ width: "100%", height: 22 }} />
					<ProgressBar value={mana.value} max={1} variant="mana" showValue style={{ width: "100%", height: 14 }} />
				</Column>
				<ResourceCounter icon="coin" value={gold.value} variant="warm" />
				<ResourceCounter icon="mana" value={gems.value} />
				<Button variant={settingsOpen.value ? "primary" : "secondary"} icon="gear" style={{ width: 128 }} onClick={() => {
					settingsOpen.value = !settingsOpen.value;
					pushLog(settingsOpen.value ? "Panel Open" : "Panel Close");
				}}>
					Panel
				</Button>
				<Button variant="secondary" icon="warning" style={{ width: 128 }} onClick={() => {
					modalOpen.value = true;
					pushLog("Modal");
				}}>
					Modal
				</Button>
			</Row>
			{settingsOpen.value ?
				<Panel
					key="user-test-panel"
					title="UIX Test"
					variant="glass"
					padding={14}
					headerHeight={34}
					style={{ position: "absolute", left: 18, top: 92, width: panelWidth, height: 280 }}
				>
					<Column key="panel-body" style={{ gap: 12, width: "100%" }}>
						<Tabs
							key="main-tabs"
							value={activeTab.value}
							items={[
								{ id: "combat", label: "Combat" },
								{ id: "inventory", label: "Bag" },
								{ id: "settings", label: "Tune" },
							]}
							onValueChange={(value) => {
								activeTab.value = value;
								pushLog(value);
							}}
						/>
						{activeTab.value === "inventory" ?
							<ScrollView
								key="inventory-scroll"
								width={panelWidth - 28}
								height={pageScrollHeight}
								contentHeight={inventoryContentHeight}
								wheelSpeed={18}
							>
								<InventoryPage />
							</ScrollView> :
							<ActivePage />
						}
					</Column>
				</Panel> : undefined}
			<Panel
				key="status-panel"
				title="Status"
				variant="solid"
				padding={12}
				headerHeight={30}
				style={{ position: "absolute", right: 18, bottom: 18, width: 300, height: 132 }}
			>
				<Column style={{ gap: 8, width: "100%" }}>
					<Text text={logText.value} fontSize={18} style={{ width: "100%", height: 28 }} />
					<Row gap={8} style={{ height: 42 }}>
						<Button variant="ghost" icon="close" style={{ width: 92 }} onClick={() => {
							hp.value = 0.74;
							mana.value = 0.52;
							gold.value = 1460;
							gems.value = 18;
							fireCooldown.value = 0;
							shieldCooldown.value = 0;
							blinkCooldown.value = 0;
							pushLog("Reset");
						}}>
							Reset
						</Button>
						<Button variant="secondary" icon="check" style={{ width: 108 }} onClick={() => {
							gold.value += 10;
							mana.value = math.min(1, mana.value + 0.08);
							pushLog("Tick");
						}}>
							Tick
						</Button>
					</Row>
				</Column>
			</Panel>
			{tooltipVisible.value ?
				<Tooltip
					key="hint-tooltip"
					title="UIX"
					text="Use tabs, toggles, slider, modal and cooldown buttons for testing."
					style={{ position: "absolute", left: 18, bottom: 18 }}
				/> : undefined}
			<ToastStack
				key="toast-stack"
				items={[
					{ id: "last", title: "Last Action", message: logText.value },
					{ id: "hp", message: `HP ${math.floor(hp.value * 100)}%  Mana ${math.floor(mana.value * 100)}%` },
				]}
				style={{ right: 18, top: 92 }}
			/>
		</align-node>
	);
}

function ModalLayer(this: void) {
	return (
		<Modal
			key="test-modal"
			open={modalOpen.value}
			title="UIX Modal"
			message="This modal uses a vector backdrop and a Panel body."
			width={300}
			height={196}
			actions={[
				{ id: "loot", label: "Loot", variant: "primary" },
				{ id: "close", label: "Close", variant: "secondary" },
			]}
			onClose={() => {
				modalOpen.value = false;
				pushLog("Backdrop Close");
			}}
			onAction={(id) => {
				if (id === "loot") {
					gold.value += 120;
					gems.value += 1;
					pushLog("Modal Loot");
				}
				modalOpen.value = false;
			}}
		>
			<Toggle checked={tooltipVisible.value} label="Show Tooltip" onChange={(value) => {
				tooltipVisible.value = value;
				pushLog(value ? "Tooltip On" : "Tooltip Off");
			}} />
		</Modal>
	);
}

const root = createRoot(host);
root.render(() => <App />);
const modalRoot = createRoot(modalHost);
modalRoot.render(() => <ModalLayer />);

host.schedule(loop(() => {
	sleep(0.25);
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25);
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25);
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25);
	if (autoRegen.value) {
		hp.value = math.min(1, hp.value + 0.005);
		mana.value = math.min(1, mana.value + 0.018);
	}
	return false;
}));

host.onCleanup(() => {
	host.unschedule();
	root.unmount();
	modalRoot.unmount();
	modalHost.removeFromParent(true);
});
