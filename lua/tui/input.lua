local bufrename = require("infra.bufrename")
local prefer = require("infra.prefer")
local bufmap = require("infra.keymap.buffer")

local api = vim.api

local state = { using = false, bufnr = nil, callback = nil, winid = nil, no_autocmd = false }
do
  local function complete(input)
    api.nvim_win_close(state.winid, false)
    local ok, err = xpcall(state.callback, debug.traceback, input)
    do
      -- the buffer should be reused
      api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {})
      state.using = false
      state.callback = nil
      state.winid = nil
      state.no_autocmd = false
    end
    if not ok then error(err) end
  end

  local function resume()
    state.no_autocmd = true

    local input
    do
      assert(api.nvim_buf_line_count(state.bufnr) == 1, "unreachable")
      local lines = api.nvim_buf_get_lines(state.bufnr, 0, 1, false)
      input = lines[1]
    end

    complete(input)
  end

  local function cancel()
    state.no_autocmd = false
    complete()
  end

  function state:prepare_buffer()
    if self.bufnr ~= nil and api.nvim_buf_is_valid(self.bufnr) then return end

    self.bufnr = api.nvim_create_buf(false, true)
    bufrename(self.bufnr, "tui://input")

    local bm = bufmap.wraps(state.bufnr)

    bm.i("<cr>", function()
      vim.cmd.stopinsert()
      -- todo: nvim bug: stopinsert wont work without this .schedule()
      vim.schedule(resume)
    end)
    bm.i("<c-c>", function()
      vim.cmd.stopinsert()
      -- todo: nvim bug: stopinsert wont work without this .schedule()
      vim.schedule(cancel)
    end)
    bm.n("<cr>", resume)
    bm.n("q", cancel)
    bm.n("<c-]>", cancel)

    api.nvim_create_autocmd("winclosed", {
      buffer = state.bufnr,
      once = true,
      callback = function()
        if self.no_autocmd then return end
        cancel()
      end,
    })
  end
end

---@param opts {prompt?: string, default?: string, completion?: string, heighlight: fun()}
---@param on_confirm fun(input?: string)
return function(opts, on_confirm)
  assert(on_confirm)

  assert(not state.using, "another input is being used")
  state.using = true

  state:prepare_buffer()
  assert(api.nvim_buf_line_count(state.bufnr) == 1)

  do -- setup window
    local width
    if opts.default == nil then
      width = 50
    else
      width = math.max(#opts.default, 50)
    end
    local height = opts.prompt and 2 or 1
    state.winid = api.nvim_open_win(state.bufnr, true, { relative = "cursor", style = "minimal", row = 1, col = 0, width = width, height = height })

    if opts.prompt then prefer.wo(state.winid, "winbar", opts.prompt) end

    if opts.default then
      api.nvim_buf_set_lines(state.bufnr, 0, 1, false, { opts.default })
      api.nvim_win_set_cursor(state.winid, { 1, #opts.default })
    end
  end

  state.callback = on_confirm
end
