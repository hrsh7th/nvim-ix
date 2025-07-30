local misc = require('ix.misc')
local kit = require('cmp-kit.kit')
local LSP = require('cmp-kit.kit.LSP')
local Async = require('cmp-kit.kit.Async')
local Keymap = require('cmp-kit.kit.Vim.Keymap')

---@alias ix.Charmap.Callback fun(fallback: fun())

---@class ix.Charmap
---@field mode string[]
---@field char string
---@field callback ix.Charmap.Callback

local ix = {
  source = require('ix.source'),
  action = require('ix.action'),
}

local private = {
  ---completion service registry.
  completion = {
    i = {} --[[@type table<integer, cmp-kit.completion.CompletionService>]],
    c = {} --[[@type table<string, cmp-kit.completion.CompletionService>]],
  },

  ---signature help service registry.
  signature_help = {
    i = {} --[[@type table<integer, cmp-kit.signature_help.SignatureHelpService>]],
    c = {} --[[@type table<string, cmp-kit.signature_help.SignatureHelpService>]],
  },

  ---charmaps registry.
  charmaps = {} --[=[@as ix.Charmap[]]=],

  ---setup registry.
  setup = {
    config = {},
    dispose = {},
  },
}

local default_config = {
  ---Expand snippet function.
  ---@type nil|cmp-kit.completion.ExpandSnippet
  expand_snippet = nil,

  ---Check if macro is executing or not.
  ---@type fun(): boolean
  is_macro_executing = function()
    return vim.fn.reg_executing() ~= ''
  end,

  ---Check if macro is recording or not.
  ---@type fun(): boolean
  is_macro_recording = function()
    return vim.fn.reg_recording() ~= ''
  end,

  ---Completion configuration.
  completion = {

    ---Enable/disable auto completion.
    ---@type boolean
    auto = true,

    ---Enable/disable auto documentation.
    ---@type boolean
    auto_docs = true,

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

      local lspkind = { pcall(require, 'lspkind') }
      local mini_icons = { pcall(require, 'mini.icons') }
      local function update()
        if lspkind[1] then
          return
        end
        lspkind = { pcall(require, 'lspkind') }
        if mini_icons[1] then
          return
        end
        mini_icons = { pcall(require, 'mini.icons') }
      end
      vim.api.nvim_create_autocmd({ 'BufEnter', 'CmdlineEnter' }, {
        callback = update,
      })

      -- mini.icons
      ---@param kind cmp-kit.kit.LSP.CompletionItemKind
      ---@return { [1]: string, [2]?: string }?
      return function(kind)
        kind = kind or LSP.CompletionItemKind.Text
        if lspkind[1] then
          if not cache[kind] then
            cache[kind] = { lspkind[2].symbolic(CompletionItemKindLookup[kind]), ('CmpItemKind' .. CompletionItemKindLookup[kind]) }
          end
          return cache[kind]
        end
        if mini_icons[1] then
          if not cache[kind] then
            cache[kind] = { mini_icons[2].get('lsp', CompletionItemKindLookup[kind]:lower()) }
          end
          return cache[kind]
        end
        return { '', '' }
      end
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
      if vim.bo.buftype == 'nofile' then
        return
      end
      do
        local service = ix.get_completion_service({ recreate = true })
        service:register_source(ix.source.completion.github(), { group = 1 })
        service:register_source(ix.source.completion.calc(), { group = 1 })
        service:register_source(ix.source.completion.emoji(), { group = 1 })
        service:register_source(ix.source.completion.path(), { group = 10 })
        ix.source.completion.attach_lsp(service, { group = 20 })
        service:register_source(ix.source.completion.buffer(), { group = 20, dedup = true })
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
  },
} --[[@as ix.SetupOption]]

---@class ix.SetupOption.Completion
---@field public auto? boolean
---@field public auto_docs? boolean
---@field public default_keyword_pattern? string
---@field public preselect? boolean
---@field public icon_resolver? fun(kind: cmp-kit.kit.LSP.CompletionItemKind): { [1]: string, [2]?: string }?

