# GitLab MR review/management — the VSCode "GitLab Workflow" equivalent.
# Reviews render through the diffview already configured in ./git.nix.
#
# Auth: a GITLAB_TOKEN env var (or a `.gitlab.nvim` file in the repo root). It
# must be a Personal Access Token (scope `api`) — gitlab.nvim sends it as a
# PRIVATE-TOKEN header, which GitLab rejects (401) for OAuth tokens.
{
  pkgs,
  lib,
  ...
}: {
  extraPlugins = [
    pkgs.gitlab-nvim
    pkgs.vimPlugins.nui-nvim
  ];

  # binary set => upstream skips its build-and-version-check path and uses ours.
  extraConfigLua = ''
    require("gitlab").setup({
      server = {
        binary = "${lib.getExe pkgs.gitlab-nvim.server}",
      },
    })
  '';

  keymaps = let
    gl = fn: {
      __raw = "function() require('gitlab').${fn} end";
    };
  in [
    {
      mode = "n";
      key = "<leader>gmo";
      action = gl "choose_merge_request()";
      options.desc = "GitLab: choose MR";
    }
    {
      mode = "n";
      key = "<leader>gmr";
      action = gl "review()";
      options.desc = "GitLab: review current MR";
    }
    {
      mode = "n";
      key = "<leader>gms";
      action = gl "summary()";
      options.desc = "GitLab: MR summary";
    }
    {
      mode = ["n" "v"];
      key = "<leader>gmc";
      action = gl "create_comment()";
      options.desc = "GitLab: comment on line(s)";
    }
    {
      mode = "n";
      key = "<leader>gmd";
      action = gl "toggle_discussions()";
      options.desc = "GitLab: toggle discussions";
    }
    {
      mode = "n";
      key = "<leader>gmA";
      action = gl "approve()";
      options.desc = "GitLab: approve MR";
    }
    {
      mode = "n";
      key = "<leader>gmR";
      action = gl "revoke()";
      options.desc = "GitLab: revoke approval";
    }
    {
      mode = "n";
      key = "<leader>gma";
      action = gl "add_assignee()";
      options.desc = "GitLab: add assignee";
    }
    {
      mode = "n";
      key = "<leader>gmv";
      action = gl "add_reviewer()";
      options.desc = "GitLab: add reviewer";
    }
    {
      mode = "n";
      key = "<leader>gmp";
      action = gl "pipeline()";
      options.desc = "GitLab: pipeline status";
    }
    {
      mode = "n";
      key = "<leader>gmb";
      action = gl "open_in_browser()";
      options.desc = "GitLab: open MR in browser";
    }
  ];
}
