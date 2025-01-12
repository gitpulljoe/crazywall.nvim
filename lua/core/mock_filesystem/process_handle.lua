---@class MockFS_ProcHandle
---@field result string
---@field closed boolean
---@field succeeded boolean
---@field code integer?
local MockFS_ProcHandle = {}
MockFS_ProcHandle.__index = MockFS_ProcHandle

---@param result string
---@param succeeded boolean
---@param code integer?
---@return MockFS_ProcHandle
function MockFS_ProcHandle:new(result, succeeded, code)
	self = {}
	self.opened = true
	setmetatable(self, MockFS_ProcHandle)
	self.result = result
	self.succeeded = succeeded
	self.code = code
	return self
end

function MockFS_ProcHandle:write()
	error("currently unimplemented")
end

---@return string
function MockFS_ProcHandle:read()
	if self.closed then
		error("attempt to read from a closed file")
	end
	return self.result
end

---@return boolean, string, integer?
function MockFS_ProcHandle:close()
	self.opened = false
	return self.succeeded, "exit", self.code
end

return MockFS_ProcHandle
