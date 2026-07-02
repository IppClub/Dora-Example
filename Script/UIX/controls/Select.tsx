import { TextAlign } from "Dora";
import { React, useSignal } from "DoraX";
import { Button } from "UIX/controls/Button";
import { Icon } from "UIX/foundation/Icon";
import { Text } from "UIX/foundation/Text";
import { Column } from "UIX/layout/Column";
import { Row } from "UIX/layout/Row";
import { mergeStyle } from "UIX/layout/helpers";
import type { UiIcon, UiNodeProps, UiSize, UiVariant } from "UIX/types";
import { getUiContext } from "UIX/context";
import { PaintNode } from "UIX/paint/PaintNode";
import { roundedPanel } from "UIX/paint/primitives";

export interface SelectItem {
	id: string;
	label: string;
	icon?: UiIcon;
	disabled?: boolean;
}

export interface SelectProps extends UiNodeProps {
	items: SelectItem[];
	value: string;
	size?: UiSize;
	variant?: UiVariant;
	placeholder?: string;
	open?: boolean;
	dropdownMaxHeight?: number;
	onOpenChange?: (this: void, open: boolean) => void;
	onValueChange?: (this: void, value: string) => void;
}

function findSelectedItem(this: void, items: SelectItem[], value: string): SelectItem | undefined {
	for (const item of items) {
		if (item.id === value) return item;
	}
	return undefined;
}

export function Select(this: void, props: SelectProps): React.Element {
	const theme = getUiContext().theme;
	const localOpen = useSignal(false);
	const open = props.open ?? localOpen.value;
	const selected = findSelectedItem(props.items, props.value);
	const size = props.size ?? "md";
	const controlHeight = theme.size.control[size];
	const itemHeight = theme.size.control.sm;
	const menuHeight = math.min(props.dropdownMaxHeight ?? 168, props.items.length * (itemHeight + theme.space.xs) + theme.space.xs);
	const setOpen = (value: boolean) => {
		if (props.open === undefined) localOpen.value = value;
		props.onOpenChange?.(value);
	};
	const selectItem = (item: SelectItem) => {
		if (item.disabled === true || props.disabled === true) return;
		props.onValueChange?.(item.id);
		setOpen(false);
	};
	return (
		<Column
			key={props.key}
			ref={props.ref}
			gap={theme.space.xs}
			style={mergeStyle({
				position: "relative",
				width: 180,
			}, props.style)}
			visible={props.visible}
			opacity={props.opacity}
		>
			<Button
				key="select-trigger"
				size={size}
				variant={props.variant ?? "ghost"}
				disabled={props.disabled}
				style={{ width: "100%" }}
				onClick={() => setOpen(!open)}
			>
				<Row style={{
					width: "100%",
					height: "100%",
					padding: [0, theme.space.md],
					alignItems: "center",
					justifyContent: "space-between",
					gap: theme.space.sm,
				}}>
					{selected?.icon !== undefined ?
						<Icon icon={selected.icon} size={theme.size.icon[size]} disabled={props.disabled} /> : undefined}
					<Text
						text={selected?.label ?? props.placeholder ?? "Select"}
						fontSize={theme.font.size.md}
						color={props.disabled === true ? theme.colors.text.disabled : theme.colors.text.primary}
						alignment={TextAlign.Left}
						style={{ flex: 1, height: controlHeight }}
					/>
					<Icon icon={open ? "chevronUp" : "chevronDown"} size={theme.size.icon.sm} disabled={props.disabled} />
				</Row>
			</Button>
			{open ?
				<Column
					key="select-menu"
					gap={theme.space.xs}
					style={{
						position: "relative",
						width: "100%",
						height: menuHeight,
						padding: theme.space.xs,
					}}
				>
					<PaintNode
						key="select-menu-surface"
						painter={(ctx) => roundedPanel(ctx, { x: 0, y: 0, width: ctx.width, height: ctx.height }, {
							variant: "solid",
							elevated: true,
						})}
					/>
					{props.items.map((item) => (
						<Button
							key={`select-item-${item.id}`}
							size="sm"
							variant={item.id === props.value ? "primary" : "ghost"}
							selected={item.id === props.value}
							disabled={props.disabled === true || item.disabled === true}
							icon={item.icon}
							style={{ width: "100%", height: itemHeight }}
							onClick={() => selectItem(item)}
						>
							{item.label}
						</Button>
					))}
				</Column> : undefined}
		</Column>
	);
}
