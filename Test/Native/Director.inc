using namespace Dora;

DORA_TEST_ENTRY(SystemUICpp) {
	Ref<Node> systemUI{SharedDirector.getSystemUI()};
	Ref<Node> marker{Node::create()};
	marker->setTag("SystemUITest"_slice);
	systemUI->addChild(marker);

	Ref<Node> regularUI{SharedDirector.getUI()};
	regularUI->addChild(Node::create());
	SharedDirector.cleanup();

	if (SharedDirector.getSystemUI() != systemUI) return false;
	if (systemUI->getChildByTag("SystemUITest"_slice) != marker) return false;
	if (SharedDirector.getUI() == regularUI) return false;

	auto safeArea = SharedApplication.getSafeArea();
	auto visualSize = SharedApplication.getVisualSize();
	if (safeArea.getLeft() < 0.0f || safeArea.getBottom() < 0.0f) return false;
	if (safeArea.getRight() > visualSize.width || safeArea.getTop() > visualSize.height) return false;

	systemUI->removeChild(marker, true);
	return true;
}

DORA_TEST_ENTRY(GameCaptureChildrenVisibleCpp) {
	Ref<Node> root{SharedDirector.getSystemUI()};
	Ref<Node> tool{Node::create()};
	root->addChild(tool);
	if (!SharedDirector.beginGameCapture()) {
		tool->removeFromParent();
		return false;
	}
	Ref<Node> game{Node::create()};
	root->addChild(game);
	struct Counts { int game = 0; int tool = 0; };
	auto counts = std::make_shared<Counts>();
	game->onRender([counts](double) { ++counts->game; return false; });
	tool->onRender([counts](double) { ++counts->tool; return false; });
	const bool visible = root->isVisible();
	const bool childrenVisible = root->isChildrenVisible();
	root->setVisible(true);
	root->setChildrenVisible(false);
	const std::string base = SharedContent.getWritablePath() + "/game-capture-children-visible";
	auto finish = [root, tool, game, visible, childrenVisible, base](bool success) {
		SharedDirector.endGameCapture();
		success = success && game->getParent() == nullptr && tool->getParent() == root;
		tool->removeFromParent();
		root->setVisible(visible);
		root->setChildrenVisible(childrenVisible);
		SharedContent.save(base + ".json", success
			? "{\"success\":true,\"hiddenChildrenNotRendered\":true,\"restoredChildrenRendered\":true,\"gameCleanedToolPreserved\":true}"
			: "{\"success\":false}");
	};
	bool accepted = SharedDirector.captureGameAsync(base + "-hidden.png",
		[root, counts, base, finish](bool saved, double, Size) {
			const bool hidden = saved && counts->game == 0 && counts->tool == 0;
			root->setChildrenVisible(true);
			bool next = SharedDirector.captureGameAsync(base + "-restored.png",
				[counts, hidden, finish](bool restored, double, Size) {
					finish(hidden && restored && counts->game > 0 && counts->tool > 0);
				});
			if (!next) finish(false);
		});
	if (!accepted) finish(false);
	// This is an asynchronous render test; inspect the JSON after both readbacks.
	return accepted;
}
