// @preview-file on nolog
import { App, Color, Director, Node as DNode, Vec2 } from "Dora";
import { React, createRoot, signal } from "DoraX";

interface ButtonProps {
	text: string;
	count: number;
	pressed: boolean;
	onTap(this: void): void;
	onPress(this: void): void;
	onRelease(this: void): void;
}

function Button(this: void, props: ButtonProps) {
	const width = 220;
	const height = 64;
	const fillColor = props.pressed ? 0xff2563eb : 0xff0f766e;
	const borderColor = props.pressed ? 0xffbfdbfe : 0xffccfbf1;

	return (
		<node
			key="button"
			width={width}
			height={height}
			touchEnabled
			onTapBegan={props.onPress}
			onTapEnded={props.onRelease}
			onTapped={props.onTap}
		>
			<draw-node key="background">
				<rect-shape
					centerX={width/2}
					centerY={height/2}
					width={width}
					height={height}
					fillColor={fillColor}
					borderWidth={3}
					borderColor={borderColor}
				/>
			</draw-node>
			<label
				sdf
				key="button-text"
				x={width/2}
				y={height/2}
				fontName="sarasa-mono-sc-regular"
				fontSize={24}
				text={`${props.text}: ${props.count}`}
				color3={0xffffff}
			/>
		</node>
	);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const clicks = signal(0);
const pressed = signal(false);

function onTap(this: void) {
	clicks.value += 1;
}

function onPress(this: void) {
	pressed.value = true;
}

function onRelease(this: void) {
	pressed.value = false;
}

root.render(() =>
	<node scaleX={2} scaleY={2}>
		<label
			sdf
			key="title"
			fontName="sarasa-mono-sc-regular"
			fontSize={30}
			text="DoraX Button Interaction"
			y={110}
			color3={0xffffff}
		/>
		<Button
			text={pressed.value ? "Pressed" : "Tap"}
			count={clicks.value}
			pressed={pressed.value}
			onTap={onTap}
			onPress={onPress}
			onRelease={onRelease}
		/>
		<label
			sdf
			key="hint"
			fontName="sarasa-mono-sc-regular"
			fontSize={18}
			text="Tap the button to verify signal-driven TSX diff updates."
			y={-100}
			color3={0xd1d5db}
		/>
	</node>
);

host.onCleanup(() => {
	root.unmount();
});

Director.clearColor = Color(0xff111827);
