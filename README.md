# nvim-xi

The completion & signatureHelp plugin for neovim.

## Warning

*The API is not yet stable. If you have made any advanced customizations, they may stop working without notice.*

## Features

- insert-mode & cmdline-mode completion.
- signatureHelp.
- common sources are built-in.
  - buffer
  - path
  - calc
  - cmdline
  - lsp.completion

## Installation

```
# lazy.nvim
{
  "hrsh7th/nvim-xi",
  dependencies = {
    "hrsh7th/nvim-cmp-kit",
  },
}
```

## Usage

The most basic usage is the following:

```lua
local xi = require('xi')

-- setup autocmds.
xi.setup({ ... })

-- common.
xi.charmap({ 'i', 'c' }, '<C-d>', xi.action.scroll(0 + 3))
xi.charmap({ 'i', 'c' }, '<C-u>', xi.action.scroll(0 - 3))

-- completion.
xi.charmap({ 'i', 'c' }, '<C-Space>', xi.action.completion.complete())
xi.charmap({ 'i', 'c' }, '<C-n>', xi.action.completion.select_next())
xi.charmap({ 'i', 'c' }, '<C-p>', xi.action.completion.select_prev())
xi.charmap({ 'i', 'c' }, '<Down>', xi.action.completion.select_next())
xi.charmap({ 'i' }, '<Up>', xi.action.completion.select_prev())
xi.charmap({ 'i' }, '<C-e>', xi.action.completion.close())
xi.charmap('c', '<CR>', xi.action.completion.commit_cmdline())
xi.charmap('i', '<CR>', xi.action.completion.commit({ select_first = true }))

-- signature_help.
xi.charmap('i', '<C-o>', xi.action.signature_help.trigger())
xi.charmap('i', '<C-j>', xi.action.signature_help.select_next())
xi.charmap('i', '<C-k>', xi.action.signature_help.select_prev())
```


