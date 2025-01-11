local PluginContext = require("lua.crazywall.context")
local Config = require("core.config")
local Context = require("core.context")
local streams = require("core.streams")
local plugin_utils = require("lua.crazywall.utils")
local fold = require("core.fold")

---@param plugin_state PluginState
return function(plugin_state)
	vim.api.nvim_create_user_command("Crazywall", function(opts)
		local plugin_ctx, err = PluginContext:new(
			opts.fargs[1] or "both",
			opts.fargs[2] or "warn",
			opts.fargs[3] or vim.fn.expand("%"),
			opts.fargs[4] or vim.fn.expand("%")
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
			false,
			(
				plugin_ctx.output_style == "planonly"
				or plugin_ctx.output_style == "both"
			)
					and streams.STDOUT
				or streams.NONE,
			(
				plugin_ctx.output_style == "textonly"
				or plugin_ctx.output_style == "both"
			)
					and streams.STDOUT
				or streams.NONE,
			false,
			false
		)

		if not ctx then
			return plugin_utils.display_err(err)
		end

		local plan, root
		plan, root, err = plugin_utils.do_fold(buf_id, ctx, true)
		if not plan or not root then
			return plugin_utils.display_err(err)
		end

		local lines =
			plugin_utils.get_plan_and_text_lines(ctx, plugin_ctx, plan)

		local float_buf_id
		float_buf_id, err = plugin_utils.display_floating_window(lines)
		if not float_buf_id then
			return nil, err
		end
		vim.cmd("setlocal nowrap")
		print(":w -> CONFIRM     :q -> EXIT")

		vim.api.nvim_create_autocmd("BufWritePost", {
			buffer = float_buf_id,
			callback = function()
				if not vim.api.nvim_buf_is_valid(float_buf_id) then
					return
				end
				vim.api.nvim_buf_call(float_buf_id, function()
					vim.cmd("write!")
				end)
				_, err = fold.execute(root, ctx)
				if err then
					return plugin_utils.display_err(err)
				end
				local plan_path = plugin_utils.get_log_path()
				err = fold.write(plan_path, tostring(plan))
				if err then
					return plugin_utils.display_err(err)
				end
				vim.cmd("bwipeout! " .. float_buf_id)
				if buf_id then
					vim.api.nvim_buf_call(buf_id, function()
						vim.cmd("edit")
					end)
				end
			end,
		})
	end, {
		nargs = "*",
		complete = function(_, line)
			local args = vim.split(line, " ")
			if #args == 2 then
				return PluginContext["output_options"]
			end
			if #args == 3 then
				return PluginContext["on_unsaved_options"]
			end
			if #args == 4 then
				return { vim.fn.expand("%") }
			end
			if #args == 5 then
				return { vim.fn.expand("%") }
			end
			return {}
		end,
		desc = "Applies crazywall to a file.",
	})
end
