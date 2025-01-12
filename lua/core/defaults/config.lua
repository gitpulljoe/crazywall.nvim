local utils = require("core.utils")
local Path = require("core.path")

---@type Config
local default_config = {

	--- With this schema, crazywall will look for a line in the source file 
	--- that begins with "# " and continue until it finds a line ending with 
	--- "[!h1]". Everything within those lines will be captured in a Section 
	--- object, and doing section:type() will return { "h1", "# ", "[!h1]" }. 
	--- The same goes for all of the other items in `note_schema`.
	note_schema = {
		{ "h1", "# ", "[!h1]" },
		{ "h2", "## ", "[!h2]" },
		{ "h3", "### ", "[!h3]" },
		{ "h4", "#### ", "[!h4]" },
		{ " - h1", "- # ", "[!h1]" },
		{ " - h2", "- ## ", "[!h2]" },
		{ " - h3", "- ### ", "[!h3]" },
		{ " - h4", "- #### ", "[!h4]" },
	},

	resolve_path = function(section)
		--- Get the directory of the parent path. If this is the first section,
		--- then its parent will be the ROOT section, and this will be the
		--- directory that the destination note will be saved to. (If
		--- `--preserve` is enabled, this will be the directory of the source
		--- file.)
		--- Note that if the parent path is Path.void(), then this will be nil.
		local path = section.parent.path:get_directory()

		--- If the parent path should be ignored, then set this section to be
		--- ignored as well.
		if not path then
			return Path.void()
		end

		--- Ignore this section if the first line starts with "{" and ends with
		--- "}" (not including the open tag or indentation).
		if
			utils.str.starts_with(section:get_lines()[1], "{")
			and utils.str.ends_with(section:get_lines()[1], "}")
		then
			return Path.void()
		end

		--- Set the filename of the note to the first line of the section, or
		--- "Untitled {section.id}", if the first line is empty/whitespace.
		local filename = utils.str.trim(section:get_lines()[1])
			or ("Untitled " .. section.id)

		--- If this section has sub-sections, then create a directory for it,
		--- and title this section "_index.md".
		if #section.children > 0 then
			path:push_directory(filename)
			path:set_filename("_index.md")
			--- The following code is equivalent:
			-- path = assert(path:join(filename .. "/_index.md"))
			return path
		end

		--- Otherwise, title it "{filename}.md"
		path:set_filename(filename .. ".md")
		return path
	end,

	transform_lines = function(section)
		--- Remove whitespace from the first line of the section.
		local lines = section:get_lines()
		lines[1] = utils.str.trim(lines[1])

		--- Then, add the open tag (the "#"s) back to the start of the first
		--- line.
		lines[1] = section:open_tag() .. lines[1]
		return lines
	end,

	resolve_reference = function(section)
		--- If the section isn't being saved to a file, then delete all lines
		--- corresponding to the section, and don't add a reference to the
		--- source file.
		if section.path:is_void() then
			return false
		end

		--- If the filename is just "_index.md", use the name of the directory
		--- as the reference instead of "_index.md". Otherwise, just use the
		--- filename.
		local filename = section.path:get_filename()
		if filename == "_index.md" then
			filename = section.path.parts[#section.path.parts - 1]
		end

		--- If the section open tag starts with a bullet point ("-"), then also
		--- add it to the reference.
		if utils.str.starts_with(section.type[2], "-") then
			return "- [[" .. filename .. "]]"
		end

		return "[[" .. filename .. "]]"
	end,

	resolve_collision = function(path, _, _, retry_count)
		--- Try to split the path into filename and extension, and return
		--- "{basename} ({retry_count}).{extension}" as the new name.
		local filename = path:get_filename()
		local name, extension = filename:match("^(.*)%.(.*)$")
		if name and extension then
			path:set_filename(name .. " (" .. retry_count .. ")." .. extension)
			return path
		end
		path:set_filename(filename .. " (" .. retry_count .. ")")
		return path
	end,

	--- Allow up to 16 config.resolve_collision() calls to be made for each
	--- section that gets mapped to the same path as another section by
	--- config.resolve_path(). After 16 attempts, throw an error.
	local_retry_count = 16,

	--- Allow up to 0 config.resolve_collision() calls to be made when trying
	--- to save a section to a path that already exists in the filesystem.
	retry_count = 0,

	--- Allow crazywall to create new directories and sub-directories if
	--- necessary to save a file.
	allow_makedir = true,

	--- Do not allow any section that gets mapped to the same path as a
	--- previous section to overwrite the previous section.
	allow_local_overwrite = false,

	--- Do not allow any section that gets mapped to the same path as an
	--- existing file in the filesystem to overwrite the file.
	allow_overwrite = false,
}

return default_config
