local utils = require("core.utils")

---@alias Stream 0|1|2

local M = {
	NONE = 0,
	STDOUT = 1,
	STDERR = 2,
}

return utils.read_only(M)
