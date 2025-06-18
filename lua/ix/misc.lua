local kit = require('cmp-kit.kit')

local misc = {}

local group = vim.api.nvim_create_augroup('ix', {
  clear = true
})

---Create disposable autocmd.
---@param e string|string[]
---@param opts vim.api.keyset.create_autocmd
---@return fun()
function misc.autocmd(e, opts)
  local id = vim.api.nvim_create_autocmd(e, kit.merge(opts, {
    group = group
  }))
  return function()
    pcall(vim.api.nvim_del_autocmd, id)
  end
end

function misc.autocmd_queue()
  local scheduling = false
  local tasks = {}
  return {
    add = function(task)
      table.insert(tasks, task)
      if not scheduling then
        scheduling = true
        vim.api.nvim_create_autocmd('SafeState', {
          once = true,
          callback = function()
            local target = tasks[#tasks]
            tasks = {}
            scheduling = false
            if target then
              target()
            end
          end
        })
      end
    end
  }
end

return misc
