return {
  { "nvim-lua/plenary.nvim" },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "BufReadPost",
    opts = {
      ensure_installed = {
        "python",
        "dart",
        "lua",
        "vim",
        "vimdoc",
        "bash",
      },
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
      },
    },
    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = vim.fn.executable("make") == 1,
      },
    },
    event = "VeryLazy",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>",                desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>",                 desc = "Live grep" },
      {
        "<leader>fp",
        function()
          require("config.grep_form").open()
        end,
        desc = "Live grep with path filter",
      },
      { "<leader>fb", "<cmd>Telescope buffers<cr>",                   desc = "Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                  desc = "Recent files" },
      { "<leader>fs", "<cmd>Telescope grep_string<cr>",               desc = "Grep word under cursor" },
      { "<leader>fc", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Fuzzy find in buffer" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>",                 desc = "Help tags" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>",               desc = "Diagnostics" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>",                desc = "Git status" },
      { "<leader>gl", "<cmd>Telescope git_commits<cr>",               desc = "Git log" },
      { "<leader>gc", "<cmd>Telescope git_branches<cr>",              desc = "Git branches" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
          path_display = { "truncate" },
          file_ignore_patterns = {
            "%.git/",
            "node_modules/",
            "__pycache__/",
            "%.pants%.d/",
            "dist/export/",
            "%.mypy_cache/",
            "%.pytest_cache/",
            "%.eggs/",
          },
        },
      })
      -- fzf-native: C-level sorter, significantly faster on large repos
      pcall(telescope.load_extension, "fzf")
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500,
        virt_text_pos = "eol",
      },
      current_line_blame_formatter = " <author>, <author_time:%Y-%m-%d>",
    },
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    opts = {},
  },
}
