return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local prefs = require("config.prefs")
      local wk = require("which-key")
      local mappings = {
        { "<leader>w", desc = "Save file" },
        { "<leader>q", desc = "Quit window" },

        { "<leader>c", group = "Code" },
        { "<leader>ca", desc = "Code action" },
        { "<leader>cf", desc = "Format file" },
        { "<leader>rn", desc = "Rename symbol" },

        { "<leader>f", group = "Find" },
        { "<leader>ff", desc = "Find files" },
        { "<leader>fg", desc = "Live grep" },
        { "<leader>fp", desc = "Live grep with path filter" },
        { "<leader>fb", desc = "Buffers" },
        { "<leader>fB", desc = "Current tab buffers" },
        { "<leader>fr", desc = "Recent files" },
        { "<leader>fR", desc = "Project replace" },
        { "<leader>fs", desc = "Grep word under cursor" },
        { "<leader>fc", desc = "Fuzzy find in buffer" },
        { "<leader>fh", desc = "Help tags" },
        { "<leader>fd", desc = "Diagnostics" },
        { "<leader>r",  desc = "Registers" },
        { "<leader>h",  desc = "Help popup" },

        { "<leader>g", group = "Git" },
        { "<leader>gs", desc = "Git status" },
        { "<leader>gl", desc = "Git log" },
        { "<leader>gc", desc = "Git branches" },

        { "<leader>e", desc = "Toggle file tree" },
        { "<leader>o", desc = "Focus file tree" },

        { "<leader>b", group = "Buffer" },
        { "<leader>bd", desc = "Close buffer" },

        { "<leader>x", group = "Diagnostics" },
        { "<leader>xx", desc = "Diagnostics panel" },

        { "<leader>s", group = "Split / Window" },
        { "<leader>sv", desc = "Vertical split" },
        { "<leader>sh", desc = "Horizontal split" },
      }

      if prefs.enabled("ENABLE_PANTS", true) then
        table.insert(mappings, { "<leader>p", group = "Project" })
        table.insert(mappings, { "<leader>pp", desc = "Run pre-push" })
        table.insert(mappings, { "<leader>t", desc = "Open Pants tests" })
      end

      wk.setup({
        delay = 300,
        preset = "modern",
      })

      wk.add(mappings)
    end,
  },
}
