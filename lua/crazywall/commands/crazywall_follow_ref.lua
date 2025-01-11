local Config = require("core.config")
local plugin_utils = require("lua.crazywall.utils")

---@param plugin_state PluginState
return function(plugin_state)
	vim.api.nvim_create_user_command("CrazywallFollowRef", function()
		local line = vim.api.nvim_get_current_line()
		local column = vim.api.nvim_win_get_cursor(0)[2]

		if not plugin_state:get_current_config() then
			return vim.api.nvim_err_writeln(
				"crazywall: Could not find config "
					.. plugin_state.current_config_name
					.. "."
			)
		end

		local config, err =
			Config:new(assert(plugin_state:get_current_config()))
		if not config then
			return plugin_utils.display_err(err)
		end

		plugin_state.follow_ref(
			line,
			column,
			config,
			plugin_state.current_config_name
		)
	end, { nargs = 0 })
end
