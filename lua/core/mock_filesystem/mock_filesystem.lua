local Path = require("core.path")

---@alias MockFile { [string]: MockFile|string }

local MockFS_IO = require("core.mock_filesystem.io")

---@class MockFilesystem
---@field table table
---@field io iolib
MockFilesystem = {}
MockFilesystem.__index = MockFilesystem
MockFilesystem.__name = "MockFilesystem"

--- @param table table
--- @return MockFilesystem
function MockFilesystem:new(table)
	self = {}
	setmetatable(self, MockFilesystem)
	---@cast self MockFilesystem
	self.table = table
	local io = MockFS_IO:new(self)
	---@cast io -MockFS_IO iolib
	self.io = io
	return self
end

---@return string
function MockFilesystem:__tostring()
	local out = ""
	---@param path Path
	local function print_elem(path, elem, filename)
		if type(elem) == type({}) then
			if filename ~= "" then
				path:push_directory(filename)
			end
			local keys = {}
			for name in pairs(elem) do
				table.insert(keys, name)
			end
			table.sort(keys)
			for _, name in ipairs(keys) do
				local p = path:copy()
				print_elem(p, elem[name], name)
			end
			out = out .. "(directory) " .. tostring(path) .. "\n"
			return
		end
		path:set_filename(filename)
		out = out .. "(file)      " .. tostring(path) .. ": \n"
		out = out .. elem .. "\n-----\n"
	end
	print_elem(assert(Path:new("/")), self.table, "")
	return out
end

return MockFilesystem
