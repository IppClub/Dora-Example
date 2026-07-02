import { App, Mouse, Size, Vec2 } from "Dora";
import type * as Dora from "Dora";
import { React, useCallback, useRef, useSignal } from "DoraX";
import { registerClip, unregisterClip } from "UIX/paint/clip";
import { mergeStyle } from "UIX/layout/helpers";
import type { UiNodeProps } from "UIX/types";
import { clamp } from "UIX/types";

export interface ScrollViewProps extends UiNodeProps {
	width?: number;
	height?: number;
	contentHeight: number;
	defaultOffsetY?: number;
	wheelSpeed?: number;
	inputOverlay?: boolean;
	dragOverlay?: boolean;
	swallowDrag?: boolean;
	onScroll?: (this: void, offsetY: number) => void;
}

export function ScrollView(this: void, props: ScrollViewProps): React.Element {
	const localOffset = useSignal(props.defaultOffsetY ?? 0);
	const localRef = useRef<Dora.AlignNode.Type>();
	const contentRef = useRef<Dora.AlignNode.Type>();
	const inputRef = useRef<Dora.AlignNode.Type>();
	const dragRef = useRef<Dora.AlignNode.Type>();
	const dragging = useRef(false);
	const scrollActive = useRef(false);
	const dragDistance = useRef(0);
	const lastDragY = useRef(0);
	const rootRef = (props.ref ?? localRef) as JSX.Ref<Dora.AlignNode.Type>;
	const styleWidth = props.style?.width as number | undefined;
	const styleHeight = props.style?.height as number | undefined;
	const width = props.width ?? styleWidth ?? 240;
	const height = props.height ?? styleHeight ?? 160;
	const maxOffset = math.max(0, props.contentHeight - height);
	const offset = clamp(localOffset.value, 0, maxOffset);

	const contentYForOffset = useCallback((next: number) => next + height - props.contentHeight / 2, [height, props.contentHeight]);
	const applyContentOffset = useCallback((next: number) => {
		const node = contentRef.current;
		if (node !== undefined) {
			node.y = contentYForOffset(next);
		}
	}, [contentYForOffset]);
	const setOffset = useCallback((value: number) => {
		const next = clamp(value, 0, maxOffset);
		localOffset.value = next;
		applyContentOffset(next);
		props.onScroll?.(next);
	}, [localOffset.value, maxOffset, props.onScroll, applyContentOffset]);
	const scrollByWheel = useCallback((deltaY: number) => {
		setOffset(offset + deltaY * (props.wheelSpeed ?? 24));
	}, [offset, props.wheelSpeed, setOffset]);
	const mouseRootLocation = useCallback(() => {
		const root = rootRef.current;
		if (root === undefined) return undefined;
		const { width: bw, height: bh } = App.bufferSize;
		const { width: vw } = App.visualSize;
		let pos = Mouse.position.mul(bw / vw);
		pos = Vec2(pos.x - bw / 2, bh / 2 - pos.y);
		return root.convertToNodeSpace(pos);
	}, []);
	const touchRootLocation = useCallback((touch: Dora.Touch.Type) => {
		const root = rootRef.current;
		if (root !== undefined && touch.worldLocation !== undefined) {
			return root.convertToNodeSpace(touch.worldLocation);
		}
		return touch.location;
	}, []);
	const isInsideTouch = useCallback((touch: Dora.Touch.Type) => {
		const location = touchRootLocation(touch);
		return location.x >= 0 && location.x <= width && location.y >= 0 && location.y <= height;
	}, [height, touchRootLocation, width]);
	const filterDrag = useCallback((touch: Dora.Touch.Type) => {
		if (!touch.first || !isInsideTouch(touch)) {
			touch.enabled = false;
		}
	}, [isInsideTouch]);
	const moveDrag = useCallback((touch: Dora.Touch.Type) => {
		const nextDistance = (dragDistance.current ?? 0) + touch.delta.length;
		(dragDistance as AnyTable).current = nextDistance;
		if (scrollActive.current || nextDistance > 10) {
			(scrollActive as AnyTable).current = true;
			setOffset(offset + touch.delta.y);
		}
	}, [dragDistance, offset, scrollActive, setOffset]);
	const beginDrag = useCallback((touch: Dora.Touch.Type) => {
		const location = touchRootLocation(touch);
		(dragging as AnyTable).current = true;
		(scrollActive as AnyTable).current = false;
		(dragDistance as AnyTable).current = 0;
		(lastDragY as AnyTable).current = location.y;
	}, [dragDistance, dragging, lastDragY, scrollActive, touchRootLocation]);
	const endDrag = useCallback(() => {
		(dragging as AnyTable).current = false;
		(scrollActive as AnyTable).current = false;
		(dragDistance as AnyTable).current = 0;
	}, [dragDistance, dragging, scrollActive]);
	const syncClip = useCallback((node: Dora.AlignNode.Type | undefined, clipWidth: number, clipHeight: number) => {
		if (node !== undefined) {
			node.size = Size(clipWidth, clipHeight);
			registerClip(node, clipWidth, clipHeight);
		}
	}, []);
	const syncInputSize = useCallback((node: Dora.AlignNode.Type | undefined, inputWidth: number, inputHeight: number) => {
		if (node !== undefined) node.size = Size(inputWidth, inputHeight);
	}, []);
	const syncContentNode = useCallback((node: Dora.AlignNode.Type | undefined) => {
		if (node !== undefined) {
			node.size = Size(width, props.contentHeight);
			node.y = contentYForOffset(offset);
		}
	}, [contentYForOffset, offset, props.contentHeight, width]);
	const onRootLayout = useCallback((w: number, h: number) => syncClip(rootRef.current, w, h), [syncClip]);
	const onRootUnmount = useCallback((node: Dora.AlignNode.Type) => {
		unregisterClip(node);
	}, []);
	const onContentLayout = useCallback(() => syncContentNode(contentRef.current), [syncContentNode]);
	const onInputLayout = useCallback((w: number, h: number) => syncInputSize(inputRef.current, w, h), [syncInputSize]);
	const onWheel = useCallback((delta: Vec2.Type) => scrollByWheel(delta.y), [scrollByWheel]);
	const onDragLayout = useCallback((w: number, h: number) => syncInputSize(dragRef.current, w, h), [syncInputSize]);
	return (
		<align-node
			key={props.key}
			ref={rootRef}
			style={mergeStyle({
				position: "relative",
				width,
				height,
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
			onLayout={onRootLayout}
			onUnmount={onRootUnmount}
		>
			<menu anchorX={0} anchorY={0} width={width} height={height}>
				<align-node
					key="content"
					ref={contentRef}
					style={{
						width,
						height: props.contentHeight,
						flexDirection: "column",
						alignItems: "flex-start",
						justifyContent: "flex-start",
					}}
					anchorX={0}
					onLayout={onContentLayout}
				>
					{props.children}
				</align-node>
			</menu>
			{props.inputOverlay !== false ?
				<align-node
					key="input-overlay"
					ref={inputRef}
					style={{
						position: "absolute",
						left: 0,
						top: 0,
						width,
						height,
					}}
					touchEnabled={!props.disabled}
					swallowTouches={props.dragOverlay === true}
					swallowMouseWheel
					onLayout={onInputLayout}
					onMouseWheel={onWheel}
				/> : undefined
			}
			{props.inputOverlay !== false ?
				<align-node
					key="drag-capture"
					ref={dragRef}
					style={{
						position: "absolute",
						left: 0,
						top: 0,
						width,
						height,
					}}
					touchEnabled={!props.disabled}
					swallowTouches={props.swallowDrag ?? false}
					onLayout={onDragLayout}
					onTapBegan={beginDrag}
					onTapMoved={moveDrag}
					onTapEnded={endDrag}
				/> : undefined
			}
		</align-node>
	);
}
