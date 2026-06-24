import { Content, Director, Log, Node as DNode, Path } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, useRef } from "DoraX";

const resultFile = Path(Content.writablePath, "DoraXResourceNodesTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	error(`[DoraXResourceNodesTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.entry.addChild(host);

const root = createRoot(host);
const spriteRef = useRef<Dora.Sprite.Type>();
const gridRef = useRef<Dora.Grid.Type>();
const tileRef = useRef<Dora.TileNode.Type>();
const modelRef = useRef<Dora.Model.Type>();
const audioRef = useRef<Dora.AudioSource.Type>();

root.render(
	<node>
		<sprite key="sprite" ref={spriteRef} file="Image/logo.png" width={80} height={80} />
		<grid key="grid" ref={gridRef} file="Image/logo.png" gridX={2} gridY={2} />
		<tile-node key="tile" ref={tileRef} file="TMX/demo.tmx" />
		<model key="model" ref={modelRef} file="Model/KidW.model" />
		<audio-source key="audio" ref={audioRef} file="Audio/di.wav" autoRemove={false} volume={0.2} />
	</node>
);

const sprite = spriteRef.current;
const grid = gridRef.current;
const tile = tileRef.current;
const model = modelRef.current;
const audio = audioRef.current;
expect(sprite !== undefined, "sprite resource node was not mounted");
expect(grid !== undefined, "grid resource node was not mounted");
expect(tile !== undefined, "tile-node resource node was not mounted");
expect(model !== undefined, "model resource node was not mounted");
expect(audio !== undefined, "audio-source resource node was not mounted");

root.render(
	<node>
		<sprite key="sprite" ref={spriteRef} file="Image/icon.png" width={64} height={64} />
		<grid key="grid" ref={gridRef} file="Image/icon.png" gridX={3} gridY={3} />
		<tile-node key="tile" ref={tileRef} file="TMX/platform.tmx" />
		<model key="model" ref={modelRef} file="Model/KidM.model" />
		<audio-source key="audio" ref={audioRef} file="Audio/select.wav" autoRemove={false} volume={0.3} />
	</node>
);

expect(spriteRef.current !== sprite, "sprite should recreate when file changes");
expect(gridRef.current !== grid, "grid should recreate when file or grid size changes");
expect(tileRef.current !== tile, "tile-node should recreate when file changes");
expect(modelRef.current !== model, "model should recreate when file changes");
expect(audioRef.current !== audio, "audio-source should recreate when file changes");

root.unmount();
expect(!host.hasChildren, "resource nodes unmount did not clear host");
host.removeFromParent(true);
Content.save(resultFile, "passed");
Log("Info", "[DoraXResourceNodesTest] passed");
