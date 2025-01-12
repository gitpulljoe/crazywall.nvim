local Path = require("core.path")

---@type table<string, PartialConfigTable>
local configs = {

	chess = {
		note_schema = {
			{ "pgn", "```pgn", "```" },
		},

		resolve_path = function(section, ctx)
			local white, black, year, result
			for _, line in ipairs(section:get_lines()) do
				white = white or string.match(line, '^%[White "(.*)"%]')
				black = black or string.match(line, '^%[Black "(.*)"%]')
				year = year
					or string.match(line, '^%[Year "(.*)"%]')
					or string.match(line, '^%[Date "(%d%d%d%d)%..*"%]')
				result = result or string.match(line, '^%[Result "(.*)"%]')
			end
			if not (white and black and year and result) then
				return Path.void()
			end
			local filename = white
				.. " - "
				.. black
				.. " ("
				.. year
				.. ") "
				.. result
				.. ".pgn"
			return assert(ctx.dest_path:join(filename))
		end,

		transform_lines = function(section)
			local lines = section:get_lines()
			table.remove(lines, 1)
			return lines
		end,

		resolve_reference = function(section)
			if section.path:is_void() then
				--- Restore the section if it was unable to be parsed.
				return section:open_tag()
					.. section:get_text()
					.. section:close_tag()
			end
			return "[[" .. section.path:get_filename():gsub("%.pgn", "") .. "]]"
		end,

		allow_overwrite = true,
	},
}

return configs
