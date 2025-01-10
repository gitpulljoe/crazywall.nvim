local Config = require("core.config")
local Context = require("core.context")
local streams = require("core.streams")
local fold = require("core.fold")
local utils = require("core.utils")
local validate = require("crazywall.validate")
local default_config = require("core.defaults.config")
local M = {}

local configs = {}
local current_config_name = "DEFAULT"

local output_options = { "both", "planonly", "textonly" }
local on_unsaved_options = { "warn", "write" }

---@type number?
local err_buf = nil

---@param path string?
---@return number?
local find_buffer = function(path)
	for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
		local bufname = vim.api.nvim_buf_get_name(buf_id)
		if bufname == path then
			return buf_id
		end
	end
	return nil
end

---@param path string
---@param text string
---@return string? errmsg
local write = function(path, text)
	local dir = vim.fn.fnamemodify(path, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	local file = io.open(path, "w")
	if file then
		local _, err = file:write(text)
		file:close()
		if err then
			return err
		end
		return
	end
	return "Unable to write to " .. path
end

---@return string
local get_plan_path = function()
	return string.format(
		"%s/crazywall/plan-%s.txt",
		vim.fn.stdpath("data"),
		os.time()
	)
end

---@param lines string[]
---@return number? buf_id
---@return string? errmsg
local display_floating_window = function(lines)
	local plan_path_prefix =
		string.format("%s/crazywall/plan-", vim.fn.stdpath("data"))
	for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
		local buf_name = vim.api.nvim_buf_get_name(buf_id)
		if utils.str.starts_with(buf_name, plan_path_prefix) then
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end
	end
	local buf_id = vim.api.nvim_create_buf(false, true)
	if not buf_id then
		return nil, "Failed to create buffer"
	end
	vim.api.nvim_buf_set_name(buf_id, get_plan_path())
	vim.api.nvim_buf_set_option(buf_id, "buftype", "")
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
	local editor_height = vim.api.nvim_get_option("lines")
	local editor_width = vim.api.nvim_get_option("columns")
	local win_height = math.min(math.floor(editor_height * 0.75), #lines)
	win_height = math.max(win_height, 1)
	local longest_line_length = (function()
		local res = 0
		for _, line in ipairs(lines) do
			res = math.max(res, #line)
		end
		return res
	end)()
	local win_width =
		math.min(math.floor(editor_width * 0.75), longest_line_length)
	win_width = math.max(win_width, 1)
	local row = math.floor((editor_height - win_height) / 2)
	local col = math.floor((editor_width - win_width) / 2)
	local win = vim.api.nvim_open_win(buf_id, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		border = "rounded",
		style = "minimal",
	})
	if not win then
		return nil, "Failed to open floating window."
	end
	vim.api.nvim_buf_set_option(buf_id, "modifiable", false)
	vim.api.nvim_buf_set_option(buf_id, "modified", false)

	vim.api.nvim_create_augroup(
		"CrazywallCloseBufferOnWindowClose",
		{ clear = true }
	)

	vim.api.nvim_create_autocmd("WinLeave", {
		group = "CrazywallCloseBufferOnWindowClose",
		pattern = "*",
		callback = function()
			if vim.fn.bufnr("%") == buf_id then
				vim.cmd('b#|bwipeout! ' .. buf_id)
			end
		end,
	})

	return buf_id
end

---@param err_text string?
local display_err = function(err_text)
	local err = err_text and utils.str.split_lines_to_list(err_text or "") or {}
	if err_buf and vim.api.nvim_buf_is_valid(err_buf) then
		vim.cmd("bdelete " .. err_buf)
	end
	local total_height = vim.api.nvim_get_option("lines") -- Total height of the Neovim window
	local split_height = math.floor(total_height / 3)
	split_height = math.min(#err, split_height)
	split_height = math.max(split_height, 3)
	vim.cmd("botright new")
	local win_id = vim.api.nvim_get_current_win()
	err_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_win_set_height(win_id, split_height)
	vim.api.nvim_buf_set_option(err_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_lines(err_buf, 0, -1, false, err)
	vim.api.nvim_buf_set_option(err_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(err_buf, "modifiable", false)
end

---@param buf_id integer?
---@param ctx Context
---@return Plan? plan
---@return string? errmsg
local do_fold = function(buf_id, ctx)
	local root, err = fold.parse(ctx)
	if not root then
		return nil, err
	end

	_, err = fold.prepare(root, ctx)
	if err then
		return nil, err
	end

	local plan
	plan, err = fold.execute(root, ctx, true)
	if not plan then
		return nil, err
	end

	if ctx.is_dry_run then
		return plan
	end

	plan, err = fold.execute(root, ctx, false)
	if err then
		error(err)
	end

	if buf_id then
		vim.api.nvim_buf_call(buf_id, function()
			vim.cmd("edit")
		end)
	end

	return plan
end

---@param buf_id integer?
---@param write_on_unsaved boolean
---@return boolean
local handle_unsaved = function(buf_id, write_on_unsaved)
	if not buf_id then
		return true
	end
	if not vim.api.nvim_buf_get_option(buf_id, "modified") then
		return true
	end
	if write_on_unsaved then
		vim.api.nvim_buf_call(buf_id, function()
			vim.cmd("write")
		end)
		return true
	end
	vim.api.nvim_err_writeln("crazywall: Buffer has unsaved changes.")
	return false
end

vim.api.nvim_create_user_command("CrazywallQuick", function(opts)
	local on_unsaved = opts.fargs[1] or "warn"
	local err = validate.string_in_list(on_unsaved, on_unsaved_options)
	if err then
		vim.api.nvim_err_writeln(err)
		return
	end

	local src_path = opts.fargs[2] or vim.fn.expand("%")
	local dest_path = opts.fargs[3] or vim.fn.expand("%")

	local buf_id = find_buffer(src_path)
	if not handle_unsaved(buf_id, on_unsaved == "write") then
		return
	end

	if configs[current_config_name] == nil then
		return vim.api.nvim_err_writeln(
			"crazywall: Could not find config " .. current_config_name .. "."
		)
	end

	local config
	config, err = Config:new(configs[current_config_name])
	if not config then
		return display_err(err)
	end

	local ctx
	ctx, err = Context:new(
		config,
		src_path,
		dest_path,
		vim.fn.readfile(src_path),
		nil,
		false,
		true,
		streams.NONE,
		streams.NONE,
		false,
		false
	)

	if not ctx then
		return display_err(err)
	end

	local plan
	plan, err = do_fold(buf_id, ctx)
	if not plan then
		return display_err(err)
	end

	local plan_path = get_plan_path()
	err = write(plan_path, tostring(plan))
	if err then
		return display_err(err)
	end

	print("crazywall: Logs written to " .. plan_path)
end, {
	nargs = "*",
	complete = function(_, line)
		local args = vim.split(line, " ")
		if #args == 2 then
			return on_unsaved_options
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

vim.api.nvim_create_user_command("CrazywallDry", function(opts)
	local output_style = opts.fargs[1] or "both"
	local on_unsaved = opts.fargs[2] or "warn"
	local err = validate.string_in_list(on_unsaved, on_unsaved_options)
		or validate.string_in_list(output_style, output_options)
	if err then
		vim.api.nvim_err_writeln(err)
		return
	end

	local src_path = opts.fargs[3] or vim.fn.expand("%")
	local dest_path = opts.fargs[4] or vim.fn.expand("%")

	local buf_id = find_buffer(src_path)
	if not handle_unsaved(buf_id, on_unsaved == "write") then
		return
	end

	if configs[current_config_name] == nil then
		return vim.api.nvim_err_writeln(
			"crazywall: Could not find config " .. current_config_name .. "."
		)
	end

	local config
	config, err = Config:new(configs[current_config_name])
	if not config then
		return display_err(err)
	end

	local ctx
	ctx, err = Context:new(
		config,
		src_path,
		dest_path,
		vim.fn.readfile(src_path),
		nil,
		true,
		false,
		(output_style == "planonly" or output_style == "both")
				and streams.STDOUT
			or streams.NONE,
		(output_style == "textonly" or output_style == "both")
				and streams.STDOUT
			or streams.NONE,
		true,
		false
	)

	if not ctx then
		return display_err(err)
	end

	local plan
	plan, err = do_fold(buf_id, ctx)
	if err then
		return display_err(err)
	end

	local text = {}
	if output_style == "planonly" or output_style == "both" then
		table.insert(text, "Plan (dry-run):")
		for line in utils.str.split_lines(tostring(plan)) do
			table.insert(text, line)
		end
	end
	if output_style == "textonly" or output_style == "both" then
		if #text ~= 0 then
			table.insert(text, "")
		end
		table.insert(text, "Text (dry-run):")
		for line in utils.str.split_lines(utils.str.join_lines(ctx.lines)) do
			table.insert(text, line)
		end
	end

	_, err = display_floating_window(text)
	if err then
		return nil, err
	end

	vim.cmd("setlocal nowrap")
end, {
	nargs = "*",
	complete = function(_, line)
		local args = vim.split(line, " ")
		if #args == 2 then
			return output_options
		end
		if #args == 3 then
			return on_unsaved_options
		end
		if #args == 4 then
			return { vim.fn.expand("%") }
		end
		if #args == 5 then
			return { vim.fn.expand("%") }
		end
		return {}
	end,
	desc = "Applies crazywall to a file, skipping the confirmation window.",
})

M.setup = function(opts)
	opts = opts or {}
	local keys = { "configs", "default_config_name" }
	for key in pairs(opts) do
		local err = validate.string_in_list(key, keys)
		if err then
			error(err)
		end
	end
	configs = opts.configs or configs
	configs.DEFAULT = configs.DEFAULT or default_config
	current_config_name = opts.default_config_name or current_config_name
end

return M
