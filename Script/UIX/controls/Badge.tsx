import { Color } from "Dora";
import type * as Dora from "Dora";
import { React } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { Icon } from "UIX/foundation/Icon";
import { Text } from "UIX/foundation/Text";
import { Row } from "UIX/layout/Row";
import { mergeStyle, textFromChildren } from "UIX/layout/helpers";
import { PaintNode } from "UIX/paint/PaintNode";
import { withAlpha } from "UIX/paint/color";
import type { UiIcon, UiNodeProps, UiSize } from "UIX/types";

export type BadgeTone = "default" | "primary" | "secondary" | "success" | "warning" | "danger" | "mana" | "warm";

export interface BadgeProps extends UiNodeProps {
	text?: string | number;
	tone?: BadgeTone;
	size?: UiSize;
	icon?: UiIcon;
	dot?: boolean;
	outline?: boolean;
}

function toneColor(this: void, ctx: import("UIX/paint/PaintNode").PaintContext, tone: BadgeTone): number {
	const theme = ctx.theme;
	if (tone === "primary") return theme.colors.accent.primary;
	if (tone === "secondary") return theme.colors.accent.secondary;
	if (tone === "success") return theme.colors.state.success;
	if (tone === "warning") return theme.colors.state.warning;
	if (tone === "danger") return theme.colors.state.danger;
	if (tone === "mana") return theme.colors.state.mana;
	if (tone === "warm") return theme.colors.accent.warm;
	return theme.colors.line.normal;
}

function badgePainter(this: void, tone: BadgeTone, outline: boolean) {
	return (ctx: import("UIX/paint/PaintNode").PaintContext) => {
		const theme = ctx.theme;
		const color = toneColor(ctx, tone);
		const radius = ctx.height * 0.5;
		const fill = outline ? theme.colors.surface.base : color;
		const fillAlpha = outline ? 0.42 * ctx.opacity : tone === "default" ? 0.32 * ctx.opacity : 0.2 * ctx.opacity;
		nvg.BeginPath();
		nvg.RoundedRect(0, 0, ctx.width, ctx.height, radius);
		nvg.FillColor(Color(withAlpha(fill, fillAlpha)));
		nvg.Fill();
		nvg.StrokeWidth(theme.stroke.hairline);
		nvg.StrokeColor(Color(withAlpha(color, tone === "default" ? 0.72 * ctx.opacity : ctx.opacity)));
		nvg.Stroke();
	};
}

export function Badge(this: void, props: BadgeProps): React.Element {
	const theme = getUiContext().theme;
	const size = props.size ?? "sm";
	const height = size === "lg" ? 34 : size === "md" ? 28 : 22;
	const fontSize = size === "lg" ? theme.font.size.md : size === "md" ? theme.font.size.sm : theme.font.size.xs;
	const iconSize = size === "lg" ? theme.size.icon.md : theme.size.icon.sm;
	const text = textFromChildren(props.children, props.text !== undefined ? tostring(props.text) : "");
	const hasIcon = props.icon !== undefined;
	const hasDot = props.dot === true;
	const paddingX = size === "lg" ? theme.space.md : theme.space.sm;
	const dotSize = 8;
	const contentWidth = math.max(0, text.length * fontSize * 0.62) + (hasIcon ? iconSize + theme.space.xs : 0) + (hasDot ? dotSize + theme.space.xs : 0);
	const width = math.max(height, contentWidth + paddingX * 2);
	const tone = props.tone ?? "default";
	const color = tone === "warm" || tone === "warning" ? theme.colors.accent.warm
		: tone === "default" ? theme.colors.text.secondary : theme.colors.text.primary;
	const accent = tone === "primary" ? theme.colors.accent.primary
		: tone === "secondary" ? theme.colors.accent.secondary
			: tone === "success" ? theme.colors.state.success
				: tone === "warning" ? theme.colors.state.warning
					: tone === "danger" ? theme.colors.state.danger
						: tone === "mana" ? theme.colors.state.mana
							: tone === "warm" ? theme.colors.accent.warm
								: theme.colors.line.normal;
	return (
		<align-node
			key={props.key}
			ref={props.ref as JSX.Ref<Dora.AlignNode.Type> | undefined}
			style={mergeStyle({
				position: "relative",
				width,
				height,
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
		>
			<PaintNode key="badge-bg" painter={badgePainter(tone, props.outline === true)} />
			<Row
				key="badge-content"
				style={{
					width: "100%",
					height: "100%",
					padding: [0, paddingX],
					alignItems: "center",
					justifyContent: "center",
					gap: theme.space.xs,
				}}
			>
				{hasDot ?
					<align-node key="badge-dot" style={{ width: dotSize, height: dotSize }}>
						<PaintNode
							key="badge-dot-paint"
							painter={(ctx) => {
								nvg.BeginPath();
								nvg.Circle(ctx.width * 0.5, ctx.height * 0.5, math.min(ctx.width, ctx.height) * 0.42);
								nvg.FillColor(Color(withAlpha(accent, ctx.opacity)));
								nvg.Fill();
							}}
						/>
					</align-node> : undefined}
				{hasIcon ?
					<Icon key="badge-icon" icon={props.icon!} size={iconSize} color={accent} /> : undefined}
				{text !== "" ?
					<Text key="badge-text" text={text} fontSize={fontSize} color={color} /> : undefined}
			</Row>
		</align-node>
	);
}
