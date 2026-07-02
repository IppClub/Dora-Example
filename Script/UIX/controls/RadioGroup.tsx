import { Color } from "Dora";
import type * as Dora from "Dora";
import { React } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { Icon } from "UIX/foundation/Icon";
import { FocusRing } from "UIX/foundation/FocusRing";
import { Text } from "UIX/foundation/Text";
import { Column } from "UIX/layout/Column";
import { Row } from "UIX/layout/Row";
import { mergeStyle } from "UIX/layout/helpers";
import { PaintNode } from "UIX/paint/PaintNode";
import { withAlpha } from "UIX/paint/color";
import { useInteraction } from "UIX/input/Interaction";
import type { UiIcon, UiNodeProps } from "UIX/types";

export interface RadioItem {
	id: string;
	label: string;
	icon?: UiIcon;
	disabled?: boolean;
	ref?: { readonly current?: Dora.Node.Type };
}

export interface RadioGroupProps extends UiNodeProps {
	value: string;
	items: RadioItem[];
	direction?: "row" | "column";
	itemWidth?: number;
	itemHeight?: number;
	gap?: number;
	focusedId?: string;
	onValueChange?: (this: void, value: string) => void;
}

interface RadioOptionProps {
	key?: string | number;
	item: RadioItem;
	selected: boolean;
	focused: boolean;
	width?: number;
	height: number;
	onSelect?: (this: void, value: string) => void;
}

function radioDotPainter(this: void, selected: boolean) {
	return (ctx: import("UIX/paint/PaintNode").PaintContext) => {
		const theme = ctx.theme;
		const state = ctx.state;
		const disabled = state.disabled;
		const size = math.min(ctx.width, ctx.height);
		const cx = ctx.width * 0.5;
		const cy = ctx.height * 0.5;
		const radius = size * 0.36;
		const stroke = selected ? theme.colors.accent.primary : theme.colors.line.normal;

		nvg.BeginPath();
		nvg.Circle(cx, cy, radius);
		nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, disabled ? theme.painter.disabledAlpha : selected ? 0.22 * ctx.opacity : ctx.opacity)));
		nvg.Fill();
		nvg.StrokeWidth(selected ? 2 : theme.stroke.hairline);
		nvg.StrokeColor(Color(withAlpha(disabled ? theme.colors.text.disabled : stroke, disabled ? 0.38 : ctx.opacity)));
		nvg.Stroke();

		if (selected) {
			nvg.BeginPath();
			nvg.Circle(cx, cy, radius * 0.60);
			nvg.FillColor(Color(withAlpha(disabled ? theme.colors.text.disabled : theme.colors.text.primary, ctx.opacity)));
			nvg.Fill();
		}
	};
}

function radioItemSurfacePainter(this: void, selected: boolean) {
	return (ctx: import("UIX/paint/PaintNode").PaintContext) => {
		const theme = ctx.theme;
		const state = ctx.state;
		const disabled = state.disabled;
		const radius = theme.radius.sm;
		const fill = disabled ? theme.colors.surface.sunken
			: selected ? theme.colors.accent.primary
				: state.pressed ? theme.colors.surface.raised : theme.colors.surface.base;
		const fillAlpha = disabled ? theme.painter.disabledAlpha * ctx.opacity
			: selected ? (state.pressed ? 0.3 : 0.18) * ctx.opacity
				: ctx.opacity;
		const stroke = selected ? theme.colors.accent.primary : theme.colors.line.normal;

		nvg.BeginPath();
		nvg.RoundedRect(0, 0, ctx.width, ctx.height, radius);
		nvg.FillColor(Color(withAlpha(fill, fillAlpha)));
		nvg.Fill();
		nvg.StrokeWidth(selected ? theme.stroke.normal : theme.stroke.hairline);
		nvg.StrokeColor(Color(withAlpha(stroke, disabled ? 0.38 : ctx.opacity)));
		nvg.Stroke();
	};
}

function RadioOption(this: void, props: RadioOptionProps): React.Element {
	const theme = getUiContext().theme;
	const disabled = props.item.disabled === true;
	const interaction = useInteraction({
		disabled,
		selected: props.selected,
	});
	if (props.focused && !interaction.state.focused) {
		interaction.setFocused(true);
	}
	const textColor = disabled ? theme.colors.text.disabled : props.selected ? theme.colors.text.primary : theme.colors.text.secondary;
	return (
		<align-node
			key={props.item.id}
			ref={props.item.ref as JSX.Ref<Dora.AlignNode.Type> | undefined}
			style={{
				position: "relative",
				width: props.width,
				height: props.height,
				minWidth: props.height,
			}}
			touchEnabled={!disabled}
			swallowTouches
			onTapBegan={() => interaction.setPressed(true)}
			onTapEnded={() => interaction.setPressed(false)}
			onTapped={() => {
				if (!disabled && !props.selected) props.onSelect?.(props.item.id);
			}}
			onUnmount={() => interaction.reset()}
		>
			<PaintNode key="radio-item-surface" state={interaction.state} painter={radioItemSurfacePainter(props.selected)} />
			<Row
				key="radio-item-content"
				style={{
					width: "100%",
					height: "100%",
					padding: [0, theme.space.sm],
					alignItems: "center",
					justifyContent: "flex-start",
					gap: theme.space.xs,
				}}
			>
				<align-node key="radio-dot" style={{ width: 20, height: 20 }}>
					<PaintNode key="radio-dot-paint" state={interaction.state} painter={radioDotPainter(props.selected)} />
				</align-node>
				{props.item.icon !== undefined ?
					<Icon key="radio-icon" icon={props.item.icon} size={theme.size.icon.sm} color={textColor} disabled={disabled} /> : undefined}
				<Text key="radio-label" text={props.item.label} fontSize={theme.font.size.sm} color={textColor} />
			</Row>
			<FocusRing key="radio-focus-ring" active={interaction.state.focused} disabled={disabled} />
		</align-node>
	);
}

export function RadioGroup(this: void, props: RadioGroupProps): React.Element {
	const theme = getUiContext().theme;
	const direction = props.direction ?? "column";
	const height = props.itemHeight ?? theme.size.control.md;
	const gap = props.gap ?? theme.space.sm;
	const items = props.items.map((item) => (
		<RadioOption
			key={item.id}
			item={item}
			selected={item.id === props.value}
			focused={item.id === props.focusedId}
			width={props.itemWidth}
			height={height}
			onSelect={props.onValueChange}
		/>
	));
	const commonStyle = mergeStyle({
		gap,
		width: props.style?.width,
		height: props.style?.height,
	}, props.style);
	return direction === "row" ? (
		<Row key={props.key} style={commonStyle} visible={props.visible} opacity={props.opacity}>
			{items}
		</Row>
	) : (
		<Column key={props.key} style={commonStyle} visible={props.visible} opacity={props.opacity}>
			{items}
		</Column>
	);
}
