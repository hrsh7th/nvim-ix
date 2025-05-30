# nvim-xi

The completion & signatureHelp plugin for neovim.

## Warning

_The API is not yet stable. If you have made any advanced customizations, they
may stop working without notice._

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

```lua
# lazy.nvim
{
  "hrsh7th/nvim-xi",
  dependencies = {
    "hrsh7th/nvim-cmp-kit",
  },
}
```

## Usage

The basic usage is the following:

```lua
vim.o.winborder = 'rounded' -- set window border style.

local xi = require('xi')

-- setup autocmds and configurations.
xi.setup()

-- common.
xi.charmap({ 'i', 'c' }, '<C-d>', xi.action.scroll(0 + 3))
xi.charmap({ 'i', 'c' }, '<C-u>', xi.action.scroll(0 - 3))

-- completion.
xi.charmap({ 'i', 'c' }, '<C-Space>', xi.action.completion.complete())
xi.charmap({ 'i', 'c' }, '<C-n>', xi.action.completion.select_next())
xi.charmap({ 'i', 'c' }, '<C-p>', xi.action.completion.select_prev())
xi.charmap({ 'i', 'c' }, '<C-e>', xi.action.completion.close())
xi.charmap('c', '<CR>', xi.action.completion.commit_cmdline())
xi.charmap('i', '<CR>', xi.action.completion.commit({ select_first = true }))
xi.charmap('i', '<Down>', xi.action.completion.select_next())
xi.charmap('i', '<Up>', xi.action.completion.select_prev())
xi.charmap('i', '<C-y>', xi.action.completion.commit({ select_first = true, replace = true, no_snippet = true }))

-- signature_help.
xi.charmap('i', '<C-o>', xi.action.signature_help.trigger())
xi.charmap('i', '<C-j>', xi.action.signature_help.select_next())
xi.charmap('i', '<C-k>', xi.action.signature_help.select_prev())
```

The default setup configuration is the following (it will be merged with user
specified configurations):

```lua
{
  -- Completion configurations.
  completion = {
    -- Enable/disable `auto` completion.
    auto = true,

    -- Enable/disable `preselect` feature that defined in the LSP spec.
    preselect = false,

    -- Default keyword pattern for completion.
    default_keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],

    -- Expand snippet function.
    -- nil|fun(snippet: string, opts: any): nil
    expand_snippet = nil,
  },

  -- SignatureHelp configurations.
  signature_help = {
    -- Enable/disable `auto` signature help triggering.
    auto = true,
  },

  -- Attach services to each modes.
  attach = {
    -- Attach insert-mode services.
    -- NOTE: This is an advanced feature and is subject to breaking changes as the API is not yet stable.
    insert_mode = function()
      do
        local service = xi.get_completion_service({ recreate = true })
        service:register_source(xi.source.completion.calc(), { group = 1 })
        service:register_source(xi.source.completion.path(), { group = 10 })
        xi.source.completion.lsp(service, { group = 20 })
        service:register_source(xi.source.completion.buffer(), { group = 100 })
      end
      do
        local service = xi.get_signature_help_service({ recreate = true })
        xi.source.signature_help.lsp(service)
      end
    end,
    -- Attach cmdline-mode services.
    -- NOTE: This is an advanced feature and is subject to breaking changes as the API is not yet stable.
    cmdline_mode = function()
      local service = xi.get_completion_service({ recreate = true })
      if vim.tbl_contains({ '/', '?' }, vim.fn.getcmdtype()) then
        service:register_source(xi.source.completion.buffer(), { group = 1 })
      elseif vim.fn.getcmdtype() == ':' then
        service:register_source(xi.source.completion.path(), { group = 1 })
        service:register_source(xi.source.completion.cmdline(), { group = 10 })
      end
    end,
  }
}
```

## FAQ

### Why do you create new completion plugin?

My thoughts are explained in the Japanese article
[here](https://zenn.dev/hrsh7th/articles/1d558a56084fe5).
