vim.lsp.config('*', {
  capabilities = require('cmp-kit').get_completion_capabilities()
})
vim.lsp.config('*', {
  capabilities = require('cmp-kit').get_signature_help_capabilities()
})
