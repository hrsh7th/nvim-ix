# `nvim-ix`

insert mode enhancement plugin for Neovim

<a href="LICENSE.md"><img alt="Software License" src="https://img.shields.io/badge/license-Anti%20996-brightgreen.svg?style=flat-square"></a>
<a href="https://deepwiki.com/hrsh7th/nvim-ix"><img src="https://deepwiki.com/badge.svg" alt="DeepWiki"></a>

**API Stability Warning**

_The API is not yet stable. If you have made any advanced customizations, they
may stop working without notice._

## Overview

`nvim-ix` is a plugin for Neovim that provides insert-mode enhancement
functionalities. It internally utilizes the core library `nvim-cmp-kit` to offer
a user-friendly API.

- **`nvim-ix`**: The interface for user configuration and operation.
- **`nvim-cmp-kit`**: The core engine responsible for the actual completion
  logic, such as generating completion candidates and interacting with LSP.

This architecture allows `nvim-ix` to provide Neovim users with an
easy-to-configure and intuitive experience, while `nvim-cmp-kit` handles complex
processing, achieving both stability and advanced features.

## Key Features

- **Completion**: Input completion in insert mode and command-line mode.
- **Signature Help**: Displays function and method signatures (argument
  information, etc.).
- **Built-in Common Sources**:
  - **Completion**
    - `buffer`: Words from the current buffer.
    - `path`: File and directory paths.
    - `calc`: Evaluation of simple mathematical expressions.
    - `cmdline`: Neovim commands.
    - `lsp.completion`: Completion candidates from LSP servers.
  - **SignatureHelp**
    - `lsp.signature_help`: Signature help from LSP servers.
- **Key-mapping**: `ix.charmap` for setting up keybindings with reduced
  conflicts.
- **Pretty Markdown Rendering**: Completion documentation / Signature Help
  rendering.

---

## Installation

**Prerequisites**

- Neovim 0.11 or later.
  - `nvim-ix` uses `vim.on_key` with empty return string. It's introduced in
    Neovim 0.11.
- NerdFonts
  - `nvim-ix`'s default view uses NerdFonts.

**Lazy.nvim example**

```lua
-- lazy.nvim
{
  "hrsh7th/nvim-ix",
  dependencies = {
    "hrsh7th/nvim-cmp-kit",
  },
}
```

## Basic Usage

To use `nvim-ix`, first call the `setup` function for initial configuration.

```lua
vim.o.winborder = 'rounded' -- (Optional) nvim-ix follows global `winborder` settings to render windows 

local ix = require('ix')

-- Update LSP capabilities
vim.lsp.config('*', {
  capabilities = ix.get_capabilities()
})

-- Setup nvim-ix
ix.setup({
  -- Register snippet expand function (optional if not using snippets)
  expand_snippet = function(snippet_body)
    -- vim.snippet.expand(snippet) -- for `neovim built-in` users
    -- require('luasnip').lsp_expand(snippet) -- for `LuaSnip` users
    -- require('snippy').expand_snippet(snippet) -- for `nvim-snippy` users
    -- vim.fn["vsnip#anonymous"](snippet_body) -- for `vim-vsnip` users
  end
})

-- Setup keymaps (Using `ix.charmap`; See below).
do
  ix.charmap({ 'i', 'c' }, '<C-d>', ix.action.scroll(0 + 3))
  ix.charmap({ 'i', 'c' }, '<C-u>', ix.action.scroll(0 - 3))

  ix.charmap({ 'i', 'c' }, '<C-Space>', ix.action.completion.complete())
  ix.charmap({ 'i', 'c' }, '<C-n>', ix.action.completion.select_next())
  ix.charmap({ 'i', 'c' }, '<C-p>', ix.action.completion.select_prev())
  ix.charmap({ 'i', 'c' }, '<C-e>', ix.action.completion.close())
  ix.charmap('c', '<CR>', ix.action.completion.commit_cmdline())
  ix.charmap('i', '<CR>', ix.action.completion.commit({ select_first = true }))
  ix.charmap('i', '<Down>', ix.action.completion.select_next())
  ix.charmap('i', '<Up>', ix.action.completion.select_prev())
  ix.charmap('i', '<C-y>', ix.action.completion.commit({ select_first = true, replace = true, no_snippet = true }))

  ix.charmap({ 'i', 's' }, '<C-o>', ix.action.signature_help.trigger_or_close())
  ix.charmap({ 'i', 's' }, '<C-j>', ix.action.signature_help.select_next())
end
```

