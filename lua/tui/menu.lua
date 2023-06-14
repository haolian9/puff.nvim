-- a drop-in replacement of vim.ui.select, just like tmux's display-menu
--
--design
--* keys are subset of [a-z]
--  * order is predicatable
--* singleton, and reuses a dedicated buffer
--* compact window layout, less eyes movement
--  * respects cursor position
--  * respects #choices and max(#each-choice)
--* dont reset window options and buffer lines initiatively

local jelly = require("infra.jellyfish")("tui.menu")
local fn = require("infra.fn")
local bufrename = require("infra.bufrename")
local prefer = require("infra.prefer")
local bufmap = require("infra.keymap.buffer")

local api = vim.api

local Keys = {}
do
  local list = {}
  local dict = {}
  do
    local str = "asdfjkl" .. "gh" .. "wertyuiop" .. "zxcvbnm"
    for i = 1, #str do
      local char = string.sub(str, i, i)
      list[i] = char
      dict[char] = i
    end
    assert(not fn.contains(list, "q"), "q is reserved for quit")
  end

  function Keys.index(key) return dict[key] end
  function Keys.iter() return fn.iter(list) end
end

local state = { bufnr = nil, winid = nil, using = false, entries = nil, choice = nil }
do
  ---@return number
  function state:prepare_buffer()
    if state.bufnr ~= nil then
      assert(api.nvim_buf_is_valid(state.bufnr), "unreachable")
      return state.bufnr
    end

    state.bufnr = api.nvim_create_buf(false, true)
    bufrename(state.bufnr, "tui://menu")
    for key in Keys.iter() do
      -- unable to use infra.keymap.buffer here
      api.nvim_buf_set_keymap(state.bufnr, "n", key, "", {
        noremap = true,
        nowait = true,
        callback = function()
          local n = assert(Keys.index(key), "unreachable: invalid key")
          -- not a present entry, do nothing
          if n > #self.entries then return end
          state.choice = n
          api.nvim_win_close(state.winid, false)
        end,
      })
    end

    local bm = bufmap.wraps(state.bufnr)
    for key in fn.iter({ "q", "<esc>", "<c-[>", "<c-]>" }) do
      bm.n(key, function() api.nvim_win_close(state.winid, false) end)
    end

    return state.bufnr
  end

  function state:cleanup()
    state.winid = nil
    state.using = false
    state.entries = nil
    state.choice = nil
  end
end

---@param entries string[]
---@param opts {prompt: string?, format_item: fun(entry: string): (string), kind: string?}
---@param callback fun(entry: string?, index: number?)
return function(entries, opts, callback)
  local formatter
  do
    if opts.kind ~= nil then
      formatter = assert(opts.format_item, "opts.format_item is required for custom opts.kind")
    else
      -- stylua: ignore
      formatter = opts.format_item or function(ent) return ent end
    end
  end
  local prompt = opts.prompt
  local has_prompt = prompt ~= nil

  if state.using then return jelly.err("a menu is just displaying, complete it to continue!") end
  assert(state.winid == nil and state.choice == nil, "unreachable: dirty state")
  state.using = true

  state:prepare_buffer()
  state.entries = entries

  local win_height
  local win_width
  do
    local lines = {}
    local line_max = 0
    local key_iter = Keys.iter()
    for ent in fn.iter(state.entries) do
      local key = assert(key_iter(), "no more lhs is available")
      local line = string.format(" %s. %s", key, formatter(ent))
      table.insert(lines, line)
      if #line > line_max then line_max = #line end
    end
    api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
    win_height = #lines
    -- 1->winbar
    if has_prompt then win_height = win_height + 1 end
    -- 1->留白
    win_width = line_max + 1
    if has_prompt then win_width = math.max(win_width, math.min(#prompt, 20)) end
  end

  do
    -- stylua: ignore
    state.winid = api.nvim_open_win(state.bufnr, true, {
      relative = "cursor", row = 1, col = 0, width = win_width, height = win_height,
      style = "minimal",
    })
    prefer.wo(state.winid, "winbar", prompt or "")

    api.nvim_create_autocmd("winleave", {
      buffer = state.bufnr,
      once = true,
      nested = true, -- so that we can trigger the winclosed event
      callback = function() api.nvim_win_close(state.winid, false) end,
    })

    api.nvim_create_autocmd("winclosed", {
      buffer = state.bufnr,
      once = true,
      callback = function()
        local choice = state.choice
        state:cleanup()
        if choice ~= nil then
          callback(entries[choice], choice)
        else
          callback(nil, nil)
        end
      end,
    })
  end

  -- there is no easy way to hide the cursor, let it be there
end
