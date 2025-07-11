// @preview-file on clear
import { React, toNode } from 'DoraX';
import { Data, PlatformWorld, Unit, UnitAction } from 'Platformer';
import { App, Body, BodyMoveType, Color, Color3, Dictionary, Rect, Size, Vec2, View, loop, once, sleep, Array, Observer, EntityEvent, Sprite, Spawn, Ease, Y, tolua, Scale, Opacity, Content, Group, Entity, Component, Director, Keyboard, KeyName, TypeName, ButtonName } from 'Dora';
import { DecisionTree, toAI } from 'PlatformerX';

const TerrainLayer = 0;
const PlayerLayer = 1;
const ItemLayer = 2;

const PlayerGroup = Data.groupFirstPlayer;
const ItemGroup = Data.groupFirstPlayer + 1;
const TerrainGroup = Data.groupTerrain;

Data.setShouldContact(PlayerGroup, ItemGroup, true);

const themeColor = App.themeColor;
const color = themeColor.toARGB();
const DesignWidth = 1500;

const world = PlatformWorld();
world.camera.boundary = Rect(-1250, -500, 2500, 1000);
world.camera.followRatio = Vec2(0.02, 0.02);
world.camera.zoom = View.size.width / DesignWidth;
world.onAppChange((settingName) => {
	if (settingName === "Size") {
		world.camera.zoom = View.size.width / DesignWidth;
	}
});

interface RectShapeProps {
	x?: number;
	y?: number;
	width: number;
	height: number;
	color: number;
}

function RectShape(props: RectShapeProps) {
	const x = props.x ?? 0;
	const y = props.y ?? 0;
	const color = Color3(props.color);
	const fillColor = Color(color, 0x66).toARGB();
	const borderColor = Color(color, 0xff).toARGB();
	return <rect-shape
		centerX={x}
		centerY={y}
		width={props.width}
		height={props.height}
		fillColor={fillColor}
		borderColor={borderColor}
		borderWidth={1}
	/>;
}

const terrain = toNode(
	<body type={BodyMoveType.Static} world={world} order={TerrainLayer} group={TerrainGroup}>
		<rect-fixture centerY={-500} width={2500} height={10} friction={1} restitution={0}/>
		<rect-fixture centerY={500} width={2500} height={10} friction={1} restitution={0}/>
		<rect-fixture centerX={1250} width={10} height={2500} friction={1} restitution={0}/>
		<rect-fixture centerX={-1250} width={10} height={2500} friction={1} restitution={0}/>
		<draw-node>
			<RectShape y={-500} width={2500} height={10} color={color}/>
			<RectShape x={1250} width={10} height={1000} color={color}/>
			<RectShape x={-1250} width={10} height={1000} color={color}/>
		</draw-node>
	</body>
);
terrain?.addTo(world);

UnitAction.add("idle", {
	priority: 1,
	reaction: 2.0,
	recovery: 0.2,
	available: self => self.onSurface,
	create: self => {
		const {playable} = self;
		playable.speed = 1.0;
		playable.play("idle", true);
		const playIdleSpecial = loop(() => {
			sleep(3);
			sleep(playable.play("idle1"));
			playable.play("idle", true);
			return false;
		});
		self.data.playIdleSpecial = playIdleSpecial;
		return owner => {
			coroutine.resume(playIdleSpecial);
			return !owner.onSurface;
		};
	}
});

UnitAction.add("move", {
	priority: 1,
	reaction: 2.0,
	recovery: 0.2,
	available: self => self.onSurface,
	create: self => {
		const {playable} = self;
		playable.speed = 1;
		playable.play("fmove", true);
		return (self, action) => {
			const {elapsedTime} = action;
			const recovery = action.recovery * 2;
			const move = self.unitDef.move as number;
			let moveSpeed: number = 1.0;
			if (elapsedTime < recovery) {
				moveSpeed = math.min(elapsedTime / recovery, 1.0);
			}
			self.velocityX = moveSpeed * (self.faceRight ? move : -move);
			return !self.onSurface;
		}
	}
});

