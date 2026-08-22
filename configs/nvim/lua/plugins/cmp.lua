return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji", -- Example: Adding an extra plugin dependency
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")

      -- 1. Modify or add Custom Keymaps
      opts.mapping = cmp.mapping.preset.insert({
        -- Use Ctrl + Space to trigger completion
        ["<C-Space>"] = cmp.mapping.complete(),
        -- Use Ctrl + e to abort completion
        ["<C-e>"] = cmp.mapping.abort(),
        -- Accept currently selected item (Set select = false to only confirm explicit selections)
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        -- Navigate completion list with Ctrl + j and Ctrl + k
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        -- Scroll documentation windows
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
      })

      -- 2. Inject New Sources (e.g., adding emoji suggestions)
      table.insert(opts.sources, { name = "emoji" }, { name = "codecompanion" }, { name = "buffer" }, { name = "path" })

      -- 3. Change Window Styles (Add borders to completion/documentation windows)
      opts.window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      }
    end,
  },
}