**Regarding LSP Capabilities Update**:

`ix.get_capabilities()` is returning LSP Capabilities that `nvim-ix` supports.

The LSP specification defines the concept of `capabilities`, which an `editor` can use to inform the server that it supports the features defined in the LSP.

`nvim-ix` supports a variety of features related to completion and signature help, so please inform the LSP server.

**Snippet Engine Integration**:

Specify your snippet engine's expansion function with the `expand_snippet`
option. If not provided, snippet-related functionalities will be disabled.

**Key-mapping with `ix.charmap`**

`ix.charmap` is a utility for easily setting up key-mappings for the plugin's
main operations. It helps avoid key conflicts with other plugins.

**`ix.setup({ ... })` reference**

The following setup call indicates all default settings.

<details>

<summary>default configuration</summary>

```lua
local ix = require('nvim-ix')
ix.setup({
  ---Expand snippet function.
  ---@type nil|cmp-kit.completion.ExpandSnippet
  expand_snippet = nil,

  ---Completion configuration.
  completion = {

    ---Enable/disable auto completion.
    ---@type boolean
    auto = true,

    ---Enable/disable LSP's preselect feature.
    ---@type boolean
    preselect = false,

    ---Default keyword pattern for completion.
    ---@type string
    default_keyword_pattern = require('cmp-kit.completion.ext.DefaultConfig').default_keyword_pattern,

    ---Resolve LSP's CompletionItemKind to icons.
    ---@type nil|fun(kind: cmp-kit.kit.LSP.CompletionItemKind): { [1]: string, [2]?: string }?
    icon_resolver = (function()
      local cache = {}

      local CompletionItemKindLookup = {}
      for k, v in pairs(LSP.CompletionItemKind) do
        CompletionItemKindLookup[v] = k
      end

      -- For mini.icons
      local ok, MiniIcons = pcall(require, 'mini.icons')
      if ok and MiniIcons then
        ---@param completion_item_kind cmp-kit.kit.LSP.CompletionItemKind
        ---@return { [1]: string, [2]?: string }?
        return function(completion_item_kind)
          if not cache[completion_item_kind] then
            local kind = CompletionItemKindLookup[completion_item_kind] or 'text'
            cache[completion_item_kind] = { MiniIcons.get('lsp', kind:lower()) }
          end
          return cache[completion_item_kind]
        end
      end
      return nil
    end)(),
  },

  ---Signature help configuration.
  signature_help = {

    ---Auto trigger signature help.
    ---@type boolean
    auto = true,

  },

  ---Attach services for each per modes.
  attach = {

    ---Insert mode service initialization.
    ---NOTE: This is an advanced feature and is subject to breaking changes as the API is not yet stable.
    ---@type fun(): nil
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

    ---Cmdline mode service initialization.
    ---NOTE: This is an advanced feature and is subject to breaking changes as the API is not yet stable.
    ---@type fun(): nil
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
})
```

</details>

---

## Advanced Usage

**Call `nvim-ix` actions anywhere**

It is possible to call `nvim-ix` actions without `ix.charmap` for integrating
some of the your specific workflows.

```lua
vim.keymap.set('i', '<CR>', function()
  ix.do_action(function(ctx)
    ctx.completion.complete()
  end)
end)
```

---

## FAQ

**Why is `ix.charmap` needed?**

Keys like `<CR>` and `<Tab>` are prone to conflicts as they are used for
multiple functions (e.g., confirming completion, inserting a newline, expanding
a snippet). `ix.charmap` aims to handle `nvim-ix` actions for these keys with
higher precedence than other mappings, reducing conflicts and ensuring reliable
behavior.

**How can I set up key-mappings without using `ix.charmap`?**

You can use `ix.do_action` for this.

```lua
vim.keymap.set('i', '<C-x><C-o>', function()
  ix.do_action(function(ctx)
    ctx.completion.complete()
  end)
end)
```

**Why create a new completion plugin?**

`nvim-ix` was developed based on the experience from existing completion plugins
(like `nvim-cmp`), aiming for a different architectural approach (adoption of
the core engine `nvim-cmp-kit`) and an API design more compliant with LSP
specifications.