UnitAction.add("jump", {
	priority: 3,
	reaction: 2.0,
	recovery: 0.1,
	queued: true,
	available: self => self.onSurface,
	create: self => {
		const jump = self.unitDef.jump as number;
		self.velocityY = jump;
		return once(() => {
			const {playable} = self;
			playable.speed = 1;
			sleep(playable.play("jump", false));
		});
	}
});

UnitAction.add("fallOff", {
	priority: 2,
	reaction: -1,
	recovery: 0.3,
	available: self => !self.onSurface,
	create: self => {
		const {playable} = self;
		if (playable.current !== "jumping") {
			playable.speed = 1;
			playable.play("jumping", true);
		}
		return loop(() => {
			if (self.onSurface) {
				playable.speed = 1;
				sleep(playable.play("landing", false));
				return true;
			}
			return false;
		});
	}
});

const { Selector, Match, Action } = DecisionTree;

Data.store["AI:playerControl"] = toAI(
	<Selector>
		<Match desc='fmove key down' onCheck={self => {
			const keyLeft = self.entity.keyLeft as boolean;
			const keyRight = self.entity.keyRight as boolean;
			return !(keyLeft && keyRight) &&
			(
				(keyLeft && self.faceRight) ||
				(keyRight && !self.faceRight)
			);
		}}>
			<Action name='turn'/>
		</Match>

		<Match desc='is falling' onCheck={self => !self.onSurface}>
			<Action name='fallOff'/>
		</Match>

		<Match desc='jump key down' onCheck={self => self.entity.keyJump as boolean}>
			<Action name='jump'/>
		</Match>

		<Match desc='fmove key down' onCheck={self => (self.entity.keyLeft || self.entity.keyRight) as boolean}>
			<Action name='move'/>
		</Match>

		<Action name='idle'/>
	</Selector>
);

const unitDef = Dictionary();
unitDef.linearAcceleration = Vec2(0, -15);
unitDef.bodyType = BodyMoveType.Dynamic;
unitDef.scale = 1.0;
unitDef.density = 1.0;
unitDef.friction = 1.0;
unitDef.restitution = 0.0;
unitDef.playable = "spine:Spine/moling";
unitDef.defaultFaceRight = true;
unitDef.size = Size(60, 300);
unitDef.sensity = 0;
unitDef.move = 300;
unitDef.jump = 1000;
unitDef.detectDistance = 350;
unitDef.hp = 5.0;
unitDef.tag = "player";
unitDef.decisionTree = "AI:playerControl";
unitDef.actions = Array([
	"idle",
	"turn",
	"move",
	"jump",
	"fallOff",
	"cancel"
]);

Observer(EntityEvent.Add, ["player"]).watch(self => {
	const unit = Unit(unitDef, world, self, Vec2(300, -350));
	unit.order = PlayerLayer;
	unit.group = PlayerGroup;
	unit.playable.position = Vec2(0, -150);
	unit.playable.play("idle", true);
	world.addChild(unit);
	world.camera.followTarget = unit;
	return false;
});

Observer(EntityEvent.Add, ["x", "icon"]).watch((self, x: number, icon: string) => {
	const sprite = toNode(
		<sprite file={icon}>
			<loop>
				<spawn>
					<angle-y time={5} start={0} stop={360}/>
					<sequence>
						<move-y time={2.5} start={0} stop={40} easing={Ease.OutQuad}/>
						<move-y time={2.5} start={40} stop={0} easing={Ease.InQuad}/>
					</sequence>
				</spawn>
			</loop>
		</sprite>
	);
	if (!sprite) return false;

	const body = toNode(
		<body
			type={BodyMoveType.Dynamic} world={world} linearAcceleration={Vec2(0, -10)}
			x={x} order={ItemLayer} group={ItemGroup}>
			<rect-fixture width={sprite.width * 0.5} height={sprite.height}/>
			<rect-fixture sensorTag={0} width={sprite.width} height={sprite.height}/>
		</body>
	);
	if (!body) return false;

	const itemBody = body as Body.Type;
	body.addChild(sprite);
	itemBody.onBodyEnter(item => {
		if (tolua.type(item) === TypeName.Unit) {
			self.picked = true;
			itemBody.group = Data.groupHide;
			itemBody.schedule(once(() => {
				sleep(sprite.runAction(Spawn(
					Scale(0.2, 1, 1.3, Ease.OutBack),
					Opacity(0.2, 1, 0)
				)));
				self.body = undefined;
			}));
		}
	});

	world.addChild(body);
	self.body = body;
	return false;
});

