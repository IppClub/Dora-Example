import { App, Color, Keyboard, Rect, Vec2 } from "Dora";
import type * as Dora from "Dora";
import { React, useCallback, useRef, useSignal } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { Icon } from "UIX/foundation/Icon";
import { PaintNode } from "UIX/paint/PaintNode";
import { withAlpha } from "UIX/paint/color";
import { mergeStyle } from "UIX/layout/helpers";
import type { UiIcon, UiNodeProps, UiSize, UiVariant } from "UIX/types";

export interface TextInputProps extends UiNodeProps {
	value?: string;
	defaultValue?: string;
	placeholder?: string;
	size?: UiSize;
	variant?: UiVariant;
	fontName?: string;
	fontSize?: number;
	maxLength?: number;
	focused?: boolean;
	prefixIcon?: UiIcon;
	suffixIcon?: UiIcon;
	onFocusChange?: (this: void, focused: boolean) => void;
	onValueChange?: (this: void, value: string) => void;
	onSubmit?: (this: void, value: string) => void;
}

const fontIds: Record<string, number> = {};

function getFontId(this: void, fontName: string): number {
	let fontId = fontIds[fontName];
	if (fontId === undefined || fontId === 0) {
		fontId = nvg.CreateFont(fontName);
		fontIds[fontName] = fontId;
	}
	return fontId;
}

function utf8Len(this: void, text: string): number {
	const [len] = utf8.len(text);
	return len ?? text.length;
}

function utf8Head(this: void, text: string, count: number): string {
	if (count <= 0) return "";
	const nextPos = utf8.offset(text, count + 1);
	return nextPos === undefined ? text : string.sub(text, 1, nextPos - 1);
}

function utf8DropTail(this: void, text: string, count: number): string {
	return utf8Head(text, math.max(0, utf8Len(text) - count));
}

function limitText(this: void, text: string, maxLength?: number): string {
	if (maxLength === undefined || maxLength <= 0) return text;
	return utf8Head(text, maxLength);
}

function measureTextWidth(this: void, fontName: string, fontSize: number, text: string): number {
	nvg.FontFaceId(getFontId(fontName));
	nvg.FontSize(fontSize);
	const bounds = Rect(0, 0, 0, 0);
	return nvg.TextBounds(0, 0, text, bounds);
}

function displayBase(this: void, text: string, editing: string): string {
	const editingLen = utf8Len(editing);
	return editingLen > 0 ? utf8DropTail(text, editingLen) : text;
}

