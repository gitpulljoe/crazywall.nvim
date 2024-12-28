local utils = require("core.utils")
local str = utils.str
local Section = require("core.section")
local traverse = require("core.traverse")
local validate = require("core.validate")

local M = {}

M.error = {

	---@param section Section?
	---@return string
	unterminated_section = function(section)
		return "Unterminated section: " .. (tostring(section) or "nil")
	end,

	---@param section Section?
	---@return string
	maximum_retry_count = function(section)
		return "Maximum retry count reached: " .. (tostring(section) or "nil")
	end,

	---@param path string
	---@param section Section?
	---@return string
	cannot_write = function(path, section)
		return "Cannot write to path " .. path .. "\n" .. tostring(section)
	end,

	---@param command string
	---@param err string?
	---@return string
	command_failed = function(command, err)
		return "Failed to execute command: "
			.. command
			.. "\nError: "
			.. (err or "")
	end,
}

---@param ctx Context
---@return Section?, string?
M.parse = function(ctx)
	local section, err =
		Section:new(utils.read_only({ "ROOT" }), ctx, 0, #ctx.lines, {}, nil)
	local root = section
	if not section then
		return nil, err
	end
	local config = ctx.config
	local open_section_symbol = config.open_section_symbol
	local note_schema = config.note_schema
	for i, line in ipairs(ctx.lines) do
		for note_idx, note_type in ipairs(note_schema) do
			local prefix = note_type[2] .. open_section_symbol
			if str.starts_with(line, prefix) then
				local curr
				curr, err = Section:new(
					utils.read_only(config.note_schema[note_idx]),
					ctx,
					i,
					nil,
					{},
					section
				)
				if not curr then
					return nil, err
				end
				table.insert(section.children, curr)
				section = curr
				break
			end
		end
		-- TODO(gitpushjoe): maybe still check if a suffix for another note type slipped through?
		if
			section
			and section.type[1] ~= "ROOT"
			and str.ends_with(line, section:suffix())
		then
			section.end_line = i
			section = section.parent
		end
	end
	if section ~= root then
		return nil, M.error.unterminated_section(section)
	end
	return section
end

---@param section_root Section
---@param ctx Context
---@return nil, string?
M.prepare = function(section_root, ctx)
	local _, err = traverse.preorder(section_root, function(section)
		if section.type[1] == "ROOT" then
			return
		end

		local path = ctx.config.resolve_path(
			utils.read_only(section),
			utils.read_only(ctx)
		)

		local err = validate.are_instances(
			"config.resolve_directory",
			{ { path, Path } }
		)
		if err then
			return nil, err
		end

		section.path = path
	end)
	if err then
		return _, err
	end

	_, err = traverse.postorder(section_root, function(section)
		if section.type[1] == "ROOT" then
			section.lines = ctx.lines
			return
		end

		local lines = ctx.config.transform_lines(
			utils.read_only(section),
			utils.read_only(ctx)
		)

		local _err = validate.types_in_list(
			"config.transform_lines",
			lines,
			validate.RETVAL,
			"string"
		)
		if _err then
			return nil, _err
		end

		ctx.lines[section.start_line] =
			ctx.config.resolve_reference(section, ctx)
		for i = section.start_line + 1, section.end_line do
			ctx.lines[i] = false
		end

		section.lines = lines
	end)
	if err then
		return nil, err
	end
	-- print("lines: \n" .. str.join_lines(section_root:get_lines()))
end

---@param section_root Section
---@param ctx Context
M.execute = function(section_root, ctx)
	local io = ctx.io

	---@param path_str string?
	---@return boolean
	local function file_exists(path_str)
		local file = io.open(path_str or "", "r")
		if file == nil then
			return false
		end
		file:close()
		return true
	end
	---@param path_str string?
	---@return file*?
	local function get_write_handle(path_str)
		return io.open(path_str or "", "w")
	end

	local _, err = traverse.preorder(section_root, function(section)
		local retry_count = 0
		local write_handle
		local full_path = tostring(section.path) or ""
		if section.type[1] == "ROOT" then
			full_path = tostring(ctx.src_path)
		end

		while retry_count <= ctx.config.retry_count do
			if section.type[1] == "ROOT" then
				break
			end
			if not file_exists(full_path) then
				break
			end
			if ctx.config.allow_overwrite then
				write_handle = get_write_handle(full_path)
				if write_handle then
					break
				end
			end
			retry_count = retry_count + 1
			if retry_count > ctx.config.retry_count then
				break
			end
			local path = ctx.config.resolve_collision(
				section.path,
				section,
				ctx,
				retry_count
			)
			section.path = path
			full_path = tostring(section.path) or ""
		end

		if retry_count > ctx.config.retry_count then
			return nil, M.error.maximum_retry_count(section)
		end
		write_handle = write_handle or get_write_handle(full_path)
		if write_handle then
			write_handle:write(str.join_lines(section.lines))
			write_handle:close()
			return
		end
		if not ctx.config.allow_makedir then
			return nil, M.error.cannot_write(full_path, section)
		end
		local command = "mkdir -p "
			.. tostring(section.path:directory():escaped())
			.. " 2>&1"
		local handle, err = io.popen(command)
		if not handle then
			return nil, M.error.command_failed(command, err)
		end

		local succeeded = handle:close()
		if succeeded ~= true then
			return nil, M.error.command_failed(command)
		end
		write_handle = get_write_handle(full_path)
		if write_handle then
			write_handle:write(str.join_lines(section.lines))
			write_handle:close()
			return
		end
		M.error.cannot_write(full_path, section)
	end)
	if err then
		return nil, err
	end
end

return M
