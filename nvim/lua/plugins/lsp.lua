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
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local prefs = require("config.prefs")
      local pants_enabled = prefs.enabled("ENABLE_PANTS", true)
      local pants = pants_enabled and require("config.pants") or nil
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local python_config_cache = {}

      local function find_pants_python(root)
        if not root or root == "" then
          return { python_path = nil, extra_paths = {} }
        end

        if python_config_cache[root] then
          return python_config_cache[root]
        end

        if not pants_enabled or not pants or not pants.is_available(root) then
          python_config_cache[root] = { python_path = nil, extra_paths = {} }
          return python_config_cache[root]
        end
        local python_path, extra_paths = pants.current_python(root)

        python_config_cache[root] = {
          python_path = python_path,
          extra_paths = extra_paths,
        }

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
          local python_config = find_pants_python(root)
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
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "buffer" },
        }),
      })
    end,
  },
}
