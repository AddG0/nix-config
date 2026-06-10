{
  programs.nixvim = {
    # Show full file in diffs instead of just changed hunks.
    opts.diffopt = "internal,filler,closeoff,context:99999";

    plugins = {
      gitsigns.enable = true;
      diffview.enable = true;
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
        action = "<cmd>DiffviewOpen<cr>";
        options.desc = "Diffview";
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
  };
}
