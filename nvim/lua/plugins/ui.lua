return {
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      local theme = require("config.theme")
      local p = theme.palette

      require("illuminate").configure({
        delay = 180,
        large_file_cutoff = 3000,
        large_file_overrides = {
          providers = { "lsp" },
        },
      })

      vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = p.surface1 })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = p.surface1 })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = p.surface2, bold = true })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      local prefs = require("config.prefs")
      local pants_enabled = prefs.enabled("ENABLE_PANTS", true)
      local pants = pants_enabled and require("config.pants") or nil

      local python_component = {
        function()
          if not pants then return "" end
          local label = pants.current_python_label_if_cached(vim.fn.getcwd())
          if not label or label == "" then return "" end
          return " " .. label
        end,
        cond = function()
          return pants and pants.is_available(vim.fn.getcwd()) or false
        end,
        color = { fg = "#a6e3a1" },
      }

      local lualine = require("lualine")
      lualine.setup({
        options = {
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { python_component, "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {},
      })

      -- Refresh lualine when async python discovery finishes
      vim.api.nvim_create_autocmd("User", {
        pattern = "PantsPythonReady",
        callback = function() lualine.refresh() end,
      })
    end,
  },

  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      local theme = require("config.theme")
      local p = theme.palette
      local base = p.base
      local active = p.surface1
      local subtle = p.subtle
      local text = p.text

      require("bufferline").setup({
        highlights = {
          fill                   = { bg = base },
          background             = { bg = base, fg = subtle },
          buffer_selected        = { bg = active, fg = text, bold = true, italic = false },
          buffer_visible         = { bg = base, fg = subtle },
          close_button           = { bg = base, fg = subtle },
          close_button_selected  = { bg = active, fg = text },
          close_button_visible   = { bg = base, fg = subtle },
          modified               = { bg = base },
          modified_selected      = { bg = active },
          modified_visible       = { bg = base },
          separator              = { bg = base, fg = base },
          separator_selected     = { bg = base, fg = base },
          separator_visible      = { bg = base, fg = base },
          indicator_selected     = { bg = active, fg = active },
          tab                    = { bg = base, fg = subtle },
          tab_selected           = { bg = active, fg = text },
          tab_separator          = { bg = base, fg = base },
          tab_separator_selected = { bg = base, fg = base },
          numbers                = { bg = base, fg = subtle },
          numbers_selected       = { bg = active, fg = text, bold = true },
          pick                   = { bg = base, fg = subtle, italic = false },
          pick_selected          = { bg = active, fg = text, italic = false },
          pick_visible           = { bg = base, fg = subtle, italic = false },
        },
        options = {
          mode = "buffers",
          separator_style = "slant",
          show_buffer_icons = true,
          show_buffer_close_icons = true,
          show_close_icon = false,
          always_show_bufferline = true,
          modified_icon = "●",
          close_icon = "󰅖",
          show_tab_indicators = true,
          offsets = {
            {
              filetype = "NvimTree",
              text = "Files",
              text_align = "left",
              separator = true,
            },
          },
        },
      })
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      local theme = require("config.theme")

      if theme.colorscheme ~= "catppuccin" then
        return
      end

      require("catppuccin").setup({
        flavour = theme.flavour,
        term_colors = true,
        color_overrides = theme.color_overrides,
        custom_highlights = function()
          return theme.custom_highlights or {}
        end,
        integrations = {
          telescope = true,
          treesitter = true,
          nvimtree = true,
          cmp = true,
          gitsigns = true,
          bufferline = true,
        },
      })

      vim.o.background = theme.background
      vim.cmd.colorscheme(theme.colorscheme)
    end,
  },

  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    priority = 1000,
    config = function()
      local theme = require("config.theme")

      if theme.colorscheme ~= "tokyonight" then
        return
      end

      local p = theme.palette

      require("tokyonight").setup({
        style = theme.flavour ~= "" and theme.flavour or "night",
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          sidebars = "dark",
          floats = "dark",
        },
        on_colors = function(colors)
          colors.bg = p.base
          colors.bg_dark = p.surface0
          colors.bg_float = p.surface0
          colors.bg_highlight = p.surface1
          colors.bg_popup = p.surface0
          colors.bg_sidebar = p.surface0
          colors.bg_statusline = p.base
          colors.fg = p.text
          colors.fg_dark = p.subtext0
          colors.fg_float = p.text
          colors.fg_gutter = p.subtle
          colors.comment = p.subtle
          colors.blue = p.blue
          colors.magenta = p.pink
          colors.purple = p.lavender
          colors.green = p.green
          colors.yellow = p.yellow
          colors.cyan = p.cyan
          colors.red = p.red
          colors.orange = p.rosewater
          colors.border = p.surface1
        end,
        on_highlights = function(highlights)
          for group, spec in pairs(theme.custom_highlights or {}) do
            highlights[group] = spec
          end
        end,
      })

      vim.o.background = theme.background
      vim.cmd.colorscheme(theme.colorscheme)
    end,
  },

  {
    "Mofiqul/dracula.nvim",
    name = "dracula",
    priority = 1000,
    config = function()
      local theme = require("config.theme")

      if theme.colorscheme ~= "dracula" then
        return
      end

      require("dracula").setup({
        transparent_bg = false,
        italic_comment = true,
        overrides = theme.custom_highlights or {},
      })

      vim.o.background = theme.background
      vim.cmd.colorscheme(theme.colorscheme)
    end,
  },

  {
    "shaunsingh/nord.nvim",
    name = "nord",
    priority = 1000,
    config = function()
      local theme = require("config.theme")

      if theme.colorscheme ~= "nord" then
        return
      end

      vim.o.background = theme.background
      vim.cmd.colorscheme(theme.colorscheme)

      for group, spec in pairs(theme.custom_highlights or {}) do
        vim.api.nvim_set_hl(0, group, spec)
      end
    end,
  },

  {
    "altercation/vim-colors-solarized",
    name = "solarized",
    priority = 1000,
    config = function()
      local theme = require("config.theme")

      if theme.colorscheme ~= "solarized" then
        return
      end

      vim.o.background = theme.background
      vim.cmd.colorscheme(theme.colorscheme)

      for group, spec in pairs(theme.custom_highlights or {}) do
        vim.api.nvim_set_hl(0, group, spec)
      end
    end,
  },
}
