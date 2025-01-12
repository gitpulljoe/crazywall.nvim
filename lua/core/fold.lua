local utils = require("core.utils")
local str = utils.str
local Section = require("core.section")
local traverse = require("core.traverse")
local validate = require("core.validate")
local Plan = require("core.plan.plan")
local Action = require("core.plan.action")
local Path = require("core.path")

--- Functions for the primary crazywall operation.
local M = {}
M.__name = "fold"

M.errors = {

	---@param section Section?
	---@return string errmsg
	unterminated_section = function(section)
		return "Unterminated section: " .. (tostring(section) or "nil")
	end,

	---@param line number
	---@return string errmsg
	inconsistent_indent = function(line)
		return "Inconsistent indent on line " .. line
	end,

	---@param retry_count number
	---@param section Section?
	---@param is_local boolean?
	---@return string errmsg
	maximum_retry_count = function(retry_count, section, is_local)
		return "Maximum "
			.. (is_local and "local " or "")
			.. "retry count of "
			.. retry_count
			.. " reached: "
			.. (tostring(section) or "nil")
	end,

	---@param path Path
	---@return string errmsg
	path_should_not_be_directory = function(path)
		return "`config.resolve_path` returned directory-type Path ("
			.. path:escaped()
			.. ") instead of file-type Path"
	end,

	---@param path string
	---@param section Section?
	---@return string errmsg
	cannot_write = function(path, section)
		return "Cannot write to path " .. path .. "\n" .. tostring(section)
	end,

	---@param command string
	---@param err string?
	---@return string errmsg
	command_failed = function(command, err)
		return "Failed to execute command: "
			.. command
			.. "\nError: "
			.. (err or "")
	end,

	---@param path string
	---@return string errmsg
	expected_file_to_be_writable = function(path)
		return "Expected file " .. tostring(path) .. " to be writable"
	end,
}

---@param ctx Context
---@return Section? section
---@return string? errmsg
M.parse = function(ctx)
	local curr_section, err = Section:new(
		0,
		utils.read_only({ Section.ROOT, "", "" }),
		ctx,
		1,
		#ctx.lines,
		{},
		nil
	)
	local id = 1
	local root = curr_section
	if not curr_section then
		return nil, err
	end
	local config = ctx.config
	local note_schema = config.note_schema
	for i, line in ipairs(ctx.lines) do
		---@cast line string
		if curr_section ~= nil and #curr_section.indent > 0 then
			local indent = curr_section.indent
			-- TODO(gitpushjoe): maybe ignoring empty lines should be config option?
			if #line ~= 0 and not str.starts_with(line, indent) then
				return nil, M.errors.inconsistent_indent(i)
			end
		end

		local indent_chars = 0
		for j = 1, #line do
			local char = string.sub(line, j, j)
			if char ~= " " and char ~= "\t" then
				break
			end
			indent_chars = indent_chars + 1
		end
		local indent = string.sub(line, 1, indent_chars)
		line = string.sub(line, indent_chars + 1)

		for note_idx, note_type in ipairs(note_schema) do
			local open_tag = note_type[2]
			local do_not_open_only_close = line == open_tag
				and curr_section
				and open_tag == curr_section:close_tag()
			if
				str.starts_with(line, open_tag) and not do_not_open_only_close
			then
				local new_section
				new_section, err = Section:new(
					id,
					utils.read_only(config.note_schema[note_idx]),
					ctx,
					i,
					nil,
					{},
					curr_section,
					indent
				)
				id = id + 1
				if not new_section then
					return nil, err
				end
				table.insert(curr_section.children, new_section)
				curr_section = new_section
				break
			end
		end
		-- TODO(gitpushjoe): maybe still check if a suffix for another note type slipped through?
		local do_not_close_only_open = line == curr_section:open_tag()
			and line == curr_section:close_tag()
			and curr_section.start_line == i
		if
			curr_section
			and not curr_section:is_root()
			and str.ends_with(line, curr_section:close_tag())
			and not do_not_close_only_open
		then
			curr_section.end_line = i
			curr_section = curr_section.parent
		end
	end
	if curr_section ~= root then
		return nil, M.errors.unterminated_section(curr_section)
	end
	return curr_section
end

