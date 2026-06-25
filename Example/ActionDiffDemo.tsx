// @preview-file on clear
import { Color, Director, Ease, Node as DNode } from "Dora";
import { React, createRoot, signal } from "DoraX";

interface ButtonProps {
	key?: string;
	x: number;
	y: number;
	text: string;
	color: number;
	onTap(this: void): void;
}

function Button(this: void, props: ButtonProps) {
	const width = 190;
	const height = 52;
	return (
		<node key={props.key} x={props.x} y={props.y} width={width} height={height} touchEnabled onTapped={props.onTap}>
			<draw-node key="face">
				<rect-shape
					centerX={width / 2}
					centerY={height / 2}
					width={width}
					height={height}
					fillColor={props.color}
					borderWidth={2}
					borderColor={0xffffffff}
				/>
			</draw-node>
			<label
				key="text"
				sdf
				x={width / 2}
				y={height / 2}
				fontName="sarasa-mono-sc-regular"
				fontSize={20}
				color3={0xffffff}
				text={props.text}
			/>
		</node>
	);
}

interface ActorProps {
	key?: string;
	x: number;
	y: number;
	title: string;
	hint: string;
	trigger: number;
	exclusive?: boolean;
}

function Actor(this: void, props: ActorProps) {
	const targetX = props.trigger % 2 === 0 ? -150 : 150;
	const fillColor = props.exclusive ? 0xfff97316 : 0xff14b8a6;
	return (
		<node key={props.key} x={props.x} y={props.y}>
			<label
				key="title"
				sdf
				y={72}
				fontName="sarasa-mono-sc-regular"
				fontSize={22}
				color3={0xffffff}
				text={props.title}
			/>
			<label
				key="hint"
				sdf
				y={42}
				fontName="sarasa-mono-sc-regular"
				fontSize={16}
				color3={0xcbd5e1}
				text={props.hint}
			/>
			<node key="actor">
				<draw-node key="shape">
					<rect-shape
						centerX={0}
						centerY={0}
						width={72}
						height={72}
						fillColor={fillColor}
						borderWidth={3}
						borderColor={0xffffffff}
					/>
				</draw-node>
				<move-x exclusive={props.exclusive} time={0.75} start={0} stop={targetX} easing={Ease.OutQuad} />
				<angle exclusive={props.exclusive} time={0.75} start={0} stop={props.trigger * 10} easing={Ease.OutQuad} />
			</node>
			<label
				key="count"
				sdf
				y={-72}
				fontName="sarasa-mono-sc-regular"
				fontSize={16}
				color3={0xe2e8f0}
				text={`trigger ${props.trigger}`}
			/>
		</node>
	);
}

const host = DNode();
Director.entry.addChild(host);

const normalTrigger = signal(0);
const exclusiveTrigger = signal(0);
const root = createRoot(host);

root.render(() =>
	<node scaleX={1.6} scaleY={1.6}>
		<label
			key="headline"
			sdf
			y={170}
			fontName="sarasa-mono-sc-regular"
			fontSize={28}
			color3={0xffffff}
			text="DoraX Action Diff"
		/>
		<Actor
			key="normal"
			x={-210}
			y={20}
			title="runAction"
			hint="tap quickly: actions can overlap"
			trigger={normalTrigger.value}
		/>
		<Actor
			key="exclusive"
			x={210}
			y={20}
			title="exclusive"
			hint="tap quickly: perform replaces old action"
			trigger={exclusiveTrigger.value}
			exclusive
		/>
		<Button
			key="normal-button"
			x={-305}
			y={-145}
			text="Run Action"
			color={0xff0f766e}
			onTap={() => {
				normalTrigger.value += 1;
			}}
		/>
		<Button
			key="exclusive-button"
			x={115}
			y={-145}
			text="Exclusive"
			color={0xffc2410c}
			onTap={() => {
				exclusiveTrigger.value += 1;
			}}
		/>
	</node>
);

host.onCleanup(() => {
	root.unmount();
});

Director.clearColor = Color(0xff111827);
