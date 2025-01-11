local PluginContext = require("crazywall.context")
local plugin_utils = require("lua.crazywall.utils")
local Config = require("core.config")
local Context = require("core.context")
local streams = require("core.streams")

---@param plugin_state PluginState
return function(plugin_state)
	vim.api.nvim_create_user_command("CrazywallQuick", function(opts)
		local plugin_ctx, err = PluginContext:new(
			"both",
			opts.fargs[1] or "warn",
			opts.fargs[2] or vim.fn.expand("%"),
			opts.fargs[3] or vim.fn.expand("%")
		)

		if not plugin_ctx then
			vim.api.nvim_err_writeln(assert(err))
			return
		end

		local buf_id = plugin_utils.find_buffer(plugin_ctx.src_path_str)
		if
			not plugin_utils.handle_unsaved(
				buf_id,
				plugin_ctx.on_unsaved == "write"
			)
		then
			return
		end

		if plugin_state:get_current_config() == nil then
			return vim.api.nvim_err_writeln(
				"crazywall: Could not find config "
					.. plugin_state:get_current_config()
					.. "."
			)
		end

		local config
		config, err = Config:new(assert(plugin_state:get_current_config()))
		if not config then
			return plugin_utils.display_err(err)
		end

		local ctx
		ctx, err = Context:new(
			config,
			plugin_ctx.src_path_str,
			plugin_ctx.dest_path_str,
			vim.fn.readfile(plugin_ctx.src_path_str),
			nil,
			false,
			true,
			streams.NONE,
			streams.NONE,
			false,
			false
		)

		if not ctx then
			return plugin_utils.display_err(err)
		end

		local plan
		plan, _, err = plugin_utils.do_fold(buf_id, ctx, false)
		if not plan then
			return plugin_utils.display_err(err)
		end

		local plan_path = plugin_utils.get_log_path()
		err = plugin_utils.write(plan_path, tostring(plan))
		if err then
			return plugin_utils.display_err(err)
		end
	end, {
		nargs = "*",
		complete = function(_, line)
			local args = vim.split(line, " ")
			if #args == 2 then
				return PluginContext["on_unsaved_options"]
			end
			if #args == 3 then
				return { vim.fn.expand("%") }
			end
			if #args == 4 then
				return { vim.fn.expand("%") }
			end
			return {}
		end,
		desc = "Applies crazywall to a file, skipping the confirmation window.",
	})
end
