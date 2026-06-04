return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      -- Disable netrw because nvim-tree replaces it
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1

      local function on_attach(bufnr)
        local api = require("nvim-tree.api")

        api.config.mappings.default_on_attach(bufnr)

        local function focus_previous_window()
          vim.cmd("stopinsert")
          vim.cmd("wincmd p")
        end

        local function open_and_focus()
          api.node.open.edit()
          focus_previous_window()
        end

        vim.keymap.set("n", "l", open_and_focus, { buffer = bufnr, desc = "Open and focus editor" })
        vim.keymap.set("n", "<CR>", open_and_focus, { buffer = bufnr, desc = "Open and focus editor" })
        vim.keymap.set("n", "h", api.node.navigate.parent_close, { buffer = bufnr, desc = "Close folder" })
        vim.keymap.set("n", "<Tab>", focus_previous_window, { buffer = bufnr, desc = "Focus previous window" })

        vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
          buffer = bufnr,
          callback = function()
            vim.cmd("stopinsert")
          end,
        })
      end

      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        git = {
          enable = true,
          timeout = 5000,
          show_on_dirs = true,
          show_on_open_dirs = true,
        },
        view = {
          width = 32,
          side = "left",
          preserve_window_proportions = true,
        },
        renderer = {
          group_empty = true,
          highlight_git = "name",
          highlight_modified = "name",
        },
        modified = {
          enable = true,
          show_on_dirs = true,
          show_on_open_dirs = true,
        },
        filters = {
          dotfiles = false,
          git_ignored = false,
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = true,
          },
        },
        update_focused_file = {
          enable = true,
          update_root = false,
        },
        on_attach = on_attach,
      })
    end,
  },
}
