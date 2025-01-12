local M = {}

---@param code number
---@param close_code number?
local apply_code = function(code, close_code)
	close_code = close_code or 39
	---@param str string
	---@return string
	return function(str)
		return string.format("\27[%dm%s\27[%dm", code, str, close_code)
	end
end

---@alias ANSI_Func (fun(s: string): string)|({ __call: ANSI_Func})

---@param code number
---@return { __call: ANSI_Func; bg: ANSI_Func; bright: ANSI_Func; bright_bg: ANSI_Func}
local function color(code)
	return setmetatable({
		bg = apply_code(code + 10, 49),
		bright = apply_code(code + 60),
		bright_bg = apply_code(code + 70, 49),
	}, {
		__call = function(_, str)
			return apply_code(code)(str)
		end,
	})
end

---@param func1 ANSI_Func
---@param func2 ANSI_Func
---@return ANSI_Func
M.compose = function(func1, func2)
	---@param str string
	---@return string
	return function(str)
		return func1(func2(str))
	end
end

M.black = color(30)
M.red = color(31)
M.green = color(32)
M.yellow = color(33)
M.blue = color(34)
M.magenta = color(35)
M.cyan = color(36)
M.white = color(37)

M.none = function(str)
	return str
end
M.bold = apply_code(1, 22)
M.italic = apply_code(3, 23)

return M