---@class ix.SetupOption.SignatureHelp
---@field public auto? boolean
---
---@class ix.SetupOption.Attach
---@field public insert_mode? fun()
---@field public cmdline_mode? fun()
---
---@class ix.SetupOption
---@field public expand_snippet? cmp-kit.completion.ExpandSnippet
---@field public is_macro_executing? fun(): boolean
---@field public is_macro_recording? fun(): boolean
---@field public completion? ix.SetupOption.Completion
---@field public signature_help? ix.SetupOption.SignatureHelp
---@field public attach? ix.SetupOption.Attach

---Setup ix module.
---@param config? ix.SetupOption
function ix.setup(config)
  private.config = kit.merge(config or {}, default_config)

  -- Dispose existing services.
  for k, service in pairs(private.completion.i) do
    service:dispose()
    private.completion.i[k] = nil
  end
  for k, service in pairs(private.completion.c) do
    service:dispose()
    private.completion.c[k] = nil
  end
  for k, service in pairs(private.signature_help.i) do
    service:dispose()
    private.signature_help.i[k] = nil
  end
  for k, service in pairs(private.signature_help.c) do
    service:dispose()
    private.signature_help.c[k] = nil
  end

  ---Dispose previous setup.
  for _, dispose in ipairs(private.setup.dispose) do
    dispose()
  end
  private.setup.dispose = {}

  ---Setup commands.
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.commands['editor.action.triggerParameterHints'] = function()
    ix.do_action(function(ctx)
      ctx.signature_help.trigger({ force = true })
    end)
    return {}
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.commands['editor.action.triggerSuggest'] = function()
    ix.do_action(function(ctx)
      ctx.completion.complete({ force = true })
    end)
    return {}
  end

  ---Setup char mapping.
  do
    vim.on_key(function(_, typed)
      if not typed or typed == '' then
        return
      end
      local mode = vim.api.nvim_get_mode().mode

      -- find charmap.
      local charmap = vim.iter(private.charmaps):find(function(charmap)
        return vim.tbl_contains(charmap.mode, mode) and vim.fn.keytrans(typed) == vim.fn.keytrans(charmap.char)
      end) --[[@as ix.Charmap?]]
      if not charmap then
        return
      end

      -- remove typeahead.
      while true do
        local c = vim.fn.getcharstr(0)
        if c == '' then
          break
        end
      end

      charmap.callback(function()
        local task = Keymap.send({ keys = typed, remap = true })
        if Async.in_context() then
          task:await()
        end
      end)

      return ''
    end, vim.api.nvim_create_namespace('ix'), {})
  end

  ---Setup insert-mode trigger.
  do
    local queue = misc.autocmd_queue()
    table.insert(
      private.setup.dispose,
      misc.autocmd({ 'TextChangedI', 'CursorMovedI' }, {
        callback = function()
          local completion_service = ix.get_completion_service()
          local signature_help_service = ix.get_signature_help_service()
          queue.add(function()
            local mode = vim.api.nvim_get_mode().mode
            if vim.tbl_contains({ 'i' }, mode) then
              if private.config.completion.auto or completion_service:is_menu_visible() then
                completion_service:complete({ force = false })
              end
            end
            if vim.tbl_contains({ 'i', 's' }, mode) then
              if private.config.signature_help.auto or signature_help_service:is_visible() then
                signature_help_service:trigger({ force = false })
              end
            end
          end)
        end,
      })
    )
    table.insert(
      private.setup.dispose,
      misc.autocmd('ModeChanged', {
        pattern = { 'i:*', 's:*' },
        callback = function()
          local completion_service = ix.get_completion_service()
          local signature_help_service = ix.get_signature_help_service()
          queue.add(function()
            local mode = vim.api.nvim_get_mode().mode
            if not vim.tbl_contains({ 'i' }, mode) then
              completion_service:clear()
            end
            if not vim.tbl_contains({ 'i', 's' }, mode) then
              signature_help_service:clear()
            elseif vim.tbl_contains({ 's' }, mode) then
              if private.config.signature_help.auto or signature_help_service:is_visible() then
                signature_help_service:trigger({ force = true })
              end
            end
          end)
        end,
      })
    )
  end

  ---Setup cmdline-mode trigger.
  do
    local queue = misc.autocmd_queue()
    table.insert(
      private.setup.dispose,
      misc.autocmd('CmdlineChanged', {
        callback = function()
          local completion_service = ix.get_completion_service()
          local signature_help_service = ix.get_signature_help_service()
          queue.add(function()
            local mode = vim.api.nvim_get_mode().mode
            if mode == 'c' then
              if private.config.completion.auto or completion_service:is_menu_visible() then
                completion_service:complete({ force = false })
              end
              if private.config.signature_help.auto or signature_help_service:is_visible() then
                signature_help_service:trigger({ force = false })
              end
            end
          end)
        end,
      })
    )
    table.insert(
      private.setup.dispose,
      misc.autocmd('CmdlineLeave', {
        callback = function()
          local completion_service = ix.get_completion_service()
          local signature_help_service = ix.get_signature_help_service()
          queue.add(function()
            local mode = vim.api.nvim_get_mode().mode
            if mode ~= 'c' then
              completion_service:clear()
              signature_help_service:clear()
            end
          end)
        end,
      })
    )
  end

  ---Setup inesrt-mode service initialization.
  do
    local queue = misc.autocmd_queue()
    table.insert(
      private.setup.dispose,
      misc.autocmd('BufEnter', {
        callback = function()
          queue.add(function()
            if private.config.attach.insert_mode then
              private.config.attach.insert_mode()
            end
          end)
        end,
      })
    )
    if private.config.attach.insert_mode then
      private.config.attach.insert_mode()
    end
  end

  ---Setup cmdline-mode service initialization.
  do
    local queue = misc.autocmd_queue()
    table.insert(
      private.setup.dispose,
      misc.autocmd('CmdlineEnter', {
        callback = function()
          queue.add(function()
            local mode = vim.api.nvim_get_mode().mode
            if mode == 'c' then
              if private.config.attach.cmdline_mode then
                private.config.attach.cmdline_mode()
              end
            end
          end)
        end,
      })
    )
    if vim.api.nvim_get_mode().mode == 'c' then
      if private.config.attach.cmdline_mode then
        private.config.attach.cmdline_mode()
      end
    end
  end
