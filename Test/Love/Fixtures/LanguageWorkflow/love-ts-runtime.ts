import "love";

const runtimeLabel = ["LOVE", "TS", "RUNTIME"].map(part => part.toLowerCase()).join("_");

love.load = () => {
	assert(runtimeLabel === "love_ts_runtime");
	print("LOVE_TS_RUNTIME_LOAD_PASS");
};

love.update = () => {
	love.event.quit(0);
};

love.quit = () => {
	print("LOVE_TS_RUNTIME_QUIT_PASS");
	return false;
};
