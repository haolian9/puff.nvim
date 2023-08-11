local bufrename = require("infra.bufrename")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local bufmap = require("infra.keymap.buffer")

local api = vim.api

local InputCollector
do
  ---@class tui.InputCollector
  ---@field bufnr integer
  ---@field value? string
  local Prototype = {}
  Prototype.__index = Prototype

  function Prototype:collect()
    assert(api.nvim_buf_line_count(self.bufnr) == 1)
    local lines = api.nvim_buf_get_lines(self.bufnr, 0, 1, false)
    self.value = lines[1]
  end

  ---@param bufnr integer
  ---@return tui.InputCollector
  function InputCollector(bufnr) return setmetatable({ bufnr = bufnr }, Prototype) end
end

---@param input? tui.InputCollector
---@param stop_insert? boolean @nil=false
local function make_rhs(input, stop_insert)
  return function()
    if input ~= nil then input:collect() end
    if stop_insert then ex("stopinsert") end
    api.nvim_win_close(0, false)
  end
end

---@class tui.input.Opts
---@field prompt? string
---@field default? string
---@field startinsert? boolean @nil=false
---@field wincall? fun(winid: integer, bufnr: integer)

---opts.{completion,highlight} are not supported
---@param opts tui.input.Opts
---@param on_complete fun(input_text?: string)
return function(opts, on_complete)
  local bufnr
  do
    bufnr = Ephemeral({ modifiable = true, undolevels = 1 }, opts.default and { opts.default } or nil)
    bufrename(bufnr, string.format("input://%s/%d", opts.prompt, bufnr))
    local input = InputCollector(bufnr)
    do
      local bm = bufmap.wraps(bufnr)
      bm.i("<cr>", make_rhs(input, true))
      bm.i("<c-c>", make_rhs(nil, true))
      bm.n("<cr>", make_rhs(input))
      local rhs_noinput = make_rhs()
      bm.n("q", rhs_noinput)
      bm.n("<esc>", rhs_noinput)
      bm.n("<c-[>", rhs_noinput)
      bm.n("<c-]>", rhs_noinput)
    end
    api.nvim_create_autocmd("bufwipeout", { buffer = bufnr, once = true, callback = function() on_complete(input.value) end })
  end

  local winid
  do
    local width = opts.default and math.max(#opts.default, 50) or 50
    winid = api.nvim_open_win(bufnr, true, { relative = "cursor", style = "minimal", row = 1, col = 2, width = width, height = 1 })
    if opts.default then api.nvim_win_set_cursor(winid, { 1, #opts.default }) end
  end

  if opts.wincall then opts.wincall(winid, bufnr) end
  if opts.startinsert then ex("startinsert") end
end
