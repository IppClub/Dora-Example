import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, signal, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXDynamicRenderTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXDynamicRenderTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const labelRef = useRef<Dora.Label.Type>();
const firstNodeRef = useRef<Dora.Node.Type>();
const secondNodeRef = useRef<Dora.Node.Type>();
const keyedBRef = useRef<Dora.Node.Type>();
const keyedARef = useRef<Dora.Node.Type>();
const drawRef = useRef<Dora.DrawNode.Type>();
const buttonRef = useRef<Dora.Node.Type>();
const buttonLabelRef = useRef<Dora.Label.Type>();
const value = signal(1);
const buttonClicks = signal(0);

interface TestButtonProps {
	title: string;
	count: number;
	ref: JSX.Ref<Dora.Node.Type>;
	labelRef: JSX.Ref<Dora.Label.Type>;
	onClick(this: void): void;
}

function TestButton(this: void, props: TestButtonProps) {
	const fillColor = props.count > 0 ? 0x2dd4bf : 0x3b82f6;
	return (
		<node
			key="button"
			ref={props.ref}
			width={160}
			height={54}
			touchEnabled
			onTapped={props.onClick}
		>
			<draw-node>
				<rect-shape width={160} height={54} fillColor={fillColor} borderWidth={2} borderColor={0xffffffff} />
			</draw-node>
			<label
				key="button-label"
				ref={props.labelRef}
				fontName="sarasa-mono-sc-regular"
				fontSize={20}
				text={`${props.title}: ${props.count}`}
				color3={0xffffff}
			/>
		</node>
	);
}

root.render(() =>
	<node>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={20} text="one" x={10} />
		<node key="first" ref={firstNodeRef} x={1} />
		<node key="second" ref={secondNodeRef} x={2} />
		<draw-node key="shape" ref={drawRef}>
			<rect-shape width={24} height={16} fillColor={0xffffffff} />
		</draw-node>
		<TestButton
			title="Clicks"
			count={buttonClicks.value}
			ref={buttonRef}
			labelRef={buttonLabelRef}
			onClick={() => {
				buttonClicks.value += 1;
			}}
		/>
	</node>
);

const firstLabel = labelRef.current;
const firstNode = firstNodeRef.current;
const secondNode = secondNodeRef.current;
expect(firstLabel !== undefined, "label was not mounted");
expect(firstNode !== undefined, "first node was not mounted");
expect(secondNode !== undefined, "second node was not mounted");
expect(drawRef.current !== undefined, "draw-node was not mounted");
expect(buttonRef.current !== undefined, "button was not mounted");
expect(buttonLabelRef.current !== undefined, "button label was not mounted");
expect(buttonRef.current!.touchEnabled, "button touch was not enabled");
expect(buttonLabelRef.current!.text === "Clicks: 0", "initial button label text was not rendered");
expect(firstLabel!.text === "one", "initial label text was not applied");
expect(firstLabel!.x === 10, "initial label x was not applied");

const firstButton = buttonRef.current;
buttonRef.current!.emit(Slot.Tapped);

Director.systemScheduler.schedule(once(() => {
	expect(buttonRef.current !== firstButton, "button event update should recreate event-bound node");
	expect(buttonLabelRef.current !== undefined, "button label was not remounted");
	expect(buttonLabelRef.current!.text === "Clicks: 1", "button click did not update label text");

	root.render(
		<node>
			<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={20} text="two" x={30} />
			<node key="second" ref={keyedBRef} x={20} />
			<node key="first" ref={keyedARef} x={10} />
		</node>
	);

	expect(labelRef.current === firstLabel, "same keyed label should be reused");
	expect(labelRef.current!.text === "two", "label text was not patched");
	expect(labelRef.current!.x === 30, "label x was not patched");
	expect(keyedBRef.current === secondNode, "keyed second node should be reused after reorder");
	expect(keyedARef.current === firstNode, "keyed first node should be reused after reorder");
	expect(keyedBRef.current!.x === 20, "reordered second node x was not patched");
	expect(keyedARef.current!.x === 10, "reordered first node x was not patched");

	root.render(() =>
		<node>
			<label key="signal-label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={20}>{value.value}</label>
		</node>
	);

	const signalLabel = labelRef.current;
	expect(signalLabel !== undefined, "signal label was not mounted");
	expect(signalLabel !== firstLabel, "label with a different key should be recreated");
	expect(signalLabel!.text === "1", "initial signal label text was not rendered");

	value.value = 7;

	Director.systemScheduler.schedule(once(() => {
		expect(labelRef.current === signalLabel, "signal update should reuse label node");
		expect(labelRef.current!.text === "7", "signal update did not patch label text");
		root.unmount();
		expect(!host.hasChildren, "root unmount did not remove rendered children");
		host.removeFromParent(true);
		Content.save(resultFile, "passed");
		Log("Info", "[DoraXDynamicRenderTest] passed");
	}));
}));