end

---Get default configuration.
---@return ix.SetupOption
function ix.get_default_config()
  return kit.merge({}, default_config)
end

---Get current completion service.
---@param option? { recreate?: boolean }
---@return cmp-kit.completion.CompletionService
function ix.get_completion_service(option)
  option = option or {}
  option.recreate = option.recreate or false

  -- cmdline mode.
  if vim.api.nvim_get_mode().mode == 'c' then
    local key = vim.fn.getcmdtype()
    if not private.completion.c[key] or option.recreate then
      if private.completion.c[key] then
        private.completion.c[key]:dispose()
      end
      local CompletionService = require('cmp-kit.completion.CompletionService')
      private.completion.c[key] = CompletionService.new({
        is_macro_executing = private.config.is_macro_executing,
        is_macro_recording = private.config.is_macro_recording,
        default_keyword_pattern = private.config.completion.default_keyword_pattern,
        preselect = private.config.completion.preselect,
        view = require('cmp-kit.completion.ext.DefaultView').new({
          auto_docs = private.config.completion.auto_docs,
          icon_resolver = private.config.completion.icon_resolver,
          use_source_name_column = true,
        }),
      })
    end
    return private.completion.c[key]
  end

  -- insert mode.
  local key = vim.api.nvim_get_current_buf()
  if not private.completion.i[key] or option.recreate then
    if private.completion.i[key] then
      private.completion.i[key]:dispose()
    end
    local CompletionService = require('cmp-kit.completion.CompletionService')
    private.completion.i[key] = CompletionService.new({
      is_macro_executing = private.config.is_macro_executing,
      is_macro_recording = private.config.is_macro_recording,
      expand_snippet = private.config.expand_snippet,
      default_keyword_pattern = private.config.completion.default_keyword_pattern,
      preselect = private.config.completion.preselect,
      view = require('cmp-kit.completion.ext.DefaultView').new({
        auto_docs = private.config.completion.auto_docs,
        icon_resolver = private.config.completion.icon_resolver,
        use_source_name_column = true,
      }),
    })
  end
  return private.completion.i[key]
