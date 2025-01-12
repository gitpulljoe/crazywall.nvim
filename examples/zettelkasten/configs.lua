local utils = require("core.utils")

---@type table<string, PartialConfigTable>
local configs = {

	zettelkasten = {
		note_schema = {
			{ "prm", "%p ", "%%" },
			{ "ref", "%r ", "%%" },
			{ "tdo", "%t ", "%%" },
			{ "quo", "%q ", "%%" },
			{ "flt", "%f ", "%%" },
			{ "qst", "%? ", "%%" },
			{ "src", "%s ", "%%" },
		},

		resolve_path = function(section, ctx)
			local path = assert(ctx.dest_path:get_directory())
			path:push_directory(section:type_name())
			--- The trailing 0 specifies that this is the first note made at
			--- this exact time
			path:set_filename(tostring(os.time()) .. "0.md")
			return path
		end,

		transform_lines = function(section)
			local lines = section:get_lines()
			local tag_set = {}
			local base_section = section
			--- Iterate up the section tree.
			repeat
				local curr_section_lines = section:get_lines()
				if #curr_section_lines <= 1 then
					break
				end
				--- Get tags at the last line.
				local line =
					utils.str.trim(curr_section_lines[#curr_section_lines - 1])
				for tag in string.gmatch(line, "#[^%s]+") do
					tag_set["is not empty"] = 1
					tag_set[tag] = 1
				end
				section = section.parent
			until not section
			table.insert(lines, "")
			--- Add the tags at the bottom of the file.
			if tag_set["is not empty"] then
				tag_set["is not empty"] = nil
				local tag_str = "Tags: "
				for tag in pairs(tag_set) do
					tag_str = tag_str .. tag .. " "
				end
				table.insert(lines, tag_str:sub(1, #tag_str - 1))
			end
			local parent = base_section.parent
			--- Add the file that this note came from.
			if parent and not parent:is_root() then
				table.insert(
					lines,
					"From: [["
						.. (parent:type_name() .. "/" .. parent.path:get_filename())
						.. "|"
						.. parent:get_lines()[1]:gsub("^# ", "")
						.. "]]"
				)
			end
			--- Remove the tags from this section as we've re-added them 
			--- already.
			for i = #lines, 1, -1 do
				local line = utils.str.trim(lines[i])
				if line:sub(1, 1) == "#" then
					table.remove(lines, i)
				end
			end
			--- Remove trailing newline.
			if lines[#lines] == "" then
				table.remove(lines, #lines)
			end
			--- Add a Markdown header.
			if lines[1] then
				lines[1] = "# " .. lines[1]
			end
			return lines
		end,

		resolve_reference = function(section)
			local reference = "[["
				.. (section:type_name() .. "/" .. section.path:get_filename())
				.. "|"
				.. section:get_transformed_lines()[1]:gsub("^# ", "")
				.. "]]"
			if section:type_name_is("src") then
				return "Source: " .. reference
			end
			return reference
		end,

		resolve_collision = function(path, _, _, retry_count)
			local filename = path:get_filename()
			filename = filename:sub(1, #filename - 4)
				--- Convert the retry_count to hex.
				.. string.format("%x", retry_count)
				.. ".md"
			path:set_filename(filename)
			return path
		end,

		allow_overwrite = true,

		allow_makedir = true,

		local_retry_count = 15,

		retry_count = 0
	},
}

return configs
