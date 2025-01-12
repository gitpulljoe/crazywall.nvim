---@class Plan
---@field actions Action[]
---@field enable_ansi boolean
Plan = {}
Plan.__index = Plan
Plan.__name = "Plan"

---@param enable_ansi boolean?
---@return Plan
function Plan:new(enable_ansi)
	enable_ansi = enable_ansi == nil and true or enable_ansi
	self = {}
	setmetatable(self, Plan)
	---@cast self Plan
	self.actions = {}
	self.enable_ansi = not not enable_ansi
	return self
end

---@param action Action?
---@return Plan
function Plan:add(action)
	table.insert(self.actions, action)
	return self
end

---@return string
function Plan:__tostring()
	local text = "action         lines   chars   path"
	for _, action in ipairs(self.actions) do
		text = text .. "\n" .. action:tostring(self.enable_ansi)
	end
	return text
end

return Plan
