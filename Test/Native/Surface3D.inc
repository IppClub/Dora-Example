using namespace Dora;

// This runs inside the initialized engine through Application.runTest(). It
// exercises the adaptive decision on the same subtree while it changes at
// runtime, including the ClipNode and grabber paths that must be isolated.
DORA_TEST_ENTRY(Surface3DCpp) {
	auto content = Node::create();
	content->setSize({64.0f, 64.0f});
	auto draw = DrawNode::create();
	draw->drawDot({32.0f, 32.0f}, 16.0f, Color(0xffffffff));
	content->addChild(draw);
	auto surface = Surface3D::create(content, {2.0f, 2.0f}, {64.0f, 64.0f});
	auto camera = Camera3D::create("Surface3DTest"sv);
	if (!surface || !camera) return false;

	surface->render(*camera);
	if (surface->isUsingTexture()) return false;
	// A non-origin Surface3D must reach the same clip coordinates as the Rust
	// View3D path, including its clip-space X flip.
	surface->setPosition(1.0f, 2.0f, 3.0f);
	const Matrix& viewProj = SharedDirector.getViewProjection();
	Matrix flipX = Matrix::Indentity;
	flipX.m[0] = -1.0f;
	Matrix flippedViewProj;
	Matrix::mulMtx(flippedViewProj, flipX, viewProj);
	Matrix expected;
	Matrix::mulMtx(expected, flippedViewProj, surface->getWorldMatrix());
	Matrix actual;
	Matrix alignedWorld = alignSurfaceWorldWithView3D(surface->getWorldMatrix(), viewProj);
	Matrix::mulMtx(actual, viewProj, alignedWorld);
	Vec4 expectedClip;
	Vec4 actualClip;
	Matrix::mulVec4(expectedClip, expected, {0.0f, 0.0f, 0.0f, 1.0f});
	Matrix::mulVec4(actualClip, actual, {0.0f, 0.0f, 0.0f, 1.0f});
	if (std::abs(expectedClip.w) <= FLT_EPSILON || std::abs(actualClip.w) <= FLT_EPSILON) return false;
	if (std::abs(expectedClip.x / expectedClip.w - actualClip.x / actualClip.w) > 0.0001f) return false;
	if (std::abs(expectedClip.y / expectedClip.w - actualClip.y / actualClip.w) > 0.0001f) return false;
	if (std::abs(expectedClip.z / expectedClip.w - actualClip.z / actualClip.w) > 0.0001f) return false;

	auto stencil = DrawNode::create();
	stencil->drawDot({32.0f, 32.0f}, 16.0f, Color(0xffffffff));
	auto clip = ClipNode::create(stencil);
	content->addChild(clip);
	surface->render(*camera);
	if (!surface->isUsingTexture()) return false;

	content->removeChild(clip, true);
	surface->render(*camera);
	if (surface->isUsingTexture()) return false;

	content->grab(true);
	surface->render(*camera);
	if (!surface->isUsingTexture()) return false;

	// Both billboard paths must remain valid with a dynamically selected
	// render target and a non-origin transform.
	surface->setBillboard(Billboard::Screen);
	surface->render(*camera);
	surface->setBillboard(Billboard::YAxis);
	surface->render(*camera);
	return true;
}
