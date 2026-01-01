local M = {}

local oop = require("infra.oop")

M.input = oop.proxy("puff.input")
M.moreinput = oop.proxy("puff.moreinput")
M.select = oop.proxy("puff.select")
M.confirm = oop.proxy("puff.confirm")

return M
