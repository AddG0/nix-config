{
  plugins = {
    gitsigns = {
      enable = true;
      settings = {
        numhl = true; # tint the line number by git status, not just the gutter bar
        current_line_blame = true;
        current_line_blame_opts = {
          virt_text_pos = "eol";
          delay = 300;
        };
      };
    };
    diffview = {
      enable = true;
      # brighten the changed text within a line, not the whole line
      settings.enhanced_diff_hl = true;
    };
    neogit.enable = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>gg";
      action = "<cmd>Neogit<cr>";
      options.desc = "Neogit";
    }
    {
      mode = "n";
      key = "<leader>gd";
      # DiffviewOpen has no toggle; close it when a diffview tab is already up.
      action.__raw = ''
        function()
          local lib = require("diffview.lib")
          if lib.get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end
      '';
      options.desc = "Diffview (toggle)";
    }

    # ── Git pickers (snacks) ──
    {
      mode = "n";
      key = "<leader>gl";
      action = "<cmd>lua Snacks.picker.git_log()<cr>";
      options.desc = "Git log";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>lua Snacks.picker.git_status()<cr>";
      options.desc = "Git status";
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>lua Snacks.picker.git_branches({ all = true })<cr>";
      options.desc = "Git branches";
    }
    {
      mode = "n";
      key = "<leader>gf";
      action = "<cmd>lua Snacks.picker.git_log_file()<cr>";
      options.desc = "Git current file history";
    }
    {
      mode = ["n" "x"];
      key = "<leader>gB";
      action.__raw = "function() Snacks.gitbrowse() end";
      options.desc = "Git browse (open)";
    }
    {
      mode = ["n" "x"];
      key = "<leader>gY";
      action.__raw = ''
        function()
          Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
        end
      '';
      options.desc = "Git browse (copy URL)";
    }

    # ── Hunks (gitsigns) ──
    {
      mode = "n";
      key = "]h";
      action = "<cmd>Gitsigns next_hunk<cr>";
      options.desc = "Next hunk";
    }
    {
      mode = "n";
      key = "[h";
      action = "<cmd>Gitsigns prev_hunk<cr>";
      options.desc = "Prev hunk";
    }
    {
      mode = "n";
      key = "<leader>ghs";
      action = "<cmd>Gitsigns stage_hunk<cr>";
      options.desc = "Stage hunk";
    }
    {
      mode = "n";
      key = "<leader>ghr";
      action = "<cmd>Gitsigns reset_hunk<cr>";
      options.desc = "Reset hunk";
    }
    {
      mode = "n";
      key = "<leader>ghp";
      action = "<cmd>Gitsigns preview_hunk<cr>";
      options.desc = "Preview hunk";
    }
    {
      mode = "n";
      key = "<leader>ghb";
      action = "<cmd>Gitsigns blame_line<cr>";
      options.desc = "Blame line";
    }
    {
      mode = "n";
      key = "<leader>ghd";
      action = "<cmd>Gitsigns diffthis<cr>";
      options.desc = "Diff this";
    }
  ];
}
