import { Color } from "Dora";
import type * as Dora from "Dora";
import { React } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { FocusRing } from "UIX/foundation/FocusRing";
import { Text } from "UIX/foundation/Text";
import { Row } from "UIX/layout/Row";
import { mergeStyle } from "UIX/layout/helpers";
import { PaintNode } from "UIX/paint/PaintNode";
import { withAlpha } from "UIX/paint/color";
import { useInteraction } from "UIX/input/Interaction";
import type { UiNodeProps } from "UIX/types";

export interface CheckboxProps extends UiNodeProps {
	checked: boolean;
	indeterminate?: boolean;
	label?: string;
	focused?: boolean;
	onChange?: (this: void, checked: boolean) => void;
}

function checkboxPainter(this: void, checked: boolean, indeterminate: boolean) {
	return (ctx: import("UIX/paint/PaintNode").PaintContext) => {
		const theme = ctx.theme;
		const state = ctx.state;
		const size = math.min(ctx.width, ctx.height);
		const x = (ctx.width - size) * 0.5;
		const y = (ctx.height - size) * 0.5;
		const radius = math.max(3, size * 0.18);
		const active = checked || indeterminate;
		const disabled = state.disabled;
		const fill = disabled
			? withAlpha(theme.colors.surface.sunken, theme.painter.disabledAlpha)
			: active ? withAlpha(theme.colors.accent.primary, state.pressed ? 0.72 : 0.58) : theme.colors.surface.sunken;
		const stroke = active ? theme.colors.accent.primary : theme.colors.line.normal;

		nvg.BeginPath();
		nvg.RoundedRect(x, y, size, size, radius);
		nvg.FillColor(Color(withAlpha(fill, ctx.opacity)));
		nvg.Fill();
		nvg.StrokeWidth(active ? theme.stroke.normal : theme.stroke.hairline);
		nvg.StrokeColor(Color(withAlpha(stroke, disabled ? 0.38 : ctx.opacity)));
		nvg.Stroke();

		if (indeterminate) {
			nvg.BeginPath();
			nvg.MoveTo(x + size * 0.28, y + size * 0.5);
			nvg.LineTo(x + size * 0.72, y + size * 0.5);
			nvg.StrokeWidth(3);
			nvg.StrokeColor(Color(withAlpha(disabled ? theme.colors.text.disabled : theme.colors.text.primary, ctx.opacity)));
			nvg.Stroke();
		} else if (checked) {
			nvg.BeginPath();
			nvg.MoveTo(x + size * 0.24, y + size * 0.48);
			nvg.LineTo(x + size * 0.43, y + size * 0.3);
			nvg.LineTo(x + size * 0.78, y + size * 0.7);
			nvg.StrokeWidth(3);
			nvg.StrokeColor(Color(withAlpha(disabled ? theme.colors.text.disabled : theme.colors.text.primary, ctx.opacity)));
			nvg.Stroke();
		}
	};
}

export function Checkbox(this: void, props: CheckboxProps): React.Element {
	const theme = getUiContext().theme;
	const disabled = props.disabled === true;
	const interaction = useInteraction({
		disabled,
		selected: props.checked || props.indeterminate === true,
	});
	if (props.focused === true && !interaction.state.focused) {
		interaction.setFocused(true);
	}
	const boxSize = 28;
	const control = (
		<align-node
			ref={props.ref as JSX.Ref<Dora.AlignNode.Type> | undefined}
			style={{ position: "relative", width: boxSize, height: boxSize }}
			touchEnabled={!disabled}
			swallowTouches
			onTapBegan={() => interaction.setPressed(true)}
			onTapEnded={() => interaction.setPressed(false)}
			onTapped={() => {
				if (!disabled) props.onChange?.(!props.checked);
			}}
			onUnmount={() => interaction.reset()}
		>
			<PaintNode
				key="checkbox-surface"
				state={interaction.state}
				painter={checkboxPainter(props.checked, props.indeterminate === true)}
			/>
			<FocusRing key="checkbox-focus-ring" active={interaction.state.focused} disabled={disabled} />
		</align-node>
	);
	return (
		<Row
			key={props.key}
			style={mergeStyle({ height: theme.size.control.sm, alignItems: "center", gap: theme.space.sm }, props.style)}
			visible={props.visible}
			opacity={props.opacity}
		>
			{control}
			{props.label !== undefined ?
				<Text text={props.label} fontSize={theme.font.size.sm} color={disabled ? theme.colors.text.disabled : theme.colors.text.primary} /> : undefined}
		</Row>
	);
}