Observer(EntityEvent.Remove, ["body"]).watch(self => {
	const body = tolua.cast(self.oldValues.body, TypeName.Body);
	if (body !== null) {
		body.removeFromParent();
	}
	return false;
});

import { Struct } from 'Utils';

interface ItemStruct {
	Name: string;
	No: number;
	X: number;
	Icon: string;
	Num: number;
	Desc: string;
}

interface ItemEntity extends Record<string, Component> {
	name: string;
	no: number;
	x: number;
	icon: string;
	num: number;
	desc: string;
	item: boolean;
}

function loadExcel() {
	const xlsx = Content.loadExcel("Data/items.xlsx", ["items"]);
	if (xlsx !== null) {
		const its = xlsx["items"];
		if (!its) return;
		const names = its[1] as [keyof ItemStruct];
		table.remove(names, 1);
		if (!Struct.has("Item")) {
			Struct.Item<ItemStruct>(names);
		}
		Group(["item"]).each(e => {
			e.destroy();
			return false;
		});
		for (let i = 2; i < its.length; i++) {
			const st = Struct.load<ItemStruct>(its[i]) as Struct<ItemStruct>;
			const item: ItemEntity = {
				name: st.Name,
				no: st.No,
				x: st.X,
				num: st.Num,
				icon: st.Icon,
				desc: st.Desc,
				item: true
			};
			Entity(item);
		}
	}
}

import * as CircleButtonCreate from "UI/Control/Basic/CircleButton";
import { SetCond, WindowFlag } from 'ImGui';
import * as ImGui from 'ImGui';

let keyboardEnabled = true;

const playerGroup = Group(["player"]);
function updatePlayerControl(key: string, flag: boolean, vpad: boolean) {
	if (keyboardEnabled && vpad) {
		keyboardEnabled = false;
	}
	playerGroup.each(self => {
		self[key] = flag;
		return false;
	})
}

interface CircleButtonProps extends JSX.Node {
	text: string;
}

function CircleButton(props: CircleButtonProps) {
	return <custom-node onCreate={() => CircleButtonCreate({
		text: props.text,
		radius: 60,
		fontSize: 36
	})} {...props}/>
}

