local utils = require("core.utils")
local M = {}

---@param str string
---@param list string[]
---@return string?
M.string_in_list = function(str, list)
	for _, elem in ipairs(list) do
		if str == elem then
			return nil
		end
	end
	return 'Item "' .. str .. '" not in {"' .. utils.str.join(list, '", "') .. '"}'
end

return M
