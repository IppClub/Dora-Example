import type * as Dora from "Dora";
import { Color } from "Dora";
import { React } from "DoraX";
import * as nvg from "nvg";
import { getUiContext } from "UIX/context";
import { Button } from "UIX/controls/Button";
import { Icon } from "UIX/foundation/Icon";
import { Text } from "UIX/foundation/Text";
import { Row } from "UIX/layout/Row";
import { mergeStyle } from "UIX/layout/helpers";
import { PaintNode } from "UIX/paint/PaintNode";
import { withAlpha } from "UIX/paint/color";
import { clamp } from "UIX/types";
import type { UiIcon, UiNodeProps } from "UIX/types";

export interface StepperProps extends UiNodeProps {
	value: number;
	min?: number;
	max?: number;
	step?: number;
	valueWidth?: number;
	prefixIcon?: UiIcon;
	suffixLabel?: string;
	formatValue?: (this: void, value: number) => string;
	decreaseRef?: { readonly current?: Dora.Node.Type };
	increaseRef?: { readonly current?: Dora.Node.Type };
	onValueChange?: (this: void, value: number) => void;
}

function normalizeValue(this: void, value: number, min: number, max: number, step: number): number {
	const snapped = step > 0 ? min + math.floor((value - min) / step + 0.5) * step : value;
	return clamp(snapped, min, max);
}

function stepperValueSurface(this: void) {
	return (ctx: import("UIX/paint/PaintNode").PaintContext) => {
		const theme = ctx.theme;
		nvg.BeginPath();
		nvg.RoundedRect(0, 0, ctx.width, ctx.height, theme.radius.sm);
		nvg.FillColor(Color(withAlpha(theme.colors.surface.sunken, ctx.state.disabled ? theme.painter.disabledAlpha : ctx.opacity)));
		nvg.Fill();
		nvg.StrokeWidth(theme.stroke.hairline);
		nvg.StrokeColor(Color(withAlpha(theme.colors.line.subtle, ctx.state.disabled ? 0.38 : ctx.opacity)));
		nvg.Stroke();
	};
}

export function Stepper(this: void, props: StepperProps): React.Element {
	const theme = getUiContext().theme;
	const min = props.min ?? 0;
	const max = props.max ?? 999;
	const step = props.step ?? 1;
	const disabled = props.disabled === true;
	const value = normalizeValue(props.value, min, max, step);
	const canDecrease = !disabled && value > min;
	const canIncrease = !disabled && value < max;
	const display = props.formatValue?.(value) ?? tostring(value);
	const valueWidth = props.valueWidth ?? 76;
	const height = theme.size.control.md;
	const emit = (next: number) => {
		if (disabled) return;
		const normalized = normalizeValue(next, min, max, step);
		if (normalized !== value) props.onValueChange?.(normalized);
	};
	const textColor = disabled ? theme.colors.text.disabled : theme.colors.text.primary;
	return (
		<Row
			key={props.key}
			ref={props.ref as JSX.Ref<Dora.AlignNode.Type> | undefined}
			style={mergeStyle({
				height,
				alignItems: "center",
				gap: 6,
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
		>
			<Button
				key="stepper-dec"
				ref={props.decreaseRef as JSX.Ref<Dora.AlignNode.Type> | undefined}
				variant="ghost"
				icon="minus"
				disabled={!canDecrease}
				style={{ width: height, height }}
				onClick={() => emit(value - step)}
			/>
			<align-node
				key="stepper-value"
				style={{
					position: "relative",
					width: valueWidth,
					height,
				}}
			>
				<PaintNode key="stepper-value-bg" state={{ disabled }} painter={stepperValueSurface()} />
				<Row
					key="stepper-value-content"
					style={{
						width: "100%",
						height: "100%",
						padding: [0, theme.space.sm],
						alignItems: "center",
						justifyContent: "center",
						gap: theme.space.xs,
					}}
				>
					{props.prefixIcon !== undefined ?
						<Icon key="stepper-prefix" icon={props.prefixIcon} size={theme.size.icon.sm} color={textColor} disabled={disabled} /> : undefined}
					<Text key="stepper-text" text={display} fontSize={theme.font.size.md} color={textColor} />
					{props.suffixLabel !== undefined ?
						<Text key="stepper-suffix" text={props.suffixLabel} fontSize={theme.font.size.xs} color={disabled ? theme.colors.text.disabled : theme.colors.text.secondary} /> : undefined}
				</Row>
			</align-node>
			<Button
				key="stepper-inc"
				ref={props.increaseRef as JSX.Ref<Dora.AlignNode.Type> | undefined}
				variant="secondary"
				icon="plus"
				disabled={!canIncrease}
				style={{ width: height, height }}
				onClick={() => emit(value + step)}
			/>
		</Row>
	);
}
