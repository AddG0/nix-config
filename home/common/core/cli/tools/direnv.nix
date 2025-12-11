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
