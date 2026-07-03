import { Color, Rect, TextAlign } from "Dora";
import type * as Dora from "Dora";
import { React } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { PaintNode } from "UIX/paint/PaintNode";
import type { UiNodeProps } from "UIX/types";
import { mergeStyle, textFromChildren } from "UIX/layout/helpers";

export interface TextProps extends UiNodeProps {
	text?: string | number;
	fontName?: string;
	fontSize?: number;
	color?: number;
	alignment?: TextAlign;
	verticalAlign?: "top" | "center" | "bottom";
	wrap?: boolean;
	lineHeight?: number;
	sdf?: boolean;
	smoothLower?: number;
	smoothUpper?: number;
}

const fontIds: Record<string, number> = {};
const wrapCharWidthRatio = 0.58;

function getFontId(this: void, fontName: string): number {
	let fontId = fontIds[fontName];
	if (fontId === undefined || fontId === 0) {
		fontId = nvg.CreateFont(fontName);
		fontIds[fontName] = fontId;
	}
	return fontId;
}

function toNvgAlign(this: void, alignment: TextAlign | undefined): nvg.TextHAlign {
	if (alignment === TextAlign.Left) return nvg.TextHAlign.Left;
	if (alignment === TextAlign.Right) return nvg.TextHAlign.Right;
	return nvg.TextHAlign.Center;
}

function splitTextLines(this: void, text: string): string[] {
	const lines = text.split("\n");
	return lines.length > 0 ? lines : [""];
}

function longestLineLength(this: void, text: string): number {
	let length = 0;
	for (const line of splitTextLines(text)) {
		length = math.max(length, line.length);
	}
	return length;
}

function splitLongWord(this: void, word: string, maxChars: number, out: string[]) {
	let index = 0;
	while (index < word.length) {
		out.push(word.substring(index, index + maxChars));
		index += maxChars;
	}
}

export function wrapTextLines(this: void, text: string, maxWidth: number, fontSize: number): string[] {
	const charWidth = math.max(1, fontSize * wrapCharWidthRatio);
	const maxChars = math.max(1, math.floor(maxWidth / charWidth));
	const lines: string[] = [];
	for (const paragraph of text.split("\n")) {
		let line = "";
		for (const word of paragraph.split(" ")) {
			if (word === "") continue;
			if (word.length > maxChars) {
				if (line !== "") {
					lines.push(line);
					line = "";
				}
				splitLongWord(word, maxChars, lines);
				continue;
			}
			const next = line === "" ? word : `${line} ${word}`;
			if (next.length > maxChars) {
				if (line !== "") lines.push(line);
				line = word;
			} else {
				line = next;
			}
		}
		lines.push(line);
	}
	return lines.length > 0 ? lines : [""];
}

function measureTextWidth(this: void, text: string): number {
	const bounds = Rect(0, 0, 0, 0);
	return nvg.TextBounds(0, 0, text, bounds);
}

function splitLongWordMeasured(this: void, word: string, maxWidth: number, out: string[]) {
	let chunk = "";
	for (let i of $range(1, word.length)) {
		const next = `${chunk}${word.substring(i - 1, i)}`;
		if (chunk !== "" && measureTextWidth(next) > maxWidth) {
			out.push(chunk);
			chunk = word.substring(i - 1, i);
		} else {
			chunk = next;
		}
	}
	if (chunk !== "") out.push(chunk);
}

function wrapTextLinesMeasured(this: void, text: string, maxWidth: number): string[] {
	const lines: string[] = [];
	for (const paragraph of text.split("\n")) {
		let line = "";
		for (const word of paragraph.split(" ")) {
			if (word === "") continue;
			if (measureTextWidth(word) > maxWidth) {
				if (line !== "") {
					lines.push(line);
					line = "";
				}
				splitLongWordMeasured(word, maxWidth, lines);
				continue;
			}
			const next = line === "" ? word : `${line} ${word}`;
			if (line !== "" && measureTextWidth(next) > maxWidth) {
				lines.push(line);
				line = word;
			} else {
				line = next;
			}
		}
		lines.push(line);
	}
	return lines.length > 0 ? lines : [""];
}

function textLinesMeasured(this: void, text: string, wrap: boolean, maxWidth: number): string[] {
	return wrap ? wrapTextLinesMeasured(text, maxWidth) : splitTextLines(text);
}

function firstLineY(this: void, height: number, blockHeight: number, lineHeight: number, verticalAlign: TextProps["verticalAlign"]): number {
	if (verticalAlign === "top") return lineHeight * 0.5;
	if (verticalAlign === "bottom") return height - blockHeight + lineHeight * 0.5;
	return (height - blockHeight) * 0.5 + lineHeight * 0.5;
}

export function Text(this: void, props: TextProps): React.Element {
	const theme = getUiContext().theme;
	const value = textFromChildren(props.children, props.text !== undefined ? tostring(props.text) : "");
	const fontSize = props.fontSize ?? theme.font.size.md;
	const fontName = props.fontName ?? theme.font.name;
	const hAlign = toNvgAlign(props.alignment);
	const lineHeight = props.lineHeight ?? fontSize * 1.25;
	const explicitLineCount = splitTextLines(value).length;
	const estimatedWidth = math.max(fontSize, longestLineLength(value) * fontSize * 0.62 + 4);
	const estimatedHeight = math.max(fontSize, lineHeight * explicitLineCount);
	return (
		<align-node
			key={props.key}
			ref={props.ref as JSX.Ref<Dora.AlignNode.Type> | undefined}
			order={props.order}
			renderOrder={props.renderOrder}
			style={mergeStyle({
				width: estimatedWidth,
				height: estimatedHeight,
				alignItems: "center",
				justifyContent: "center",
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
		>
			<PaintNode
				key="text-paint"
				painter={(ctx) => {
					const x = hAlign === nvg.TextHAlign.Left ? 0 : hAlign === nvg.TextHAlign.Right ? ctx.width : ctx.width * 0.5;
					nvg.FontFaceId(getFontId(fontName));
					nvg.FontSize(fontSize);
					nvg.TextAlign(hAlign, nvg.TextVAlign.Middle);
					nvg.FillColor(Color(props.color ?? ctx.theme.colors.text.primary));
					const lines = textLinesMeasured(value, props.wrap === true, ctx.width);
					const blockHeight = lineHeight * lines.length;
					const y0 = firstLineY(ctx.height, blockHeight, lineHeight, props.verticalAlign);
					nvg.Save();
					nvg.Scale(1, -1);
					for (let i of $range(1, lines.length)) {
						const y = y0 + (lines.length - i) * lineHeight;
						nvg.Text(x, -y, lines[i - 1]);
					}
					nvg.Restore();
				}}
			/>
		</align-node>
	);
}
