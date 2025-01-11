local utils = require("core.utils")

local fold = require("core.fold")
local M = {}

---@type number?
local err_buf = nil

---@return string
M.get_log_path = function()
	return string.format(
		"%s/crazywall/log-%s.txt",
		vim.fn.stdpath("data"),
		os.time()
	)
end

---@param path string?
---@return integer?
M.find_buffer = function(path)
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
M.write = function(path, text)
	local dir = vim.fn.fnamemodify(path, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	local buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(
		buf_id,
		0,
		-1,
		false,
		utils.str.split_lines_to_list(text)
	)
	local filename = path
	vim.api.nvim_buf_call(buf_id, function()
		vim.cmd("write " .. filename)
	end)
	vim.cmd("bd! " .. buf_id)
end

---@param plugin_ctx PluginContext
---@param ctx Context
---@param plan Plan
---@return string[]
M.get_plan_and_text_lines = function(ctx, plugin_ctx, plan)
	local lines = {}
	if
		plugin_ctx.output_style == "planonly"
		or plugin_ctx.output_style == "both"
	then
		table.insert(lines, "Plan (dry-run):")
		for line in utils.str.split_lines(tostring(plan)) do
			table.insert(lines, line)
		end
	end
	if
		plugin_ctx.output_style == "textonly"
		or plugin_ctx.output_style == "both"
	then
		if #lines ~= 0 then
			table.insert(lines, "")
		end
		table.insert(lines, "Text (dry-run):")
		for line in utils.str.split_lines(utils.str.join_lines(ctx.lines)) do
			table.insert(lines, line)
		end
	end
	return lines
end

---@param lines string[]
---@return integer? buf_id
---@return string? errmsg
M.display_floating_window = function(lines)
	local plan_path_prefix =
		string.format("%s/crazywall/log-", vim.fn.stdpath("data"))
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
	vim.api.nvim_buf_set_name(buf_id, M.get_log_path())
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
				vim.cmd("b#|bwipeout! " .. buf_id)
			end
		end,
	})

	return buf_id
end

---@param err_text string?
M.display_err = function(err_text)
	local err = err_text and utils.str.split_lines_to_list(err_text or "") or {}
	if err_buf and vim.api.nvim_buf_is_valid(err_buf) then
		vim.cmd("bdelete " .. err_buf)
	end
	local total_height = vim.api.nvim_get_option("lines")
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
---@param is_dry_run boolean
---@return Plan? plan
---@return Section? root
---@return string? errmsg
M.do_fold = function(buf_id, ctx, is_dry_run)
	local root, err = fold.parse(ctx)
	if not root then
		return nil, nil, err
	end

	_, err = fold.prepare(root, ctx)
	if err then
		return nil, nil, err
	end

	local plan
	plan, err = fold.execute(root, ctx, true)
	if not plan then
		return nil, nil, err
	end

	if is_dry_run then
		return plan, root
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

	return plan, root
end

---@param buf_id integer?
---@param write_on_unsaved boolean
---@return boolean
M.handle_unsaved = function(buf_id, write_on_unsaved)
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

return M
