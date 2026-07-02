import { React } from "DoraX";

export interface SpacerProps {
	flex?: number;
	width?: number;
	height?: number;
}

export function Spacer(this: void, props: SpacerProps): React.Element {
	const flex = props.flex ?? (props.width === undefined && props.height === undefined ? 1 : 0);
	return <align-node style={{ flex, width: props.width, height: props.height }} />;
}
