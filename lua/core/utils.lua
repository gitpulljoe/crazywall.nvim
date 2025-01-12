local M = {}

M.str = {

	---@param str string
	---@param prefix string
	---@return boolean
	starts_with = function(str, prefix)
		return string.sub(str, 1, #prefix) == prefix
	end,

	---@param str string
	---@param suffix string
	---@return boolean
	ends_with = function(str, suffix)
		return string.sub(str, -string.len(suffix)) == suffix
	end,

	---@param str string
	---@param include_empty boolean?
	---@return fun(): string
	split_lines = function(str, include_empty)
		include_empty = include_empty or false
		return include_empty and str:gmatch("([^\n]*)\n?")
			or str:gmatch("[^\r\n]+")
	end,

	---@param str string
	---@param include_empty boolean?
	---@return string[]
	split_lines_to_list = function(str, include_empty)
		local gen = M.str.split_lines(str, include_empty)
		local res = {}
		for v in gen do
			table.insert(res, v)
		end
		return res
	end,

	---@param list (string|boolean)[]
	---@param delim string
	---@return string
	join = function(list, delim)
		delim = delim or ""
		local result = ""
		for i, str in ipairs(list) do
			if str ~= false then
				result = result .. (i == 1 and "" or delim) .. str
			end
		end
		return result
	end,

	---@param list (string|boolean)[]
	---@return string
	join_lines = function(list)
		return M.str.join(list, "\n")
	end,

	---@param str string
	---@return string
	trim = function(str)
		return string.match(str, "^%s*(.-)%s*$")
	end,
}

---@generic T
---@param tbl T
---@return T
M.read_only = function(tbl)
	local proxy = {}
	local mt = {
		__index = tbl,
		__newindex = function(self)
			error(
				(self.__name and (self.__name .. ": ") or "")
					.. "attempt to update a read-only table",
				2
			)
		end,
	}
	setmetatable(proxy, mt)
	return proxy
end

---@param handle file*?
---@return string?
M.read_from_handle = function(handle)
	if not handle then
		return nil
	end
	local res = handle:read("*a")
	handle:close()
	if res:sub(#res, #res) == "\n" then
		res = res:sub(1, #res - 1)
	end
	return res
end

---@return string
M.get_home_directory = function()
	return assert(M.read_from_handle(io.popen("echo $HOME")) .. "/")
end

return M
