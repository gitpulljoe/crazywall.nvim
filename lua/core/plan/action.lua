local utils = require("core.utils")
local Path = require("core.path")
local ansi = require("core.ansi")

---@alias CREATE_ACTION { type: "CREATE", path: Path, lines: string[], tostring: fun(self: Action, enable_ansi: boolean?): string }
---@alias OVERWRITE_ACTION { type: "OVERWRITE", path: Path, lines: string[], tostring: fun(self: Action, enable_ansi: boolean?): string }
---@alias MKDIR_ACTION { type: "MKDIR", path: Path, tostring: fun(self: Action, enable_ansi: boolean?): string }
---@alias IGNORE_ACTION { type: "IGNORE", path: Path, lines: string[], tostring: fun(self: Action, enable_ansi: boolean?): string }
---@alias RENAME_ACTION { type: "RENAME", path: Path, new_path: Path, tostring: fun(self: Action, enable_ansi: boolean?): string }

---@alias Action CREATE_ACTION|OVERWRITE_ACTION|MKDIR_ACTION|IGNORE_ACTION|RENAME_ACTION

local M = {}

M.CREATE = "CREATE"
M.OVERWRITE = "OVERWRITE"
M.MKDIR = "MKDIR"
M.IGNORE = "IGNORE"
M.RENAME = "RENAME"

--- @param self Action
--- @param enable_ansi boolean
--- @return string
local tostring = function(self, enable_ansi)
	local color = enable_ansi
			and (({
				[M.CREATE] = ansi.green,
				[M.MKDIR] = ansi.yellow,
				[M.OVERWRITE] = ansi.magenta,
				[M.IGNORE] = ansi.red,
				[M.RENAME] = ansi.cyan,
			})[self.type] or error("Unknown action type: " .. self.type))
		or ansi.none
	local bold = enable_ansi and ansi.bold or ansi.none
	local text = bold(
		"[ "
			.. string.rep(" ", #"OVERWRITE" - #self.type)
			.. self.type
			.. " ]  "
	)
	local line_count_str = "-"
	local char_count_str = "-"
	if self.lines then
		line_count_str = tostring(#self.lines)
		local char_count = 0
		for _, line in ipairs(self.lines) do
			char_count = char_count + #line
		end
		char_count_str = tostring(char_count)
	end
	return color(
		text
			.. string.rep(" ", #"lines " - #line_count_str)
			.. line_count_str
			.. "  "
			.. string.rep(" ", #"chars " - #char_count_str)
			.. char_count_str
			.. "  "
			.. tostring(self.path)
			.. (self.type == M.RENAME and "\n" .. string.rep(
				" ",
				#"action         lines   chars   " - #"->  "
			) .. "->  " .. tostring(self.new_path) or "")
	)
end

---@param path Path
---@param lines string[]
---@return CREATE_ACTION
function M.create(path, lines)
	local corrected_lines = {}
	for _, line in ipairs(lines) do
		if line ~= false then
			table.insert(corrected_lines, line)
		end
	end
	---@type CREATE_ACTION
	local action = {
		type = M.CREATE,
		path = path,
		lines = corrected_lines,
		tostring = tostring,
	}
	return utils.read_only(action)
end

---@param path Path
---@param lines string[]
---@return OVERWRITE_ACTION
function M.overwrite(path, lines)
	local corrected_lines = {}
	for _, line in ipairs(lines) do
		if line ~= false then
			table.insert(corrected_lines, line)
		end
	end
	---@type OVERWRITE_ACTION
	local action = {
		type = M.OVERWRITE,
		path = path,
		lines = corrected_lines,
		tostring = tostring,
	}
	return utils.read_only(action)
end

---@param dir Path
---@return MKDIR_ACTION
function M.mkdir(dir)
	---@type MKDIR_ACTION
	local action = {
		type = M.MKDIR,
		path = dir,
		tostring = tostring,
	}
	return utils.read_only(action)
end

---@param lines string[]
---@return IGNORE_ACTION
function M.ignore(lines)
	local corrected_lines = {}
	for _, line in ipairs(lines) do
		if line ~= false then
			table.insert(corrected_lines, line)
		end
	end
	---@type IGNORE_ACTION
	local action = {
		type = M.IGNORE,
		path = Path.void(),
		lines = corrected_lines,
		tostring = tostring,
	}
	return utils.read_only(action)
end

---@param original_path Path
---@param new_path Path
---@return RENAME_ACTION
function M.rename(original_path, new_path)
	---@type RENAME_ACTION
	local action = {
		type = M.RENAME,
		path = original_path,
		new_path = new_path,
		tostring = tostring,
	}
	return utils.read_only(action)
end

return M
