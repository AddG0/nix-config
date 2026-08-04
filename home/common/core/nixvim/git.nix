{pkgs, ...}: {
  # Flog isn't a nixvim module, so add the plugin directly.
  extraPlugins = [pkgs.vimPlugins.vim-flog];

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
          # Without a name, bufferline labels the tab from the diffview panel's buffer path.
          # gitlab.nvim reviews render through diffview too, but its is_open/tabid are set
          # only after DiffviewOpen returns, hence the defer.
          view_opened.__raw = ''
            function(view)
              vim.schedule(function()
                local name
                local ok, reviewer = pcall(require, "gitlab.reviewer")
                if ok and reviewer.is_open and reviewer.tabid == view.tabpage then
                  local info = require("gitlab.state").INFO or {}
                  name = info.source_branch and ("MR " .. info.source_branch)
                    or info.iid and ("MR !" .. info.iid)
                    or "MR Review"
                elseif view.class:name() == "FileHistoryView" then
                  name = "File History"
                else
                  -- rev_arg is nil for a plain working-tree diff
                  name = view.rev_arg and ("Git Diff " .. view.rev_arg) or "Git Diff"
                end
                pcall(vim.cmd, "BufferLineTabRename " .. name)
              end)
            end
          '';
        };
      };
    };
    neogit = {
      enable = true;
      # ghostty speaks the kitty graphics protocol, so draw real graph lines.
      settings.graph_style = "kitty";
    };
    fugitive.enable = true; # Flog's git backend
  };

  keymaps = [
    # ── Lazygit (LazyVim <leader>gg/<leader>gG) ──
    {
      # Root Dir: open lazygit at the repo root, not the file's cwd.
      mode = "n";
      key = "<leader>gg";
      action.__raw = ''function() Snacks.lazygit({ cwd = Snacks.git.get_root() }) end'';
      options.desc = "Lazygit (Root Dir)";
    }
    {
      mode = "n";
      key = "<leader>gG";
      action.__raw = ''function() Snacks.lazygit() end'';
      options.desc = "Lazygit (cwd)";
    }

    # ── Extra full-UI tools (not in LazyVim; moved off their default keys) ──
    {
      mode = "n";
      key = "<leader>gN";
      action = "<cmd>Neogit<cr>";
      options.desc = "Neogit";
    }
    {
      mode = "n";
      key = "<leader>gv";
      action = "<cmd>DiffviewOpen<cr>";
      options.desc = "Diffview";
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>lua Snacks.picker.git_branches({ all = true })<cr>";
      options.desc = "Git branches (checkout)";
    }
    {
      # -all: the whole graph, not just the current branch
      mode = ["n" "x"];
      key = "<leader>gt";
      action = "<cmd>Flog -all<cr>";
      options.desc = "Git tree (Flog)";
    }

    # ── Git pickers (LazyVim scheme) ──
    {
      mode = "n";
      key = "<leader>gl";
      action.__raw = ''function() Snacks.picker.git_log({ cwd = Snacks.git.get_root() }) end'';
      options.desc = "Git Log";
    }
    {
      mode = "n";
      key = "<leader>gL";
      action = "<cmd>lua Snacks.picker.git_log()<cr>";
      options.desc = "Git Log (cwd)";
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>lua Snacks.picker.git_log_line()<cr>";
      options.desc = "Git Blame Line";
    }
    {
      mode = "n";
      key = "<leader>gf";
      action = "<cmd>lua Snacks.picker.git_log_file()<cr>";
      options.desc = "Git Current File History";
    }
    {
      # --follow traces the file through renames so history survives a move.
      mode = "n";
      key = "<leader>gF";
      action = "<cmd>DiffviewFileHistory --follow %<cr>";
      options.desc = "File history (follow renames)";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>lua Snacks.picker.git_status()<cr>";
      options.desc = "Git Status";
    }
    {
      mode = "n";
      key = "<leader>gS";
      action = "<cmd>lua Snacks.picker.git_stash()<cr>";
      options.desc = "Git Stash";
    }
    {
      mode = "n";
      key = "<leader>gd";
      action = "<cmd>lua Snacks.picker.git_diff()<cr>";
      options.desc = "Git Diff (hunks)";
    }
    {
      mode = "n";
      key = "<leader>gD";
      action.__raw = ''function() Snacks.picker.git_diff({ base = "origin", group = true }) end'';
      options.desc = "Git Diff (origin)";
    }
    {
      mode = ["n" "x"];
      key = "<leader>gB";
      action.__raw = "function() Snacks.gitbrowse() end";
      options.desc = "Open on remote (browser)";
    }
    {
      mode = ["n" "x"];
      key = "<leader>gY";
      action.__raw = ''
        function()
          Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
        end
      '';
      options.desc = "Copy remote URL";
    }

    # ── Hunks (gitsigns — LazyVim <leader>gh group) ──
    {
      # In a diff view, jump by diff change (]c); otherwise by gitsigns hunk.
      mode = "n";
      key = "]h";
      action.__raw = ''
        function()
          if vim.wo.diff then vim.cmd.normal({ "]c", bang = true })
          else require("gitsigns").nav_hunk("next") end
        end
      '';
      options.desc = "Next Hunk";
    }
    {
      mode = "n";
      key = "[h";
      action.__raw = ''
        function()
          if vim.wo.diff then vim.cmd.normal({ "[c", bang = true })
          else require("gitsigns").nav_hunk("prev") end
        end
      '';
      options.desc = "Prev Hunk";
    }
    {
      mode = "n";
      key = "]H";
      action.__raw = ''function() require("gitsigns").nav_hunk("last") end'';
      options.desc = "Last Hunk";
    }
    {
      mode = "n";
      key = "[H";
      action.__raw = ''function() require("gitsigns").nav_hunk("first") end'';
      options.desc = "First Hunk";
    }
    {
      mode = ["n" "x"];
      key = "<leader>ghs";
      action = ":Gitsigns stage_hunk<cr>";
      options.desc = "Stage Hunk";
    }
    {
      mode = ["n" "x"];
      key = "<leader>ghr";
      action = ":Gitsigns reset_hunk<cr>";
      options.desc = "Reset Hunk";
    }
    {
      mode = "n";
      key = "<leader>ghS";
      action = "<cmd>Gitsigns stage_buffer<cr>";
      options.desc = "Stage Buffer";
    }
    {
      mode = "n";
      key = "<leader>ghu";
      action = "<cmd>Gitsigns undo_stage_hunk<cr>";
      options.desc = "Undo Stage Hunk";
    }
    {
      mode = "n";
      key = "<leader>ghR";
      action = "<cmd>Gitsigns reset_buffer<cr>";
      options.desc = "Reset Buffer";
    }
    {
      mode = "n";
      key = "<leader>ghp";
      action = "<cmd>Gitsigns preview_hunk_inline<cr>";
      options.desc = "Preview Hunk Inline";
    }
    {
      mode = "n";
      key = "<leader>ghb";
      action.__raw = ''function() require("gitsigns").blame_line({ full = true }) end'';
      options.desc = "Blame Line";
    }
    {
      mode = "n";
      key = "<leader>ghB";
      action = "<cmd>Gitsigns blame<cr>";
      options.desc = "Blame Buffer";
    }
    {
      mode = "n";
      key = "<leader>ghd";
      action = "<cmd>Gitsigns diffthis<cr>";
      options.desc = "Diff This";
    }
    {
      mode = "n";
      key = "<leader>ghD";
      action.__raw = ''function() require("gitsigns").diffthis("~") end'';
      options.desc = "Diff This ~";
    }
    {
      mode = ["o" "x"];
      key = "ih";
      action = ":<C-U>Gitsigns select_hunk<cr>";
      options.desc = "GitSigns Select Hunk";
    }
  ];
}
