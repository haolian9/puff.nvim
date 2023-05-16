a drop-in replacement of `vim.ui.{input,select}`

## features
* use floating windows rather than `:input`

## prerequisites
* nvim 0.9.*
* haolian9/infra.nvim

## status
* just works (tm)

## usage
* `vim.ui.input = function(...) require'tui.input'(...) end`
* `vim.ui.select = function(...) require'tui.select'(...) end`

## how it works
* tui.{input,menu} employ a dedicated buffer to avoid the overhead of frequently 
    creating the buffer, creating/binding rhs functions.
* tui.menu use `map <nowait>` to disable [a-z]+'s native rhs

