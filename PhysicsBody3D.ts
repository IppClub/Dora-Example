import {
	Body3D,
	Body3DType,
	BodyDef3D,
	FixtureDef3D,
	FixtureDef3DType,
	Node3DType,
	PhysicsWorld3DType,
	Vec3,
} from "Dora";

function tryMakeBody3D(
	world: PhysicsWorld3DType,
	node: Node3DType,
	fixture: FixtureDef3DType,
	type = 2
): Body3DType | undefined {
	const parent = node.parent;
	const position = node.position;
	const angles = node.angles;
	node.removeFromParent(false);
	node.position = Vec3(0, 0, 0);
	node.angles = Vec3(0, 0, 0);
	const def = BodyDef3D();
	def.type = type;
	if (!def.attach(fixture)) {
		node.position = position;
		node.angles = angles;
		parent?.addChild(node);
		return undefined;
	}
	const body = Body3D(def, world, position, angles) as Body3DType | undefined;
	if (!body) {
		node.position = position;
		node.angles = angles;
		parent?.addChild(node);
		return undefined;
	}
	body.addChild(node);
	parent?.addChild(body);
	return body;
}

export function makeBody3D(
	world: PhysicsWorld3DType,
	node: Node3DType,
	fixture: FixtureDef3DType,
	type = 2
): Body3DType {
	const body = tryMakeBody3D(world, node, fixture, type);
	if (!body) throw new Error("failed to create Body3D");
	return body;
}

export function makeBoxBody3D(world: PhysicsWorld3DType, node: Node3DType, halfExtent: Vec3.Type, type = 2) {
	return makeBody3D(world, node, FixtureDef3D.box(halfExtent), type);
}

export function makeSphereBody3D(world: PhysicsWorld3DType, node: Node3DType, radius: number, type = 2) {
	return makeBody3D(world, node, FixtureDef3D.sphere(radius), type);
}

export function makeCapsuleBody3D(
	world: PhysicsWorld3DType,
	node: Node3DType,
	halfHeight: number,
	radius: number,
	type = 2
) {
	return makeBody3D(world, node, FixtureDef3D.capsule(halfHeight, radius), type);
}
