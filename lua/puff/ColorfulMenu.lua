local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("puff.ColorfulMenu")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")

local facts = {}
do
  do
    local hi = highlighter(0)

    if vim.go.background == "light" then
      hi("PuffColorfulMenuOption", { fg = 27, bold = true })
    else
      hi("PuffColorfulMenuOption", { fg = 33, bold = true })
    end
  end

  facts.ns = ni.create_namespace("puff://colorfulmenu")
end

---@param spec puff.Menu.Spec
---@return integer bufnr
local function create_buf(spec)
  assert(#spec.entries <= #spec.key_pool.list, "no enough keys for puff.menu entries")

  local bufnr
  do
    local lines = {}
    if spec.subject ~= nil then table.insert(lines, spec.subject) end
    if spec.desc ~= nil then listlib.extend(lines, spec.desc) end
    listlib.extend(lines, itertools.map(spec.entries, spec.entfmt))

    bufnr = Ephemeral({ namepat = "puff://menu/{bufnr}", handyclose = true }, lines)
  end

  do
    local offset = 0
    if spec.subject ~= nil then offset = offset + 1 end
    if spec.desc ~= nil then offset = offset + #spec.desc end
    for index = 1, #spec.entries do
      local lnum = index - 1 + offset
      local key = assert(spec.key_pool.list[index])
      ni.buf_set_extmark(bufnr, facts.ns, lnum, 0, {
        virt_text_pos = "inline",
        virt_text = { { key, "PuffColorfulMenuOption" }, { ". " } },
        hl_mode = "replace",
        right_gravity = false,
      })
    end
  end

  do
    local index

    local bm = bufmap.wraps(bufnr)
    for _, key in ipairs(spec.key_pool.list) do
      bm.n(key, function()
        local n = assert(spec.key_pool:index(key), "unreachable: invalid key")
        -- not a present entry, do nothing
        if n > buflines.count(bufnr) then return jelly.info("no such option: %s", key) end
        index = n
        ni.win_close(0, false)
      end)
    end

    bm.n("<cr>", "<nop>")

    ni.create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        local choice = spec.entries[index]
        vim.schedule(function() -- to avoid 'Vim:E1159: Cannot split a window when closing the buffer'
          spec.on_decide(choice, choice ~= nil and index or nil)
        end)
      end,
    })
  end

  return bufnr
end

---@param spec puff.Menu.Spec
---@param bufnr integer
---@return integer winid
local function open_win(spec, bufnr)
  local winopts
  do
    local height = buflines.count(bufnr)

    local width = 0
    width = width + 3 -- #'a. '
    for _, len in unsafe.linelen_iter(bufnr, itertools.range(height)) do
      if len > width then width = len end
    end
    width = width + 1 + 1 -- 留白

    winopts = { relative = "cursor", row = 1, col = 0, width = width, height = height }
  end

  local winid = rifts.open.win(bufnr, true, winopts)

  do --cursor
    local lnum = 0
    if spec.subject then lnum = lnum + 1 end
    if spec.desc then lnum = lnum + #spec.desc end

    wincursor.go(winid, lnum, 0)
  end

  return winid
end

---@param spec puff.Menu.Spec
---@return integer winid
---@return integer bufnr
return function(spec)
  local bufnr = create_buf(spec)
  local winid = open_win(spec, bufnr)

  -- there is no easy way to hide the cursor, let it be there
  return winid, bufnr
end

