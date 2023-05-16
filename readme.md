a drop-in replacement of `vim.ui.{input,select}`

https://user-images.githubusercontent.com/6236829/238661875-d5beeca6-fe16-44aa-9f8c-dcf4923d5235.mp4

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

