---@class PluginState
---@field configs PartialConfigTable[]
---@field current_config_name string
---@field follow_ref fun(line: string, column: integer, config: Config, config_name: string): any
local PluginState = {}
PluginState.__index = PluginState

---@return PluginState
function PluginState:new()
	self = {}
	setmetatable(self, PluginState)
	---@cast self PluginState
	self.configs = {}
	self.current_config_name = "DEFAULT"
	self.follow_ref = function(line)
		---@param path string
		local file_exists_and_is_not_directory = function(path)
			local stat = vim.loop.fs_stat(path)
			return stat ~= nil and stat.type == "file"
		end
		--- Find text within [[]]s.
		local match = string.match(line, "%[%[(.-)%]%]")
		if not match then
			return
		end
		local current_file_dir = vim.fn.expand("%:p:h")
		local extension = '.' .. vim.fn.expand("%:e")
		---@param path string
		local expand_path = function(path)
			return vim.fn.fnamemodify(current_file_dir .. "/" .. path, ":p")
		end
		---@param path string
		local open_path = function(path)
			vim.cmd("edit " .. vim.fn.fnameescape(path))
		end
		for _, path in ipairs({
			expand_path(match .. extension),
			expand_path(match),
			expand_path(match .. "/_index" .. extension),
		}) do
			if file_exists_and_is_not_directory(path) then
				open_path(path)
				return
			end
		end
		print(
			"Default :CrazywallFollowRef failed. Read the docs to see how you can customize its behavior: https://github.com/gitpulljoe/crazywall.nvim"
		)
	end
	return self
end

---@return PartialConfigTable?
function PluginState:get_current_config()
	return self.configs[self.current_config_name]
end

return PluginState
