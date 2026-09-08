// Native regression: run inside a matching Dora engine, not via Node::emit.
// On macOS compile as a bundle with Dora's include paths and
// -std=c++20 -bundle -undefined dynamic_lookup; load using package.loadlib.
#include "Const/Header.h"
#include "Node/Node.h"
#include "Input/TouchDispather.h"
#include "SDL.h"
#include "lua.h"
#include <stdexcept>

using namespace Dora;

namespace {
struct TestNode : Node {
	bool& destroyed;
	explicit TestNode(bool& flag) : Node(false), destroyed(flag) { }
	~TestNode() override { destroyed = true; }
};

void check(bool value, const char* message) {
	if (!value) throw std::runtime_error(message);
}

void runCase(const char* action, uint32_t eventType) {
	bool destroyed = false;
	Ref<TestNode> owner(new TestNode(destroyed));
	check(owner->init(), "node init");
	owner->setTouchEnabled(true);
	owner->onEnter();
	auto handler = std::make_shared<NodeTouchHandler>(owner.get());
	int began = 0, ended = 0, tapped = 0, moved = 0;
	auto invalidate = [&] {
		if (std::string_view(action) == "destroy") {
			owner->onExit();
			owner->cleanup();
			owner = nullptr;
			check(!destroyed, "target destroyed inside active touch callback");
		} else if (std::string_view(action) == "disable") {
			owner->setTouchEnabled(false);
		} else if (std::string_view(action) == "detach") {
			owner->onExit();
		}
	};
	owner->slot("TapFilter"_slice, [&](Event*) { if (eventType == SDL_FINGERDOWN) invalidate(); });
	owner->slot("TapBegan"_slice, [&](Event*) { ++began; });
	owner->slot("TapMoved"_slice, [&](Event*) { ++moved; if (eventType == SDL_FINGERMOTION) invalidate(); });
	owner->slot("TapEnded"_slice, [&](Event*) { ++ended; if (eventType == SDL_FINGERUP) invalidate(); });
	owner->slot("Tapped"_slice, [&](Event*) { ++tapped; });
	SDL_Event event{};
	event.type = SDL_FINGERDOWN;
	event.tfinger.fingerId = 123;
	event.tfinger.x = event.tfinger.y = 0.5f;
	auto dispatch = [&] {
		if (Touch::getSource() & Touch::FromTouch) return handler->handle(event);
		SDL_Event mouse{};
		mouse.type = event.type == SDL_FINGERDOWN ? SDL_MOUSEBUTTONDOWN
			: event.type == SDL_FINGERUP ? SDL_MOUSEBUTTONUP : SDL_MOUSEMOTION;
		mouse.button.button = SDL_BUTTON_LEFT;
		mouse.button.x = mouse.button.y = 100;
		return handler->handle(mouse);
	};
	dispatch();
	if (eventType == SDL_FINGERMOTION) {
		event.type = SDL_FINGERMOTION;
		event.tfinger.x = 0.8f;
		dispatch();
	}
	event.type = SDL_FINGERUP;
	dispatch();
	if (std::string_view(action) == "normal") {
		check(began == 1 && ended == 1 && tapped == 1, "normal tap order/count");
	} else {
		check(tapped == 0, "invalidated node received Tapped");
		check(began == (eventType == SDL_FINGERDOWN ? 0 : 1), "TapBegan after invalidation");
		check(ended == (eventType == SDL_FINGERUP ? 1 : 0), "TapEnded after invalidation");
		check(moved == (eventType == SDL_FINGERMOTION ? 1 : 0), "TapMoved count");
		// Dispatcher may retain the handler while processing more queued SDL events.
		event.type = SDL_FINGERDOWN;
		check(!dispatch(), "stale handler consumed new touch");
		if (std::string_view(action) == "destroy") check(destroyed, "target retained between events");
	}
	if (owner) { owner->onExit(); owner->cleanup(); }
}
}

extern "C" int luaopen_TouchLifetimeTest(lua_State* L) {
	try {
		for (int repeat = 0; repeat < 100; ++repeat) {
			runCase("normal", SDL_FINGERUP);
			for (auto action : {"destroy", "disable", "detach"}) {
				for (auto type : {SDL_FINGERDOWN, SDL_FINGERMOTION, SDL_FINGERUP}) runCase(action, type);
			}
		}
		lua_pushstring(L, "PASS: 1000 native SDL touch lifetime cases");
	} catch (const std::exception& e) {
		lua_pushstring(L, e.what());
	}
	return 1;
}
