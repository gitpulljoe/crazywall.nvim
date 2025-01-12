require("core.section")

local M = {}

---@param section Section
---@param callback fun(section: Section): nil, string?
---@return nil, string?
M.preorder = function(section, callback)
	local _, err = callback(section)
	if err then
		return nil, err
	end
	for _, child in ipairs(section.children) do
		_, err = M.preorder(child, callback)
		if err then
			return nil, err
		end
	end
end

---@param section Section
---@param callback fun(section: Section): nil, string?
---@return nil, string?
M.postorder = function(section, callback)
	for _, child in ipairs(section.children) do
		local _, err = M.postorder(child, callback)
		if err then
			return nil, err
		end
	end
	local _, err = callback(section)
	if err then
		return nil, err
	end
end

return M
