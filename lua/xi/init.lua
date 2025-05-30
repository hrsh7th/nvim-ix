local misc = require('xi.misc')
local kit = require('cmp-kit.kit')
local Async = require('cmp-kit.kit.Async')
local Keymap = require('cmp-kit.kit.Vim.Keymap')
local CompletionService = require('cmp-kit.completion.CompletionService')
local SignatureHelpService = require('cmp-kit.signature_help.SignatureHelpService')

---@alias xi.Charmap.Callback fun(api: xi.API, fallback: fun())

---@class xi.Charmap
---@field mode string[]
---@field char string
---@field callback xi.Charmap.Callback


local xi = {
  source = require('xi.source'),
  action = require('xi.action'),
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
  charmaps = {} --[=[@as xi.Charmap[]]=],

  ---setup registry.
  setup = {
    config = {},
    dispose = {},
  }
}

---@class xi.SetupOption.Completion
---@field public auto? boolean
---@field public default_keyword_pattern? string
---@field public expand_snippet? cmp-kit.completion.ExpandSnippet
---@field public preselect? boolean

---@class xi.SetupOption.SignatureHelp
---@field public auto? boolean
---
---@class xi.SetupOption.Attach
---@field public insert_mode? fun()
---@field public cmdline_mode? fun()
---
---@class xi.SetupOption
---@field public completion? xi.SetupOption.Completion
---@field public signature_help? xi.SetupOption.SignatureHelp
---@field public attach? xi.SetupOption.Attach

---Setup xi module.
---@param config? xi.SetupOption
function xi.setup(config)
  private.config = kit.merge(config or {}, {
    completion = {
      auto = true,
      preselect = false,
    },
    signature_help = {
      auto = true,
    },
    attach = {
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
  } --[[@as xi.SetupOption]])

  vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0, modeline = false })

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
      end) --[[@as xi.Charmap?]]
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

      xi.do_action(function(ctx)
        charmap.callback(ctx, function()
          Keymap.send({ keys = charmap.char, remap = true }):await()
        end)
      end)

      return ''
    end, vim.api.nvim_create_namespace('xi'), {})
  end

  ---Setup insert-mode trigger.
  do
    local rev = 0
    table.insert(private.setup.dispose, misc.autocmd({ 'TextChangedI', 'CursorMovedI' }, {
      callback = function()
        rev = rev + 1
        local c = rev
        vim.schedule(function()
          if c ~= rev then
            return
          end
          if vim.tbl_contains({ 'i' }, vim.api.nvim_get_mode().mode) then
            if private.config.completion.auto or xi.get_completion_service():is_menu_visible() then
              xi.get_completion_service():complete({ force = false })
            end
          end
          if vim.tbl_contains({ 'i', 's' }, vim.api.nvim_get_mode().mode) then
            if private.config.signature_help.auto or xi.get_signature_help_service():is_visible() then
              xi.get_signature_help_service():trigger({ force = false })
            end
          end
        end)
      end
    }))
    table.insert(private.setup.dispose, misc.autocmd('ModeChanged', {
      pattern = 'i:*',
      callback = function()
        rev = rev + 1
        local c = rev
        vim.schedule(function()
          if c ~= rev then
            return
          end
          if not vim.tbl_contains({ 'i' }, vim.api.nvim_get_mode().mode) then
            xi.get_completion_service():clear()
          end
          if not vim.tbl_contains({ 'i', 's' }, vim.api.nvim_get_mode().mode) then
            xi.get_signature_help_service():clear()
          end
        end)
      end
    }))
    table.insert(private.setup.dispose, vim.api.nvim_create_autocmd('ModeChanged', {
      pattern = '*:s',
      callback = function()
        rev = rev + 1
        local c = rev
        vim.schedule(function()
          if c ~= rev then
            return
          end
          if private.config.signature_help.auto then
            xi.get_signature_help_service():trigger({ force = true })
          end
        end)
      end
    }))
  end

  ---Setup cmdline-mode trigger.
  do
    local rev = 0
    table.insert(private.setup.dispose, misc.autocmd('CmdlineChanged', {
      callback = function()
        rev = rev + 1
        local c = rev
        vim.schedule(function()
          if c ~= rev then
            return
          end
          if vim.fn.mode(1):sub(1, 1) == 'c' then
            if private.config.completion.auto or xi.get_completion_service():is_menu_visible() then
              xi.get_completion_service():complete({ force = false })
            end
            if private.config.signature_help.auto or xi.get_signature_help_service():is_visible() then
              xi.get_signature_help_service():trigger({ force = false })
            end
          end
        end)
      end
    }))
    table.insert(private.setup.dispose, misc.autocmd('ModeChanged', {
      pattern = 'c:*',
      callback = function()
        rev = rev + 1
        local c = rev
        vim.schedule(function()
          if c ~= rev then
            return
          end
          if not vim.api.nvim_get_mode().mode ~= 'c' then
            xi.get_completion_service():clear()
            xi.get_signature_help_service():clear()
          end
        end)
      end
    }))
  end

  ---Setup inesrt-mode service initialization.
  do
    table.insert(private.setup.dispose, misc.autocmd('BufEnter', {
      callback = function()
        if private.config.attach.insert_mode then
          private.config.attach.insert_mode()
        end
      end
    }))
    if private.config.attach.insert_mode then
      private.config.attach.insert_mode()
    end
  end

  ---Setup cmdline-mode service initialization.
  do
    table.insert(private.setup.dispose, misc.autocmd('CmdlineEnter', {
      callback = function()
        if private.config.attach.cmdline_mode then
          private.config.attach.cmdline_mode()
        end
      end
    }))
    if vim.api.nvim_get_mode().mode == 'c' then
      if private.config.attach.cmdline_mode then
        private.config.attach.cmdline_mode()
      end
    end
  end
