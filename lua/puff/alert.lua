---design choices
---* learn from dunst
---* position: right top
---* show multiple alerts with stack form
---* urgency: low, normal, critical
---* timeout
---* consist of: summary, body, icon/category/subject/source
---* no animation: slide, fade ...

local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local jelly = require("infra.jellyfish")("puff.alert", "debug")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")

local api = vim.api
local uv = vim.uv

local xmark_ns = api.nvim_create_namespace("puff.alert.icons")

local urgency_hi = { low = "JellyDebug", normal = "JellyInfo", critical = "JellyError" }

local function create_buf() --
  return Ephemeral({ name = "puff://alert" })
end

local bufnr, winid

local dismiss_at --os.time(), unix timestamp, in seconds
local timer = uv.new_timer()

---@param summary string
---@param body string[]
---@param icon? string
---@param urgency 'low'|'normal'|'critical'
---@param timeout integer @in second
return function(summary, body, icon, urgency, timeout)
  assert(timeout > 0 and timeout < 5, "unreasonable timeout value")

  if not (bufnr and api.nvim_buf_is_valid(bufnr)) then bufnr = create_buf() end

  timer:stop()

  do --adjust dismiss_at
    local now = os.time()
    if dismiss_at == nil then
      dismiss_at = now + timeout
    else
      dismiss_at = math.min(now + 5, dismiss_at + timeout)
    end
    jelly.debug("dismiss_at: %s", dismiss_at)
  end

  do --summary line
    local high = buflines.high(bufnr)
    local text = { { summary, "JellySource" } }
    if icon ~= nil then table.insert(text, 1, { icon }) end

    if high == 0 then
      api.nvim_buf_set_extmark(bufnr, xmark_ns, 0, 0, { virt_text = text, virt_text_pos = "inline", right_gravity = false })
    else
      buflines.appends(bufnr, high, { "", "" })
      local lnum = high + 2
      api.nvim_buf_set_extmark(bufnr, xmark_ns, lnum, 0, { virt_text = text, virt_text_pos = "inline", right_gravity = false })
    end
  end

  do --body lines
    assert(#body > 0)
    local high = buflines.high(bufnr)
    local hi = urgency_hi[urgency]

    buflines.appends(bufnr, high, listlib.zeros(#body, ""))

    for i, line in ipairs(body) do
      local lnum = high + i
      api.nvim_buf_set_extmark(bufnr, xmark_ns, lnum, 0, { virt_text = { { line, hi } }, virt_text_pos = "inline", right_gravity = false })
    end
  end

  if not (winid and api.nvim_win_is_valid(winid)) then
    winid = rifts.open.fragment(bufnr, false, {
      relative = "editor",
      border = "single",
      title = "flashes",
      title_pos = "center",
    }, {
      width = 25,
      height = buflines.count(bufnr),
      horizontal = "right",
      vertical = "top",
    })
    prefer.wo(winid, "wrap", true)
  else
    local line_count = buflines.count(bufnr)
    local height_max = math.floor(vim.go.lines * 0.5)
    jelly.debug("line_count=%s, height_max=%s", line_count, height_max)
    api.nvim_win_set_config(winid, { height = math.min(line_count, height_max) })
  end

  wincursor.follow(winid)

  do
    local dismiss = vim.schedule_wrap(function()
      if not api.nvim_win_is_valid(winid) then goto reset end

      --if the window get focused, wait for next round
      if api.nvim_get_current_win() == winid then return end

      --still has time
      if os.time() < dismiss_at then return end

      --now we need to close the win
      api.nvim_win_close(winid, false)

      ::reset::
      timer:stop()
      dismiss_at = nil
    end)

    --try to dismiss at every 1s
    timer:start(1000, 1000, dismiss)
  end
end
