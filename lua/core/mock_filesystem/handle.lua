---@class MockFS_Handle
---@field parent_directory table
---@field filename string
---@field opened boolean
local MockFS_Handle = {}
MockFS_Handle.__index = MockFS_Handle

---@param parent_directory table
---@param filename string
---@return MockFS_Handle
function MockFS_Handle:new(parent_directory, filename)
	self = {}
	setmetatable(self, MockFS_Handle)
	---@cast self MockFS_Handle
	self.parent_directory = parent_directory
	self.filename = filename
	self.opened = true
	return self
end

---@param text string
---@return MockFS_Handle?, string?
function MockFS_Handle:write(text)
	if not self.opened then
		return nil, "Cannot write to a closed file"
	end
	self.parent_directory[self.filename] = text
	return self, nil
end

---@return boolean, string, integer?
function MockFS_Handle:close()
	self.opened = false
	return true, "exit", 0
end

return MockFS_Handle