---@param section_root Section
---@param ctx Context
---@return nil
---@return string? errmsg
M.prepare = function(section_root, ctx)
	---@type { [string]: Section }
	local created_files = {}

	local _, err = traverse.preorder(section_root, function(section)
		if section:is_root() then
			section.path = ctx.dest_path
			return
		end

		local path = ctx.config.resolve_path(
			utils.read_only(section),
			utils.read_only(ctx)
		)

		local err =
			validate.are_instances("config.resolve_path", { { path, Path } })
		if err then
			return nil, err
		end
		if path:is_directory() then
			return nil, M.errors.path_should_not_be_directory(path)
		end
		local original_path = path:copy()

		local retries = 0
		while not path:is_void() and created_files[tostring(path)] do
			if ctx.config.allow_local_overwrite then
				created_files[tostring(path)].path = Path.void()
				break
			end
			section.path = path
			if retries >= ctx.config.local_retry_count then
				return nil, M.errors.maximum_retry_count(retries, section, true)
			end
			retries = retries + 1
			path = ctx.config.resolve_collision(
				original_path:copy(),
				utils.read_only(section),
				utils.read_only(ctx),
				retries
			)
		end
		if not path:is_void() then
			created_files[tostring(path)] = section
		end

		if err then
			return nil, err
		end

		section.path = path
	end)
	if err then
		return nil, err
	end

	_, err = traverse.postorder(section_root, function(section)
		if section:is_root() then
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

		section.lines = lines

		local reference = ctx.config.resolve_reference(section, ctx)
		_err = validate.types(
			"config.resolve_reference",
			{ { reference, "string|boolean" } }
		)
		if _err then
			return nil, _err
		end

		ctx.lines[section.start_line] = reference
				and (section.indent .. reference)
			or false
		for i = section.start_line + 1, section.end_line do
			ctx.lines[i] = false
		end
	end)
	if err then
		return nil, err
	end
end

---@param section_root Section
---@param ctx Context
---@param is_dry_run boolean?
---@return Plan? plan
---@return string? errmsg
M.execute = function(section_root, ctx, is_dry_run)
	is_dry_run = is_dry_run or false
	local io = ctx.io
	local plan = Plan:new(ctx.ansi_enabled)
	local created_or_modified_paths = {}

	---@param path_str string?
	---@return boolean
	local function file_exists(path_str)
		if created_or_modified_paths[path_str] then
			return true
		end
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
		if is_dry_run then
			local directory = assert(Path:new(path_str or "")):get_directory()
			if not file_exists(tostring(directory)) then
				return nil
			end
			local file, err = io.open(tostring(directory), "w")
			--- shouldn't be necessary
			if file then
				file:close()
			end
			return utils.str.ends_with(err or "", "directory") and {} or nil
		end
		return io.open(path_str or "", "w")
	end

	---@param handle file*?
	---@param lines string[]
	---@param path Path
	---@param is_overwrite boolean?
	---@return string? errmsg
	local function write(handle, lines, path, is_overwrite)
		is_overwrite = is_overwrite or false
		created_or_modified_paths[tostring(path)] = 1
		if not is_dry_run and handle then
			local _, err = handle:write(str.join_lines(lines))
			handle:close()
			if err then
				return err
			end
		end
		plan:add(
			(is_overwrite and Action.overwrite or Action.create)(path, lines)
		)
	end

	---@param directory Path
	---@return string? errmsg
	local function mkdir(directory)
		created_or_modified_paths[tostring(directory)] = 1
		if not is_dry_run then
			local command = "mkdir -p "
				.. tostring(directory:escaped())
				.. " 2>&1"
			local handle, err = io.popen(command)
			if not handle then
				return M.errors.command_failed(command, err)
			end
			local succeeded
			succeeded, err = handle:close()
			if succeeded ~= true then
				return M.errors.command_failed(command, err)
			end
		end
		plan:add(Action.mkdir(directory))
	end

	local _, err = traverse.preorder(section_root, function(section)
		local original_path = section.path:copy()
		local retries = 0
		local full_path = tostring(section.path) or ""
		local is_overwrite = false
		local rename_action = nil
		local write_handle = nil

		if section.path:is_void() then
			plan:add(Action.ignore(section.lines))
			return
		end

		while true do
			if section:is_root() then
				is_overwrite = ctx.src_path == ctx.dest_path
				break
			end
			if not file_exists(full_path) then
				break
			end
			if ctx.config.allow_overwrite then
				write_handle = get_write_handle(full_path)
				is_overwrite = true
				if write_handle then
					break
				end
			end
			retries = retries + 1
			if retries > ctx.config.retry_count then
				break
			end
			local path = ctx.config.resolve_collision(
				original_path:copy(),
				section,
				ctx,
				retries
			)
			rename_action = Action.rename(original_path, path)
			section.path = path
			full_path = tostring(section.path) or ""
		end

		if section:is_root() and ctx.preserve then
			return
		end

		if retries > ctx.config.retry_count then
			return nil,
				M.errors.maximum_retry_count(ctx.config.retry_count, section)
		end
		plan:add(rename_action)
		write_handle = write_handle or get_write_handle(full_path)

		if write_handle then
			local err =
				write(write_handle, section.lines, section.path, is_overwrite)
			if err then
				return nil, err
			end
			return
		end

		if not ctx.config.allow_makedir then
			return nil, M.errors.cannot_write(full_path, section)
		end

		local err = mkdir(assert(section.path:get_directory()))
		if err then
			return nil, err
		end

		write_handle = get_write_handle(full_path)
		err = write(write_handle, section.lines, section.path, is_overwrite)
		if err then
			return nil, err
		end
	end)
	if err then
		return nil, err
	end
	return plan
end

return M
