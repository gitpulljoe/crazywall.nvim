local mock_fs_utils = require("core.mock_filesystem.utils")
local Handle = require("core.mock_filesystem.handle")
local ProcessHandle = require("core.mock_filesystem.process_handle")
local validate = require("core.validate")
local Path = require("core.path")

---@class MockFS_IO
---@field mock_filesystem MockFilesystem
local MockFS_IO = {}
MockFS_IO.__index = MockFS_IO

MockFS_IO.errors = {

	--- @return string
	mock_path_is_empty = function()
		return "Empty mock path string passed to MockFS_IO.open"
	end,

	--- @param path_str string
	--- @return string
	mock_path_should_start_with_slash = function(path_str)
		return "Mock path "
			.. path_str
			.. ' passed to MockFS_IO.open should start with "/"'
	end,

	--- @param mode string
	--- @return string
	invalid_mode = function(mode)
		return "Invalid mode " .. mode .. " passed to MockFS_IO.open"
	end,

	--- @param path string
	--- @return string
	no_such_file_or_directory = function(path)
		return path .. ": No such file or directory"
	end,

	--- @param path string
	--- @return string
	is_a_directory = function(path)
		return path .. " is a directory"
	end,

	--- @param command string
	--- @return string
	command_currently_unimplemented = function(command)
		return "Command `" .. command .. "` currently unimplemented"
	end,

	--- @param path string
	--- @return string
	cannot_create_directory_file_exists = function(path)
		return "mkdir: cannot create directory `" .. path .. "`: File exists"
	end,
}

local function make_function_open(self)
	--- @param path string
	--- @param mode string
	--- @return MockFS_Handle?, string?
	return function(path, mode)
		local err = validate.types(
			"MockFS_IO.open",
			{ { path, "string", "path" }, { mode, "string", "mode" } }
		)
		if err then
			return nil, err
		end
		if #path == 0 then
			return nil, MockFS_IO.errors.mock_path_is_empty()
		end
		if path:sub(1, 1) ~= "/" then
			return nil, MockFS_IO.errors.mock_path_should_start_with_slash(path)
		end
		if not (mode == "r" or mode == "w" or mode == "a") then
			return nil, MockFS_IO.errors.invalid_mode(mode)
		end
		local parts = mock_fs_utils.split_to_table(path)
		local curr = self.mock_filesystem.table
		for i = 1, #parts - 1 do
			local part = parts[i]
			curr = curr[part]
			if curr == nil then
				return nil, MockFS_IO.errors.no_such_file_or_directory(path)
			end
		end
		if
			(mode == "w" or mode == "a")
			and type(curr[parts[#parts]]) == type({})
		then
			return nil, MockFS_IO.errors.no_such_file_or_directory(path)
		end
		if mode == "r" and curr[parts[#parts]] == nil then
			return nil, MockFS_IO.errors.no_such_file_or_directory(path)
		end
		return Handle:new(curr, parts[#parts])
	end
end

---@param self MockFS_IO
local function make_function_popen(self)
	--- @param command string
	--- @return MockFS_ProcHandle?, string?
	return function(command)
		local match = string.gmatch(command, "mkdir %-p '(.*)' 2>%&1")()
		if not match then
			return nil,
				MockFS_IO.errors.command_currently_unimplemented(command)
		end
		local path, err = Path:new(match)
		if not path then
			return nil, err
		end
		local curr = self.mock_filesystem.table
		for _, part in ipairs(path.parts) do
			if part ~= "" then
				if curr[part] and type(curr[part]) ~= type({}) then
					return nil,
						MockFS_IO.errors.cannot_create_directory_file_exists(
							tostring(path)
						)
				end
				curr[part] = curr[part] or {}
				---@cast curr any
				curr = curr[part]
			end
		end
		return ProcessHandle:new("", true, 0)
	end
end

---@param mock_filesystem MockFilesystem
---@return MockFS_IO
function MockFS_IO:new(mock_filesystem)
	self = {}
	setmetatable(self, MockFS_IO)
	self.mock_filesystem = mock_filesystem
	self.open = make_function_open(self)
	self.popen = make_function_popen(self)
	return self
end

return MockFS_IO
