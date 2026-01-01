local Keyring = require("puff.Keyring")
local Menu = require("puff.Menu")

local key_pool = Keyring("yn")
local entries = { "go ahead", "wait, no" }
local function entfmt(ent) return ent end

---@param opts {subject?:string, desc?:string[], entries?:[string,string]}
---@param on_decide fun(confirmed:boolean)
return function(opts, on_decide)
  Menu({
    key_pool = key_pool,
    subject = opts.subject,
    desc = opts.desc,
    entries = opts.entries or entries,
    entfmt = entfmt,
    on_decide = function(_, index) on_decide(index == 1) end,
    colorful = true,
  })
end
