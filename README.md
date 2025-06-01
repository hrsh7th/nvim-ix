# nvim-ix

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
  "hrsh7th/nvim-ix",
  dependencies = {
    "hrsh7th/nvim-cmp-kit",
  },
}
```

## Usage

The basic usage is the following:

```lua
vim.o.winborder = 'rounded' -- set window border style.

local ix = require('ix')

-- update lsp capabilities.
vim.lsp.config('*', {
  capabilities = ix.get_capabilities()
})

-- setup autocmds and configurations.
ix.setup({
  expand_snippet = function(snippet)
    dot_context.expand_snippet({ body = snippet })
  end
})

-- common.
ix.charmap({ 'i', 'c' }, '<C-d>', ix.action.scroll(0 + 3))
ix.charmap({ 'i', 'c' }, '<C-u>', ix.action.scroll(0 - 3))

-- completion.
ix.charmap({ 'i', 'c' }, '<C-Space>', ix.action.completion.complete())
ix.charmap({ 'i', 'c' }, '<C-n>', ix.action.completion.select_next())
ix.charmap({ 'i', 'c' }, '<C-p>', ix.action.completion.select_prev())
ix.charmap({ 'i', 'c' }, '<C-e>', ix.action.completion.close())
ix.charmap('c', '<CR>', ix.action.completion.commit_cmdline())
ix.charmap('i', '<CR>', ix.action.completion.commit({ select_first = true }))
ix.charmap('i', '<Down>', ix.action.completion.select_next())
ix.charmap('i', '<Up>', ix.action.completion.select_prev())
ix.charmap('i', '<C-y>', ix.action.completion.commit({ select_first = true, replace = true, no_snippet = true }))

-- signature_help.
ix.charmap('i', '<C-o>', ix.action.signature_help.trigger())
ix.charmap('i', '<C-j>', ix.action.signature_help.select_next())
ix.charmap('i', '<C-k>', ix.action.signature_help.select_prev())
```

<details>
  <summary>the default setup configurations</summary>

```lua
{

  -- Expand snippet function.
  -- nil|fun(snippet: string, opts: any): nil
  expand_snippet = nil,

  -- Completion configurations.
  completion = {
    -- Enable/disable `auto` completion.
    auto = true,

    -- Enable/disable `preselect` feature that defined in the LSP spec.
    preselect = false,

    -- Default keyword pattern for completion.
    default_keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
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
        local service = ix.get_completion_service({ recreate = true })
        service:register_source(ix.source.completion.calc(), { group = 1 })
        service:register_source(ix.source.completion.path(), { group = 10 })
        ix.source.completion.attach_lsp(service, { group = 20 })
        service:register_source(ix.source.completion.buffer(), { group = 100 })
      end
      do
        local service = ix.get_signature_help_service({ recreate = true })
        ix.source.signature_help.attach_lsp(service)
      end
    end,
    -- Attach cmdline-mode services.
    -- NOTE: This is an advanced feature and is subject to breaking changes as the API is not yet stable.
    cmdline_mode = function()
      local service = ix.get_completion_service({ recreate = true })
      if vim.tbl_contains({ '/', '?' }, vim.fn.getcmdtype()) then
        service:register_source(ix.source.completion.buffer(), { group = 1 })
      elseif vim.fn.getcmdtype() == ':' then
        service:register_source(ix.source.completion.path(), { group = 1 })
        service:register_source(ix.source.completion.cmdline(), { group = 10 })
      end
    end,
  }
}
```

</details>

## FAQ

### How to mapping without using `ix.charmap`?

You can use the following instead.

```lua
vim.keymap.set({ 'i', 'c' }, '<C-n>', function()
  ix.do_action(function(ctx)
    ix.action.completion.select_next({ no_insert = true })(ctx)
  end)
end)
```

Note: `ix.action.*` can only be executed inside `ix.do_action(function(ctx) ... end)`.

### Why do you create new completion plugin?

My thoughts are explained in the Japanese article
[here](https://zenn.dev/hrsh7th/articles/1d558a56084fe5).
