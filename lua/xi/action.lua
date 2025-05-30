local action = {}

--- common.
do
  ---Scroll completion docs or signature help.
  function action.scroll(delta)
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      local exec = false
      if ctx.completion.is_docs_visible() then
        ctx.completion.scroll_docs(delta)
        exec = true
      end
      if ctx.signature_help.is_visible() then
        ctx.signature_help.scroll(delta)
        exec = true
      end
      if not exec then
        fallback()
      end
    end
  end
end

--- completion.
do
  action.completion = {}

  ---Invoke completion.
  function action.completion.complete()
    ---@type xi.Charmap.Callback
    return function(ctx)
      ctx.completion.complete({ force = true })
    end
  end

  ---Select next completion item.
  ---@param option? { no_insert?: boolean }
  function action.completion.select_next(option)
    option = option or {}
    option.no_insert = option.no_insert or false

    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      local selection = ctx.completion.get_selection()
      if selection then
        ctx.completion.select(selection.index + 1, option.no_insert)
      else
        fallback()
      end
    end
  end

  ---Select prev completion item.
  ---@param option? { no_insert?: boolean }
  function action.completion.select_prev(option)
    option = option or {}
    option.no_insert = option.no_insert or false

    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      local selection = ctx.completion.get_selection()
      if selection then
        ctx.completion.select(selection.index - 1, option.no_insert)
      else
        fallback()
      end
    end
  end

  ---Commit completion item.
  ---@param option? { select_first?: boolean, replace?: boolean, no_snippet?: boolean  }
  function action.completion.commit(option)
    option = option or {}
    option.select_first = option.select_first or false
    option.replace = option.replace or false
    option.no_snippet = option.no_snippet or false

    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      local selection = ctx.completion.get_selection()
      if selection then
        local index = selection.index
        if option.select_first and index == 0 then
          index = 1
        end

        if index > 0 then
          if ctx.completion.commit(index, { replace = option.replace, no_snippet = option.no_snippet }) then
            return
          end
        end
        fallback()
      end
    end
  end

  ---Commit completion for cmdline.
  function action.completion.commit_cmdline()
    ---@type xi.Charmap.Callback
    return function(ctx)
      ctx.completion.close()
      vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'n', true) -- don't use `ctx.fallback` here it sends extra `<Cmd>...<CR>` keys, that prevent Hit-Enter prompt unexpectedly.
    end
  end

  ---Close completion menu.
  function action.completion.close()
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      if ctx.completion.is_menu_visible() then
        ctx.completion.close()
      else
        fallback()
      end
    end
  end

  ---Scroll completion docs.
  ---@param delta integer
  function action.completion.scroll_docs(delta)
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      if ctx.completion.is_docs_visible() then
        ctx.completion.scroll_docs(delta)
      else
        fallback()
      end
    end
  end
end

--- signature_help.
do
  action.signature_help = {}

  ---Trigger signature help.
  function action.signature_help.trigger()
    ---@type xi.Charmap.Callback
    return function(ctx)
      ctx.signature_help.trigger()
    end
  end

  ---Select next signature help item.
  function action.signature_help.select_next()
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      if ctx.signature_help.is_visible() then
        local data = ctx.signature_help.get_active_signature_data()
        if data then
          local index = data.signature_index + 1
          if index > data.signature_count then
            index = 1
          end
          ctx.signature_help.select(index)
        end
      else
        fallback()
      end
    end
  end

  ---Select prev signature help item.
  function action.signature_help.select_prev()
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      if ctx.signature_help.is_visible() then
        local data = ctx.signature_help.get_active_signature_data()
        if data then
          local index = data.signature_index - 1
          if index < 1 then
            index = data.signature_count
          end
          ctx.signature_help.select(index)
        end
      else
        fallback()
      end
    end
  end

  ---Scroll signature help view.
  function action.signature_help.scroll(delta)
    ---@type xi.Charmap.Callback
    return function(ctx, fallback)
      if ctx.signature_help.is_visible() then
        ctx.signature_help.scroll(delta)
      else
        fallback()
      end
    end
  end
end

return action