export function TextInput(this: void, props: TextInputProps): React.Element {
	const ui = getUiContext();
	const theme = ui.theme;
	const size = props.size ?? "md";
	const height = theme.size.control[size];
	const fontName = props.fontName ?? theme.font.name;
	const fontSize = props.fontSize ?? theme.font.size.md;
	const iconSize = theme.size.icon[size];
	const disabled = props.disabled === true;
	const localValue = useSignal(props.defaultValue ?? "");
	const focused = useSignal(props.focused === true);
	const editing = useRef("");
	const editingBase = useRef<string | undefined>(undefined);
	const valueRef = useRef("");
	const rootRef = (props.ref ?? useRef<Dora.AlignNode.Type>()) as JSX.Ref<Dora.AlignNode.Type>;
	const styleWidth = props.style?.width as number | undefined;
	const width = props.style?.width === undefined ? 220 : styleWidth;
	const textValue = props.value ?? localValue.value;
	(valueRef as AnyTable).current = textValue;

	const setFocused = useCallback((next: boolean) => {
		if (disabled) return;
		if (focused.value !== next) {
			focused.value = next;
			props.onFocusChange?.(next);
		}
	}, [disabled, focused.value, props.onFocusChange]);

	const updateIMEPos = useCallback(() => {
		const node = rootRef.current;
		if (node === undefined) return;
		const leftInset = theme.space.md + (props.prefixIcon !== undefined ? iconSize + theme.space.sm : 0);
		const rightInset = theme.space.md + (props.suffixIcon !== undefined ? iconSize + theme.space.sm : 0);
		const textWidth = math.max(1, node.width - leftInset - rightInset);
		const text = valueRef.current ?? "";
		const contentWidth = measureTextWidth(fontName, fontSize, text);
		const offsetX = math.max(contentWidth + 4 - textWidth, 0);
		const cursorX = leftInset + math.max(0, contentWidth - offsetX);
		node.convertToWindowSpace(Vec2(cursorX, height * 0.5), (pos) => {
			Keyboard.updateIMEPosHint(pos);
		});
	}, [fontName, fontSize, height, iconSize, props.prefixIcon, props.suffixIcon, theme.space.md, theme.space.sm]);

	const emitValue = useCallback((nextValue: string) => {
		const next = limitText(nextValue, props.maxLength);
		if (props.value === undefined) localValue.value = next;
		(valueRef as AnyTable).current = next;
		props.onValueChange?.(next);
		updateIMEPos();
	}, [localValue.value, props.maxLength, props.onValueChange, props.value, updateIMEPos, valueRef]);

	const attachInput = useCallback(() => {
		const node = rootRef.current;
		if (node === undefined || disabled) return;
		updateIMEPos();
		node.detachIME();
		node.attachIME();
		updateIMEPos();
	}, [disabled, updateIMEPos]);

	const onAttachIME = useCallback(() => {
		const node = rootRef.current;
		if (node !== undefined) node.keyboardEnabled = true;
		(editing as AnyTable).current = "";
		(editingBase as AnyTable).current = undefined;
		setFocused(true);
	}, [editing, editingBase, setFocused]);

	const onDetachIME = useCallback(() => {
		const node = rootRef.current;
		if (node !== undefined) node.keyboardEnabled = false;
		(editing as AnyTable).current = "";
		(editingBase as AnyTable).current = undefined;
		setFocused(false);
	}, [editing, editingBase, setFocused]);

	const onTextInput = useCallback((text: string) => {
		if (disabled) return;
		const base = editingBase.current ?? displayBase(valueRef.current ?? "", editing.current ?? "");
		(editing as AnyTable).current = "";
		(editingBase as AnyTable).current = undefined;
		emitValue(`${base}${text}`);
	}, [disabled, editing, editingBase, emitValue]);

	const onTextEditing = useCallback((text: string) => {
		if (disabled) return;
		const base = editingBase.current ?? displayBase(valueRef.current ?? "", editing.current ?? "");
		if (text === "") {
			(editing as AnyTable).current = "";
			(editingBase as AnyTable).current = undefined;
			if (props.value === undefined) localValue.value = base;
			(valueRef as AnyTable).current = base;
			props.onValueChange?.(base);
			updateIMEPos();
			return;
		}
		(editingBase as AnyTable).current = base;
		const next = limitText(`${base}${text}`, props.maxLength);
		(editing as AnyTable).current = text;
		if (props.value === undefined) localValue.value = next;
		(valueRef as AnyTable).current = next;
		props.onValueChange?.(next);
		updateIMEPos();
	}, [disabled, editing, editingBase, localValue.value, props.maxLength, props.onValueChange, props.value, updateIMEPos, valueRef]);

	const onKeyPressed = useCallback((key: Dora.KeyName) => {
		if (disabled) return;
		if (App.platform === "Android" && utf8Len(editing.current ?? "") === 1) {
			if (key === "BackSpace") {
				(editing as AnyTable).current = "";
				(editingBase as AnyTable).current = undefined;
			}
		} else if ((editing.current ?? "") !== "") {
			return;
		}
		if (key === "BackSpace") {
			(editingBase as AnyTable).current = undefined;
			const next = utf8DropTail(valueRef.current ?? "", 1);
			emitValue(next);
		} else if (key === "Return") {
			(editingBase as AnyTable).current = undefined;
			rootRef.current?.detachIME();
			props.onSubmit?.(valueRef.current ?? "");
		} else if (key === "Escape") {
			(editingBase as AnyTable).current = undefined;
			rootRef.current?.detachIME();
		}
	}, [disabled, editing, editingBase, emitValue, props.onSubmit]);

	const state = { disabled, focused: false };
	const textColor = disabled ? theme.colors.text.disabled : theme.colors.text.primary;
	const placeholderColor = theme.colors.text.secondary;
	const iconColor = disabled ? theme.colors.text.disabled : focused.value ? theme.colors.accent.primary : theme.colors.text.secondary;
	const prefixOffset = props.prefixIcon !== undefined ? iconSize + theme.space.sm : 0;
	const suffixOffset = props.suffixIcon !== undefined ? iconSize + theme.space.sm : 0;
	const leftInset = theme.space.md + prefixOffset;
	const rightInset = theme.space.md + suffixOffset;
	const controlWidth = width ?? 220;
	const textAreaWidth = math.max(1, controlWidth - leftInset - rightInset);
	const hasText = textValue !== "";
	const contentWidth = measureTextWidth(fontName, fontSize, textValue);
	const offsetX = hasText && focused.value ? math.max(contentWidth + 4 - textAreaWidth, 0) : 0;
	const cursorLeft = leftInset + math.max(0, hasText ? contentWidth - offsetX : 0) + 2;
	const cursorTop = height * 0.24;
	const cursorHeight = height * 0.52;
	return (
		<align-node
			key={props.key}
			ref={rootRef}
			style={mergeStyle({
				position: "relative",
				width: width ?? 220,
				height,
				minWidth: 96,
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
			touchEnabled={!disabled}
			swallowTouches
			onTapped={attachInput}
			onAttachIME={onAttachIME}
			onDetachIME={onDetachIME}
			onTextInput={onTextInput}
			onTextEditing={onTextEditing}
			onKeyPressed={onKeyPressed}
		>
			<PaintNode
				key="text-input-paint"
				state={state}
				painter={(ctx) => {
					const textAreaWidth = math.max(1, ctx.width - leftInset - rightInset);
					const displayText = valueRef.current ?? "";
					const hasText = displayText !== "";
					const paintText = hasText ? displayText : props.placeholder ?? "";
					const contentWidth = measureTextWidth(fontName, fontSize, displayText);
					const paintWidth = hasText ? contentWidth : measureTextWidth(fontName, fontSize, paintText);
					const radius = theme.radius.md;
					const active = focused.value && !disabled;
					const offsetX = hasText && active ? math.max(contentWidth + 4 - textAreaWidth, 0) : 0;
					const fillAlpha = disabled ? theme.painter.disabledAlpha : 0.72;
					nvg.BeginPath();
					nvg.RoundedRect(1, 2, ctx.width - 2, ctx.height - 3, radius);
					nvg.FillColor(Color(withAlpha(0xff000000, 0.18 * ctx.opacity)));
					nvg.Fill();
					nvg.BeginPath();
					nvg.RoundedRect(0, 0, ctx.width, ctx.height, radius);
					nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, fillAlpha * ctx.opacity)));
					nvg.Fill();
					nvg.BeginPath();
					nvg.RoundedRect(2, 2, ctx.width - 4, ctx.height - 4, math.max(1, radius - 2));
					nvg.FillColor(Color(withAlpha(theme.colors.surface.raised, (active ? 0.2 : 0.1) * ctx.opacity)));
					nvg.Fill();
					if (active) {
						nvg.BeginPath();
						nvg.RoundedRect(3, 3, ctx.width - 6, ctx.height - 6, math.max(1, radius - 3));
						nvg.FillColor(Color(withAlpha(theme.colors.accent.primary, 0.055 * ctx.opacity)));
						nvg.Fill();
					}
					nvg.BeginPath();
					nvg.RoundedRect(0.5, 0.5, ctx.width - 1, ctx.height - 1, radius);
					nvg.StrokeWidth(active ? 1.5 : theme.stroke.hairline);
					nvg.StrokeColor(Color(withAlpha(active ? theme.colors.accent.primary : theme.colors.line.normal, (disabled ? 0.4 : active ? 0.82 : 0.72) * ctx.opacity)));
					nvg.Stroke();
					if (active) {
						nvg.BeginPath();
						nvg.RoundedRect(2.5, 2.5, ctx.width - 5, ctx.height - 5, math.max(1, radius - 2));
						nvg.StrokeWidth(1);
						nvg.StrokeColor(Color(withAlpha(theme.colors.focus.glow, 0.65 * ctx.opacity)));
						nvg.Stroke();
					}
					nvg.Save();
					nvg.IntersectScissor(leftInset, 0, textAreaWidth, ctx.height);
					nvg.FontFaceId(getFontId(fontName));
					nvg.FontSize(fontSize);
					nvg.TextAlign(nvg.TextHAlign.Left, nvg.TextVAlign.Middle);
					nvg.FillColor(Color(withAlpha(hasText ? textColor : placeholderColor, hasText ? ctx.opacity : 0.72 * ctx.opacity)));
					nvg.Scale(1, -1);
					nvg.Text(leftInset - offsetX + (hasText ? 0 : theme.space.sm), -ctx.height * 0.5, paintText);
					nvg.Restore();
				}}
			/>
			{focused.value && !disabled ?
				<align-node
					key="text-input-cursor"
					style={{
						position: "absolute",
						left: cursorLeft,
						top: cursorTop,
						width: 2,
						height: cursorHeight,
					}}
				>
					<PaintNode
						key="text-input-cursor-paint"
						painter={(ctx) => {
							nvg.BeginPath();
							nvg.RoundedRect(0, 0, ctx.width, ctx.height, 1);
							nvg.FillColor(Color(withAlpha(theme.colors.accent.primary, ctx.node.opacity)));
							nvg.Fill();
						}}
					>
						<loop>
							<opacity time={0.08} start={1} stop={1} />
							<delay time={0.36} />
							<opacity time={0.12} start={1} stop={0} />
							<delay time={0.24} />
							<opacity time={0.12} start={0} stop={1} />
						</loop>
					</PaintNode>
				</align-node> : undefined}
			{props.prefixIcon !== undefined ?
				<align-node
					key="text-input-prefix"
					style={{
						position: "absolute",
						left: theme.space.md,
						top: (height - iconSize) * 0.5,
						width: iconSize,
						height: iconSize,
					}}
				>
					<Icon icon={props.prefixIcon} size={iconSize} disabled={disabled} color={iconColor} />
				</align-node> : undefined}
			{props.suffixIcon !== undefined ?
				<align-node
					key="text-input-suffix"
					style={{
						position: "absolute",
						right: theme.space.md,
						top: (height - iconSize) * 0.5,
						width: iconSize,
						height: iconSize,
					}}
				>
					<Icon icon={props.suffixIcon} size={iconSize} disabled={disabled} color={iconColor} />
				</align-node> : undefined}
		</align-node>
	);
}
