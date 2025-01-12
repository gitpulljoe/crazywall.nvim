local M = {}

---@param path string
---@return fun(): string
M.split = function (path)
	return path:gmatch("([^/]+)")
end

---@param path string
---@return string[]
M.split_to_table = function (path)
	local tbl = {}
	for v in path:gmatch("([^/]+)") do
		table.insert(tbl, v)
	end
	return tbl
end

return M
