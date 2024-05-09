local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("puff.input", "info")
local bufmap = require("infra.keymap.buffer")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")

local api = vim.api

local InputCollector
do
  ---@class puff.InputCollector
  ---@field bufnr integer
  ---@field value? string
  local Impl = {}
  Impl.__index = Impl

  function Impl:collect()
    assert(buflines.count(self.bufnr) == 1)
    self.value = buflines.line(self.bufnr, 0)
  end

  ---@param bufnr integer
  ---@return puff.InputCollector
  function InputCollector(bufnr) return setmetatable({ bufnr = bufnr }, Impl) end
end

---@param input? puff.InputCollector
---@param stop_insert boolean
local function make_closewin_rhs(input, stop_insert)
  return function()
    if input ~= nil then input:collect() end
    if stop_insert then ex("stopinsert") end
    api.nvim_win_close(0, false)
  end
end

---@class puff.input.Opts
---@field prompt? string
---@field default? string
---@field startinsert? 'i'|'a'|'I'|'A'false @nil=false
---@field wincall? fun(winid: integer, bufnr: integer) @timing: just created the win without setting any winopts
---@field bufcall? fun(bufnr: integer) @timing: just created the buf without setting any bufopts

---opts.{completion,highlight} are not supported
---@param opts puff.input.Opts
---@param on_complete fun(input_text?: string)
return function(opts, on_complete)
  local bufnr
  do
    local function namefn(nr) return string.format("input://%s/%d", opts.prompt, nr) end
    bufnr = Ephemeral({ modifiable = true, undolevels = 1, namefn = namefn }, opts.default and { opts.default } or nil)
    --todo: show prompt as inline extmark

    if opts.bufcall then opts.bufcall(bufnr) end

    local input = InputCollector(bufnr)

    api.nvim_create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        vim.schedule(function() -- to avoid 'Vim:E1159: Cannot split a window when closing the buffer'
          on_complete(input.value)
        end)
      end,
    })

    local bm = bufmap.wraps(bufnr)

    bm.i("<cr>", make_closewin_rhs(input, true))
    bm.i("<c-c>", make_closewin_rhs(nil, true))
    bm.n("<cr>", make_closewin_rhs(input, false))

    do
      local rhs = make_closewin_rhs(nil, false)
      bm.n("q", rhs)
      bm.n("<esc>", rhs)
      bm.n("<c-[>", rhs)
      bm.n("<c-]>", rhs)
    end

    do
      local function rhs() jelly.info("o/O/yy has no effect here") end
      bm.n("o", rhs)
      bm.n("O", rhs)
      bm.n("yy", rhs)
      --todo: yyp
    end
  end

  local winid
  do
    local width = opts.default and math.max(#opts.default, 50) or 50
    local winopts = { relative = "cursor", row = 1, col = 2, width = width, height = 1 }
    winid = rifts.open.win(bufnr, true, winopts)
    if opts.default then wincursor.go(winid, 0, #opts.default) end
    if opts.wincall then opts.wincall(winid, bufnr) end
  end

  if opts.startinsert then feedkeys(opts.startinsert, "n") end
end
