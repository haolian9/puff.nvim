-- a drop-in replacement of vim.ui.select, just like tmux's display-menu
--
--design
--* keys are subset of [a-z]
--  * order is predicatable
--* each menu have its own buffer, multiple menus can appear at the same time
--* compact window layout, less eyes movement
--  * respects cursor position
--  * respects #choices and max(#each-choice)
--* dont reset window options and buffer lines initiatively

local bufrename = require("infra.bufrename")
local Ephemeral = require"infra.Ephemeral"
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("tui.Menu")
local prefer = require("infra.prefer")

local api = vim.api

---@class tui.Menu
---@field private id integer
---@field private key_pool tui.KeyPool
local Menu = {}
do
  Menu.__index = Menu

  ---@param entries string[]
  ---@param formatter fun(entry: string):string
  ---@param prompt? string
  ---@param callback fun(entry: string?, index: number?)
  function Menu:display(entries, formatter, prompt, callback)
    local lines = {}
    do
      local key_iter = self.key_pool:iter()
      for _, ent in ipairs(entries) do
        local key = assert(key_iter(), "no more lhs is available")
        local line = string.format(" %s. %s", key, formatter(ent))
        table.insert(lines, line)
      end
    end

    local win_height, win_width
    do
      local line_max = 0
      for _, line in ipairs(lines) do
        if #line > line_max then line_max = #line end
      end
      win_height = #lines
      win_width = line_max + 1
      if prompt ~= nil then
        -- 1->winbar
        win_height = win_height + 1
        -- 1->留白
        win_width = math.max(win_width, math.min(#prompt, 20))
      end
    end

    local canvas = { entries = entries, callback = callback, choice = nil, bufnr = nil, winid = nil }

    do -- setup buf
      canvas.bufnr = Ephemeral(nil, lines)

      bufrename(canvas.bufnr, string.format("tui://menu#%d", self.id))

      for key in self.key_pool:iter() do
        -- unable to use infra.keymap.buffer here
        api.nvim_buf_set_keymap(canvas.bufnr, "n", key, "", {
          noremap = true,
          nowait = true,
          callback = function()
            local n = assert(self.key_pool:index(key), "unreachable: invalid key")
            -- not a present entry, do nothing
            if n > api.nvim_buf_line_count(canvas.bufnr) then return jelly.info("no such option: %s", key) end
            canvas.choice = n
            api.nvim_win_close(canvas.winid, false)
          end,
        })
      end

      handyclosekeys(canvas.bufnr)

      api.nvim_create_autocmd("bufwipeout", {
        buffer = canvas.bufnr,
        once = true,
        callback = function()
          local choice = canvas.choice
          canvas.callback(canvas.entries[choice], choice)
        end,
      })
    end

    do -- display
      local winid = api.nvim_open_win(canvas.bufnr, true, { relative = "cursor", row = 1, col = 0, width = win_width, height = win_height, style = "minimal" })
      canvas.winid = winid
      prefer.wo(winid, "winbar", prompt or "")
    end

    -- there is no easy way to hide the cursor, let it be there
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

---@param key_pool tui.KeyPool
---@return tui.Menu
return function(key_pool) return setmetatable({ id = next_id(), key_pool = key_pool }, Menu) end
