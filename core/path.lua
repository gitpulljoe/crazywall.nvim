local validate = require("core.validate")
local utils = require("core.utils")

--- Representation of a path as a stack of string "parts".
--- Should always be absolute paths.
--- Directories are reprsented with a trailing "/".
---
--- @class Path
--- @field parts string[]
local Path = {}
Path.__index = Path
Path.__name = "Path"

Path.errors = {

	--- @return string
	cannot_modify_void = function()
		return "Cannot modify void path."
	end,

	--- @param path string
	--- @return string
	path_should_begin_with_slash = function(path)
		return "Path " .. path .. ' should begin with "/" or "~/"'
	end,
}

---@param path Path
local handle_is_void = function(path)
	if path:is_void() then
		error(Path.errors.cannot_modify_void())
	end
end

---@param path string|string[]
---`allow_relative` IS INTENDED FOR INTERNAL USE ONLY.
---@param allow_relative boolean?
---@return Path? path
---@return string? errmsg
function Path:new(path, allow_relative)
	self = {}
	setmetatable(self, Path)
	--- @cast self Path

	local err = validate.types("Path:new", { { path, "string|table", "path" } })
	if err then
		return nil, err
	end

	self.parts = {}
	if type(path) == type({}) then
		---@cast path string[]
		err = validate.types_in_list("Path:new", path, "path", "string")
		if err then
			return nil, err
		end

		for _, part in ipairs(path) do
			table.insert(self.parts, part)
		end
	else
		---@cast path string
		if path:sub(1, 1) == "~" and path:sub(2, 2) == "/" then
			path = assert(utils.get_home_directory()) .. path:sub(3)
		end
		if not allow_relative and path:sub(1, 1) ~= "/" then
			return nil, Path.errors.path_should_begin_with_slash(path)
		end
		table.insert(self.parts, "")
		for part in string.gmatch(path, "[^/]+") do
			table.insert(self.parts, part)
		end
		if #self.parts == 1 and self.parts[1] == nil then
			self.parts = {}
		end
	end
	return self
end

--- Path for discarding all text written to it.
--- Equivalent to `Path:new("/dev/null")`.
--- Trying to modify a `Path.void()` will throw an error.
--- `Path.void():directory()` will return an empty string.
--- @return Path
function Path.void()
	return assert(Path:new("/dev/null"))
end

--- Returns true if the `Path` is equivalent to `Path.void()`.
--- @return boolean
function Path:is_void()
	return #self.parts == 3
		and self.parts[1] == ""
		and self.parts[2] == "dev"
		and self.parts[3] == "null"
end

