local bufrename = require("infra.bufrename")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

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

local next_id
do
  local count = 0
  function next_id()
    count = count + 1
    return count
  end
end

---opts.{completion,highlight} are not supported
---@param opts {prompt?: string, default?: string, enter_insertmode?: boolean}
---@param on_complete fun(input_text?: string)
return function(opts, on_complete)
  local id = next_id()

  local bufnr
  do
    bufnr = Ephemeral({ modifiable = true, undolevels = 1 }, opts.default and { opts.default } or nil)
    bufrename(bufnr, string.format("tui://input#%d", id))

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
  do -- setup window
    local width = opts.default and math.max(#opts.default, 50) or 50
    local height = opts.prompt and 2 or 1
    winid = api.nvim_open_win(bufnr, true, { relative = "cursor", style = "minimal", row = 1, col = 0, width = width, height = height })
    if opts.prompt then prefer.wo(winid, "winbar", opts.prompt) end
    if opts.enter_insertmode then ex("startinsert") end
  end
end
