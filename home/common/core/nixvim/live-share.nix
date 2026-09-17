# Pair programming — the nvim analog of VSCode's Live Share (ms-vsliveshare).
# Host <leader>ls copies a tunnel URL; guest pastes it into <leader>lj.
{pkgs, ...}: {
  extraPlugins = [pkgs.vimPlugins.live-share-nvim];

  # The default localhost.run provider tunnels over ssh.
  extraPackages = [pkgs.openssh];

  extraConfigLua = ''
    require("live-share").setup({
      username = vim.env.USER or "addg",
    })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>ls";
      action = "<cmd>LiveShareHostStart<cr>";
      options.desc = "Host session";
    }
    {
      mode = "n";
      key = "<leader>lj";
      action.__raw = ''
        function()
          vim.ui.input({ prompt = "Live Share URL: " }, function(url)
            if url and url ~= "" then
              vim.cmd("LiveShareJoin " .. url)
            end
          end)
        end
      '';
      options.desc = "Join session";
    }
    {
      mode = "n";
      key = "<leader>lq";
      action = "<cmd>LiveShareStop<cr>";
      options.desc = "Stop session";
    }
    {
      mode = "n";
      key = "<leader>lp";
      action = "<cmd>LiveSharePeers<cr>";
      options.desc = "Peers";
    }
    {
      mode = "n";
      key = "<leader>lf";
      action = "<cmd>LiveShareFollow<cr>";
      options.desc = "Follow peer";
    }
    {
      mode = "n";
      key = "<leader>lF";
      action = "<cmd>LiveShareUnfollow<cr>";
      options.desc = "Unfollow peer";
    }
    {
      mode = "n";
      key = "<leader>lw";
      action = "<cmd>LiveShareWorkspace<cr>";
      options.desc = "Browse host workspace";
    }
    {
      mode = "n";
      key = "<leader>lt";
      action = "<cmd>LiveShareTerminal<cr>";
      options.desc = "Shared terminal";
    }
  ];
}