--- Returns true if the `Path` is a directory.
---
--- Examples:
--- ```lua
--- assert(Path:new("/foo/bar/"):is_directory())
--- assert(not Path:new("/foo/bar/baz"):is_directory())
--- ```
--- @return boolean
function Path:is_directory()
	return self.parts[#self.parts] == ""
end

--- Modifies the `Path` to a directory, by removing the filename.
--- Equivalent to `Path:set_filename("")`.
--- Throws an error if the path is `Path.void()`.
---
--- Examples:
--- ```lua
--- local path = Path:new("/foo/bar/baz")
--- assert(path:to_directory() == Path:new("/foo/bar/"))
--- assert(path:to_directory() == Path:new("/foo/bar/"))
--- ```
--- @return Path
function Path:to_directory()
	handle_is_void(self)
	self.parts[#self.parts] = ""
	return self
end

--- Removes the last directory from the `Path`. If there is a filename, the
--- filename is retained.
--- Returns the popped directory.
--- Throws an error if the path is `Path.void()`.
---
--- Examples:
--- ```lua
--- local path = Path:new("/foo/bar/baz")
--- assert(path:pop_directory() == "bar")
--- assert(path == Path:new("/foo/baz"))
--- path = Path:new("/foo/baz/")
--- assert(path:pop_directory() == "baz")
--- assert(path == Path:new("/foo/"))
--- ```
--- @return string? errmsg
function Path:pop_directory()
	handle_is_void(self)
	if #self.parts <= 2 then
		return
	end
	return table.remove(self.parts, #self.parts - 1)
end

--- Appends a directory to the stack, before the filename, if any.
--- Returns `self`.
--- Throws an error if the path is `Path.void()`.
---
--- Examples:
--- ```lua
--- local path = Path:new("/foo/baz")
--- assert(path:push_directory("bar") == Path:new("/foo/bar/baz"))
--- path = Path:new("/foo/bar/")
--- assert(path:push_directory("baz") == Path:new("/foo/bar/baz/"))
--- ```
--- @param part string
--- @return self
function Path:push_directory(part)
	handle_is_void(self)
	if #self.parts == 0 then
		table.insert(self.parts, part)
		return self
	end
	table.insert(self.parts, #self.parts, part)
	return self
end

--- Returns a copy of the `Path`, representing the directory the path is
--- contained in. Returns a copy of `self` if the `Path` is already a
--- directory.
---
--- Examples:
--- ```lua
--- assert(Path:new("/foo/bar/baz"):directory() == Path:new("/foo/bar/"))
--- assert(Path:new("/foo/bar/baz/"):directory() == Path:new("/foo/bar/baz/"))
--- ```
--- @return Path?
function Path:get_directory()
	if self:is_void() then
		return nil
	end
	local copy = self:copy()
	return copy:to_directory()
end

--- Modifies the filename of the path. Set to `""` to make the path a
--- directory. Returns the old filename.
--- Throws an error if the path is `Path.void()`.
---
--- Examples:
--- ```lua
--- local path = Path:new("/foo/baz")
--- assert(path:set_filename("bar") == "baz")
--- assert(path == Path:new("/foo/bar"))
--- assert(path:set_filename("") == "bar")
--- assert(path == Path:new("/foo/"))
--- ```
--- @param filename string
--- @return string old_filename
function Path:set_filename(filename)
	handle_is_void(self)
	if #self.parts < 1 then
		return ""
	end
	local old_filename = self.parts[#self.parts]
	self.parts[#self.parts] = filename
	return old_filename
end

--- Returns the filename of the path. Returns `""` if the path is a directory
--- or if the path is void.
--- @return string
function Path:get_filename()
	if self:is_void() then
		return ""
	end
	return self.parts[#self.parts]
end

---@return string
function Path:__tostring()
	local out = ""
	for i, part in ipairs(self.parts) do
		out = out .. part:gsub("/", "") .. (i ~= #self.parts and "/" or "")
	end
	return out
end

--- Returns an escaped, single-quoted representation of the path for use on the
--- command line.
---
--- Example:
--- ```lua
--- assert(Path:new("/foo/'bar'/baz"):escaped() == "'/foo/'\\''bar'\\''/baz'")
--- ```
--- @return string
function Path:escaped()
	return "'" .. tostring(self):gsub("'", "'\\''") .. "'"
end

--- If the `path` given is a relative path (like `"./foo"` or `"../bar"`), then
--- the `path` is expanded, with the self directory as the base `"./"` path.
--- Otherwise, behaves identically to `Path:new(path)`.
---
--- Examples:
--- ```lua
--- assert(Path:new("/foo/"):join("bar") == Path:new("/foo/bar"))
--- assert(Path:new("/foo/bar"):join("./baz") == Path:new("/foo/baz"))
--- ```
--- @param path string
--- @return Path? new_path
--- @return string? errmsg
function Path:join(path)
	local err = validate.types("Path:join", { { path, "string", "path" } })
	if err then
		return nil, err
	end
	if
		path:sub(1, 1) == "."
		and path:sub(2, 2) == "."
		and path:sub(3, 3) == "/"
	then
		local copy = self:copy()
		copy:pop_directory()
		path = assert(tostring(copy:get_directory())) .. path:sub(4)
	elseif path:sub(1, 1) == "." and path:sub(2, 2) == "/" then
		path = assert(tostring(self:get_directory())) .. path:sub(3)
	elseif path.sub(1, 1) ~= "/" then
		path = assert(tostring(self:get_directory())) .. path
	end
	return Path:new(path)
end

--- Returns a copy of the `Path`.
--- @return Path
function Path:copy()
	return assert(Path:new(self.parts))
end

--- @param rhs Path
--- @return boolean
function Path:__eq(rhs)
	if #self.parts ~= #rhs.parts then
		return false
	end
	for i = 1, #self.parts do
		if self.parts[i] ~= rhs.parts[i] then
			return false
		end
	end
	return true
end

return Path
