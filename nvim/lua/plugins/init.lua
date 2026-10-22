return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "L3MON4D3/LuaSnip",
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    dependencies = { "rafamadriz/friendly-snippets" },
  },
  {
    "mrcjkb/rustaceanvim",
    version = "^7",
   -- ft = "rust", 
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        map("n", "]c", gs.next_hunk, "Next Git Hunk")
        map("n", "[c", gs.prev_hunk, "Previous Git Hunk")

        map("n", "<leader>cp", gs.preview_hunk, "Preview Git Hunk")

        map("n", "<leader>cr", gs.reset_hunk, "Reset Git Hunk")
        map("n", "<leader>cb", function() gs.blame_line{full=true} end, "Blame Line")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git Diff Open" },
      { "<leader>gx", "<cmd>DiffviewClose<cr>", desc = "Git Diff Close" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git Current File History" },
    },
    config = function()
      require("diffview").setup({
      })
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
  	"nvim-treesitter/nvim-treesitter",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc",
       "html", "css"
  		},
  	},
    commit = "454354e",
  },
}
