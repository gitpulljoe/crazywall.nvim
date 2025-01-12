---@type table<string, PartialConfigTable>
local configs = {

	refactor = {
		note_schema = {
			{ "refactor", '""" -> ', '""" """' },
		},

		resolve_path = function(section, ctx)
			local desired_path = section:get_lines()[1]
			desired_path = desired_path:sub(1, #desired_path - 4)
			return assert(ctx.dest_path:join(desired_path))
		end,

		transform_lines = function(section)
			local lines = section:get_lines()
			table.remove(lines, 1)
			return lines
		end,

		resolve_reference = function(section, ctx)
			local symbols = {}
			for _, line in ipairs(section:get_lines() or {}) do
				local match = string.match(line, "^def (.*)%(")
					or string.match(line, "^class (.*)%(")
				if match then
					table.insert(symbols, match)
				end
			end
			local used_symbols = {}
			for i = section.end_line + 1, #ctx.lines do
				local line = ctx.lines[i]
				for _, symbol in ipairs(symbols) do
					if string.find(tostring(line), symbol) then
						table.insert(used_symbols, symbol)
					end
				end
			end
			local reference = "from "
				.. section.path:get_filename():gsub(".py", "")
				.. " import "
			if not #symbols then
				reference = reference .. "*"
			else
				for i, symbol in ipairs(used_symbols) do
					reference = reference
						.. symbol
						.. (i ~= #used_symbols and ", " or "")
				end
			end
			return reference
		end,
	},
}

return configs
