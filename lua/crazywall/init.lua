local plugin_validate = require("crazywall.validate")
local default_config = require("core.defaults.config")
local PluginState = require("lua.crazywall.state")
local Config = require("core.config")
local cmd_crazywall = require("lua.crazywall.commands.crazywall")
local cmd_crazywall_dry = require("lua.crazywall.commands.crazywall_dry")
local cmd_crazywall_quick = require("lua.crazywall.commands.crazywall_quick")
local cmd_crazywall_follow_ref =
	require("lua.crazywall.commands.crazywall_follow_ref")
local M = {}

local plugin_state = PluginState:new()
cmd_crazywall(plugin_state)
cmd_crazywall_dry(plugin_state)
cmd_crazywall_quick(plugin_state)
cmd_crazywall_follow_ref(plugin_state)

M.setup = function(opts)
	opts = opts or {}
	local keys = { "configs", "default_config_name", "follow_ref" }
	for key in pairs(opts) do
		local err = plugin_validate.string_in_list(key, keys)
		if err then
			error(err)
		end
	end
	if opts.configs then
		for name, config_table in pairs(opts.configs) do
			local config, err = Config:new(config_table)
			if not config then
				error(
					"Error occurred when trying to build config "
						.. name
						.. ": \n"
						.. err
				)
			end
		end
	end
	plugin_state.configs = opts.configs or plugin_state.configs
	plugin_state.configs["DEFAULT"] = plugin_state.configs.DEFAULT
		or default_config
	plugin_state.current_config_name = opts.default_config_name
		or plugin_state.current_config_name
	plugin_state.follow_ref = opts.follow_ref or plugin_state.follow_ref
end

return M
