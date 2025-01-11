local plugin_validate = require("crazywall.validate")

---@class PluginContext
---@field output_style "both"|"planonly"|"textonly"
---@field on_unsaved "warn"|"write"
---@field src_path_str string
---@field dest_path_str string
local PluginContext = {}
PluginContext["output_options"] = { "both", "planonly", "textonly" }
PluginContext["on_unsaved_options"] = { "warn", "write" }

---@param output_style "both"|"planonly"|"textonly"
---@param on_unsaved "warn"|"write"
---@param src_path_str string
---@param dest_path_str string
---@return PluginContext? ctx
---@return string? errmsg
function PluginContext:new(output_style, on_unsaved, src_path_str, dest_path_str)
	self = {}
	setmetatable(self, PluginContext)
	local err = plugin_validate.string_in_list(
		on_unsaved,
		PluginContext["on_unsaved_options"]
	) or plugin_validate.string_in_list(
		output_style,
		PluginContext["output_options"]
	)
	if err then
		return nil, err
	end
	---@cast self PluginContext
	self.output_style = output_style
	self.on_unsaved = on_unsaved
	self.src_path_str = src_path_str
	self.dest_path_str = dest_path_str
	return self
end

return PluginContext
