local validate = require("core.validate")
local default_config = require("core.defaults.config")

--- @alias NoteSchema [string, string, string][]

--- Configuration options for crazywall.
--- All missing fields will use the defaults in `./core/defaults/config.lua`.
--- @class (exact) PartialConfigTable
---
--- Defines a schema for note types with their corresponding open and close
--- tags. Should be a list of `{ note_type_name, open_tag, close_tag }` lists.
---
--- Example:
--- ```lua
--- 	{ { "Heading", "# ", "[!end]" } }
--- ```
--- @field note_schema NoteSchema?
---
--- Callback to determine the destination `Path` of `section`.
--- Both `section` and `context` are read_only.
--- @field resolve_path (fun(section: Section, context: Context): Path)|nil
---
--- Callback to generate the text content to be written to the destination
--- path of `section`. It should return an array of strings, which will be
--- joined together with newlines and written to `section.path` during
--- execution. Both `section` and `context` are read_only.
--- @field transform_lines (fun(section: Section, context: Context): string[])|nil
---
--- Callback to resolve the "reference" of the section. During the execute
--- step, once the destination text is resolved using `transform_lines`, all of
--- the text content within the section will be replaced with this reference.
--- Return `false` to indicate no reference, in which case the entire section
--- will be deleted.
--- Both `section` and `context` are read_only.
--- @field resolve_reference (fun(section: Section, context: Context): string|boolean)|nil
---
--- Number of attempts to try resolving a local collision (two sections
--- assigned the same path).
--- @field local_retry_count number?
---
--- Number of attempts to try resolving a nonlocal collision (the path
--- assigned to a section is already occupied by another file).
--- @field retry_count number?
---
--- Callback to resolve a local/nonlocal path collision.
--- Both `section` and `context` are read_only.
--- @field resolve_collision (fun(path: Path, section: Section, context: Context, retry_count: number): Path)|nil
---
--- Specifies if a section is allowed to overwrite a previous section if they
--- were both assigned the same path.
--- @field allow_local_overwrite boolean?
---
--- Specifies if a section is allowed to overwrite a file in the filesystem
--- when necessary.
--- @field allow_overwrite boolean?
---
--- Specifies if creating directories when necessary, is allowed.
--- @field allow_makedir boolean?

--- @class Config
--- @field note_schema NoteSchema
--- @field resolve_path fun(section: Section, context: Context): Path
--- @field transform_lines fun(section: Section, context: Context): string[]
--- @field resolve_reference fun(section: Section, context: Context): string|boolean
--- @field retry_count number
--- @field local_retry_count number
--- @field resolve_collision fun(path: Path, section: Section, context: Context, retry_count: number): Path
--- @field allow_local_overwrite boolean
--- @field allow_overwrite boolean
--- @field allow_makedir boolean
local Config = {}
Config.__index = Config
Config.__name = "Config"

Config.errors = {

	--- @param list table
	--- @return string errmsg
	missing_item_in_note_schema_list = function(list, idx)
		return "Missing "
			.. (#list <= 1 and "open-tag" or "close-tag")
			.. "in config.note_schema["
			.. idx
			.. "]."
	end,

	--- @return string errmsg
	root_reserved = function()
		return "Cannot use "
			.. "ROOT"
			.. " as the name of a note type in `config.note_schema`."
	end,

	--- @param key string
	unexpected_key = function(key)
		return "Unexpected key " .. key .. " in config."
	end,
}

--- @param config_table PartialConfigTable
--- @return Config? config
--- @return string? errmsg
function Config:new(config_table)
	self = {}
	--- @cast self Config
	setmetatable(self, Config)
	local err = validate.types("Config:new", {
		{ config_table, "table", "config_table" },
	}) or validate.types("Config:new", {
		{ config_table.note_schema, "table?", "note_schema" },
		{ config_table.resolve_path, "function?", "resolve_path" },
		{ config_table.transform_lines, "function?", "transform_lines" },
		{ config_table.resolve_reference, "function?", "resolve_reference" },
		{ config_table.retry_count, "number?", "retry_count" },
		{ config_table.local_retry_count, "number?", "local_retry_count" },
		{ config_table.resolve_collision, "function?", "resolve_collision" },
		{ config_table.allow_overwrite, "boolean?", "allow_overwrite" },
		{
			config_table.allow_local_overwrite,
			"boolean?",
			"allow_local_overwrite",
		},
		{ config_table.allow_makedir, "boolean?", "allow_makedir" },
	})
	if err then
		return nil, err
	end
	for key, _ in pairs(config_table) do
		if default_config[key] == nil then
			return nil, Config.errors.unexpected_key(key)
		end
	end
	local note_schema = config_table.note_schema or default_config.note_schema
	for i, note_type in ipairs(note_schema) do
		local curr_string = "config_table.note_schema[" .. i .. "]"
		if #note_type < 3 then
			return nil,
				Config.errors.missing_item_in_note_schema_list(note_type, i)
		end
		err = validate.types("Config:new", {
			{ note_type[1], "string", curr_string .. "[1]" },
			{ note_type[2], "string", curr_string .. "[2]" },
			{ note_type[3], "string", curr_string .. "[3]" },
		})
		if err then
			return nil, err
		end
		if note_type[1] == "ROOT" then
			return nil, Config.errors.root_reserved()
		end
	end
	self.note_schema = note_schema
	self.resolve_path = config_table.resolve_path or default_config.resolve_path
	self.transform_lines = config_table.transform_lines
		or default_config.transform_lines
	self.resolve_reference = config_table.resolve_reference
		or default_config.resolve_reference
	self.retry_count = config_table.retry_count or default_config.retry_count
	self.local_retry_count = config_table.local_retry_count
		or default_config.local_retry_count
	self.resolve_collision = config_table.resolve_collision
		or default_config.resolve_collision
	self.allow_overwrite = (function()
		if config_table.allow_overwrite == nil then
			return default_config.allow_overwrite
		end
		return config_table.allow_overwrite
	end)()
	self.allow_local_overwrite = (function()
		if config_table.allow_local_overwrite == nil then
			return default_config.allow_local_overwrite
		end
		return config_table.allow_local_overwrite
	end)()
	self.allow_makedir = (function()
		if config_table.allow_makedir == nil then
			return default_config.allow_makedir
		end
		return config_table.allow_makedir
	end)()
	return self
end

return Config
