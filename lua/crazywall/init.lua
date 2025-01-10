local Config = require("core.config")
local Context = require("core.context")
local streams = require("core.streams")
local fold = require("core.fold")
local utils = require("core.utils")
local M = {}

local configs = {}

local output_options = { "both", "planonly", "textonly" }
local on_unsaved_options = { "warn", "write" }

---@type number?
local err_buf = nil

---@param path string?
---@return number?
local function find_buffer(path)
	for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
		local bufname = vim.api.nvim_buf_get_name(buf_id)
		if bufname == path then
			return buf_id
		end
	end
	return nil
end

---@param err_text string?
local display_err = function(err_text)
	local err = err_text and utils.str.split_lines_to_list(err_text or "") or {}
	if err_buf and vim.api.nvim_buf_is_valid(err_buf) then
		vim.cmd("bdelete " .. err_buf)
	end
	local total_height = vim.api.nvim_get_option("lines") -- Total height of the Neovim window
	local split_height = math.floor(total_height / 3)
	vim.cmd("botright new")
	local win_id = vim.api.nvim_get_current_win()
	err_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_win_set_height(win_id, split_height)
	vim.api.nvim_buf_set_option(err_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_lines(err_buf, 0, -1, false, err)
	vim.api.nvim_buf_set_option(err_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(err_buf, "modifiable", false)
end

vim.api.nvim_create_user_command("CrazywallQuick", function(opts)
	local on_unsaved = opts.fargs[2] or "warn"
	local src_path = opts.fargs[3] or vim.fn.expand("%")
	local dest_path = opts.fargs[4] or vim.fn.expand("%")

	local buf_id = find_buffer(src_path)

	if
		buf_id
		and on_unsaved == "warn"
		and vim.api.nvim_buf_get_option(buf_id, "modified")
	then
		vim.api.nvim_err_writeln("crazywall: Buffer has unsaved changes.")
		return
	else
		if buf_id and vim.api.nvim_buf_get_option(buf_id, "modified") then
			vim.api.nvim_buf_call(buf_id, function()
				vim.cmd("write")
			end)
		end
	end

	local config, err = Config:new({})
	if not config then
		display_err(err)
		return
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
		display_err(err)
		return
	end

	local root
	root, err = fold.parse(ctx)
	if not root then
		display_err(err)
		return
	end

	_, err = fold.prepare(root, ctx)
	if err then
		display_err(err)
		return
	end

	local plan
	plan, err = fold.execute(root, ctx, true)
	if not plan then
		display_err(err)
		return
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
	print("Done!")
end, {
	nargs = "*", -- Expect exactly 2 arguments
	complete = function(_, line)
		local args = vim.split(line, " ")
		if #args == 2 then
			return output_options
		elseif #args == 3 then
			return on_unsaved_options
		elseif #args == 4 then
			return { vim.fn.expand("%") }
		elseif #args == 5 then
			return { vim.fn.expand("%") }
		end
		return {}
	end,
	desc = "Folds a file with crazywall, skipping the confirmation window.",
})

M.setup = function(opts)
	opts = opts or {}
	configs = opts.configs or configs
end

M.foo = 42

return M
