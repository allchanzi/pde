return {
  -- Formatter plugin
  {
    "stevearc/conform.nvim",
    opts = function()
      local prefs = require("config.prefs")
      local project = require("config.project")
      local pants_enabled = prefs.enabled("ENABLE_PANTS", true)

      return {
        formatters_by_ft = {
          python = function(bufnr)
            if pants_enabled and project.is_pants_project(vim.api.nvim_buf_get_name(bufnr)) then
              return {}
            end

            return { "black" }
          end,
          dart = { "dart_format" },
        },
        format_on_save = {
          timeout_ms = 1000,
          lsp_format = "fallback",
        },
      }
    end,
  },
}
