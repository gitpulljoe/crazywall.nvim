local utils = require("core.utils")
local Path = require("core.path")
local validate = require("core.validate")
local str = utils.str
local streams = require("core.streams")
local Config = require("core.config")

--- Represents the current state during execution, configuration options, and
--- command-line arguments.
--- @class (exact) Context
---
--- The current config being used.
--- @field config Config
---
--- The current state of the text.
--- At initialization, the source text is split by newlines. As section
--- references are resolved, their lines aren't actually "deleted", but they
--- are replaced with false. The methods `context:get_lines()`,
--- `section:get_lines()`, `context:get_text()`, `section:get_text()`, and
--- `utils.str.join_lines` will automatically handle this, and ignore those
--- lines.
--- @field lines (string|boolean)[]
---
--- Specifies if a mock filesystem is currently being used.
--- @field use_mock_filesystem boolean
---
--- The path to the input source file.
--- @field src_path Path
---
--- The destination path. If `--preserve` is passed, this will NOT be
--- Path.void().
--- @field dest_path Path
---
--- The mock filesystem being used, if any.
--- @field mock_filesystem MockFilesystem?
---
--- Specifies if `--dry-run` was passed. Does NOT specify if the current
--- execution step is a dry run or not.
--- @field is_dry_run boolean
---
--- Specifies if `--yes` was passed.
--- @field auto_confirm boolean
---
--- The stream to emit the plan object to.
--- @field plan_stream Stream
---
--- The stream to emit the destination text to.
--- @field text_stream Stream
---
--- Specifies if `--preserve` was passed.
--- @field preserve boolean
---
--- If `context.use_mock_filesystem`, then this will be the MockFS_IO
--- associated with the mock filesystem. Otherwise, will be the Lua `io`
--- library.
--- @field io iolib
---
--- Specifies if `--no-ansi` was not passed.
--- @field ansi_enabled boolean

local Context = {}
Context.__index = Context
Context.__name = "Context"

Context.errors = {

	---@param value number
	invalid_value_for_plan_stream = function(value)
		return "Invalid plan_stream value "
			.. value
			.. " passed to Config:new()"
	end,

	---@param value number
	invalid_value_for_text_stream = function(value)
		return "Invalid text_stream value "
			.. value
			.. " passed to Config:new()"
	end,
}

---@param config Config
---@param src_path string
---@param dest_path string
---@param inp string|string[]
---@param mock_filesystem MockFilesystem?
---@param is_dry_run boolean
---@param auto_confirm boolean
---@param plan_stream Stream
---@param text_stream Stream
---@param preserve boolean
---@param ansi_enabled boolean
---@return Context? ctx
---@return string? errmsg
function Context:new(
	config,
	src_path,
	dest_path,
	inp,
	mock_filesystem,
	is_dry_run,
	auto_confirm,
	plan_stream,
	text_stream,
	preserve,
	ansi_enabled
)
	self = {}
	---@cast self Context
	setmetatable(self, Context)

	local err = validate.are_instances("Context:new", {
		{ config, Config, "config" },
		mock_filesystem
				and { mock_filesystem, MockFilesystem, "mock_filesystem" }
			or nil,
	})
	if err then
		return nil, err
	end

	self.config = config or {}
	self.use_mock_filesystem = not not mock_filesystem
	self.mock_filesystem = mock_filesystem

	---@type unknown
	err = validate.types("Context:new", {
		{ src_path, "string", "src_path" },
		{ dest_path, "string?", "dest_path" },
		{ inp, "table|string", "inp" },
		{ auto_confirm, "boolean", "auto_confirm" },
		{ preserve, "boolean", "preserve" },
		{ is_dry_run, "boolean", "is_dry_run" },
		{ ansi_enabled, "boolean", "ansi_enabled" },
	})
	if err then
		return nil, err
	end

	if
		plan_stream ~= streams.NONE
		and plan_stream ~= streams.STDOUT
		and plan_stream ~= streams.STDERR
	then
		return nil, Context.errors.invalid_value_for_plan_stream(plan_stream)
	end
	if
		text_stream ~= streams.NONE
		and text_stream ~= streams.STDOUT
		and text_stream ~= streams.STDERR
	then
		return nil, Context.errors.invalid_value_for_text_stream(plan_stream)
	end

	self.lines = {}
	self.io = mock_filesystem and mock_filesystem.io or io
	self.preserve = preserve
	self.ansi_enabled = ansi_enabled
	self.is_dry_run = is_dry_run

	local lines = {}
	if type(inp) == type("") then
		---@cast inp string
		local data = str.split_lines(inp, true)
		for line in data do
			table.insert(lines, line)
		end
	else
		---@cast inp string[]
		for i, line in ipairs(inp) do
			---@type unknown
			err = validate.types("Context:new", {
				{ line, "string", "inp[" .. i .. "]" },
			})
			if err then
				return nil, err
			end

			table.insert(lines, tostring(line))
		end
	end

	self.lines = lines
	self.auto_confirm = auto_confirm
	self.plan_stream = plan_stream
	self.text_stream = text_stream
	local source, dest
	source, err = Path:new(src_path)
	if not source then
		return nil, err
	end
	self.src_path = source
	if not dest_path then
		return self
	end
	dest, err = Path:new(dest_path)
	if not dest then
		return nil, err
	end
	self.dest_path = dest
	return self
end

--- Returns the source text, but with the deleted lines removed. Lines are
--- deleted as section texts are replaced with references.
--- @return string[]
function Context:get_lines()
	local lines = {}
	for _, line in ipairs(self.lines) do
		if line ~= false then
			table.insert(lines, line)
		end
	end
	return lines
end

--- Returns the current state of the source text.
--- @return string
function Context:get_text()
	return utils.str.join_lines(self:get_lines())
end

return Context
