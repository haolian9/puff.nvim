local Keyring = require("puff.Keyring")
local Menu = require("puff.Menu")

local key_pool = Keyring("asdfjkl" .. "gh" .. "wertyuiop" .. "zxcvbnm" .. "ASDFJKL" .. "GH" .. "WERTYUIOP" .. "ZXCVBNM")
local function default_entfmt(ent) return ent end

---keep the same signature as vim.ui.select
---user should check if entry and index are nil in on_choice()
---@param items any[]
---@param opts {prompt?:string, format_item?:(fun(item):string), kind?:string}
---@param on_choice fun(entry?:string, index?:number) @index: 1-based
return function(items, opts, on_choice)
  assert(#items > 0)
  opts = opts or {}

  local entfmt
  if opts.kind ~= nil then
    entfmt = assert(opts.format_item, "opts.format_item is required for custom opts.kind")
  else
    entfmt = opts.format_item or default_entfmt
  end

  Menu({
    key_pool = key_pool,
    subject = opts.prompt,
    desc = nil,
    entries = items,
    entfmt = entfmt,
    on_decide = on_choice,
    colorful = true,
  })
end
