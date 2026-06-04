return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "echasnovski/mini.nvim",
    },
    opts = {},
  },

  {
    "lervag/vimtex",
    ft = { "tex", "plaintex", "bib" },
    init = function()
      if vim.uv.fs_stat("/Applications/Skim.app") then
        vim.g.vimtex_view_method = "skim"
      end
      vim.g.vimtex_quickfix_mode = 0
    end,
  },
}
