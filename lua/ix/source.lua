local misc = require('ix.misc')
local kit = require('cmp-kit.kit')

local source = {}

source.completion = {}

---Create github source.
---@return cmp-kit.completion.CompletionSource
function source.completion.github()
  return require('cmp-kit.completion.ext.source.github')()
end

---Create buffer source.
---@param option? cmp-kit.completion.ext.source.buffer.Option
---@return cmp-kit.completion.CompletionSource
function source.completion.buffer(option)
  return require('cmp-kit.completion.ext.source.buffer')(kit.merge(option or {}, {
    get_bufnrs = function()
      local bufs = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) ~= 'nofile' then
          table.insert(bufs, buf)
        end
      end
      return bufs
    end,
    gather_keyword_length = 3,
  } --[[@as cmp-kit.completion.ext.source.buffer.Option]]))
end

---Create emoji source.
---@return cmp-kit.completion.CompletionSource
function source.completion.emoji()
  return require('cmp-kit.completion.ext.source.emoji')()
end

---Create path source.
---@param option? cmp-kit.completion.ext.source.path.Option
---@return cmp-kit.completion.CompletionSource
function source.completion.path(option)
  return require('cmp-kit.completion.ext.source.path')(kit.merge(option or {}, {
    enable_file_document = true,
  } --[[@as cmp-kit.completion.ext.source.path.Option]]))
end

---Create calc source.
---@return cmp-kit.completion.CompletionSource
function source.completion.calc()
  return require('cmp-kit.completion.ext.source.calc')()
end

---Create cmdline source.
---@return cmp-kit.completion.CompletionSource
function source.completion.cmdline()
  return require('cmp-kit.completion.ext.source.cmdline')()
end

---Attach lsp completion source to the completion service.
---@param completion_service cmp-kit.completion.CompletionService
---@param option? { bufnr: integer?, group: integer?, priority: integer?, server?: table<string, cmp-kit.completion.ext.source.lsp.completion.Option> }
function source.completion.attach_lsp(completion_service, option)
  option = option or {}
  option.bufnr = option.bufnr or vim.api.nvim_get_current_buf()
  option.bufnr = option.bufnr ~= 0 and vim.api.nvim_get_current_buf() or option.bufnr
  option.group = option.group or 10
  option.priority = option.priority or 100
  option.server = option.server or {}

  local attached = {} --[[@type table<integer, fun()>]]

  -- attach.
  local function attach()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = option.bufnr })) do
      if attached[client.id] then
        attached[client.id]()
      end
      attached[client.id] = completion_service:register_source(require('cmp-kit.completion.ext.source.lsp.completion')(kit.merge({ client = client }, option.server[client.name] or {})), {
        group = option.group,
        priority = option.priority,
      })
    end
  end
  completion_service:on_dispose(misc.autocmd('LspAttach', {
    callback = attach,
  }))
  attach()

  -- detach.
  completion_service:on_dispose(misc.autocmd('LspDetach', {
    callback = function(e)
      if attached[e.data.client_id] then
        attached[e.data.client_id]()
        attached[e.data.client_id] = nil
      end
    end,
  }))
end

source.signature_help = {}

---Attach lsp signature_help source to the signature_help service.
---@param signature_help_service cmp-kit.signature_help.SignatureHelpService
---@param option? { bufnr: integer?, group: integer?, priority: integer? }
function source.signature_help.attach_lsp(signature_help_service, option)
  option = option or {}
  option.bufnr = option.bufnr or vim.api.nvim_get_current_buf()
  option.bufnr = option.bufnr ~= 0 and vim.api.nvim_get_current_buf() or option.bufnr
  option.group = option.group or 10
  option.priority = option.priority or 100

  local attached = {} --[[@type table<integer, fun()>]]

  -- attach.
  local function attach()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = option.bufnr })) do
      if attached[client.id] then
        attached[client.id]()
        attached[client.id] = nil
      end
      attached[client.id] = signature_help_service:register_source(require('cmp-kit.signature_help.ext.source.lsp.signature_help')({ client = client }), {
        group = option.group,
        priority = option.priority,
      })
    end
  end
  signature_help_service:on_dispose(misc.autocmd('LspAttach', {
    callback = attach,
  }))
  attach()

  -- detach.
  signature_help_service:on_dispose(misc.autocmd('LspDetach', {
    callback = function(e)
      if attached[e.data.client_id] then
        attached[e.data.client_id]()
        attached[e.data.client_id] = nil
      end
    end,
  }))
end

return source
