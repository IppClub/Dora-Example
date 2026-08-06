function love.conf(config)
	assert(config.version == "11.5")
	assert(type(config.window) == "table")
end
