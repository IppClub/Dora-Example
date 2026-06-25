import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXPropsPatchTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXPropsPatchTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

function close(this: void, a: number, b: number) {
	return math.abs(a - b) < 0.0001;
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const nodeRef = useRef<Dora.Node.Type>();
const replacementRef = useRef<Dora.Node.Type>();
const targetRef = useRef<Dora.Node.Type>();
const transformTargetRef = targetRef as unknown as JSX.Ref<JSX.Node>;
const labelRef = useRef<Dora.Label.Type>();
const eventRef = useRef<Dora.Node.Type>();
const updateRef = useRef<Dora.Node.Type>();
const inputRef = useRef<Dora.Node.Type>();

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={nodeRef}
			x={1}
			y={2}
			scaleX={1}
			scaleY={1}
			angle={0}
			anchorX={0.1}
			anchorY={0.2}
			opacity={0.5}
			color3={0xff0000}
			width={10}
			height={20}
			tag="initial"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="small" />
	</node>
);

const node = nodeRef.current;
const label = labelRef.current;
expect(node !== undefined, "node was not mounted");
expect(label !== undefined, "label was not mounted");
const initialOpacity = node!.opacity;

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={nodeRef}
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			anchorX={0.3}
			anchorY={0.4}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="patched" />
	</node>
);

expect(nodeRef.current === node, "ordinary node should be reused while patching props");
expect(nodeRef.current!.x === 11 && nodeRef.current!.y === 12, "position props were not patched");
expect(nodeRef.current!.scaleX === 2 && nodeRef.current!.scaleY === 3, "scale props were not patched");
expect(nodeRef.current!.angle === 45, "angle prop was not patched");
expect(close(nodeRef.current!.anchor.x, 0.3) && close(nodeRef.current!.anchor.y, 0.4), "anchor props were not patched");
expect(nodeRef.current!.opacity !== initialOpacity, "opacity prop was not patched");
expect(nodeRef.current!.width === 30 && nodeRef.current!.height === 40, "size props were not patched");
expect(nodeRef.current!.tag === "patched", "tag prop was not patched");
expect(nodeRef.current!.transformTarget === targetRef.current, "transformTarget ref was not patched");
expect(labelRef.current === label, "label should be reused when font construction props do not change");
expect(labelRef.current!.text === "patched", "label text was not patched");

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={replacementRef}
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			anchorX={0.3}
			anchorY={0.4}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="patched" />
	</node>
);
expect(nodeRef.current === undefined, "old ref should clear when ref changes");
expect(replacementRef.current === node, "new ref should point to reused node");

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			anchorX={0.3}
			anchorY={0.4}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="patched" />
	</node>
);
expect(replacementRef.current === undefined, "removed ref should clear old ref");

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={nodeRef}
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			anchorX={0.3}
			anchorY={0.4}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="patched" />
	</node>
);
expect(nodeRef.current === node, "ref should bind again after being removed");

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={nodeRef}
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
		/>
		<label
			key="label"
			ref={labelRef}
			fontName="sarasa-mono-sc-regular"
			fontSize={18}
			text="smooth"
			smoothLower={0.2}
			smoothUpper={0.8}
		/>
	</node>
);

expect(close(nodeRef.current!.anchor.x, 0.3) && close(nodeRef.current!.anchor.y, 0.4), "removed anchor props should keep previous values");
expect(nodeRef.current!.transformTarget === undefined, "removed transformTarget should clear to undefined");
expect(labelRef.current === label, "label should still be reused when smooth props change");
expect(close(labelRef.current!.smooth.x, 0.2) && close(labelRef.current!.smooth.y, 0.8), "smooth props were not patched");

root.render(
	<node>
		<node key="target" ref={targetRef} />
		<node
			key="node"
			ref={nodeRef}
			x={11}
			y={12}
			scaleX={2}
			scaleY={3}
			angle={45}
			opacity={0.75}
			color3={0x00ff00}
			width={30}
			height={40}
			tag="patched"
			transformTarget={transformTargetRef}
		/>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={18} text="default-smooth" />
	</node>
);

expect(close(labelRef.current!.smooth.x, 0.2) && close(labelRef.current!.smooth.y, 0.8), "removed smooth props should keep previous values");

root.render(
	<node>
		<label key="label" ref={labelRef} fontName="sarasa-mono-sc-regular" fontSize={30} text="large" />
	</node>
);
expect(labelRef.current !== label, "label should be recreated when fontSize changes");
expect(labelRef.current!.text === "large", "recreated label text was not applied");

let taps = 0;
function firstHandler(this: void) {
	taps += 1;
}
function secondHandler(this: void) {
	taps += 10;
}

root.render(<node key="event" ref={eventRef} onTapped={firstHandler} />);
const firstEventNode = eventRef.current;
expect(firstEventNode !== undefined, "event node was not mounted");
firstEventNode!.emit(Slot.Tapped);
expect(taps === 1, "first event handler was not called");

root.render(<node key="event" ref={eventRef} onTapped={secondHandler} />);
expect(eventRef.current === firstEventNode, "event handler change should patch node without recreation");
eventRef.current!.emit(Slot.Tapped);
expect(taps === 11, "second event handler should replace first handler");

root.render(<node key="event" ref={eventRef} />);
expect(eventRef.current === firstEventNode, "event handler removal should patch node without recreation");
eventRef.current!.emit(Slot.Tapped);
expect(taps === 11, "removed event handler should clear slot callbacks");

root.render(<node key="update" ref={updateRef} onUpdate={() => false} />);
const firstUpdateNode = updateRef.current;
expect(firstUpdateNode !== undefined, "update node was not mounted");

root.render(<node key="update" ref={updateRef} onUpdate={() => true} />);
expect(updateRef.current === firstUpdateNode, "onUpdate change should patch node without recreation");

root.render(<node key="update" ref={updateRef} />);
expect(updateRef.current === firstUpdateNode, "onUpdate removal should patch node without recreation");

root.render(<node key="input" ref={inputRef} />);
const inputNode = inputRef.current;
expect(inputNode !== undefined, "input node was not mounted");
expect(!inputNode!.touchEnabled, "input node should start without touch enabled");
expect(!inputNode!.keyboardEnabled, "input node should start without keyboard enabled");
expect(!inputNode!.controllerEnabled, "input node should start without controller enabled");

root.render(<node key="input" ref={inputRef} onTapped={() => {}} />);
expect(inputRef.current === inputNode, "adding tap event should patch input node");
expect(inputNode!.touchEnabled, "adding tap event should auto-enable touch");

root.render(<node key="input" ref={inputRef} onKeyDown={() => {}} />);
expect(inputRef.current === inputNode, "adding key event should patch input node");
expect(inputNode!.keyboardEnabled, "adding key event should auto-enable keyboard");

root.render(<node key="input" ref={inputRef} onButtonDown={() => {}} />);
expect(inputRef.current === inputNode, "adding controller event should patch input node");
expect(inputNode!.controllerEnabled, "adding controller event should auto-enable controller");

Director.systemScheduler.schedule(once(() => {
	root.unmount();
	host.removeFromParent(true);
	Content.save(resultFile, "passed");
	Log("Info", "[DoraXPropsPatchTest] passed");
}));
