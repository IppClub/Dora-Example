// @preview-file on clear
import { Data, Decision, PlatformWorld, Unit, UnitAction } from 'Platformer';
import { App, Body, BodyDef, BodyMoveType, Color, Dictionary, Rect, Size, Vec2, View, loop, once, sleep, Array, Observer, EntityEvent, Sprite, Spawn, AngleY, Sequence, Ease, Y, tolua, Scale, Opacity, Content, Group, Entity, Component, Director, Menu, Keyboard, KeyName, TypeName, AlignNode, ButtonName } from 'Dora';
import * as Rectangle from 'UI/View/Shape/Rectangle';

const TerrainLayer = 0;
const PlayerLayer = 1;
const ItemLayer = 2;

const PlayerGroup = Data.groupFirstPlayer;
const ItemGroup = Data.groupFirstPlayer + 1;
const TerrainGroup = Data.groupTerrain;

Data.setShouldContact(PlayerGroup, ItemGroup, true);

const themeColor = App.themeColor;
const fillColor = Color(themeColor.toColor3(), 0x66).toARGB();
const borderColor = themeColor.toARGB();
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

const terrainDef = BodyDef();
terrainDef.type = BodyMoveType.Static;
terrainDef.attachPolygon(Vec2(0, -500), 2500, 10, 0, 1, 1, 0);
terrainDef.attachPolygon(Vec2(0, 500), 2500, 10, 0, 1, 1, 0);
terrainDef.attachPolygon(Vec2(1250, 0), 10, 1000, 0, 1, 1, 0);
terrainDef.attachPolygon(Vec2(-1250, 0), 10, 1000, 0, 1, 1, 0);

const terrain = Body(terrainDef, world, Vec2.zero);
terrain.order = TerrainLayer;
terrain.group = TerrainGroup;
terrain.addChild(Rectangle({
	y: -500,
	width: 2500,
	height: 10,
	fillColor: fillColor,
	borderColor: borderColor,
	fillOrder: 1,
	lineOrder: 2
}));
terrain.addChild(Rectangle({
	x: 1250,
	y: 0,
	width: 10,
	height: 1000,
	fillColor: fillColor,
	borderColor: borderColor,
	fillOrder: 1,
	lineOrder: 2
}));
terrain.addChild(Rectangle({
	x: -1250,
	y: 0,
	width: 10,
	height: 1000,
	fillColor: fillColor,
	borderColor: borderColor,
	fillOrder: 1,
	lineOrder: 2
}));
world.addChild(terrain);