end

---Get current signature_help service.
---@param option? { recreate?: boolean }
---@return cmp-kit.signature_help.SignatureHelpService
function ix.get_signature_help_service(option)
  option = option or {}
  option.recreate = option.recreate or false

  -- cmdline mode.
  if vim.api.nvim_get_mode().mode == 'c' then
    local key = vim.fn.getcmdtype()
    if not private.signature_help.c[key] or option.recreate then
      if private.signature_help.c[key] then
        private.signature_help.c[key]:dispose()
      end
      local SignatureHelpService = require('cmp-kit.signature_help.SignatureHelpService')
      private.signature_help.c[key] = SignatureHelpService.new({
        view = require('cmp-kit.signature_help.ext.DefaultView').new(),
      })
    end
    return private.signature_help.c[key]
  end

  -- insert mode.
  local key = vim.api.nvim_get_current_buf()
  if not private.signature_help.i[key] or option.recreate then
    if private.signature_help.i[key] then
      private.signature_help.i[key]:dispose()
    end
    local SignatureHelpService = require('cmp-kit.signature_help.SignatureHelpService')
    private.signature_help.i[key] = SignatureHelpService.new({
      view = require('cmp-kit.signature_help.ext.DefaultView').new(),
    })
  end
  return private.signature_help.i[key]
end

ix.charmap = {}

---Del charmap.
---@param mode string|string[]
---@param char string
function ix.charmap.del(mode, char)
  for i = #private.charmaps, 1, -1 do
    local charmap = private.charmaps[i]
    if vim.tbl_contains(charmap.mode, mode) and charmap.char == vim.keycode(char) then
      table.remove(private.charmaps, i)
    end
  end
end

---Set charmap.
---@param mode string|string[]
---@param char string
---@param callback ix.Charmap.Callback
function ix.charmap.set(mode, char, callback)
  local l = 0
  local i = 1
  local n = false
  while i <= #char do
    local c = char:sub(i, i)
    if c == '<' then
      n = true
    elseif c == '\\' then
      i = i + 1
    else
      if n then
        if c == '>' then
          n = false
          l = l + 1
        end
      else
        l = l + 1
      end
    end
    i = i + 1
  end

  if l > 1 then
    error('`ix.charmap` does not support multiple key sequence')
  end

  table.insert(private.charmaps, {
    mode = kit.to_array(mode),
    char = vim.keycode(char),
    callback = callback,
  })
end

---Run ix action in async-context.
---@class ix.API.Completion
---@field prevent fun(callback: fun())
---@field hide fun()
---@field show_docs fun()
---@field hide_docs fun()
---@field is_menu_visible fun(): boolean
---@field is_docs_visible fun(): boolean
---@field get_selection fun(): cmp-kit.completion.Selection|nil
---@field complete fun(option?: { force?: boolean })
---@field select fun(index: integer, preselect?: boolean)
---@field scroll_docs fun(delta: integer)
---@field commit fun(index: integer, option?: { replace: boolean, no_snippet: boolean }): boolean
---@class ix.API.SignatureHelp
---@field prevent fun(callback: fun())
---@field trigger fun(option?: { force?: boolean })
---@field close fun()
---@field is_visible fun(): boolean
---@field get_active_signature_data fun(): cmp-kit.signature_help.ActiveSignatureData|nil
---@field select fun(index: integer)
---@field scroll fun(delta: integer)
---@class ix.API
---@field completion ix.API.Completion
---@field signature_help ix.API.SignatureHelp
---@field schedule fun()
---@field feedkeys fun(keys: string, remap?: boolean)