end

---Get current completion service.
---@param option? { recreate: boolean }
---@return cmp-kit.completion.CompletionService
function xi.get_completion_service(option)
  option = option or {}
  option.recreate = option.recreate or false

  -- cmdline mode.
  if vim.api.nvim_get_mode().mode == 'c' then
    local key = vim.fn.getcmdtype()
    if not private.completion.c[key] or option.recreate then
      if private.completion.c[key] then
        private.completion.c[key]:dispose()
      end
      private.completion.c[key] = CompletionService.new({
        default_keyword_pattern = private.config.completion.default_keyword_pattern,
        preselect = private.config.completion.preselect,
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
    private.completion.i[key] = CompletionService.new({
      default_keyword_pattern = private.config.completion.default_keyword_pattern,
      preselect = private.config.completion.preselect,
      expand_snippet = private.config.completion.expand_snippet,
    })
  end
  return private.completion.i[key]
end

---Get current signature_help service.
---@param option? { recreate: boolean }
---@return cmp-kit.signature_help.SignatureHelpService
function xi.get_signature_help_service(option)
  option = option or {}
  option.recreate = option.recreate or false

  -- cmdline mode.
  if vim.api.nvim_get_mode().mode == 'c' then
    local key = vim.fn.getcmdtype()
    if not private.signature_help.c[key] or option.recreate then
      if private.signature_help.c[key] then
        private.signature_help.c[key]:dispose()
      end
      private.signature_help.c[key] = SignatureHelpService.new()
    end
    return private.signature_help.c[key]
  end

  -- insert mode.
  local key = vim.api.nvim_get_current_buf()
  if not private.signature_help.i[key] or option.recreate then
    if private.signature_help.i[key] then
      private.signature_help.i[key]:dispose()
    end
    private.signature_help.i[key] = SignatureHelpService.new()
  end
  return private.signature_help.i[key]
end

---Setup character mapping.
---@param mode 'i' | 'c' | ('i' | 'c')[]
---@param char string
---@param callback fun(api: xi.API, fallback: fun())
function xi.charmap(mode, char, callback)
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
    error('`xi.charmap` does not support multiple key sequence')
  end

  table.insert(private.charmaps, {
    mode = kit.to_array(mode),
    char = vim.keycode(char),
    callback = callback,
  })
end

---Run xi action in async-context.
---@class xi.API.Completion
---@field prevent fun(callback: fun())
---@field close fun()
---@field is_menu_visible fun(): boolean
---@field is_docs_visible fun(): boolean
---@field get_selection fun(): cmp-kit.completion.Selection|nil
---@field complete fun(option?: { force?: boolean })
---@field select fun(index: integer, preselect?: boolean)
---@field scroll_docs fun(delta: integer)
---@field commit fun(index: integer, option?: { replace: boolean, no_snippet: boolean }): boolean
---@class xi.API.SignatureHelp
---@field prevent fun(callback: fun())
---@field trigger fun()
---@field close fun()
---@field is_visible fun(): boolean
---@field get_active_signature_data fun(): cmp-kit.signature_help.ActiveSignatureData|nil
---@field select fun(index: integer)
---@field scroll fun(delta: integer)
---@class xi.API
---@field completion xi.API.Completion
---@field signature_help xi.API.SignatureHelp
---@field schedule fun()
---@field feedkeys fun(keys: string, remap?: boolean)
function xi.do_action(runner)
  local ctx
  ctx = {
    completion = {
      prevent = function(callback)
        local resume = xi.get_completion_service():prevent()
        callback()
        resume()
      end,
      close = function()
        xi.get_completion_service():clear()
      end,
      is_menu_visible = function()
        return xi.get_completion_service():is_menu_visible()
      end,
      is_docs_visible = function()
        return xi.get_completion_service():is_docs_visible()
      end,
      get_selection = function()
        return xi.get_completion_service():get_selection()
      end,
      complete = function(option)
        xi.get_completion_service():complete(option):await()
      end,
      select = function(index, preselect)
        xi.get_completion_service():select(index, preselect):await()
      end,
      scroll_docs = function(delta)
        xi.get_completion_service():scroll_docs(delta)
      end,
      commit = function(index, option)
        local match = xi.get_completion_service():get_match_at(index)
        if match then
          xi.get_completion_service():commit(match.item, option):await()
          return true
        end
        return false
      end,
    },
    signature_help = {
      prevent = function(callback)
        local resume = xi.get_signature_help_service():prevent()
        callback()
        resume()
      end,
      trigger = function()
        xi.get_signature_help_service():trigger({ force = true }):await()
      end,
      close = function()
        xi.get_signature_help_service():clear()
      end,
      is_visible = function()
        return xi.get_signature_help_service():is_visible()
      end,
      get_active_signature_data = function()
        return xi.get_signature_help_service():get_active_signature_data()
      end,
      select = function(index)
        xi.get_signature_help_service():select(index)
      end,
      scroll = function(delta)
        xi.get_signature_help_service():scroll(delta)
      end,
    },
    schedule = function()
      Async.schedule():await()
    end,
    feedkeys = function(keys, remap)
      Keymap.send({ { keys = keys, remap = not not remap } }):await()
    end,
  } --[[@as xi.API]]
  if runner then
    Async.run(function()
      runner(ctx)
    end)
  end
end

---Get xi supported capabilities.
---@return table
function xi.get_capabilities()
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
            }
          },
          insertReplaceSupport = true,
          resolveSupport = {
            properties = {
              "documentation",
              "additionalTextEdits",
              "insertTextFormat",
              "insertTextMode",
              "command",
            },
          },
          insertTextModeSupport = {
            valueSet = {
              1, -- asIs
              2, -- adjustIndentation
            }
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
          }
        }
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
      }
    },
  }
end

return xi
