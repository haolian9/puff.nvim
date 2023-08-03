local KeyPool = require("tui.KeyPool")
local Menu = require("tui.Menu")

local M = {}

M.input = require("tui.input")

do
  local key_pool = KeyPool("asdfjkl" .. "gh" .. "wertyuiop" .. "zxcvbnm")
  local function default_formatter(ent) return ent end

  ---@param entries string[]
  ---@param opts {prompt: string?, format_item: fun(entry: string): (string), kind: string?}
  ---@param callback fun(entry: string?, index: number?)
  function M.select(entries, opts, callback)
    opts = opts or {}

    local formatter
    if opts.kind ~= nil then
      formatter = assert(opts.format_item, "opts.format_item is required for custom opts.kind")
    else
      formatter = opts.format_item or default_formatter
    end

    local menu = Menu(key_pool)
    menu:display(entries, formatter, opts.prompt, callback)
  end
end

do
  local key_pool = KeyPool("yn")
  local ents = { "yes! go ahead", "no! wait" }
  local function fmt(ent) return ent end

  ---@param opts {prompt?: string}
  ---@param on_decide fun(confirmed: boolean)
  function M.confirm(opts, on_decide)
    local menu = Menu(key_pool)
    menu:display(ents, fmt, opts.prompt, function(_, index) on_decide(index == 1) end)
  end
end

return M
