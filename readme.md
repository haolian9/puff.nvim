a drop-in replacement of `vim.ui.{input,select}`

https://user-images.githubusercontent.com/6236829/238661875-d5beeca6-fe16-44aa-9f8c-dcf4923d5235.mp4

## features, designs
* use floating windows rather than `:input`
* just need to press one key, no additional `<cr>`
* puff.{input,menu} employ a dedicated buffer to avoid the overhead of frequently 
    creating the buffer, creating/binding rhs functions.
* puff.menu use `map <nowait>` to disable [a-z]+'s native rhs
* limited number of entries. for larger entry set, i'd prefer haolian9/beckon.nvim

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim

## status
* just works (tm)

## usage
* `vim.ui.input = function(...) require'puff.input'(...) end`
* `vim.ui.select = function(...) require'puff.select'(...) end`
