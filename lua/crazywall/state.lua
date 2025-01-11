---@class PluginState
---@field configs PartialConfigTable[]
---@field current_config_name string
local PluginState = {}
PluginState.__index = PluginState

---@return PluginState
function PluginState:new()
	self = {}
	setmetatable(self, PluginState)
	---@cast self PluginState
	self.configs = {}
	self.current_config_name = "DEFAULT"
	return self
end

---@return PartialConfigTable?
function PluginState:get_current_config()
	return self.configs[self.current_config_name]
end

return PluginState
