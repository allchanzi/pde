return {
  {
    "williamboman/mason.nvim",
    opts = {},
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "basedpyright", "rust_analyzer" },
      automatic_installation = true,
    },
  },

  {
    "hrsh7th/cmp-nvim-lsp",
  },

  {
    "L3MON4D3/LuaSnip",
    dependencies = {
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local ls = require("luasnip")

      ls.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
      })

      ls.add_snippets("python", require("config.snippets.python"))
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    opts = function()
      local theme = require("config.theme")
      local p = theme.palette

      vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", {
        bg = p.surface1,
        fg = p.text,
        bold = true,
      })

      return {
        bind = true,
        hint_enable = false,
        floating_window = true,
        floating_window_above_cur_line = true,
        doc_lines = 0,
        fix_pos = true,
        close_timeout = 2000,
        handler_opts = {
          border = "rounded",
        },
        hi_parameter = "LspSignatureActiveParameter",
      }
    end,
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local prefs = require("config.prefs")
      local pants_enabled = prefs.enabled("ENABLE_PANTS", true)
      local pants = pants_enabled and require("config.pants") or nil
      local poetry = require("config.poetry")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local python_config_cache = {}

      local function find_python_config(root)
        if not root or root == "" then
          return { python_path = nil, extra_paths = {} }
        end

        if python_config_cache[root] then
          return python_config_cache[root]
        end

        if pants_enabled and pants and pants.is_available(root) then
          local python_path, extra_paths = pants.current_python(root)

          python_config_cache[root] = {
            python_path = python_path,
            extra_paths = extra_paths,
          }

          return python_config_cache[root]
        end

        if poetry.is_available(root) then
          local python_path, extra_paths = poetry.current_python(root)

          python_config_cache[root] = {
            python_path = python_path,
            extra_paths = extra_paths,
          }

          return python_config_cache[root]
        end

        python_config_cache[root] = { python_path = nil, extra_paths = {} }

        return python_config_cache[root]
      end

      vim.lsp.config("basedpyright", {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              typeCheckingMode = "basic",
              diagnosticMode = "openFilesOnly",
            },
          },
        },
        before_init = function(_, config)
          local root = config.root_dir or vim.fn.getcwd()
          local python_config = find_python_config(root)
          local python_path = python_config.python_path

          if python_path then
            config.settings = config.settings or {}
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = python_path
            config.settings.python.analysis = config.settings.python.analysis or {}
            config.settings.python.analysis.extraPaths = python_config.extra_paths
          end
        end,
      })

      vim.lsp.enable("basedpyright")

      vim.lsp.config("rust_analyzer", {
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            diagnostics = { enable = true },
          },
        },
      })
      vim.lsp.enable("rust_analyzer")

      vim.lsp.config("dartls", {
        capabilities = capabilities,
      })
      vim.lsp.enable("dartls")
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "luasnip", priority = 1100 },
          { name = "nvim_lsp", priority = 1000 },
          { name = "path", priority = 750 },
          { name = "buffer", priority = 500 },
        }),
      })
    end,
  },
}