const ui = toNode(
	<align-node windowRoot style={{flexDirection: 'column-reverse'}}
		onButtonDown={(id, buttonName) => {
			if (id !== 0) return;
			switch (buttonName) {
				case ButtonName.Left: updatePlayerControl("keyLeft", true, true); break;
				case ButtonName.Right: updatePlayerControl("keyRight", true, true); break;
				case ButtonName.B: updatePlayerControl("keyJump", true, true); break;
			}
		}}
		onButtonUp={(id, buttonName) => {
			if (id !== 0) return;
			switch (buttonName) {
				case ButtonName.Left: updatePlayerControl("keyLeft", false, true); break;
				case ButtonName.Right: updatePlayerControl("keyRight", false, true); break;
				case ButtonName.B: updatePlayerControl("keyJump", false, true); break;
			}
		}}>
		<align-node style={{height: 60, justifyContent: 'space-between', margin: [0, 20, 40], flexDirection: 'row'}}>
			<align-node style={{width: 130, height: 60}}>
				<menu width={250} height={120} anchorX={0} anchorY={0} scaleX={0.5} scaleY={0.5}>
					<CircleButton
						text={"Left\n(a)"} anchorX={0} anchorY={0}
						onTapBegan={() => updatePlayerControl("keyLeft", true, true)}
						onTapEnded={() => updatePlayerControl("keyLeft", false, true)}
					/>
					<CircleButton
						text={"Right\n(a)"} x={130} anchorX={0} anchorY={0}
						onTapBegan={() => updatePlayerControl("keyRight", true, true)}
						onTapEnded={() => updatePlayerControl("keyRight", false, true)}
					/>
				</menu>
			</align-node>
			<align-node style={{width: 60, height: 60}}>
				<menu width={120} height={120} anchorX={0} anchorY={0} scaleX={0.5} scaleY={0.5}>
					<CircleButton
						text={"Jump\n(j)"} anchorX={0} anchorY={0}
						onTapBegan={() => updatePlayerControl("keyJump", true, true)}
						onTapEnded={() => updatePlayerControl("keyJump", false, true)}
					/>
				</menu>
			</align-node>
		</align-node>
	</align-node>
);

if (ui) {
	ui.addTo(Director.ui);
	ui.schedule(() => {
		const keyA = Keyboard.isKeyPressed(KeyName.A);
		const keyD = Keyboard.isKeyPressed(KeyName.D);
		const keyJ = Keyboard.isKeyPressed(KeyName.J);
		if (keyD || keyD || keyJ) {
			keyboardEnabled = true;
		}
		if (!keyboardEnabled) {
			return false;
		}
		updatePlayerControl("keyLeft", keyA, false);
		updatePlayerControl("keyRight", keyD, false);
		updatePlayerControl("keyJump", keyJ, false);
		return false;
	});
}

const pickedItemGroup = Group(["picked"]);
const windowFlags = [
	WindowFlag.NoDecoration,
	WindowFlag.AlwaysAutoResize,
	WindowFlag.NoSavedSettings,
	WindowFlag.NoFocusOnAppearing,
	WindowFlag.NoNav,
	WindowFlag.NoMove
];
Director.ui.schedule(() => {
	const size = App.visualSize;
	ImGui.SetNextWindowBgAlpha(0.35);
	ImGui.SetNextWindowPos(Vec2(size.width - 10, 10), SetCond.Always, Vec2(1, 0));
	ImGui.SetNextWindowSize(Vec2(100, 300), SetCond.FirstUseEver);
	ImGui.Begin("BackPack", windowFlags, () => {
		if (ImGui.Button("重新加载Excel")) {
			loadExcel();
		}
		ImGui.Separator();
		ImGui.Dummy(Vec2(100, 10));
		ImGui.Text("背包 (TSX)");
		ImGui.Separator();
		ImGui.Columns(3, false);
		pickedItemGroup.each(e => {
			const item = e as any as ItemEntity;
			if (item.num > 0) {
				if (ImGui.ImageButton("item" + item.no, item.icon, Vec2(50, 50))) {
					item.num -= 1;
					const sprite = Sprite(item.icon);
					if (!sprite) return false;
					sprite.scaleX = sprite.scaleY = 0.5;
					sprite.perform(Spawn(
						Opacity(1, 1, 0),
						Y(1, 150, 250)
					));
					const player = playerGroup.find(() => true);
					if (player !== undefined) {
						const unit = player.unit as Unit.Type;
						unit.addChild(sprite);
					}
				}
				if (ImGui.IsItemHovered()) {
					ImGui.BeginTooltip(() => {
						ImGui.Text(item.name);
						ImGui.TextColored(themeColor, "数量：");
						ImGui.SameLine();
						ImGui.Text(item.num.toString());
						ImGui.TextColored(themeColor, "描述：");
						ImGui.SameLine();
						ImGui.Text(item.desc.toString());
					})
				}
				ImGui.NextColumn();
			}
			return false;
		});
	});
	return false;
});

Entity({player: true});
loadExcel();