---Run ix action with given runner.
---@param runner fun(ctx: ix.API)
---@return cmp-kit.kit.Async.AsyncTask
function ix.do_action(runner)
  local ctx
  ctx = {
    completion = {
      prevent = function(callback)
        local resume = ix.get_completion_service():prevent()
        callback()
        resume()
      end,
      hide = function()
        ix.get_completion_service():clear()
      end,
      show_docs = function()
        ix.get_completion_service():show_docs()
      end,
      hide_docs = function()
        ix.get_completion_service():hide_docs()
      end,
      is_menu_visible = function()
        return ix.get_completion_service():is_menu_visible()
      end,
      is_docs_visible = function()
        return ix.get_completion_service():is_docs_visible()
      end,
      get_selection = function()
        return ix.get_completion_service():get_selection()
      end,
      complete = function(option)
        ix.get_completion_service():complete(option):await()
      end,
      select = function(index, preselect)
        ix.get_completion_service():select(index, preselect):await()
      end,
      scroll_docs = function(delta)
        ix.get_completion_service():scroll_docs(delta)
      end,
      commit = function(index, option)
        local completion_service = ix.get_completion_service()

        -- nvim-ix uses async queue to handle TextChanged/CursorMoved event.
        -- So if the user tries to commit a completion item, the completion menu does not updated yet.
        -- To avoid this, nvim-ix needs to immediately update the completion menu.
        completion_service:matching()

        local match = completion_service:get_matches()[index]
        if match then
          completion_service:commit(match.item, option):await()
          return true
        end
        return false
      end,
    },
    signature_help = {
      prevent = function(callback)
        local resume = ix.get_signature_help_service():prevent()
        callback()
        resume()
      end,
      trigger = function(option)
        ix.get_signature_help_service():trigger(option):await()
      end,
      close = function()
        ix.get_signature_help_service():clear()
      end,
      is_visible = function()
        return ix.get_signature_help_service():is_visible()
      end,
      get_active_signature_data = function()
        return ix.get_signature_help_service():get_active_signature_data()
      end,
      select = function(index)
        ix.get_signature_help_service():select(index)
      end,
      scroll = function(delta)
        ix.get_signature_help_service():scroll(delta)
      end,
    },
    schedule = function()
      Async.schedule():await()
    end,
    feedkeys = function(keys, remap)
      Keymap.send({ { keys = keys, remap = not not remap } }):await()
    end,
  } --[[@as ix.API]]
  return Async.run(function()
    runner(ctx)
  end)
end

---Get ix supported capabilities.
function ix.get_capabilities()
  vim.deprecate('ix.get_capabilities', 'nvim-ix automatic resolve lsp capabilities now', '0.0.0', 'nvim-ix')
  return {
    textDocument = {
      completion = {
        dynamicRegistration = true,
        completionItem = {
          snippetSupport = true,
          commitCharactersSupport = true,
          deprecatedSupport = true,
          preselectSupport = true,
          tagSupport = {
            valueSet = {
              1, -- Deprecated
            },
          },
          insertReplaceSupport = true,
          resolveSupport = {
            properties = {
              'documentation',
              'additionalTextEdits',
              'insertTextFormat',
              'insertTextMode',
              'command',
            },
          },
          insertTextModeSupport = {
            valueSet = {
              1, -- asIs
              2, -- adjustIndentation
            },
          },
          labelDetailsSupport = true,
        },
        contextSupport = true,
        insertTextMode = 1,
        completionList = {
          itemDefaults = {
            'commitCharacters',
            'editRange',
            'insertTextFormat',
            'insertTextMode',
            'data',
          },
        },
      },
      signatureHelp = {
        dynamicRegistration = true,
        signatureInformation = {
          documentationFormat = { 'markdown', 'plaintext' },
          parameterInformation = {
            labelOffsetSupport = true,
          },
          activeParameterSupport = true,
        },
        contextSupport = true,
      },
    },
  } --[[@as cmp-kit.kit.LSP.ClientCapabilities]]
end

return ix
