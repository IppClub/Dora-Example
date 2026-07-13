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

export function makeBody3D(
	world: PhysicsWorld3DType,
	node: Node3DType,
	fixture: FixtureDef3DType,
	type = 2
): Body3DType {
	const parent = node.parent;
	const position = node.position;
	const angles = node.angles;
	node.removeFromParent(false);
	node.position = Vec3(0, 0, 0);
	node.angles = Vec3(0, 0, 0);
	const def = BodyDef3D();
	def.type = type;
	if (!def.attach(fixture)) throw new Error("failed to attach FixtureDef3D");
	const body = Body3D(def, world, position, angles);
	body.addChild(node);
	parent?.addChild(body);
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
