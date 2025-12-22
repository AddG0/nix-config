{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true; # better than native direnv nix functionality - https://github.com/nix-community/nix-direnv
    sops-direnv.enable = true;
    lastpass.enable = true;
    onepassword.enable = true;
    silent = true;
  };

  # Global direnvrc - automatically loads per-project non-commited envrc files
  home.file.".config/direnv/direnvrc".text = ''
    # Move .direnv cache outside project directories
    # This prevents JDT/IDE from following symlinks into the Nix store
    # https://github.com/direnv/direnv/wiki/Customizing-cache-location
    : "''${XDG_CACHE_HOME:="''${HOME}/.cache"}"
    declare -A direnv_layout_dirs
    direnv_layout_dir() {
      local hash path
      echo "''${direnv_layout_dirs[$PWD]:=$(
        hash="$(sha1sum - <<< "$PWD" | head -c40)"
        path="''${PWD//[^a-zA-Z0-9]/-}"
        echo "''${XDG_CACHE_HOME}/direnv/layouts/''${hash}''${path}"
      )}"
    }

    # Automatically load .envrc.private for personal secrets (per-project)
    source_env_if_exists ".envrc.private"

    # Optionally: machine-specific overrides (per-project)
    source_env_if_exists ".envrc.local"
  '';

  # Global git ignores for direnv private files
  programs.git.ignores = [
    ".envrc.private"
    ".envrc.local"
  ];
}