UnitAction.add("idle", {
	priority: 1,
	reaction: 2.0,
	recovery: 0.2,
	available: self => {
		return self.onSurface;
	},
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
	available: self => {
		return self.onSurface;
	},
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
	available: self => {
		return self.onSurface;
	},
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
	available: self => {
		return !self.onSurface;
	},
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

const {Sel, Seq, Con, Act} = Decision;

Data.store["AI:playerControl"] = Sel([
	Seq([
		Con("fmove key down", self => {
			const keyLeft = self.entity.keyLeft as boolean;
			const keyRight = self.entity.keyRight as boolean;
			return !(keyLeft && keyRight) &&
			(
				(keyLeft && self.faceRight) ||
				(keyRight && !self.faceRight)
			);
		}),
		Act("turn")
	]),
	Seq([
		Con("is falling", self => {
			return !self.onSurface;
		}),
		Act("fallOff")
	]),
	Seq([
		Con("jump key down", self => {
			return self.entity.keyJump as boolean;
		}),
		Act("jump")
	]),
	Seq([
		Con("fmove key down", self => {
			return (self.entity.keyLeft || self.entity.keyRight) as boolean;
		}),
		Act("move")
	]),
	Act("idle")
]);

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
unitDef.usePreciseHit = false;
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
	const sprite = Sprite(icon);
	if (!sprite) return false;
	sprite.runAction(Spawn(
		AngleY(5, 0, 360),
		Sequence(
			Y(2.5, 0, 40, Ease.OutQuad),
			Y(2.5, 40, 0, Ease.InQuad)
		)
	), true);

	const bodyDef = BodyDef();
	bodyDef.type = BodyMoveType.Dynamic;
	bodyDef.linearAcceleration = Vec2(0, -10);
	bodyDef.attachPolygon(sprite.width * 0.5, sprite.height);
	bodyDef.attachPolygonSensor(0, sprite.width, sprite.height);

	const body = Body(bodyDef, world, Vec2(x, 0));
	body.order = ItemLayer;
	body.group = ItemGroup;
	body.addChild(sprite);

	body.onBodyEnter(item => {
		if (tolua.type(item) === TypeName.Unit) {
			self.picked = true;
			body.group = Data.groupHide;
			body.schedule(once(() => {
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
			}
			Entity(item);
		}
	}
}

import * as CircleButton from "UI/Control/Basic/CircleButton";
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

const ui = AlignNode(true);
ui.css('flex-direction: column-reverse');
ui.onButtonDown((id, buttonName) => {
	if (id !== 0) return;
	switch (buttonName) {
		case ButtonName.Left: updatePlayerControl("keyLeft", true, true); break;
		case ButtonName.Right: updatePlayerControl("keyRight", true, true); break;
		case ButtonName.B: updatePlayerControl("keyJump", true, true); break;
	}
});
ui.onButtonUp((id, buttonName) => {
	if (id !== 0) return;
	switch (buttonName) {
		case ButtonName.Left: updatePlayerControl("keyLeft", false, true); break;
		case ButtonName.Right: updatePlayerControl("keyRight", false, true); break;
		case ButtonName.B: updatePlayerControl("keyJump", false, true); break;
	}
});
ui.addTo(Director.ui);

const bottomAlign = AlignNode();
bottomAlign.css(`
	height: 60;
	justify-content: space-between;
	margin: 0, 20, 40;
	flex-direction: row
`);
bottomAlign.addTo(ui);

const leftAlign = AlignNode();
leftAlign.css('width: 130; height: 60');
leftAlign.addTo(bottomAlign);

const leftMenu = Menu();
leftMenu.size = Size(250, 120);
leftMenu.anchor = Vec2.zero;
leftMenu.scaleX = leftMenu.scaleY = 0.5;
leftMenu.addTo(leftAlign);

const leftButton = CircleButton({
	text: "左(a)",
	radius: 60,
	fontSize: 36
});
leftButton.anchor = Vec2.zero;
leftButton.onTapBegan(() => {
	updatePlayerControl("keyLeft", true, true);
});
leftButton.onTapEnded(() => {
	updatePlayerControl("keyLeft", false, true);
});
leftButton.addTo(leftMenu);

const rightButton = CircleButton({
	text: "右(d)",
	x: 130,
	radius: 60,
	fontSize: 36
});
rightButton.anchor = Vec2.zero;
rightButton.onTapBegan(() => {
	updatePlayerControl("keyRight", true, true);
});
rightButton.onTapEnded(() => {
	updatePlayerControl("keyRight", false, true);
});
rightButton.addTo(leftMenu);

const rightAlign = AlignNode();
rightAlign.css('width: 60; height: 60');
rightAlign.addTo(bottomAlign);

const rightMenu = Menu();
rightMenu.size = Size(120, 120);
rightMenu.anchor = Vec2.zero;
rightMenu.scaleX = rightMenu.scaleY = 0.5;
rightAlign.addChild(rightMenu);

const jumpButton = CircleButton({
	text: "跳(j)",
	radius: 60,
	fontSize: 36
});
jumpButton.anchor = Vec2.zero;
jumpButton.onTapBegan(() => {
	updatePlayerControl("keyJump", true, true);
});
jumpButton.onTapEnded(() => {
	updatePlayerControl("keyJump", false, true);
});
jumpButton.addTo(rightMenu);

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
		ImGui.Text("背包 (TypeScript)");
		ImGui.Separator();
		ImGui.Columns(3, false);
		pickedItemGroup.each(e => {
			const item = e as any as ItemEntity;
			if (item.num > 0) {
				if (ImGui.ImageButton("item" + item.no, item.icon, Vec2(50, 50))) {
					item.num -= 1;
					const sprite = Sprite(item.icon);
					if (!sprite) return false;
					sprite.scaleX = 0.5;
					sprite.scaleY = 0.5;
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
