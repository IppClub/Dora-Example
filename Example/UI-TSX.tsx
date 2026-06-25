// @preview-file on clear
import { React, createRoot, reference, signal, toAction, toNode, useCallback } from 'DoraX';
import { Director, Ease, Size, sleep, thread, Vec2, once } from 'Dora';
import type * as Dora from 'Dora';

import * as LineRectCreate from 'UI/View/Shape/LineRect';
import * as ButtonCreate from 'UI/Control/Basic/Button';
import { Button } from 'UI/Control/Basic/Button';
import * as ScrollAreaCreate from 'UI/Control/Basic/ScrollArea';
import { ScrollArea, AlignMode } from 'UI/Control/Basic/ScrollArea';

interface ButtonProps {
	ref?: JSX.Ref<Button.Type>;
	key?: string | number;
	text: string;
	width: number;
	height: number;
	children?: React.Element[];
	onMount?: (this: void, node: Dora.Node.Type) => void;
	onClick: (this: void) => void;
}

const Button = (props: ButtonProps) => {
	const { text, onClick } = props;
	const createButton = useCallback(() => {
		const btn = ButtonCreate({
			text,
			width: 50,
			height: 50
		});
		btn.onTapped(onClick);
		return btn;
	}, [text, onClick]);
	return <custom-node key={props.key} onMount={props.onMount} onCreate={createButton} children={props.children} />;
};

interface ScrollAreaProps {
	ref?: JSX.Ref<ScrollArea.Type>;
	x?: number;
	y?: number;
	width: number;
	height: number;
	viewWidth?: number;
	viewHeight?: number;
	paddingX?: number; // default 200
	paddingY?: number; // default 200
	scrollBar?: boolean; // default true
	scrollBarColor3?: number; // default App.themeColor.toARGB()
	clipping?: boolean; // default true
	children?: React.Element[];
};

const ScrollArea = (props: ScrollAreaProps) => {
	return <custom-node onCreate={() => {
		const { width, height } = props;
		const scrollArea = ScrollAreaCreate(props);
		if (props.ref) {
			(props.ref as unknown as { current: ScrollArea.Type }).current = scrollArea;
		}
		if (props.children) {
			for (let child of props.children) {
				toNode(child)?.addTo(scrollArea.view);
			}
			scrollArea.adjustSizeWithAlign(AlignMode.Auto, 10, Size(width, height));
		}
		return scrollArea;
	}} />;
};

interface ItemProps {
	id: number;
	name: string;
	value: number;
	mountButton: (this: void, node: Dora.Node.Type) => void;
	remove: (this: void) => void;
};

const scrollArea = reference<ScrollArea.Type>();
const items = signal<ItemProps[]>([]);
let listRoot: ReturnType<typeof createRoot> | undefined;

function adjustScrollArea(this: void) {
	const { current } = scrollArea;
	if (!current) return;
	current.adjustSizeWithAlign(AlignMode.Auto);
}

function scheduleAdjustScrollArea(this: void) {
	Director.scheduler.schedule(once(() => {
		sleep();
		adjustScrollArea();
	}));
}

function setItems(this: void, nextItems: ItemProps[]) {
	items.value = nextItems;
	scheduleAdjustScrollArea();
}

function removeItem(this: void, target: ItemProps) {
	const nextItems: ItemProps[] = [];
	for (let item of items.value) {
		if (item !== target) {
			nextItems.push(item);
		}
	}
	setItems(nextItems);
}

function appendItem(this: void, item: ItemProps) {
	const nextItems: ItemProps[] = [];
	for (let current of items.value) {
		nextItems.push(current);
	}
	nextItems.push(item);
	setItems(nextItems);
}

function createItem(this: void, id: number): ItemProps {
	const item = {} as ItemProps;
	item.id = id;
	item.name = `btn ${id}`;
	item.value = id;
	item.remove = () => {
		thread(() => {
			sleep(0.5);
			removeItem(item);
		});
	};
	item.mountButton = (node) => {
		const btn = node as Button.Type;
		btn.once(() => {
			btn.face.perform(toAction(
				<scale time={0.3} start={0} stop={1} easing={Ease.OutBack} />
			));
			sleep();
			adjustScrollArea();
		});
	};
	return item;
}

function renderItems(this: void) {
	return items.value.map(item => (
		<Button
			key={item.id}
			text={item.name}
			width={50}
			height={50}
			onClick={item.remove}
			onMount={item.mountButton}
		/>
	));
}

function mountItemRoot(this: void) {
	const { current } = scrollArea;
	if (!current || listRoot) return;
	listRoot = createRoot(current.view);
	listRoot.render(renderItems);
	adjustScrollArea();
}

function updateScrollLayout(this: void, width: number, height: number) {
	const { current } = scrollArea;
	if (!current) return;
	current.position = Vec2(width / 2, height / 2);
	current.adjustSizeWithAlign(AlignMode.Auto, 10, Size(width, height));
	current.getChildByTag("border")?.removeFromParent();
	const border = LineRectCreate({ x: -width / 2, y: -height / 2, width, height, color: 0xffffffff });
	current.addChild(border, 0, "border");
	mountItemRoot();
}

function startAddingItems(this: void) {
	thread(() => {
		for (let i of $range(1, 30)) {
			appendItem(createItem(i));
			sleep(1);
		}
	});
}

function App(this: void) {
	return (
		<align-node windowRoot style={{ alignItems: 'center', justifyContent: 'center' }}>
			<align-node style={{ width: "50%", height: "50%" }} onLayout={updateScrollLayout}>
				<ScrollArea ref={scrollArea} width={250} height={300} paddingX={0} />
			</align-node>
		</align-node>
	);
}

const appNode = toNode(<App />);
if (appNode) {
	appNode.onCleanup(() => {
		if (listRoot) {
			listRoot.unmount();
			listRoot = undefined;
		}
	});
	startAddingItems();
}
