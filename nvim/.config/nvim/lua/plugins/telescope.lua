return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "debugloop/telescope-undo.nvim",
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release" },
  },
  config = function()
    local telescope = require "telescope"
    local actions = require "telescope.actions"
    local transform_mod = require("telescope.actions.mt").transform_mod

    local trouble = require "trouble"
    local trouble_telescope = require "trouble.sources.telescope"

    -- or create your custom action
    local custom_actions = transform_mod {
      open_trouble_qflist = function(prompt_bufnr)
        trouble.toggle "quickfix"
      end,
    }

    telescope.setup {
      defaults = {
        path_display = { "smart" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
            ["<C-t>"] = trouble_telescope.open,
          },
        },
      },
      extensions = {
        fzf = {
          fuzzy = true, -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true, -- override the file sorter
          case_mode = "smart_case", -- or "ignore_case" or "respect_case"
          -- the default case_mode is "smart_case"
        },
      },
    }
    telescope.load_extension "fzf"
    telescope.load_extension "undo"
  end,
}
