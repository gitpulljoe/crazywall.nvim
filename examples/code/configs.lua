local utils = require("core.utils")
local Path = require("core.path")

---@type table<string, PartialConfigTable>
local configs = {

	code = {
		note_schema = {
			{ "py_write", "```py -> ", "```" },
			{ "py_read", "```py <- ", "```" },
			{ "execute", "```run", "```" },
		},

		resolve_path = function(section, ctx)
			if section:type_name_is("py_write") then
				local desired_path = section:get_lines()[1]
				return assert(ctx.dest_path:join(desired_path))
			end
			return Path.void()
		end,

		transform_lines = function(section)
			local lines = section:get_lines()
			table.remove(lines, 1)
			return lines
		end,

		resolve_reference = function(section, ctx)
			if section:type_name_is("py_write") then
				return "[[" .. section:get_lines()[1] .. "]]"
			end
			if section:type_name_is("py_read") then
				local path_str = section:get_lines()[1]
				--- expand relative paths to be absolute paths
				local path = ctx.src_path:join(path_str)
				local handle = io.open(tostring(path), "r")
				local text = utils.read_from_handle(handle)
				return "```py <- " .. path_str .. "\n" .. text .. "\n```"
			end
			if section:type_name_is("execute") then
				assert(utils.str.starts_with(section:get_lines()[2], "$ "))
				local cmd = section:get_lines()[2]:sub(3)
				cmd = "cd "
					.. ctx.src_path:get_directory():escaped()
					.. "\n"
					.. cmd
					--- pipe stderr to stdout so that errors are visible
					.. " 2>&1"
				local handle = io.popen(cmd)
				local result = utils.read_from_handle(handle)
				return "```run\n"
					.. section:get_lines()[2]
					.. "\n"
					.. result
					.. "\n```"
			end
			error("unreachable")
		end,

		allow_overwrite = true,
	},
}

return configs
