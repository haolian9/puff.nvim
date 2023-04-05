a drop-in replacement of `vim.ui.select`, inspired by tmux's `display-menu`

## prerequisites
* nvim 0.8.*
* haolian9/infra.nvim

## status
* just works (tm)

## usage
* `vim.ui.select = function(...) require'display_menu'(...) end` # the wrapper is for to load this module on-demand
