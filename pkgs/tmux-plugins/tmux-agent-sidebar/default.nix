# Real-time agent-monitoring sidebar. One store path serves three roles — tmux
# rtp, `claude --plugin-dir` root, and where hook.sh finds bin/ — so the plugin's
# own hooks/hooks.json drives state (Claude side wired in the claude-code module).
{
  lib,
  rustPlatform,
  tmuxPlugins,
  fetchFromGitHub,
  makeWrapper,
  bash,
  tmux,
  gnused,
  gawk,
  coreutils,
}: let
  version = "0.13.0";
  src = fetchFromGitHub {
    owner = "hiroppy";
    repo = "tmux-agent-sidebar";
    rev = "ae45bbae16f44c0b229913eef995065ad9969fe0";
    hash = "sha256-ZAjTaAWq7guImUD+7td88dUBQeSerVzRF7m2okdVR3w=";
  };

  bin = rustPlatform.buildRustPackage {
    pname = "tmux-agent-sidebar";
    inherit version src;
    cargoHash = "sha256-OerkrbT2O0ga47f9rIURWrLoiODGwuRgjLiG7VcbZ+c=";

    # These probe a live git repo/worktree, absent in the build sandbox.
    checkFlags = [
      "--skip=group::tests::resolve_git_info_for_real_repo"
      "--skip=group::tests::worktree_and_main_share_same_repo_root"
    ];
  };
  # mkTmuxPlugin's default omits --flake, so it looks for a default.nix this
  # repo doesn't have. --subpackage keeps bin's cargoHash in step with the bump.
  extraPassthru = {
    inherit bin;
    updateScript = ["nix-update" "--flake" "tmuxPlugins-tmux-agent-sidebar" "--subpackage" "bin"];
  };

  plugin = tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-agent-sidebar";
    rtpFilePath = "tmux-agent-sidebar.tmux";
    inherit version src;

    nativeBuildInputs = [makeWrapper];

    # .tmux and hook.sh both look for bin/tmux-agent-sidebar. Wrap only .tmux
    # (needs bash/tmux/sed/awk); hook.sh calls the absolute binary, so no PATH.
    postInstall = ''
      mkdir -p "$target/bin"
      ln -s ${bin}/bin/tmux-agent-sidebar "$target/bin/tmux-agent-sidebar"
      wrapProgram "$target/tmux-agent-sidebar.tmux" \
        --prefix PATH : ${lib.makeBinPath [bash tmux gnused gawk coreutils]}
    '';

    meta = {
      description = "Real-time tmux sidebar TUI monitoring AI coding agents across sessions";
      homepage = "https://github.com/hiroppy/tmux-agent-sidebar";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
      mainProgram = "tmux-agent-sidebar";
    };
  };
in
  # mkTmuxPlugin shallow-merges its own `passthru` over the attrs it is given,
  # dropping ours, so re-attach them to the result instead.
  plugin // extraPassthru // {passthru = plugin.passthru // extraPassthru;}
