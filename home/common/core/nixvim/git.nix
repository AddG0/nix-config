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
      settings = {
        # brighten the changed text within a line, not the whole line
        enhanced_diff_hl = true;
        hooks = {
          # Diff windows start with numbers off; restore our hybrid number column.
          diff_buf_win_enter.__raw = ''
            function()
              vim.opt_local.number = true
              vim.opt_local.relativenumber = true
            end
          '';
          # gitlab.nvim reviews render through diffview; name that tab from the MR.
          # is_open/tabid are set only after DiffviewOpen returns, so defer the check.
          view_opened.__raw = ''
            function(view)
              vim.schedule(function()
                local ok, reviewer = pcall(require, "gitlab.reviewer")
                if not (ok and reviewer.is_open and reviewer.tabid == view.tabpage) then
                  return
                end
                local info = require("gitlab.state").INFO or {}
                local name = info.source_branch and ("MR " .. info.source_branch)
                  or info.iid and ("MR !" .. info.iid)
                  or "MR Review"
                pcall(vim.cmd, "BufferLineTabRename " .. name)
              end)
            end
          '';
        };
      };
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
}
